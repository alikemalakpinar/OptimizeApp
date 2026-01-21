//
//  CompressionTypes.swift
//  optimize
//
//  Advanced compression configuration types for the Stream Rewriting engine.
//  These types enable vector-preserving PDF optimization with intelligent
//  content detection and MRC (Mixed Raster Content) support.
//

import Foundation
import CoreGraphics

// MARK: - Advanced Configuration

/// Configuration for the advanced PDF compression engine.
/// Supports vector preservation, MRC layers, and intelligent content detection.
struct CompressionConfig {
    /// JPEG/HEIF quality factor (0.0 - 1.0)
    let quality: Float

    /// Target resolution in DPI (72 = screen, 150 = balanced, 300 = print)
    let targetResolution: CGFloat

    /// When true, text and vector graphics are preserved without rasterization
    let preserveVectors: Bool

    /// Enable Mixed Raster Content for scanned documents
    let useMRC: Bool

    /// Enable aggressive compression (may reduce quality further)
    let aggressiveMode: Bool

    /// Minimum text character threshold to consider a page as "vector text"
    /// IMPORTANT: Bu değer tek başına yeterli değil, multi-signal detection kullanılmalı
    let textThreshold: Int

    /// DPI threshold below which images are considered low-res and skipped
    let minImageDPI: CGFloat

    /// Enable multi-signal vector detection (recommended: true)
    /// Uses: text length + annotation count + rotation + trim box + page dimensions
    let useMultiSignalDetection: Bool

    /// Minimum SSIM quality threshold (0.0 - 1.0) for quality guard
    /// If compressed image SSIM falls below this, quality is increased
    let minSSIMThreshold: Float

    /// Enable adaptive quality floor - prevents unreadable output
    let enableAdaptiveQualityFloor: Bool

    // MARK: - Preset Configurations

    // ═══════════════════════════════════════════════════════════════════════════════
    // ULTIMATE COMPRESSION ALGORITHM v2.0
    // ═══════════════════════════════════════════════════════════════════════════════
    // Bu presetler maksimum sıkıştırma + kabul edilebilir kalite için optimize edildi.
    // Her preset, dosya boyutunu %40-80 oranında küçültecek şekilde ayarlandı.
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Commercial quality preset - OPTIMIZED for maximum compression with good quality
    /// Hedef: %50-60 boyut azaltma, metin okunabilirliği korunur
    static let commercial = CompressionConfig(
        quality: 0.45,
        targetResolution: 120,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 50,          // 30 → 50: Daha güvenli vektör tespiti
        minImageDPI: 60,
        useMultiSignalDetection: true,  // ✅ Multi-signal aktif
        minSSIMThreshold: 0.82,         // Kalite garantisi
        enableAdaptiveQualityFloor: true
    )

    /// High quality preset - BALANCED compression with excellent fidelity
    /// Hedef: %40-50 boyut azaltma, kalite kaybı minimum
    static let highQuality = CompressionConfig(
        quality: 0.55,
        targetResolution: 150,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: false,
        textThreshold: 40,          // 25 → 40: Dengeli
        minImageDPI: 72,
        useMultiSignalDetection: true,
        minSSIMThreshold: 0.88,         // Yüksek kalite
        enableAdaptiveQualityFloor: true
    )

    /// Extreme compression preset - MAXIMUM size reduction
    /// Hedef: %70-85 boyut azaltma, web/mobil görüntüleme için optimize
    static let extreme = CompressionConfig(
        quality: 0.20,
        targetResolution: 60,
        preserveVectors: false,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 100,         // 150 → 100: Biraz daha dengeli
        minImageDPI: 36,
        useMultiSignalDetection: true,
        minSSIMThreshold: 0.70,         // Düşük ama okunabilir
        enableAdaptiveQualityFloor: true
    )

    /// Email-optimized preset - target ~10MB attachments
    /// Hedef: %60-70 boyut azaltma, e-posta için ideal
    static let mail = CompressionConfig(
        quality: 0.30,
        targetResolution: 80,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 50,          // 40 → 50
        minImageDPI: 48,
        useMultiSignalDetection: true,
        minSSIMThreshold: 0.78,
        enableAdaptiveQualityFloor: true
    )

    /// WhatsApp/messaging optimized preset - ULTRA compact for instant sharing
    /// Hedef: %65-75 boyut azaltma, hızlı paylaşım için
    static let messaging = CompressionConfig(
        quality: 0.35,
        targetResolution: 90,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 50,          // 40 → 50
        minImageDPI: 48,
        useMultiSignalDetection: true,
        minSSIMThreshold: 0.75,
        enableAdaptiveQualityFloor: true
    )

    /// Ultra compression preset - For archival and maximum space saving
    /// Hedef: %80-90 boyut azaltma, arşivleme için
    static let ultra = CompressionConfig(
        quality: 0.15,
        targetResolution: 50,
        preserveVectors: false,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 80,          // 200 → 80: Daha dengeli
        minImageDPI: 30,
        useMultiSignalDetection: true,
        minSSIMThreshold: 0.65,         // Minimum kabul edilebilir
        enableAdaptiveQualityFloor: true
    )

    /// Smart preset - Adaptive compression based on content analysis
    /// Hedef: İçeriğe göre otomatik ayarlama
    static let smart = CompressionConfig(
        quality: 0.40,
        targetResolution: 100,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 50,          // 35 → 50
        minImageDPI: 50,
        useMultiSignalDetection: true,
        minSSIMThreshold: 0.80,
        enableAdaptiveQualityFloor: true
    )

    // MARK: - Initialization

    init(
        quality: Float,
        targetResolution: CGFloat,
        preserveVectors: Bool,
        useMRC: Bool,
        aggressiveMode: Bool,
        textThreshold: Int = 50,
        minImageDPI: CGFloat = 72,
        useMultiSignalDetection: Bool = true,
        minSSIMThreshold: Float = 0.80,
        enableAdaptiveQualityFloor: Bool = true
    ) {
        self.quality = max(0.1, min(1.0, quality))
        self.targetResolution = max(48, min(600, targetResolution))
        self.preserveVectors = preserveVectors
        self.useMRC = useMRC
        self.aggressiveMode = aggressiveMode
        self.textThreshold = max(10, textThreshold)
        self.minImageDPI = max(36, minImageDPI)
        self.useMultiSignalDetection = useMultiSignalDetection
        self.minSSIMThreshold = max(0.5, min(1.0, minSSIMThreshold))
        self.enableAdaptiveQualityFloor = enableAdaptiveQualityFloor
    }
}

// MARK: - Compression Outcome (v4.1 - Output Guarantee System)

/// Represents the outcome of a compression operation with detailed diagnostics.
/// This enum ensures the user always knows what happened, especially when
/// output >= input (the "4.5MB → 4.5MB" problem).
enum CompressionOutcome: Equatable {
    /// Compression succeeded with measurable size reduction
    case success(savedBytes: Int64, savedPercent: Int)

    /// File was compressed but savings were minimal (<5%)
    case marginalSuccess(savedBytes: Int64, savedPercent: Int, reason: String)

    /// Compression was retried with more aggressive settings
    case retriedWithAggressiveProfile(savedBytes: Int64, savedPercent: Int, retryCount: Int)

    /// File is already optimized - no further reduction possible without quality loss
    case alreadyOptimized(diagnostics: CompressionDiagnostics)

    /// File format doesn't benefit from compression (e.g., already compressed formats)
    case noReductionPossible(reason: NoReductionReason)

    /// Compression failed with an error
    case failed(error: CompressionError)

    /// User-friendly message for display
    var userMessage: String {
        switch self {
        case .success(_, let percent):
            return "Başarılı! Dosya %\(percent) küçültüldü."
        case .marginalSuccess(_, let percent, let reason):
            return "Dosya %\(percent) küçültüldü. \(reason)"
        case .retriedWithAggressiveProfile(_, let percent, let retryCount):
            return "Yeniden denendi (\(retryCount)x). %\(percent) küçültüldü."
        case .alreadyOptimized(let diagnostics):
            return "Bu dosya zaten optimize edilmiş. \(diagnostics.summary)"
        case .noReductionPossible(let reason):
            return reason.userMessage
        case .failed(let error):
            return error.localizedDescription
        }
    }

    /// Whether the operation should be considered successful
    var isSuccess: Bool {
        switch self {
        case .success, .marginalSuccess, .retriedWithAggressiveProfile:
            return true
        case .alreadyOptimized, .noReductionPossible, .failed:
            return false
        }
    }
}

/// Detailed diagnostics for when compression doesn't reduce file size
struct CompressionDiagnostics: Equatable {
    let originalSize: Int64
    let attemptedSize: Int64
    let originalCodec: String?
    let attemptedQuality: Float
    let isAlreadyCompressed: Bool
    let hasEmbeddedThumbnails: Bool
    let metadataSize: Int64

    var summary: String {
        if isAlreadyCompressed {
            return "Dosya zaten sıkıştırılmış format kullanıyor."
        }
        if metadataSize > originalSize / 10 {
            return "Metadata boyutu yüksek, ancak kaldırılamadı."
        }
        return "Daha fazla sıkıştırma kaliteyi ciddi şekilde düşürür."
    }
}

/// Reasons why compression cannot reduce file size
enum NoReductionReason: Equatable {
    case alreadyCompressedFormat(format: String)
    case qualityLossUnacceptable
    case minimalCompressibleContent
    case encryptedContent
    case unsupportedInternalFormat

    var userMessage: String {
        switch self {
        case .alreadyCompressedFormat(let format):
            return "\(format.uppercased()) zaten sıkıştırılmış bir format. Daha fazla küçültme mümkün değil."
        case .qualityLossUnacceptable:
            return "Daha fazla sıkıştırma kaliteyi kabul edilemez seviyeye düşürür."
        case .minimalCompressibleContent:
            return "Dosyada sıkıştırılabilir içerik yok veya çok az."
        case .encryptedContent:
            return "Şifrelenmiş içerik sıkıştırılamaz."
        case .unsupportedInternalFormat:
            return "Desteklenmeyen dahili format."
        }
    }
}

// MARK: - Retry Configuration for "Output >= Input" Scenarios

/// Configuration for automatic retry with more aggressive settings
struct CompressionRetryConfig {
    /// Maximum number of retry attempts
    static let maxRetries = 3

    /// Quality reduction per retry attempt
    static let qualityReductionPerRetry: Float = 0.15

    /// Resolution reduction per retry attempt
    static let resolutionReductionPerRetry: CGFloat = 20

    /// Get progressively more aggressive config for each retry
    static func configForRetry(_ retryCount: Int, baseConfig: CompressionConfig) -> CompressionConfig {
        let qualityReduction = Float(retryCount) * qualityReductionPerRetry
        let resolutionReduction = CGFloat(retryCount) * resolutionReductionPerRetry

        return CompressionConfig(
            quality: max(0.15, baseConfig.quality - qualityReduction),
            targetResolution: max(60, baseConfig.targetResolution - resolutionReduction),
            preserveVectors: retryCount < 2 ? baseConfig.preserveVectors : false,
            useMRC: baseConfig.useMRC,
            aggressiveMode: true, // Always aggressive on retry
            textThreshold: baseConfig.textThreshold,
            minImageDPI: max(36, baseConfig.minImageDPI - CGFloat(retryCount * 10)),
            useMultiSignalDetection: baseConfig.useMultiSignalDetection,
            minSSIMThreshold: max(0.60, baseConfig.minSSIMThreshold - Float(retryCount) * 0.05),
            enableAdaptiveQualityFloor: baseConfig.enableAdaptiveQualityFloor
        )
    }
}

// MARK: - Processing Error Types

/// Errors specific to the advanced compression pipeline
enum ProcessingError: Error, LocalizedError {
    case encryptionError
    case writePermission
    case corruptedData
    case memoryLimit
    case renderFailed
    case unsupportedColorSpace
    case pageProcessingFailed(page: Int)
    case mrcSeparationFailed
    case streamParsingFailed

    var errorDescription: String? {
        switch self {
        case .encryptionError:
            return "PDF is encrypted. Please provide an unlocked file."
        case .writePermission:
            return "Unable to write to the destination. Check storage permissions."
        case .corruptedData:
            return "The PDF file appears to be corrupted or malformed."
        case .memoryLimit:
            return "Insufficient memory to process this file."
        case .renderFailed:
            return "Failed to render PDF page content."
        case .unsupportedColorSpace:
            return "The PDF uses an unsupported color space."
        case .pageProcessingFailed(let page):
            return "Failed to process page \(page + 1)."
        case .mrcSeparationFailed:
            return "MRC layer separation failed for scanned content."
        case .streamParsingFailed:
            return "Failed to parse PDF content streams."
        }
    }
}

// MARK: - Document Classification

/// Classification of PDF document type based on content analysis
enum DocumentType {
    /// Digital-born PDF with vector text and graphics
    case digitalBorn

    /// Scanned document (images of pages)
    case scanned

    /// Mixed content (some pages digital, some scanned)
    case hybrid

    /// Photo album or image-heavy presentation
    case photoAlbum
}

// MARK: - Page Content Analysis

/// Detailed analysis of a single PDF page's content
struct PageContentAnalysis {
    /// Page index (0-based)
    let pageIndex: Int

    /// Total character count from text extraction
    let textCharacterCount: Int

    /// Estimated image coverage as percentage (0.0 - 1.0)
    let imageCoverage: Double

    /// Whether the page has selectable/vector text
    let hasVectorText: Bool

    /// Recommended compression strategy for this page
    let recommendedStrategy: PageCompressionStrategy

    /// Estimated compression ratio achievable (0.0 - 1.0, lower is more compressed)
    let estimatedCompressionRatio: Double
}

/// Compression strategy for individual pages
enum PageCompressionStrategy {
    /// Keep page as-is, only compress embedded images
    case preserveVector

    /// Apply MRC separation (foreground/background layers)
    case mrcSeparation

    /// Rasterize and compress as single image
    case rasterize

    /// High-quality image compression (HEIF/JPEG2000)
    case photoOptimization

    /// Bi-tonal compression for black/white scans
    case bitonalCompression
}

// MARK: - Compression Statistics

/// Statistics from a compression operation
struct CompressionStatistics {
    /// Original file size in bytes
    let originalSize: Int64

    /// Compressed file size in bytes
    let compressedSize: Int64

    /// Number of pages processed
    let pagesProcessed: Int

    /// Number of images compressed
    let imagesCompressed: Int

    /// Number of pages where vector content was preserved
    let vectorPagesPreserved: Int

    /// Number of pages processed with MRC
    let mrcPagesProcessed: Int

    /// Processing time in seconds
    let processingTime: TimeInterval

    /// Compression ratio (compressed/original)
    var compressionRatio: Double {
        guard originalSize > 0 else { return 1.0 }
        return Double(compressedSize) / Double(originalSize)
    }

    /// Savings percentage (0-100)
    var savingsPercent: Int {
        guard originalSize > 0 else { return 0 }
        let saved = originalSize - compressedSize
        return Int((Double(saved) / Double(originalSize)) * 100)
    }

    /// Average compression per page in KB
    var averagePageSizeKB: Double {
        guard pagesProcessed > 0 else { return 0 }
        return Double(compressedSize) / 1024.0 / Double(pagesProcessed)
    }
}

// MARK: - Image Optimization Intent

/// Specific optimization technique to apply to images
enum ImageOptimizationIntent {
    /// Preserve image quality, minimal compression
    case preserve

    /// Standard JPEG compression
    case jpeg

    /// JPEG 2000 (lossy wavelet compression)
    case jpeg2000

    /// HEIF/HEIC (modern efficient compression)
    case heif

    /// JBIG2 (bi-tonal black/white)
    case jbig2

    /// CCITT Group 4 (fax-style bi-tonal)
    case ccittG4

    /// Deflate/ZIP compression
    case deflate
}

// MARK: - MRC Layer Types

/// Layer types in Mixed Raster Content separation
enum MRCLayerType {
    /// Foreground mask (typically black text on transparent)
    case foregroundMask

    /// Background layer (colors, images without text)
    case background

    /// Full page (no separation applied)
    case fullPage
}

// MARK: - Progress Tracking

/// Detailed progress information during compression
struct CompressionProgress {
    /// Current processing stage
    let stage: ProcessingStage

    /// Overall progress (0.0 - 1.0)
    let overallProgress: Double

    /// Current page being processed (1-indexed for display)
    let currentPage: Int?

    /// Total pages in document
    let totalPages: Int?

    /// Estimated time remaining in seconds
    let estimatedTimeRemaining: TimeInterval?

    /// Current operation description
    let statusMessage: String

    init(
        stage: ProcessingStage,
        overallProgress: Double,
        currentPage: Int? = nil,
        totalPages: Int? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        statusMessage: String = ""
    ) {
        self.stage = stage
        self.overallProgress = max(0, min(1, overallProgress))
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.statusMessage = statusMessage.isEmpty ? stage.displayName : statusMessage
    }
}

// MARK: - Extension for ProcessingStage

extension ProcessingStage {
    /// Human-readable name for the stage
    var displayName: String {
        switch self {
        case .preparing:
            return "Preparing..."
        case .uploading:
            return "Analyzing Content..."
        case .optimizing:
            return "Optimizing..."
        case .downloading:
            return "Finalizing..."
        }
    }

    /// Localized description for UI
    var localizedDescription: String {
        switch self {
        case .preparing:
            return "Loading and validating document"
        case .uploading:
            return "Detecting text and image regions"
        case .optimizing:
            return "Compressing while preserving quality"
        case .downloading:
            return "Writing optimized PDF"
        }
    }
}
