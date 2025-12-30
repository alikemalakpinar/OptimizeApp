//
//  AnalyticsService.swift
//  optimize
//
//  Analytics service for tracking app usage and events
//

import Foundation

// MARK: - Analytics Event Types
enum AnalyticsEvent: String {
    // Onboarding
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"

    // File Operations
    case fileSelected = "file_selected"
    case fileAnalysisStarted = "file_analysis_started"
    case fileAnalysisCompleted = "file_analysis_completed"

    // Compression
    case compressionStarted = "compression_started"
    case compressionCompleted = "compression_completed"
    case compressionFailed = "compression_failed"
    case compressionRetried = "compression_retried"

    // Presets
    case presetSelected = "preset_selected"
    case customPresetUsed = "custom_preset_used"

    // Sharing
    case fileShared = "file_shared"
    case fileSaved = "file_saved"

    // Paywall
    case paywallViewed = "paywall_viewed"
    case subscriptionStarted = "subscription_started"
    case subscriptionRestored = "subscription_restored"

    // Settings
    case settingsOpened = "settings_opened"
    case settingChanged = "setting_changed"

    // Errors
    case errorOccurred = "error_occurred"
}

// MARK: - Analytics Service
@MainActor
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    // Check if analytics is enabled via UserDefaults (synced with SettingsScreen)
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enableAnalytics")
    }

    private init() {}

    // MARK: - Event Tracking

    /// Track a simple event without parameters
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }

        let eventData: [String: Any] = [
            "event": event.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "iOS",
            "app_version": appVersion
        ]

        logEvent(eventData)

        // TODO: Send to analytics backend when implemented
        // sendToBackend(eventData)
    }

    /// Track an event with custom parameters
    func track(_ event: AnalyticsEvent, parameters: [String: Any]) {
        guard isEnabled else { return }

        var eventData: [String: Any] = [
            "event": event.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "iOS",
            "app_version": appVersion
        ]

        // Merge custom parameters
        for (key, value) in parameters {
            eventData[key] = value
        }

        logEvent(eventData)

        // TODO: Send to analytics backend when implemented
        // sendToBackend(eventData)
    }

    // MARK: - Convenience Methods

    /// Track file selection with file info
    func trackFileSelected(fileName: String, fileSize: Int64) {
        track(.fileSelected, parameters: [
            "file_name": fileName,
            "file_size_bytes": fileSize,
            "file_size_mb": Double(fileSize) / 1_000_000
        ])
    }

    /// Track compression completion with results
    func trackCompressionCompleted(
        originalSize: Int64,
        compressedSize: Int64,
        savingsPercent: Int,
        presetId: String,
        duration: TimeInterval
    ) {
        track(.compressionCompleted, parameters: [
            "original_size_bytes": originalSize,
            "compressed_size_bytes": compressedSize,
            "savings_percent": savingsPercent,
            "preset_id": presetId,
            "duration_seconds": duration
        ])
    }

    /// Track compression failure with error info
    func trackCompressionFailed(error: Error, presetId: String) {
        track(.compressionFailed, parameters: [
            "error_message": error.localizedDescription,
            "preset_id": presetId
        ])
    }

    /// Track preset selection
    func trackPresetSelected(presetId: String, isCustom: Bool = false) {
        if isCustom {
            track(.customPresetUsed, parameters: ["preset_id": presetId])
        } else {
            track(.presetSelected, parameters: ["preset_id": presetId])
        }
    }

    /// Track settings change
    func trackSettingChanged(setting: String, newValue: Any) {
        track(.settingChanged, parameters: [
            "setting_name": setting,
            "new_value": "\(newValue)"
        ])
    }

    /// Track error occurrence
    func trackError(_ error: Error, context: String) {
        track(.errorOccurred, parameters: [
            "error_message": error.localizedDescription,
            "context": context
        ])
    }

    // MARK: - Private Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func logEvent(_ eventData: [String: Any]) {
        #if DEBUG
        print("[Analytics] \(eventData)")
        #endif
    }

    // Placeholder for future backend integration
    // private func sendToBackend(_ eventData: [String: Any]) {
    //     // Implementation for Firebase, Mixpanel, or custom backend
    // }
}

// MARK: - Analytics Helper Extension for AppCoordinator
extension AnalyticsService {
    /// Track full compression flow
    func trackCompressionFlow(
        file: FileInfo,
        preset: CompressionPreset,
        result: CompressionResult?,
        error: Error?,
        startTime: Date
    ) {
        let duration = Date().timeIntervalSince(startTime)

        if let result = result {
            trackCompressionCompleted(
                originalSize: file.size,
                compressedSize: result.compressedSize,
                savingsPercent: result.savingsPercent,
                presetId: preset.id,
                duration: duration
            )
        } else if let error = error {
            trackCompressionFailed(error: error, presetId: preset.id)
        }
    }
}

