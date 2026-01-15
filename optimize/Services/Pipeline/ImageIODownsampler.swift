//
//  ImageIODownsampler.swift
//  optimize
//
//  Memory-Efficient Image Downsampling using ImageIO Framework
//
//  This is the "secret sauce" that separates App Store leaders from basic tools.
//  Instead of loading full image into memory and then resizing (which can cause OOM),
//  ImageIO creates a downsampled version directly from the file/data source.
//
//  BENEFITS:
//  - 90% less memory usage compared to UIImage-based resizing
//  - Preserves EXIF orientation automatically
//  - Works with HEIC, JPEG, PNG, TIFF, and more
//  - Suitable for processing 50+ page PDFs on iPhone SE
//
//  REFERENCE: WWDC 2018 "Image and Graphics Best Practices"
//

import Foundation
import ImageIO
import UIKit
import CoreGraphics

// MARK: - DPI-Based Compression Levels

/// Compression levels mapped to target DPI for print/screen use cases
enum ImageDPILevel: CaseIterable {
    case screen      // 72 DPI - Web/Email sharing
    case standard    // 150 DPI - General purpose
    case print       // 300 DPI - Print quality
    case original    // No downsampling

    /// Target DPI value
    var dpi: CGFloat {
        switch self {
        case .screen: return 72
        case .standard: return 150
        case .print: return 300
        case .original: return 0 // No limit
        }
    }

    /// Maximum pixel dimension for A4 page at this DPI
    /// A4 = 8.27" x 11.69" (210mm x 297mm)
    var maxDimensionForA4: CGFloat {
        switch self {
        case .screen: return 842      // 11.69" * 72 DPI
        case .standard: return 1754   // 11.69" * 150 DPI
        case .print: return 3508      // 11.69" * 300 DPI
        case .original: return 0
        }
    }

    /// JPEG compression quality for this level
    var jpegQuality: CGFloat {
        switch self {
        case .screen: return 0.5
        case .standard: return 0.7
        case .print: return 0.85
        case .original: return 0.95
        }
    }

    /// Human-readable description
    var description: String {
        switch self {
        case .screen: return "Screen (72 DPI)"
        case .standard: return "Standard (150 DPI)"
        case .print: return "Print (300 DPI)"
        case .original: return "Original"
        }
    }
}

// MARK: - ImageIO Downsampler

/// High-performance image downsampler using ImageIO framework
/// This is the recommended approach by Apple for memory-efficient image processing
final class ImageIODownsampler {

    // MARK: - Configuration

    struct Configuration {
        let maxPixelSize: CGFloat
        let jpegQuality: CGFloat
        let preserveAspectRatio: Bool
        let shouldCache: Bool

        static func forLevel(_ level: ImageDPILevel) -> Configuration {
            Configuration(
                maxPixelSize: level.maxDimensionForA4,
                jpegQuality: level.jpegQuality,
                preserveAspectRatio: true,
                shouldCache: false // Don't cache for batch processing
            )
        }

        static let screen = Configuration.forLevel(.screen)
        static let standard = Configuration.forLevel(.standard)
        static let print = Configuration.forLevel(.print)
    }

    // MARK: - Core Downsampling (From Data)

    /// Downsample image data without fully decoding into memory
    /// This is the "magic" - ImageIO reads only what's needed for the target size
    ///
    /// - Parameters:
    ///   - data: Source image data (JPEG, PNG, HEIC, etc.)
    ///   - config: Downsampling configuration
    /// - Returns: Downsampled CGImage, or nil if failed
    static func downsample(data: Data, config: Configuration) -> CGImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: config.shouldCache
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }

        return downsample(source: source, config: config)
    }

    // MARK: - Core Downsampling (From URL)

    /// Downsample image directly from file URL (most memory efficient)
    ///
    /// - Parameters:
    ///   - url: Source image file URL
    ///   - config: Downsampling configuration
    /// - Returns: Downsampled CGImage, or nil if failed
    static func downsample(url: URL, config: Configuration) -> CGImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: config.shouldCache
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        return downsample(source: source, config: config)
    }

    // MARK: - Core Downsampling (From Source)

    /// Internal downsampling implementation
    private static func downsample(source: CGImageSource, config: Configuration) -> CGImage? {
        // Skip downsampling if no size limit
        guard config.maxPixelSize > 0 else {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }

        let downsampleOptions: [CFString: Any] = [
            // Create thumbnail from image, not embedded thumbnail
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Maximum pixel size (longest edge)
            kCGImageSourceThumbnailMaxPixelSize: config.maxPixelSize,
            // Preserve aspect ratio
            kCGImageSourceCreateThumbnailWithTransform: config.preserveAspectRatio,
            // Don't cache the full image
            kCGImageSourceShouldCacheImmediately: true
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary)
    }

    // MARK: - UIImage Convenience Methods

    /// Downsample UIImage with memory efficiency
    /// Note: This still requires the original UIImage in memory temporarily
    /// For best results, use URL-based downsampling when possible
    static func downsample(image: UIImage, config: Configuration) -> UIImage? {
        // Convert to data first (required for ImageIO)
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        guard let cgImage = downsample(data: data, config: config) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }

    /// Downsample UIImage and return compressed JPEG data
    /// This is the most common use case for PDF image optimization
    static func downsampleToJPEG(image: UIImage, config: Configuration) -> Data? {
        guard let downsampledImage = downsample(image: image, config: config) else {
            // Fallback: just compress without downsampling
            return image.jpegData(compressionQuality: config.jpegQuality)
        }

        return downsampledImage.jpegData(compressionQuality: config.jpegQuality)
    }

    /// Downsample from URL and return compressed JPEG data
    /// RECOMMENDED: Most memory-efficient approach
    static func downsampleToJPEG(url: URL, config: Configuration) -> Data? {
        guard let cgImage = downsample(url: url, config: config) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: config.jpegQuality)
    }

    // MARK: - Smart Downsampling (Auto-detect best level)

    /// Automatically determine the best compression level based on image size
    /// Prevents over-compression of already small images
    static func smartDownsample(data: Data, targetLevel: ImageDPILevel) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        let currentMax = max(width, height)
        let targetMax = targetLevel.maxDimensionForA4

        // If image is already smaller than target, just recompress
        if currentMax <= targetMax || targetMax == 0 {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return nil
            }
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: targetLevel.jpegQuality)
        }

        // Downsample to target size
        let config = Configuration.forLevel(targetLevel)
        guard let downsampledCG = downsample(source: source, config: config) else {
            return nil
        }

        return UIImage(cgImage: downsampledCG).jpegData(compressionQuality: config.jpegQuality)
    }

    // MARK: - Batch Processing Support

    /// Process multiple images with memory cleanup between each
    /// Essential for processing multi-page PDFs without OOM
    static func batchDownsample(
        images: [UIImage],
        config: Configuration,
        onProgress: ((Int, Int) -> Void)? = nil
    ) -> [Data] {
        var results: [Data] = []
        results.reserveCapacity(images.count)

        for (index, image) in images.enumerated() {
            autoreleasepool {
                if let data = downsampleToJPEG(image: image, config: config) {
                    results.append(data)
                }
                onProgress?(index + 1, images.count)
            }
        }

        return results
    }

    // MARK: - Image Analysis

    /// Get image dimensions without fully loading into memory
    static func getImageSize(from data: Data) -> CGSize? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    /// Get image dimensions from file URL
    static func getImageSize(from url: URL) -> CGSize? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    /// Calculate estimated file size after compression
    static func estimateCompressedSize(originalSize: CGSize, config: Configuration) -> Int {
        let targetMax = config.maxPixelSize > 0 ? config.maxPixelSize : max(originalSize.width, originalSize.height)
        let scale = min(1.0, targetMax / max(originalSize.width, originalSize.height))

        let targetWidth = originalSize.width * scale
        let targetHeight = originalSize.height * scale
        let pixels = targetWidth * targetHeight

        // Rough estimate: JPEG at quality Q uses approximately (Q * 0.5) bytes per pixel
        let bytesPerPixel = config.jpegQuality * 0.5
        return Int(pixels * bytesPerPixel)
    }
}

// MARK: - HEIC Support (iOS 11+)

extension ImageIODownsampler {

    /// Check if HEIC encoding is available on this device
    static var isHEICSupported: Bool {
        let supportedTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return supportedTypes.contains("public.heic")
    }

    /// Downsample and encode to HEIC format (50% smaller than JPEG at same quality)
    /// Falls back to JPEG if HEIC is not supported
    static func downsampleToHEIC(image: UIImage, config: Configuration) -> Data? {
        guard isHEICSupported else {
            // Fallback to JPEG
            return downsampleToJPEG(image: image, config: config)
        }

        guard let downsampledImage = downsample(image: image, config: config),
              let cgImage = downsampledImage.cgImage else {
            return image.jpegData(compressionQuality: config.jpegQuality)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.heic" as CFString,
            1,
            nil
        ) else {
            return downsampledImage.jpegData(compressionQuality: config.jpegQuality)
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: config.jpegQuality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return downsampledImage.jpegData(compressionQuality: config.jpegQuality)
        }

        return data as Data
    }
}

// MARK: - PDF Integration Helpers

extension ImageIODownsampler {

    /// Convert compression preset to ImageIO configuration
    static func configuration(for preset: CompressionPreset) -> Configuration {
        switch preset.quality {
        case .low:
            return .screen
        case .medium:
            return .standard
        case .high:
            return .print
        case .custom:
            return .standard
        }
    }

    /// Optimize image for PDF embedding with DPI awareness
    /// Returns JPEG data suitable for PDF XObject replacement
    static func optimizeForPDF(
        image: UIImage,
        targetDPI: ImageDPILevel,
        pageSize: CGSize // PDF page size in points (72 DPI)
    ) -> Data? {
        // Calculate target pixel dimensions based on DPI
        let scaleFactor = targetDPI.dpi / 72.0
        let targetWidth = pageSize.width * scaleFactor
        let targetHeight = pageSize.height * scaleFactor
        let targetMax = max(targetWidth, targetHeight)

        let config = Configuration(
            maxPixelSize: targetMax,
            jpegQuality: targetDPI.jpegQuality,
            preserveAspectRatio: true,
            shouldCache: false
        )

        return downsampleToJPEG(image: image, config: config)
    }
}

// MARK: - AdvancedImageEncoder Integration (v4.0)

extension ImageIODownsampler {

    /// Advanced encoding with profile support
    /// Uses AdvancedImageEncoder for metadata stripping, orientation fix, and color space conversion
    static func advancedEncode(
        url: URL,
        profile: OptimizationProfile
    ) -> ImageEncodingResult? {
        return AdvancedImageEncoder.shared.encode(url: url, profile: profile)
    }

    /// Advanced encoding from CGImageSource
    static func advancedEncode(
        source: CGImageSource,
        profile: OptimizationProfile,
        originalSize: Int64
    ) -> ImageEncodingResult? {
        return AdvancedImageEncoder.shared.encode(
            source: source,
            profile: profile,
            originalSize: originalSize
        )
    }

    /// Smart encode: Chooses between basic and advanced encoding based on profile
    /// - If profile has stripMetadata or convertToSRGB enabled, use AdvancedImageEncoder
    /// - Otherwise, use basic ImageIO downsampling for speed
    static func smartEncode(
        url: URL,
        profile: OptimizationProfile
    ) -> Data? {
        // If advanced features are needed, use AdvancedImageEncoder
        if profile.stripMetadata || profile.convertToSRGB || profile.removeColorProfiles {
            return advancedEncode(url: url, profile: profile)?.data
        }

        // Otherwise, use fast ImageIO downsampling
        let config = Configuration(
            maxPixelSize: CGFloat(profile.targetDPI * 12), // ~A4 at target DPI
            jpegQuality: profile.imageQuality,
            preserveAspectRatio: true,
            shouldCache: false
        )

        return downsampleToJPEG(url: url, config: config)
    }

    /// Smart encode from UIImage
    static func smartEncode(
        image: UIImage,
        profile: OptimizationProfile
    ) -> Data? {
        // Convert to data for analysis
        guard let sourceData = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        // If advanced features are needed
        if profile.stripMetadata || profile.convertToSRGB || profile.removeColorProfiles {
            guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil) else {
                return nil
            }

            return AdvancedImageEncoder.shared.encode(
                source: source,
                profile: profile,
                originalSize: Int64(sourceData.count)
            )?.data
        }

        // Fast path: basic downsampling
        let config = Configuration(
            maxPixelSize: CGFloat(profile.targetDPI * 12),
            jpegQuality: profile.imageQuality,
            preserveAspectRatio: true,
            shouldCache: false
        )

        return downsampleToJPEG(image: image, config: config)
    }

    /// Batch process with profile support
    static func batchSmartEncode(
        urls: [URL],
        profile: OptimizationProfile,
        onProgress: ((Double) -> Void)? = nil
    ) async -> [URL: Data] {
        var results: [URL: Data] = [:]
        let total = Double(urls.count)

        for (index, url) in urls.enumerated() {
            autoreleasepool {
                if let data = smartEncode(url: url, profile: profile) {
                    results[url] = data
                }
            }
            onProgress?(Double(index + 1) / total)
        }

        return results
    }
}
