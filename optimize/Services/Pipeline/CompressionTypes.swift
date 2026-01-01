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

    /// Commercial quality preset - balanced compression with vector preservation
    static let commercial = CompressionConfig(
        quality: 0.6,
        targetResolution: 144,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: false,
        textThreshold: 50,
        minImageDPI: 72
    )

    /// High quality preset - minimal compression, maximum fidelity
    static let highQuality = CompressionConfig(
        quality: 0.8,
        targetResolution: 200,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: false,
        textThreshold: 30,
        minImageDPI: 96
    )

    /// Extreme compression preset - maximum size reduction
    static let extreme = CompressionConfig(
        quality: 0.3,
        targetResolution: 72,
        preserveVectors: false,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 100,
        minImageDPI: 48
    )

    /// Email-optimized preset - target ~25MB attachments
    static let mail = CompressionConfig(
        quality: 0.4,
        targetResolution: 100,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: true,
        textThreshold: 50,
        minImageDPI: 60
    )

    /// WhatsApp/messaging optimized preset
    static let messaging = CompressionConfig(
        quality: 0.5,
        targetResolution: 120,
        preserveVectors: true,
        useMRC: true,
        aggressiveMode: false,
        textThreshold: 50,
        minImageDPI: 72
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
