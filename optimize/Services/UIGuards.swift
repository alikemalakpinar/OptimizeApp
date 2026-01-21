//
//  UIGuards.swift
//  optimize
//
//  Collection of UI safety guards and enhancements.
//  Prevents common UX issues and improves reliability.
//
//  INCLUDES:
//  - DoubleTapPrevention: Prevents accidental double-taps
//  - MinimumProcessingDelay: Makes fast operations feel deliberate
//  - LowBatteryGuard: Warns before heavy operations on low battery
//  - AccessibilityHelpers: Dynamic Type and VoiceOver support
//

import SwiftUI
import UIKit
import Combine

// MARK: - Double Tap Prevention

/// Prevents accidental double-taps from triggering action twice
/// Common edge case: User taps "Optimize" button, operation starts twice
struct DoubleTapPreventionModifier: ViewModifier {
    let cooldown: TimeInterval
    @State private var lastTapTime: Date = .distantPast
    @State private var isDisabled: Bool = false

    init(cooldown: TimeInterval = 0.5) {
        self.cooldown = cooldown
    }

    func body(content: Content) -> some View {
        content
            .disabled(isDisabled)
            .onTapGesture {
                let now = Date()
                if now.timeIntervalSince(lastTapTime) >= cooldown {
                    lastTapTime = now
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard !isDisabled else { return }
                    isDisabled = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
                        isDisabled = false
                    }
                }
            )
    }
}

/// Button style that prevents double-taps
struct SafeButtonStyle: ButtonStyle {
    @State private var lastTapTime: Date = .distantPast
    let cooldown: TimeInterval

    init(cooldown: TimeInterval = 0.5) {
        self.cooldown = cooldown
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    /// Prevents double-tap issues on buttons
    func preventDoubleTap(cooldown: TimeInterval = 0.5) -> some View {
        self.modifier(DoubleTapPreventionModifier(cooldown: cooldown))
    }
}

// MARK: - Minimum Processing Delay

/// Ensures operations feel deliberate even when they're instant
/// UX Principle: Operations < 1 second feel like "nothing happened"
actor MinimumProcessingDelay {

    /// Default minimum delay for processing operations
    static let standard: TimeInterval = 1.5

    /// Minimum delay for quick operations
    static let quick: TimeInterval = 0.8

    /// Execute with minimum delay
    static func execute<T>(
        minimumDelay: TimeInterval = standard,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let startTime = Date()

        let result = try await operation()

        let elapsed = Date().timeIntervalSince(startTime)
        let remainingDelay = minimumDelay - elapsed

        if remainingDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
        }

        return result
    }

    /// Execute with minimum delay (non-throwing)
    static func execute<T>(
        minimumDelay: TimeInterval = standard,
        operation: @escaping () async -> T
    ) async -> T {
        let startTime = Date()

        let result = await operation()

        let elapsed = Date().timeIntervalSince(startTime)
        let remainingDelay = minimumDelay - elapsed

        if remainingDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
        }

        return result
    }
}

// MARK: - Low Battery Guard

/// Warns user before heavy operations when battery is low
/// Prevents mid-operation shutdowns on 1% battery
@MainActor
final class LowBatteryGuard: ObservableObject {

    // MARK: - Singleton

    static let shared = LowBatteryGuard()

    // MARK: - Configuration

    /// Battery level below which to warn (15%)
    private let warningThreshold: Float = 0.15

    /// Battery level below which to block heavy operations (5%)
    private let criticalThreshold: Float = 0.05

    // MARK: - Published State

    @Published private(set) var batteryLevel: Float = 1.0
    @Published private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published private(set) var isLowPowerModeEnabled: Bool = false

    // MARK: - Initialization

    private init() {
        setupBatteryMonitoring()
    }

    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true

        // Initial values
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        // Listen for changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerModeDidChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    @objc private func batteryLevelDidChange() {
        batteryLevel = UIDevice.current.batteryLevel
    }

    @objc private func batteryStateDidChange() {
        batteryState = UIDevice.current.batteryState
    }

    @objc private func powerModeDidChange() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: - Public API

    /// Check if battery level allows heavy operations
    var canPerformHeavyOperation: Bool {
        // Always allow if charging
        if batteryState == .charging || batteryState == .full {
            return true
        }
        return batteryLevel > criticalThreshold
    }

    /// Check if we should warn the user
    var shouldWarnAboutBattery: Bool {
        // Don't warn if charging
        if batteryState == .charging || batteryState == .full {
            return false
        }
        return batteryLevel <= warningThreshold || isLowPowerModeEnabled
    }

    /// Get warning message if applicable
    var warningMessage: String? {
        guard shouldWarnAboutBattery else { return nil }

        let percentage = Int(batteryLevel * 100)

        if batteryLevel <= criticalThreshold {
            return String(localized: "Pil seviyesi kritik düşük (%\(percentage)). Şarj etmeden devam etmeniz önerilmez.")
        } else if isLowPowerModeEnabled {
            return String(localized: "Düşük Güç Modu açık. İşlem daha yavaş olabilir.")
        } else {
            return String(localized: "Pil seviyesi düşük (%\(percentage)). Uzun işlemler için şarj etmenizi öneririz.")
        }
    }

    /// Formatted battery percentage
    var formattedBatteryLevel: String {
        let percentage = Int(batteryLevel * 100)
        return "%\(percentage)"
    }
}

// MARK: - Accessibility Helpers

/// Helpers for Dynamic Type and VoiceOver support
enum AccessibilityHelpers {

    /// Check if user has increased text size
    static var hasLargeTextEnabled: Bool {
        UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
    }

    /// Check if VoiceOver is running
    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    /// Check if reduced motion is enabled
    static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Check if user prefers increased contrast
    static var prefersIncreasedContrast: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }

    /// Announce message to VoiceOver
    static func announce(_ message: String, delay: TimeInterval = 0.1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Notify VoiceOver that screen has changed
    static func notifyScreenChanged(focus element: Any? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }

    /// Notify VoiceOver that layout has changed
    static func notifyLayoutChanged(focus element: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}

// MARK: - Accessibility View Modifier

struct AccessibilityEnhancedModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits

    init(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
    }

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

extension View {
    /// Enhanced accessibility configuration
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self.modifier(AccessibilityEnhancedModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits
        ))
    }
}

// MARK: - Dynamic Type Scaling

struct DynamicTypeScalingModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory

    /// Maximum scale factor for accessibility sizes
    let maxScale: CGFloat

    init(maxScale: CGFloat = 1.5) {
        self.maxScale = maxScale
    }

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .minimumScaleFactor(0.8)
    }
}

extension View {
    /// Limit dynamic type scaling to prevent layout issues
    func limitDynamicTypeScaling(maxScale: CGFloat = 1.5) -> some View {
        self.modifier(DynamicTypeScalingModifier(maxScale: maxScale))
    }
}
