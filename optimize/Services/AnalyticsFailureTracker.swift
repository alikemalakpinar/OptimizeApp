//
//  AnalyticsFailureTracker.swift
//  optimize
//
//  Tracks compression failures for debugging and product improvement.
//  Helps identify which file types/sizes are problematic.
//
//  PRIVACY:
//  - No file content is ever logged
//  - Only metadata (size, type, error) is tracked
//  - Data is aggregated locally
//  - User can opt out via Settings
//
//  USE CASES:
//  - Identify problematic file types
//  - Track success/failure rates by preset
//  - Detect patterns in crashes
//  - Measure improvement over releases
//

import Foundation

// MARK: - Failure Type

enum CompressionFailureType: String, Codable {
    case fileValidation = "file_validation"
    case diskSpace = "disk_space"
    case memoryPressure = "memory_pressure"
    case timeout = "timeout"
    case corruptedInput = "corrupted_input"
    case encodingError = "encoding_error"
    case unknownError = "unknown_error"
    case cancelled = "cancelled"
    case passwordProtected = "password_protected"
    case unsupportedFormat = "unsupported_format"
    case noCompression = "no_compression" // Output >= Input
}

// MARK: - Failure Record

struct FailureRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let failureType: CompressionFailureType
    let fileType: String // pdf, mp4, jpg, etc.
    let fileSizeMB: Double
    let pageCount: Int? // For PDFs
    let duration: TimeInterval? // For videos
    let presetId: String?
    let errorMessage: String?
    let deviceModel: String
    let osVersion: String
    let appVersion: String

    init(
        failureType: CompressionFailureType,
        fileType: String,
        fileSizeMB: Double,
        pageCount: Int? = nil,
        duration: TimeInterval? = nil,
        presetId: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.failureType = failureType
        self.fileType = fileType
        self.fileSizeMB = fileSizeMB
        self.pageCount = pageCount
        self.duration = duration
        self.presetId = presetId
        self.errorMessage = errorMessage

        // Device info (non-identifying)
        var systemInfo = utsname()
        uname(&systemInfo)
        self.deviceModel = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - Analytics Statistics

struct FailureStatistics: Codable {
    var totalAttempts: Int = 0
    var totalSuccesses: Int = 0
    var totalFailures: Int = 0

    var failuresByType: [CompressionFailureType: Int] = [:]
    var failuresByFileType: [String: Int] = [:]

    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalSuccesses) / Double(totalAttempts) * 100
    }

    var failureRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalFailures) / Double(totalAttempts) * 100
    }

    mutating func recordSuccess() {
        totalAttempts += 1
        totalSuccesses += 1
    }

    mutating func recordFailure(type: CompressionFailureType, fileType: String) {
        totalAttempts += 1
        totalFailures += 1
        failuresByType[type, default: 0] += 1
        failuresByFileType[fileType, default: 0] += 1
    }

    /// Most common failure type
    var topFailureType: CompressionFailureType? {
        failuresByType.max(by: { $0.value < $1.value })?.key
    }

    /// Most problematic file type
    var mostProblematicFileType: String? {
        failuresByFileType.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Analytics Failure Tracker

final class AnalyticsFailureTracker {

    // MARK: - Singleton

    static let shared = AnalyticsFailureTracker()

    // MARK: - Configuration

    private let maxRecordsToKeep = 100
    private let storageKey = "com.optimize.failureRecords"
    private let statisticsKey = "com.optimize.failureStatistics"

    // MARK: - State

    private var records: [FailureRecord] = []
    private var statistics: FailureStatistics = FailureStatistics()

    // MARK: - Initialization

    private init() {
        loadRecords()
        loadStatistics()
    }

    // MARK: - Public API

    /// Record a successful compression
    func recordSuccess(fileType: String, fileSizeMB: Double, presetId: String?) {
        statistics.recordSuccess()
        saveStatistics()

        #if DEBUG
        print("📊 [Analytics] Success recorded. Rate: \(String(format: "%.1f", statistics.successRate))%")
        #endif
    }

    /// Record a compression failure
    func recordFailure(
        type: CompressionFailureType,
        fileType: String,
        fileSizeMB: Double,
        pageCount: Int? = nil,
        duration: TimeInterval? = nil,
        presetId: String? = nil,
        errorMessage: String? = nil
    ) {
        // Update statistics
        statistics.recordFailure(type: type, fileType: fileType)
        saveStatistics()

        // Create record
        let record = FailureRecord(
            failureType: type,
            fileType: fileType,
            fileSizeMB: fileSizeMB,
            pageCount: pageCount,
            duration: duration,
            presetId: presetId,
            errorMessage: errorMessage
        )

        // Add to records
        records.append(record)

        // Trim if too many
        if records.count > maxRecordsToKeep {
            records = Array(records.suffix(maxRecordsToKeep))
        }

        saveRecords()

        #if DEBUG
        print("📊 [Analytics] Failure recorded: \(type.rawValue) for \(fileType)")
        print("   - Failure rate: \(String(format: "%.1f", statistics.failureRate))%")
        print("   - Top failure type: \(statistics.topFailureType?.rawValue ?? "none")")
        #endif
    }

    /// Get current statistics
    func getStatistics() -> FailureStatistics {
        return statistics
    }

    /// Get recent failure records
    func getRecentFailures(limit: Int = 10) -> [FailureRecord] {
        return Array(records.suffix(limit).reversed())
    }

    /// Get failures by type
    func getFailures(ofType type: CompressionFailureType) -> [FailureRecord] {
        return records.filter { $0.failureType == type }
    }

    /// Reset all analytics data
    func resetData() {
        records = []
        statistics = FailureStatistics()
        saveRecords()
        saveStatistics()
    }

    // MARK: - Persistence

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FailureRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func saveRecords() {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    private func loadStatistics() {
        guard let data = UserDefaults.standard.data(forKey: statisticsKey),
              let decoded = try? JSONDecoder().decode(FailureStatistics.self, from: data) else {
            return
        }
        statistics = decoded
    }

    private func saveStatistics() {
        guard let encoded = try? JSONEncoder().encode(statistics) else { return }
        UserDefaults.standard.set(encoded, forKey: statisticsKey)
    }
}

// MARK: - Debug View (for Settings)

#if DEBUG
import SwiftUI

struct FailureAnalyticsDebugView: View {
    let tracker = AnalyticsFailureTracker.shared

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Total Attempts", value: "\(tracker.getStatistics().totalAttempts)")
                LabeledContent("Success Rate", value: String(format: "%.1f%%", tracker.getStatistics().successRate))
                LabeledContent("Failure Rate", value: String(format: "%.1f%%", tracker.getStatistics().failureRate))
            }

            Section("Top Failures") {
                if let topType = tracker.getStatistics().topFailureType {
                    LabeledContent("Type", value: topType.rawValue)
                }
                if let topFileType = tracker.getStatistics().mostProblematicFileType {
                    LabeledContent("File Type", value: topFileType)
                }
            }

            Section("Recent Failures") {
                ForEach(tracker.getRecentFailures()) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.failureType.rawValue)
                            .font(.headline)
                        Text("\(record.fileType) • \(String(format: "%.1f", record.fileSizeMB)) MB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let error = record.errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button("Reset Analytics", role: .destructive) {
                    tracker.resetData()
                }
            }
        }
        .navigationTitle("Failure Analytics")
    }
}
#endif
