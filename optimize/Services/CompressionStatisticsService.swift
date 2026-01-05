//
//  CompressionStatisticsService.swift
//  optimize
//
//  Compression usage statistics and analytics
//  Tracks total savings, compression ratios, file types, and trends
//

import Foundation
import SwiftUI

// MARK: - Compression Statistics Service

@MainActor
final class CompressionStatisticsService: ObservableObject {
    static let shared = CompressionStatisticsService()

    // MARK: - Configuration

    private let statsFileName = "compression_statistics.json"
    private let dailyStatsFileName = "daily_statistics.json"

    // MARK: - Background Queue

    private let saveQueue = DispatchQueue(label: "com.optimize.statistics", qos: .utility)

    // MARK: - Published State

    @Published private(set) var stats = CompressionStats()
    @Published private(set) var dailyStats: [DailyStats] = []
    @Published private(set) var fileTypeStats: [FileTypeStats] = []

    // MARK: - Initialization

    private init() {
        loadStats()
    }

    // MARK: - Public API

    /// Record a compression result
    func recordCompression(result: CompressionResult, preset: CompressionPreset) {
        let bytesSaved = result.originalFile.size - result.compressedSize
        let fileExtension = URL(fileURLWithPath: result.originalFile.name).pathExtension.lowercased()

        // Update overall stats
        stats.totalFilesCompressed += 1
        stats.totalBytesProcessed += result.originalFile.size
        stats.totalBytesSaved += bytesSaved
        // Note: processingTime tracked separately if needed

        // Update file type stats
        updateFileTypeStats(extension: fileExtension, bytesSaved: bytesSaved, originalSize: result.originalFile.size)

        // Update daily stats
        updateDailyStats(bytesSaved: bytesSaved, filesProcessed: 1)

        // Update best/worst compression
        let ratio = Double(bytesSaved) / Double(result.originalFile.size) * 100
        if ratio > stats.bestCompressionRatio {
            stats.bestCompressionRatio = ratio
            stats.bestCompressionFile = result.originalFile.name
        }
        if stats.worstCompressionRatio == 0 || (ratio < stats.worstCompressionRatio && ratio > 0) {
            stats.worstCompressionRatio = ratio
            stats.worstCompressionFile = result.originalFile.name
        }

        // Update preset usage
        stats.presetUsage[preset.id, default: 0] += 1

        // Update streaks
        updateStreaks()

        saveStatsAsync()
    }

    /// Get compression trend for last N days
    func getCompressionTrend(days: Int = 7) -> [TrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).reversed().map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return TrendPoint(date: today, value: 0)
            }

            let saved = dailyStats
                .first { calendar.isDate($0.date, inSameDayAs: date) }?
                .bytesSaved ?? 0

            return TrendPoint(date: date, value: Double(saved))
        }
    }

    /// Get file type distribution
    func getFileTypeDistribution() -> [PieSlice] {
        let total = fileTypeStats.reduce(0) { $0 + $1.count }
        guard total > 0 else { return [] }

        return fileTypeStats.prefix(5).map { stat in
            PieSlice(
                label: stat.fileType.uppercased(),
                value: Double(stat.count) / Double(total),
                color: colorForFileType(stat.fileType)
            )
        }
    }

    /// Reset all statistics
    func resetStatistics() {
        stats = CompressionStats()
        dailyStats = []
        fileTypeStats = []
        saveStatsAsync()
    }

    /// Get achievement progress
    func getAchievements() -> [StatisticsAchievement] {
        var achievements: [StatisticsAchievement] = []

        // Space Saver achievements
        achievements.append(StatisticsAchievement(
            id: "space_saver_1",
            title: "Alan Kurtarici",
            description: "100 MB tasarruf et",
            icon: "externaldrive.fill",
            progress: min(1.0, Double(stats.totalBytesSaved) / (100 * 1024 * 1024)),
            isUnlocked: stats.totalBytesSaved >= 100 * 1024 * 1024
        ))

        achievements.append(StatisticsAchievement(
            id: "space_saver_2",
            title: "Depolama Ustasi",
            description: "1 GB tasarruf et",
            icon: "externaldrive.fill.badge.checkmark",
            progress: min(1.0, Double(stats.totalBytesSaved) / (1024 * 1024 * 1024)),
            isUnlocked: stats.totalBytesSaved >= 1024 * 1024 * 1024
        ))

        // File count achievements
        achievements.append(StatisticsAchievement(
            id: "file_master_1",
            title: "Ilk Adim",
            description: "10 dosya sikistir",
            icon: "doc.on.doc",
            progress: min(1.0, Double(stats.totalFilesCompressed) / 10),
            isUnlocked: stats.totalFilesCompressed >= 10
        ))

        achievements.append(StatisticsAchievement(
            id: "file_master_2",
            title: "Dosya Ustasi",
            description: "100 dosya sikistir",
            icon: "doc.on.doc.fill",
            progress: min(1.0, Double(stats.totalFilesCompressed) / 100),
            isUnlocked: stats.totalFilesCompressed >= 100
        ))

        // Streak achievements
        achievements.append(StatisticsAchievement(
            id: "streak_1",
            title: "Duzenli Kullanici",
            description: "7 gun ust uste kullan",
            icon: "flame",
            progress: min(1.0, Double(stats.currentStreak) / 7),
            isUnlocked: stats.longestStreak >= 7
        ))

        // Efficiency achievement
        let avgRatio = stats.averageCompressionRatio
        achievements.append(StatisticsAchievement(
            id: "efficiency_1",
            title: "Verimlilik Usta",
            description: "Ortalama %50+ sikistirma orani",
            icon: "bolt.fill",
            progress: min(1.0, avgRatio / 50),
            isUnlocked: avgRatio >= 50
        ))

        return achievements
    }

    // MARK: - Private Methods

    private func updateFileTypeStats(extension ext: String, bytesSaved: Int64, originalSize: Int64) {
        let fileType = ext.isEmpty ? "other" : ext

        if let index = fileTypeStats.firstIndex(where: { $0.fileType == fileType }) {
            fileTypeStats[index].count += 1
            fileTypeStats[index].totalBytesSaved += bytesSaved
            fileTypeStats[index].totalBytesProcessed += originalSize
        } else {
            fileTypeStats.append(FileTypeStats(
                fileType: fileType,
                count: 1,
                totalBytesSaved: bytesSaved,
                totalBytesProcessed: originalSize
            ))
        }

        // Sort by count
        fileTypeStats.sort { $0.count > $1.count }
    }

    private func updateDailyStats(bytesSaved: Int64, filesProcessed: Int) {
        let today = Calendar.current.startOfDay(for: Date())

        if let index = dailyStats.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            dailyStats[index].bytesSaved += bytesSaved
            dailyStats[index].filesProcessed += filesProcessed
        } else {
            dailyStats.append(DailyStats(
                date: today,
                bytesSaved: bytesSaved,
                filesProcessed: filesProcessed
            ))
        }

        // Keep only last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: today) ?? today
        dailyStats.removeAll { $0.date < cutoff }

        // Sort by date
        dailyStats.sort { $0.date > $1.date }
    }

    private func updateStreaks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if we have activity today
        let hasActivityToday = dailyStats.contains { calendar.isDate($0.date, inSameDayAs: today) }

        if hasActivityToday {
            // Check if we had activity yesterday
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            let hadActivityYesterday = dailyStats.contains { calendar.isDate($0.date, inSameDayAs: yesterday) }

            if hadActivityYesterday || stats.currentStreak == 0 {
                // Continue or start streak
                if stats.lastActivityDate == nil || !calendar.isDate(stats.lastActivityDate!, inSameDayAs: today) {
                    stats.currentStreak += 1
                }
            } else if stats.lastActivityDate == nil || !calendar.isDate(stats.lastActivityDate!, inSameDayAs: yesterday) {
                // Reset streak
                stats.currentStreak = 1
            }

            stats.lastActivityDate = today

            if stats.currentStreak > stats.longestStreak {
                stats.longestStreak = stats.currentStreak
            }
        }
    }

    private func colorForFileType(_ type: String) -> Color {
        switch type.lowercased() {
        case "pdf": return .red
        case "jpg", "jpeg", "png", "heic": return .blue
        case "mp4", "mov": return .purple
        case "doc", "docx": return .indigo
        case "xls", "xlsx": return .green
        case "ppt", "pptx": return .orange
        default: return .gray
        }
    }

    // MARK: - Persistence

    private func getStatsFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(statsFileName)
    }

    private func getDailyStatsFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(dailyStatsFileName)
    }

    private func loadStats() {
        // Load main stats
        if let data = try? Data(contentsOf: getStatsFileURL()),
           let decoded = try? JSONDecoder().decode(CompressionStats.self, from: data) {
            stats = decoded
        }

        // Load daily stats
        if let data = try? Data(contentsOf: getDailyStatsFileURL()),
           let decoded = try? JSONDecoder().decode(StoredDailyStats.self, from: data) {
            dailyStats = decoded.daily
            fileTypeStats = decoded.fileTypes
        }
    }

    private func saveStatsAsync() {
        let statsToSave = stats
        let dailyToSave = StoredDailyStats(daily: dailyStats, fileTypes: fileTypeStats)
        let statsURL = getStatsFileURL()
        let dailyURL = getDailyStatsFileURL()

        saveQueue.async {
            if let data = try? JSONEncoder().encode(statsToSave) {
                try? data.write(to: statsURL, options: .atomic)
            }

            if let data = try? JSONEncoder().encode(dailyToSave) {
                try? data.write(to: dailyURL, options: .atomic)
            }
        }
    }
}

// MARK: - Supporting Types

struct CompressionStats: Codable, Equatable {
    var totalFilesCompressed: Int = 0
    var totalBytesProcessed: Int64 = 0
    var totalBytesSaved: Int64 = 0
    var totalCompressionTime: TimeInterval = 0

    var bestCompressionRatio: Double = 0
    var bestCompressionFile: String = ""
    var worstCompressionRatio: Double = 0
    var worstCompressionFile: String = ""

    var presetUsage: [String: Int] = [:]

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActivityDate: Date?

    var averageCompressionRatio: Double {
        guard totalBytesProcessed > 0 else { return 0 }
        return Double(totalBytesSaved) / Double(totalBytesProcessed) * 100
    }

    var formattedTotalSaved: String {
        ByteCountFormatter.string(fromByteCount: totalBytesSaved, countStyle: .file)
    }

    var formattedTotalProcessed: String {
        ByteCountFormatter.string(fromByteCount: totalBytesProcessed, countStyle: .file)
    }

    var averageProcessingTime: TimeInterval {
        guard totalFilesCompressed > 0 else { return 0 }
        return totalCompressionTime / Double(totalFilesCompressed)
    }
}

struct DailyStats: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    var bytesSaved: Int64
    var filesProcessed: Int

    var formattedSaved: String {
        ByteCountFormatter.string(fromByteCount: bytesSaved, countStyle: .file)
    }
}

struct FileTypeStats: Codable, Identifiable {
    var id: String { fileType }
    let fileType: String
    var count: Int
    var totalBytesSaved: Int64
    var totalBytesProcessed: Int64

    var averageRatio: Double {
        guard totalBytesProcessed > 0 else { return 0 }
        return Double(totalBytesSaved) / Double(totalBytesProcessed) * 100
    }
}

private struct StoredDailyStats: Codable {
    let daily: [DailyStats]
    let fileTypes: [FileTypeStats]
}

struct TrendPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct PieSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct StatisticsAchievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let progress: Double
    let isUnlocked: Bool
}
