//
//  HapticManager.swift
//  optimize
//
//  Centralized haptic feedback system for premium tactile experience.
//  Provides consistent haptic patterns across the app.
//
//  PHILOSOPHY:
//  - Different haptics for different actions create "premium feel"
//  - Success should feel rewarding
//  - Errors should feel distinct but not jarring
//  - Interactions should feel responsive
//

import UIKit
import CoreHaptics

// MARK: - Haptic Type

enum HapticType {
    // Basic feedback
    case selection          // Light tap for selections
    case light              // Subtle feedback
    case medium             // Standard feedback
    case heavy              // Strong feedback

    // Contextual feedback
    case success            // Completion, achievement
    case warning            // Caution, attention needed
    case error              // Something went wrong

    // Custom patterns
    case compression        // During compression progress
    case complete           // Task completed
    case celebration        // Achievement unlocked
    case buttonPress        // Button tap
    case toggle             // Switch toggle
    case slider             // Slider value change
    case notification       // Alert notification
}

// MARK: - Haptic Manager

final class HapticManager {

    // MARK: - Singleton

    static let shared = HapticManager()

    // MARK: - Properties

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Initialization

    private init() {
        setupHapticEngine()
        prepareGenerators()
    }

    private func setupHapticEngine() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        guard supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.playsHapticsOnly = true
            engine?.isAutoShutdownEnabled = true

            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }

            try engine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }

    private func prepareGenerators() {
        selectionGenerator.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Public Interface

    /// Trigger haptic feedback
    func trigger(_ type: HapticType) {
        switch type {
        case .selection:
            selectionGenerator.selectionChanged()

        case .light:
            impactLight.impactOccurred()

        case .medium:
            impactMedium.impactOccurred()

        case .heavy:
            impactHeavy.impactOccurred()

        case .success:
            notificationGenerator.notificationOccurred(.success)

        case .warning:
            notificationGenerator.notificationOccurred(.warning)

        case .error:
            notificationGenerator.notificationOccurred(.error)

        case .compression:
            playCompressionPattern()

        case .complete:
            playCompletePattern()

        case .celebration:
            playCelebrationPattern()

        case .buttonPress:
            impactSoft.impactOccurred(intensity: 0.7)

        case .toggle:
            impactRigid.impactOccurred(intensity: 0.6)

        case .slider:
            selectionGenerator.selectionChanged()

        case .notification:
            impactMedium.impactOccurred()
        }
    }

    /// Trigger haptic with custom intensity (0.0 - 1.0)
    func trigger(_ type: HapticType, intensity: CGFloat) {
        let clampedIntensity = max(0, min(1, intensity))

        switch type {
        case .light:
            impactLight.impactOccurred(intensity: clampedIntensity)
        case .medium:
            impactMedium.impactOccurred(intensity: clampedIntensity)
        case .heavy:
            impactHeavy.impactOccurred(intensity: clampedIntensity)
        default:
            trigger(type)
        }
    }

    // MARK: - Custom Patterns

    /// Pulsing pattern during compression
    private func playCompressionPattern() {
        guard supportsHaptics, let engine = engine else {
            impactSoft.impactOccurred(intensity: 0.5)
            return
        }

        do {
            let pattern = try createCompressionPattern()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            impactSoft.impactOccurred(intensity: 0.5)
        }
    }

    /// Satisfying completion pattern
    private func playCompletePattern() {
        guard supportsHaptics, let engine = engine else {
            notificationGenerator.notificationOccurred(.success)
            return
        }

        do {
            let pattern = try createCompletePattern()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            notificationGenerator.notificationOccurred(.success)
        }
    }

    /// Celebration pattern for achievements
    private func playCelebrationPattern() {
        guard supportsHaptics, let engine = engine else {
            // Fallback: Multiple impacts
            Task {
                for i in 0..<3 {
                    impactMedium.impactOccurred(intensity: 0.8)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            return
        }

        do {
            let pattern = try createCelebrationPattern()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            notificationGenerator.notificationOccurred(.success)
        }
    }

    // MARK: - Pattern Creation

    private func createCompressionPattern() throws -> CHHapticPattern {
        let events: [CHHapticEvent] = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0.05,
                duration: 0.1
            )
        ]

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createCompletePattern() throws -> CHHapticPattern {
        let events: [CHHapticEvent] = [
            // Initial impact
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            ),
            // Rising feedback
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.1
            ),
            // Final satisfying tap
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0.2
            )
        ]

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createCelebrationPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        // Create a burst of haptics
        for i in 0..<5 {
            let time = Double(i) * 0.08
            let intensity = Float(0.5 + Double(i) * 0.1)

            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: time
                )
            )
        }

        // Final big impact
        events.append(
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0.5
            )
        )

        return try CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - Progress Haptics

    /// Provide haptic feedback during progress (call periodically)
    func progressTick(progress: Double) {
        // Only trigger at certain milestones
        let milestones = [0.25, 0.5, 0.75, 1.0]

        for milestone in milestones {
            if abs(progress - milestone) < 0.01 {
                impactLight.impactOccurred(intensity: CGFloat(milestone))
                break
            }
        }
    }
}

// MARK: - SwiftUI View Extension

import SwiftUI

extension View {
    /// Add haptic feedback on tap
    func hapticOnTap(_ type: HapticType = .selection) -> some View {
        self.onTapGesture {
            HapticManager.shared.trigger(type)
        }
    }

    /// Add haptic feedback on change
    func hapticOnChange<T: Equatable>(of value: T, type: HapticType = .selection) -> some View {
        self.onChange(of: value) { _, _ in
            HapticManager.shared.trigger(type)
        }
    }
}
