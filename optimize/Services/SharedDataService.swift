//
//  SharedDataService.swift
//  optimize
//
//  Shared data layer for App Groups — enables widget extension to read compression stats.
//  Both the main app and widget extension use this service to access shared UserDefaults.
//

import Foundation

/// App Groups identifier shared between main app and widget extension
enum AppGroupConfig {
    static let suiteName = "group.optimized.widget"
}

/// Data model for widget-readable compression statistics
struct WidgetData: Codable {
    var totalBytesSaved: Int64
    var totalFilesCompressed: Int
    var averageSavingsPercent: Double
    var lastCompressionDate: Date?
    var weeklyBytesSaved: Int64
    var weeklyFilesCompressed: Int
    var streakDays: Int

    static let empty = WidgetData(
        totalBytesSaved: 0,
        totalFilesCompressed: 0,
        averageSavingsPercent: 0,
        lastCompressionDate: nil,
        weeklyBytesSaved: 0,
        weeklyFilesCompressed: 0,
        streakDays: 0
    )
}

/// Service that writes compression stats to App Groups shared container
/// so the widget extension can read them.
final class SharedDataService {
    static let shared = SharedDataService()

    private let defaults: UserDefaults?
    private let key = "widget.compressionData"

    private init() {
        defaults = UserDefaults(suiteName: AppGroupConfig.suiteName)
    }

    /// Write current stats to shared container (call after each compression)
    func updateWidgetData(_ data: WidgetData) {
        guard let defaults = defaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
        }
    }

    /// Read stats from shared container (used by widget)
    func readWidgetData() -> WidgetData {
        guard let defaults = defaults,
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .empty
        }
        return decoded
    }

    /// Convenience: sync from CompressionStatisticsService
    func syncFromStatistics(
        totalBytesSaved: Int64,
        totalFilesCompressed: Int,
        averageSavingsPercent: Double,
        lastDate: Date?,
        weeklyBytesSaved: Int64,
        weeklyFiles: Int,
        streak: Int
    ) {
        let data = WidgetData(
            totalBytesSaved: totalBytesSaved,
            totalFilesCompressed: totalFilesCompressed,
            averageSavingsPercent: averageSavingsPercent,
            lastCompressionDate: lastDate,
            weeklyBytesSaved: weeklyBytesSaved,
            weeklyFilesCompressed: weeklyFiles,
            streakDays: streak
        )
        updateWidgetData(data)
    }
}
