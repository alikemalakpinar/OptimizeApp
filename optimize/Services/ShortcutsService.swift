//
//  ShortcutsService.swift
//  optimize
//
//  Siri Shortcuts integration via AppIntents framework.
//  Provides quick actions for compression, batch processing, and storage reports.
//
//  INTENTS:
//  - CompressFileIntent: Open app to compress a file
//  - QuickOptimizeIntent: Launch batch optimization for photos
//  - StorageReportIntent: Get storage savings summary
//
//  SHORTCUTS GALLERY:
//  - "Haftalık Temizlik" — Batch optimize all screenshots
//  - "Hızlı Sıkıştır" — Open file picker for compression
//  - "Depolama Raporu" — Show total savings
//

import AppIntents
import SwiftUI

// MARK: - Compress File Intent

/// Opens the app to compress a file — appears in Shortcuts gallery
struct CompressFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Dosya Sıkıştır"
    static var description = IntentDescription(
        "Optimize uygulamasını açarak dosya sıkıştırma işlemi başlatır.",
        categoryName: "Sıkıştırma"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // App will open to the file picker automatically
        return .result()
    }
}

// MARK: - Quick Optimize Intent (Batch Photos)

/// Launches batch optimization for photos from Shortcuts
struct QuickOptimizeIntent: AppIntent {
    static var title: LocalizedStringResource = "Fotoğrafları Optimize Et"
    static var description = IntentDescription(
        "Galerideki fotoğrafları toplu olarak optimize eder.",
        categoryName: "Sıkıştırma"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Navigate to batch processing screen
        await MainActor.run {
            NotificationCenter.default.post(
                name: .shortcutBatchOptimize,
                object: nil
            )
        }
        return .result()
    }
}

// MARK: - Storage Report Intent

/// Returns a text summary of compression savings — works without opening app
struct StorageReportIntent: AppIntent {
    static var title: LocalizedStringResource = "Depolama Raporu"
    static var description = IntentDescription(
        "Toplam sıkıştırma tasarrufu özetini gösterir.",
        categoryName: "Analiz"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let data = SharedDataService.shared.readWidgetData()

        let totalSaved = ByteCountFormatter.string(fromByteCount: data.totalBytesSaved, countStyle: .file)
        let weekSaved = ByteCountFormatter.string(fromByteCount: data.weeklyBytesSaved, countStyle: .file)
        let avgPercent = String(format: "%.0f", data.averageSavingsPercent)

        let report = """
        📊 Optimize Depolama Raporu

        Toplam tasarruf: \(totalSaved)
        Bu hafta: \(weekSaved)
        Sıkıştırılan dosya: \(data.totalFilesCompressed)
        Ortalama tasarruf: %\(avgPercent)
        Gün serisi: \(data.streakDays)
        """

        return .result(value: report)
    }
}

// MARK: - App Shortcuts Provider

/// Provides pre-built shortcuts for the Shortcuts gallery
struct OptimizeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompressFileIntent(),
            phrases: [
                "Dosya sıkıştır \(.applicationName) ile",
                "\(.applicationName) ile dosya optimize et",
                "\(.applicationName) aç"
            ],
            shortTitle: "Dosya Sıkıştır",
            systemImageName: "arrow.down.right.and.arrow.up.left"
        )

        AppShortcut(
            intent: QuickOptimizeIntent(),
            phrases: [
                "Fotoğrafları optimize et \(.applicationName) ile",
                "\(.applicationName) ile toplu sıkıştır",
                "Haftalık temizlik yap \(.applicationName) ile"
            ],
            shortTitle: "Haftalık Temizlik",
            systemImageName: "photo.stack"
        )

        AppShortcut(
            intent: StorageReportIntent(),
            phrases: [
                "Depolama raporu \(.applicationName)",
                "\(.applicationName) ne kadar tasarruf ettim",
                "\(.applicationName) istatistikleri göster"
            ],
            shortTitle: "Depolama Raporu",
            systemImageName: "chart.bar.fill"
        )
    }
}

// MARK: - Notification Names for Shortcut Navigation

extension Notification.Name {
    static let shortcutBatchOptimize = Notification.Name("shortcutBatchOptimize")
    static let shortcutOpenCompressor = Notification.Name("shortcutOpenCompressor")
}
