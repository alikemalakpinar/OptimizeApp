//
//  SharedDataReader.swift
//  OptimizeWidget
//
//  Reads compression stats from App Groups shared container.
//  Mirror of SharedDataService for the widget target.
//

import Foundation

enum WidgetAppGroupConfig {
    static let suiteName = "group.optimized.widget"
}

struct WidgetCompressionData: Codable {
    var totalBytesSaved: Int64
    var totalFilesCompressed: Int
    var averageSavingsPercent: Double
    var lastCompressionDate: Date?
    var weeklyBytesSaved: Int64
    var weeklyFilesCompressed: Int
    var streakDays: Int

    static let empty = WidgetCompressionData(
        totalBytesSaved: 0,
        totalFilesCompressed: 0,
        averageSavingsPercent: 0,
        lastCompressionDate: nil,
        weeklyBytesSaved: 0,
        weeklyFilesCompressed: 0,
        streakDays: 0
    )

    static let preview = WidgetCompressionData(
        totalBytesSaved: 1_250_000_000,
        totalFilesCompressed: 347,
        averageSavingsPercent: 68.5,
        lastCompressionDate: Date(),
        weeklyBytesSaved: 245_000_000,
        weeklyFilesCompressed: 23,
        streakDays: 5
    )
}

enum SharedDataReader {
    private static let key = "widget.compressionData"

    static func read() -> WidgetCompressionData {
        guard let defaults = UserDefaults(suiteName: WidgetAppGroupConfig.suiteName),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetCompressionData.self, from: data) else {
            return .empty
        }
        return decoded
    }
}

// MARK: - Formatting Helpers

enum WidgetFormatter {
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = bytes >= 1_073_741_824 ? [.useGB] : [.useMB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }

    static func formatBytesCompact(_ bytes: Int64) -> (value: String, unit: String) {
        if bytes >= 1_073_741_824 {
            let gb = Double(bytes) / 1_073_741_824
            return (String(format: "%.1f", gb), "GB")
        } else {
            let mb = Double(bytes) / 1_048_576
            return (String(format: "%.0f", mb), "MB")
        }
    }

    static func trendArrow(weekly: Int64, total: Int64) -> String {
        guard total > 0 else { return "" }
        return weekly > 0 ? "arrow.up.right" : "minus"
    }
}
