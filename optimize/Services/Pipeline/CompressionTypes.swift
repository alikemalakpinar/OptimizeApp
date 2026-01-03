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
    let textThreshold: Int

    /// DPI threshold below which images are considered low-res and skipped
    let minImageDPI: CGFloat

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
        quality: 0.45,              // 0.6 → 0.45: Daha agresif JPEG, göze çarpmayan fark
        targetResolution: 120,      // 144 → 120: Boyut küçülür, kalite korunur
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,       // false → true: MRC ve sıkıştırma optimizasyonu aktif
        textThreshold: 30,          // 50 → 30: Daha fazla sayfa vektör olarak korunur
        minImageDPI: 60             // 72 → 60: Düşük DPI görüntüler de işlenir
    )

    /// High quality preset - BALANCED compression with excellent fidelity
    /// Hedef: %40-50 boyut azaltma, kalite kaybı minimum
    static let highQuality = CompressionConfig(
        quality: 0.55,              // 0.8 → 0.55: Görsel fark yok, büyük boyut kazancı
        targetResolution: 150,      // 200 → 150: Print kalitesi korunur
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: false,
        textThreshold: 25,          // 30 → 25: Daha fazla vektör koruması
        minImageDPI: 72
    )

    /// Extreme compression preset - MAXIMUM size reduction
    /// Hedef: %70-85 boyut azaltma, web/mobil görüntüleme için optimize
    static let extreme = CompressionConfig(
        quality: 0.20,              // 0.3 → 0.20: Ultra agresif ama okunabilir
        targetResolution: 60,       // 72 → 60: Ekran görüntüleme için yeterli
        preserveVectors: false,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 150,         // 100 → 150: Daha fazla rasterizasyon
        minImageDPI: 36             // 48 → 36: Tüm görseller işlenir
    )

    /// Email-optimized preset - target ~10MB attachments (was 25MB)
    /// Hedef: %60-70 boyut azaltma, e-posta için ideal
    static let mail = CompressionConfig(
        quality: 0.30,              // 0.4 → 0.30: E-posta için fazlasıyla yeterli
        targetResolution: 80,       // 100 → 80: Ekran görüntüleme optimize
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 40,
        minImageDPI: 48             // 60 → 48: Tüm görseller sıkıştırılır
    )

    /// WhatsApp/messaging optimized preset - ULTRA compact for instant sharing
    /// Hedef: %65-75 boyut azaltma, hızlı paylaşım için
    static let messaging = CompressionConfig(
        quality: 0.35,              // 0.5 → 0.35: Mobil ekranlarda mükemmel
        targetResolution: 90,       // 120 → 90: Telefon ekranları için ideal
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,       // false → true: Maksimum sıkıştırma
        textThreshold: 40,
        minImageDPI: 48             // 72 → 48: Tüm görseller işlenir
    )

    /// NEW: Ultra compression preset - For archival and maximum space saving
    /// Hedef: %80-90 boyut azaltma, arşivleme için
    static let ultra = CompressionConfig(
        quality: 0.15,
        targetResolution: 50,
        preserveVectors: false,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 200,
        minImageDPI: 30
    )

    /// NEW: Smart preset - Adaptive compression based on content analysis
    /// Hedef: İçeriğe göre otomatik ayarlama
    static let smart = CompressionConfig(
        quality: 0.40,
        targetResolution: 100,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 35,
        minImageDPI: 50
    )

    // MARK: - Initialization

    init(
        quality: Float,
        targetResolution: CGFloat,
        preserveVectors: Bool,
        useMRC: Bool,
        aggressiveMode: Bool,
        textThreshold: Int = 50,
        minImageDPI: CGFloat = 72
    ) {
        self.quality = max(0.1, min(1.0, quality))
        self.targetResolution = max(48, min(600, targetResolution))
        self.preserveVectors = preserveVectors
        self.useMRC = useMRC
        self.aggressiveMode = aggressiveMode
        self.textThreshold = max(10, textThreshold)
        self.minImageDPI = max(36, minImageDPI)
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
