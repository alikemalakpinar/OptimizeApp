//
//  HEICConversionService.swift
//  optimize
//
//  HEIC (High Efficiency Image Container) conversion module.
//
//  Provides bidirectional conversion:
//  - JPEG/PNG → HEIC: Reduces image storage by 40-50% with equal visual quality
//  - HEIC → JPEG: Ensures compatibility with older systems/apps
//
//  Uses ImageIO framework for memory-efficient processing (no full UIImage loading).
//  All operations are file-to-file to minimize peak memory usage.
//
//  REFERENCE: HEIC uses HEVC (H.265) intra-frame compression, which is
//  significantly more efficient than JPEG's DCT-based approach.
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

// MARK: - HEIC Conversion Service

final class HEICConversionService {

    static let shared = HEICConversionService()

    // MARK: - Types

    enum ConversionFormat: String, CaseIterable {
        case heic
        case jpeg
        case png

        var utType: CFString {
            switch self {
            case .heic: return AVFileType.heic as CFString
            case .jpeg: return kUTTypeJPEG
            case .png: return kUTTypePNG
            }
        }

        var fileExtension: String { rawValue }

        var displayName: String {
            switch self {
            case .heic: return "HEIC"
            case .jpeg: return "JPEG"
            case .png: return "PNG"
            }
        }
    }

    struct ConversionResult {
        let outputURL: URL
        let originalSize: Int64
        let convertedSize: Int64
        let format: ConversionFormat

        var savingsPercent: Int {
            guard originalSize > 0 else { return 0 }
            let saved = originalSize - convertedSize
            return max(0, Int((Double(saved) / Double(originalSize)) * 100))
        }

        var formattedOriginalSize: String {
            ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
        }

        var formattedConvertedSize: String {
            ByteCountFormatter.string(fromByteCount: convertedSize, countStyle: .file)
        }
    }

    enum ConversionError: LocalizedError {
        case unsupportedFormat
        case imageSourceCreationFailed
        case imageDestinationCreationFailed
        case conversionFailed
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "Bu format desteklenmiyor."
            case .imageSourceCreationFailed:
                return "Görüntü dosyası okunamadı."
            case .imageDestinationCreationFailed:
                return "Çıktı dosyası oluşturulamadı."
            case .conversionFailed:
                return "Dönüştürme işlemi başarısız oldu."
            case .fileNotFound:
                return "Dosya bulunamadı."
            }
        }
    }

    // MARK: - Public API

    /// Check if device supports HEIC encoding
    var isHEICSupported: Bool {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return types.contains("public.heic")
    }

    /// Detect the format of an image file
    func detectFormat(at url: URL) -> ConversionFormat? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let uti = CGImageSourceGetType(source) as String? else {
            return nil
        }

        if uti.contains("heic") || uti.contains("heif") {
            return .heic
        } else if uti.contains("jpeg") || uti.contains("jpg") {
            return .jpeg
        } else if uti.contains("png") {
            return .png
        }
        return nil
    }

    /// Convert an image file to the specified format
    /// - Parameters:
    ///   - sourceURL: Source image file URL
    ///   - targetFormat: Desired output format
    ///   - quality: Compression quality (0.0-1.0), only applies to lossy formats
    /// - Returns: ConversionResult with output URL and size info
    func convert(
        sourceURL: URL,
        to targetFormat: ConversionFormat,
        quality: Float = 0.82
    ) async throws -> ConversionResult {
        // Validate source exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ConversionError.fileNotFound
        }

        let originalSize = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0

        // Create ImageIO source
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ConversionError.imageSourceCreationFailed
        }

        // Generate output URL
        let outputURL = generateOutputURL(for: sourceURL, format: targetFormat)

        // Create ImageIO destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            targetFormat.utType,
            1,
            nil
        ) else {
            throw ConversionError.imageDestinationCreationFailed
        }

        // Set compression properties
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        // Copy image from source to destination with format conversion
        // This is memory-efficient: ImageIO handles the transcoding internally
        // without loading the full decompressed bitmap into memory
        guard CGImageSourceGetCount(imageSource) > 0 else {
            throw ConversionError.conversionFailed
        }

        CGImageDestinationAddImageFromSource(destination, imageSource, 0, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            // Clean up failed output
            try? FileManager.default.removeItem(at: outputURL)
            throw ConversionError.conversionFailed
        }

        let convertedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

        return ConversionResult(
            outputURL: outputURL,
            originalSize: originalSize,
            convertedSize: convertedSize,
            format: targetFormat
        )
    }

    /// Batch convert multiple images
    func batchConvert(
        urls: [URL],
        to targetFormat: ConversionFormat,
        quality: Float = 0.82,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> [ConversionResult] {
        var results: [ConversionResult] = []

        for (index, url) in urls.enumerated() {
            let result = try await convert(sourceURL: url, to: targetFormat, quality: quality)
            results.append(result)
            onProgress(index + 1, urls.count)
        }

        return results
    }

    /// Estimate savings from converting JPEG to HEIC
    /// Based on typical HEIC savings of 40-50% over JPEG at equivalent quality
    func estimateHEICSavings(jpegSizeBytes: Int64) -> Int64 {
        // HEIC typically achieves 40-50% savings over JPEG
        // Use conservative 40% estimate
        return Int64(Double(jpegSizeBytes) * 0.40)
    }

    // MARK: - Private

    private func generateOutputURL(for sourceURL: URL, format: ConversionFormat) -> URL {
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let outputName = "\(fileName)_converted.\(format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(outputName)
    }
}
