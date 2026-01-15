//
//  PreflightAnalyzer.swift
//  optimize
//
//  Pre-compression analysis engine that answers "How much can I save?"
//  Analyzes files BEFORE processing to estimate potential gains.
//
//  CAPABILITIES:
//  - Metadata size estimation
//  - Incremental update detection (PDF)
//  - Color space analysis
//  - Smart recommendations
//  - Compression potential scoring
//

import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

// MARK: - Analysis Report

struct PreflightReport: Equatable {

    // MARK: - File Info

    let fileURL: URL
    let fileSize: Int64
    let fileType: FileCategory

    // MARK: - Analysis Results

    /// Estimated size of strippable metadata
    let metadataSizeEstimate: Int64

    /// Whether file has invisible garbage (incremental updates, ghost objects)
    let hasInvisibleGarbage: Bool

    /// Detected color space
    let colorSpace: String

    /// Whether color space conversion would help
    let needsColorSpaceConversion: Bool

    /// Image dimensions (for images/PDFs)
    let dimensions: CGSize?

    /// Page count (for PDFs)
    let pageCount: Int?

    /// Has embedded fonts (for PDFs)
    let hasEmbeddedFonts: Bool

    /// Estimated compression potential (0.0 - 1.0)
    let compressionPotential: Double

    // MARK: - Recommendations

    /// Human-readable recommendation
    let recommendation: String

    /// Suggested optimization strategy
    let suggestedStrategy: OptimizationStrategy

    /// Warnings (e.g., "File is encrypted")
    let warnings: [String]

    // MARK: - Computed Properties

    /// Estimated output size after compression
    var estimatedCompressedSize: Int64 {
        Int64(Double(fileSize) * (1.0 - compressionPotential))
    }

    /// Estimated savings in bytes
    var estimatedSavings: Int64 {
        fileSize - estimatedCompressedSize
    }

    /// Estimated savings percentage
    var estimatedSavingsPercentage: Int {
        Int(compressionPotential * 100)
    }

    /// Motivational message about savings
    var savingsMessage: String {
        let savedMB = Double(estimatedSavings) / 1_000_000
        let photos = Int(savedMB / 3.0) // ~3MB per photo
        let songs = Int(savedMB / 5.0) // ~5MB per song

        if photos >= 10 {
            return String(localized: "\(photos) fotoğraflık alan kazanabilirsin!")
        } else if songs >= 5 {
            return String(localized: "\(songs) şarkılık alan kazanabilirsin!")
        } else if savedMB >= 1 {
            return String(localized: "\(String(format: "%.1f", savedMB)) MB tasarruf edebilirsin!")
        } else {
            return String(localized: "Dosya optimize edilebilir")
        }
    }
}

// MARK: - Preflight Analyzer

actor PreflightAnalyzer {

    // MARK: - Singleton

    static let shared = PreflightAnalyzer()

    // MARK: - Main Analysis

    /// Analyze file and generate preflight report
    func analyze(url: URL) async -> PreflightReport {
        let fileSize = getFileSize(url)
        let ext = url.pathExtension.lowercased()
        let fileType = FileCategory.from(extension: ext)

        switch fileType {
        case .image:
            return await analyzeImage(url: url, fileSize: fileSize)
        case .pdf:
            return await analyzePDF(url: url, fileSize: fileSize)
        case .video:
            return analyzeVideo(url: url, fileSize: fileSize)
        default:
            return createGenericReport(url: url, fileSize: fileSize, fileType: fileType)
        }
    }

    // MARK: - Image Analysis

    private func analyzeImage(url: URL, fileSize: Int64) async -> PreflightReport {
        var metadataSize: Int64 = 0
        var colorSpace = "sRGB"
        var needsConversion = false
        var dimensions: CGSize?
        var warnings: [String] = []
        var compressionPotential: Double = 0.3 // Base potential

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return createGenericReport(url: url, fileSize: fileSize, fileType: .image)
        }

        // Analyze metadata
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            // EXIF data
            if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                metadataSize += Int64(estimateMetadataSize(exif))

                // Check for MakerNotes (can be huge)
                if exif["MakerNote"] != nil {
                    metadataSize += 50_000 // MakerNotes can be 50KB+
                }
            }

            // GPS data
            if props[kCGImagePropertyGPSDictionary as String] != nil {
                metadataSize += 1024
            }

            // TIFF/IPTC data
            if props[kCGImagePropertyTIFFDictionary as String] != nil {
                metadataSize += 4096
            }
            if props[kCGImagePropertyIPTCDictionary as String] != nil {
                metadataSize += 2048
            }

            // Get dimensions
            if let width = props[kCGImagePropertyPixelWidth as String] as? Int,
               let height = props[kCGImagePropertyPixelHeight as String] as? Int {
                dimensions = CGSize(width: width, height: height)

                // Large images have more compression potential
                if width * height > 4000 * 3000 {
                    compressionPotential += 0.2
                }
            }
        }

        // Analyze color space
        if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
           let cs = cgImage.colorSpace,
           let name = cs.name as String? {
            colorSpace = name

            // Display P3 has embedded profile (~500KB)
            if name.contains("P3") || name.contains("DisplayP3") {
                metadataSize += 500_000
                needsConversion = true
                compressionPotential += 0.1
            }

            // Adobe RGB also needs conversion
            if name.contains("Adobe") {
                needsConversion = true
                compressionPotential += 0.05
            }
        }

        // Check file format for potential
        let ext = url.pathExtension.lowercased()
        if ext == "png" {
            // PNGs often compress very well when converted to JPEG
            compressionPotential += 0.3

            // Check if it's a photo-like PNG (no transparency)
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let hasAlpha = cgImage.alphaInfo != .none && cgImage.alphaInfo != .noneSkipLast
                if !hasAlpha {
                    compressionPotential += 0.2
                }
            }
        } else if ext == "bmp" || ext == "tiff" || ext == "tif" {
            compressionPotential += 0.5 // Uncompressed formats
        }

        // Cap potential
        compressionPotential = min(compressionPotential, 0.9)

        // Generate recommendation
        let recommendation = generateImageRecommendation(
            needsConversion: needsConversion,
            metadataSize: metadataSize,
            compressionPotential: compressionPotential
        )

        let suggestedStrategy: OptimizationStrategy = compressionPotential > 0.5 ? .ultra : .balanced

        return PreflightReport(
            fileURL: url,
            fileSize: fileSize,
            fileType: .image,
            metadataSizeEstimate: metadataSize,
            hasInvisibleGarbage: false,
            colorSpace: colorSpace,
            needsColorSpaceConversion: needsConversion,
            dimensions: dimensions,
            pageCount: nil,
            hasEmbeddedFonts: false,
            compressionPotential: compressionPotential,
            recommendation: recommendation,
            suggestedStrategy: suggestedStrategy,
            warnings: warnings
        )
    }

    // MARK: - PDF Analysis

    private func analyzePDF(url: URL, fileSize: Int64) async -> PreflightReport {
        var metadataSize: Int64 = 0
        var hasIncrementalUpdates = false
        var pageCount: Int?
        var hasEmbeddedFonts = false
        var warnings: [String] = []
        var compressionPotential: Double = 0.3

        // Check for incremental updates (multiple %%EOF markers)
        if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            // Check last 50KB for EOF markers
            let tailSize = min(data.count, 50_000)
            let tail = data.suffix(tailSize)
            let tailString = String(decoding: tail, as: UTF8.self)

            let eofCount = tailString.components(separatedBy: "%%EOF").count - 1
            if eofCount > 1 {
                hasIncrementalUpdates = true
                metadataSize += Int64(eofCount * 50_000) // Each update adds ~50KB garbage
                compressionPotential += 0.2
            }

            // Check for embedded fonts (rough heuristic)
            if tailString.contains("/FontFile") || tailString.contains("/FontDescriptor") {
                hasEmbeddedFonts = true
                compressionPotential += 0.1
            }
        }

        // Open PDF for detailed analysis
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        if let document = PDFDocument(url: url) {
            pageCount = document.pageCount

            // Check if encrypted
            if document.isEncrypted {
                warnings.append(String(localized: "PDF şifrelenmiş, bazı işlemler sınırlı olabilir"))
            }

            // Analyze first page for image density
            if let firstPage = document.page(at: 0) {
                let bounds = firstPage.bounds(for: .mediaBox)
                let pageArea = bounds.width * bounds.height

                // Large pages often contain high-res images
                if pageArea > 500_000 { // ~A4 at 150 DPI
                    compressionPotential += 0.15
                }
            }

            // More pages = more potential savings
            if let count = pageCount, count > 10 {
                compressionPotential += 0.1
            }
        }

        // Cap potential
        compressionPotential = min(compressionPotential, 0.85)

        // Generate recommendation
        let recommendation: String
        if hasIncrementalUpdates {
            recommendation = String(localized: "PDF'de artımlı güncellemeler tespit edildi. Ultra mod önerilir.")
        } else if compressionPotential > 0.5 {
            recommendation = String(localized: "PDF yüksek sıkıştırma potansiyeline sahip.")
        } else {
            recommendation = String(localized: "Standart optimizasyon önerilir.")
        }

        let suggestedStrategy: OptimizationStrategy = hasIncrementalUpdates ? .ultra : .balanced

        return PreflightReport(
            fileURL: url,
            fileSize: fileSize,
            fileType: .pdf,
            metadataSizeEstimate: metadataSize,
            hasInvisibleGarbage: hasIncrementalUpdates,
            colorSpace: "Mixed",
            needsColorSpaceConversion: false,
            dimensions: nil,
            pageCount: pageCount,
            hasEmbeddedFonts: hasEmbeddedFonts,
            compressionPotential: compressionPotential,
            recommendation: recommendation,
            suggestedStrategy: suggestedStrategy,
            warnings: warnings
        )
    }

    // MARK: - Video Analysis

    private func analyzeVideo(url: URL, fileSize: Int64) -> PreflightReport {
        // Video compression potential is usually high
        let compressionPotential: Double = 0.5

        return PreflightReport(
            fileURL: url,
            fileSize: fileSize,
            fileType: .video,
            metadataSizeEstimate: 0,
            hasInvisibleGarbage: false,
            colorSpace: "YUV",
            needsColorSpaceConversion: false,
            dimensions: nil,
            pageCount: nil,
            hasEmbeddedFonts: false,
            compressionPotential: compressionPotential,
            recommendation: String(localized: "Video sıkıştırması yüksek tasarruf sağlayabilir."),
            suggestedStrategy: .balanced,
            warnings: []
        )
    }

    // MARK: - Helpers

    private func getFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private func estimateMetadataSize(_ dict: [String: Any]) -> Int {
        // Rough estimation: 50 bytes per key-value pair
        var size = dict.count * 50

        for (_, value) in dict {
            if let stringValue = value as? String {
                size += stringValue.count
            } else if let dataValue = value as? Data {
                size += dataValue.count
            } else if let nestedDict = value as? [String: Any] {
                size += estimateMetadataSize(nestedDict)
            }
        }

        return size
    }

    private func generateImageRecommendation(
        needsConversion: Bool,
        metadataSize: Int64,
        compressionPotential: Double
    ) -> String {
        var parts: [String] = []

        if needsConversion {
            parts.append(String(localized: "Renk profili dönüşümü önerilir"))
        }

        if metadataSize > 100_000 {
            parts.append(String(localized: "Yüksek metadata tespit edildi"))
        }

        if compressionPotential > 0.6 {
            parts.append(String(localized: "Yüksek sıkıştırma potansiyeli"))
        }

        if parts.isEmpty {
            return String(localized: "Standart optimizasyon önerilir")
        }

        return parts.joined(separator: ". ") + "."
    }

    private func createGenericReport(url: URL, fileSize: Int64, fileType: FileCategory) -> PreflightReport {
        PreflightReport(
            fileURL: url,
            fileSize: fileSize,
            fileType: fileType,
            metadataSizeEstimate: 0,
            hasInvisibleGarbage: false,
            colorSpace: "Unknown",
            needsColorSpaceConversion: false,
            dimensions: nil,
            pageCount: nil,
            hasEmbeddedFonts: false,
            compressionPotential: 0.2,
            recommendation: String(localized: "Temel optimizasyon uygulanabilir"),
            suggestedStrategy: .balanced,
            warnings: []
        )
    }
}

// MARK: - FileCategory Extension

extension FileCategory {
    static func from(extension ext: String) -> FileCategory {
        switch ext.lowercased() {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "tif", "webp":
            return .image
        case "mp4", "mov", "m4v", "avi", "mkv", "wmv":
            return .video
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf":
            return .document
        default:
            return .other
        }
    }
}
