//
//  AppModels.swift
//  optimize
//
//  Data models for the app
//

import Foundation

// MARK: - File Models
struct FileInfo: Identifiable, Equatable {
    let id: UUID
    let name: String
    let url: URL
    let size: Int64 // bytes
    let pageCount: Int?
    let fileType: FileType

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var sizeMB: Double {
        Double(size) / 1_000_000
    }

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        size: Int64,
        pageCount: Int? = nil,
        fileType: FileType = .pdf
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.size = size
        self.pageCount = pageCount
        self.fileType = fileType
    }
}

// MARK: - Analysis Result
struct AnalysisResult: Equatable {
    let pageCount: Int
    let imageCount: Int
    let imageDensity: ImageDensity
    let estimatedSavings: SavingsLevel
    let isAlreadyOptimized: Bool
    let originalDPI: Int?

    enum ImageDensity: String {
        case low = "Düşük"
        case medium = "Orta"
        case high = "Yüksek"
    }
}

// MARK: - Compression Preset
struct CompressionPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let targetSizeMB: Int?
    let quality: CompressionQuality
    let isProOnly: Bool

    enum CompressionQuality: String {
        case low = "mail"
        case medium = "whatsapp"
        case high = "quality"
        case custom = "custom"
    }

    static let defaultPresets: [CompressionPreset] = [
        CompressionPreset(
            id: "mail",
            name: "Mail (25 MB)",
            description: "E-posta eklerine uygun",
            icon: "envelope.fill",
            targetSizeMB: 25,
            quality: .low,
            isProOnly: false
        ),
        CompressionPreset(
            id: "whatsapp",
            name: "WhatsApp",
            description: "Hızlı paylaşım için optimize",
            icon: "message.fill",
            targetSizeMB: nil,
            quality: .medium,
            isProOnly: false
        ),
        CompressionPreset(
            id: "quality",
            name: "En İyi Kalite",
            description: "Minimum kayıp, maksimum sıkıştırma",
            icon: "star.fill",
            targetSizeMB: nil,
            quality: .high,
            isProOnly: false
        ),
        CompressionPreset(
            id: "custom",
            name: "Özel Boyut",
            description: "Hedef boyut belirle",
            icon: "slider.horizontal.3",
            targetSizeMB: nil,
            quality: .custom,
            isProOnly: true
        )
    ]
}

// MARK: - Compression Result
struct CompressionResult: Identifiable, Equatable {
    let id: UUID
    let originalFile: FileInfo
    let compressedURL: URL
    let compressedSize: Int64
    let savingsPercent: Int
    let processedAt: Date

    var compressedSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    var compressedSizeMB: Double {
        Double(compressedSize) / 1_000_000
    }

    init(
        id: UUID = UUID(),
        originalFile: FileInfo,
        compressedURL: URL,
        compressedSize: Int64,
        processedAt: Date = Date()
    ) {
        self.id = id
        self.originalFile = originalFile
        self.compressedURL = compressedURL
        self.compressedSize = compressedSize
        self.processedAt = processedAt

        let originalSize = originalFile.size
        let saved = originalSize - compressedSize
        self.savingsPercent = originalSize > 0 ? Int((Double(saved) / Double(originalSize)) * 100) : 0
    }
}

// MARK: - History Item
struct HistoryItem: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let originalSize: Int64
    let compressedSize: Int64
    let savingsPercent: Int
    let processedAt: Date
    let presetUsed: String

    var originalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    var compressedSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: processedAt, relativeTo: Date())
    }
}

// MARK: - Subscription
enum SubscriptionPlan: String, CaseIterable {
    case free = "free"
    case monthly = "monthly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .free: return "Ücretsiz"
        case .monthly: return "Aylık"
        case .yearly: return "Yıllık"
        }
    }
}

struct SubscriptionStatus {
    let plan: SubscriptionPlan
    let isActive: Bool
    let expiresAt: Date?
    let dailyUsageCount: Int
    let dailyUsageLimit: Int

    var canProcess: Bool {
        if plan != .free { return true }
        return dailyUsageCount < dailyUsageLimit
    }

    var remainingUsage: Int {
        max(0, dailyUsageLimit - dailyUsageCount)
    }

    static let free = SubscriptionStatus(
        plan: .free,
        isActive: true,
        expiresAt: nil,
        dailyUsageCount: 0,
        dailyUsageLimit: 1
    )

    static let pro = SubscriptionStatus(
        plan: .yearly,
        isActive: true,
        expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
        dailyUsageCount: 0,
        dailyUsageLimit: .max
    )
}

// MARK: - App Settings
struct AppSettings: Equatable {
    var defaultPresetId: String = "whatsapp"
    var processOnWifiOnly: Bool = true
    var deleteOriginalAfterProcess: Bool = false
    var historyRetentionDays: Int = 30
    var enableAnalytics: Bool = true
}

// MARK: - FileInfo Extension for URL Initialization
// Note: The main from(url:) implementation is in PDFCompressionService.swift
// which provides more complete functionality including page count for PDFs

