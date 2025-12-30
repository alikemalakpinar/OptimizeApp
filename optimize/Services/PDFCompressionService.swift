//
//  PDFCompressionService.swift
//  optimize
//
//  Real PDF compression service using CoreGraphics and PDFKit
//

import Foundation
import PDFKit
import UIKit
import CoreGraphics

// MARK: - Compression Service
@MainActor
class PDFCompressionService: ObservableObject {
    static let shared = PDFCompressionService()

    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var currentStage: ProcessingStage = .preparing
    @Published var error: CompressionError?

    private init() {}

    // MARK: - Compression Quality
    enum CompressionLevel {
        case mail       // Aggressive compression, target ~25MB
        case whatsapp   // Medium compression
        case quality    // Light compression, best quality
        case custom(targetMB: Int)

        var jpegQuality: CGFloat {
            switch self {
            case .mail: return 0.3
            case .whatsapp: return 0.5
            case .quality: return 0.75
            case .custom(let targetMB):
                if targetMB < 10 { return 0.2 }
                else if targetMB < 25 { return 0.4 }
                else if targetMB < 50 { return 0.6 }
                else { return 0.7 }
            }
        }

        var scale: CGFloat {
            switch self {
            case .mail: return 0.5
            case .whatsapp: return 0.65
            case .quality: return 0.85
            case .custom(let targetMB):
                if targetMB < 10 { return 0.4 }
                else if targetMB < 25 { return 0.55 }
                else if targetMB < 50 { return 0.7 }
                else { return 0.8 }
            }
        }
    }

    // MARK: - Compress PDF
    func compressPDF(
        at sourceURL: URL,
        preset: CompressionPreset,
        onProgress: @escaping (ProcessingStage, Double) -> Void
    ) async throws -> URL {
        isProcessing = true
        progress = 0
        currentStage = .preparing
        error = nil

        defer { isProcessing = false }

        // Determine compression level
        let level: CompressionLevel
        switch preset.quality {
        case .low:
            level = .mail
        case .medium:
            level = .whatsapp
        case .high:
            level = .quality
        case .custom:
            level = .custom(targetMB: preset.targetSizeMB ?? 25)
        }

        // Stage 1: Preparing - Read the PDF
        currentStage = .preparing
        onProgress(.preparing, 0)

        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw CompressionError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        guard let pdfDocument = PDFDocument(url: sourceURL) else {
            throw CompressionError.invalidPDF
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw CompressionError.emptyPDF
        }

        onProgress(.preparing, 1.0)

        // Stage 2: Processing each page
        currentStage = .optimizing

        // Create output directory
        let outputURL = getOutputURL(for: sourceURL)

        // Create new PDF context
        guard let pdfData = NSMutableData() as CFMutableData?,
              let consumer = CGDataConsumer(data: pdfData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw CompressionError.contextCreationFailed
        }

        // Process each page
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            let pageRect = page.bounds(for: .mediaBox)
            let scaledRect = CGRect(
                x: 0,
                y: 0,
                width: pageRect.width * level.scale,
                height: pageRect.height * level.scale
            )

            // Render page to image
            let renderer = UIGraphicsImageRenderer(size: scaledRect.size)
            let pageImage = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(scaledRect)

                ctx.cgContext.translateBy(x: 0, y: scaledRect.height)
                ctx.cgContext.scaleBy(x: level.scale, y: -level.scale)

                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            // Compress the image
            guard let compressedData = pageImage.jpegData(compressionQuality: level.jpegQuality),
                  let compressedImage = UIImage(data: compressedData) else {
                continue
            }

            // Add to PDF
            var mediaBox = CGRect(origin: .zero, size: scaledRect.size)
            pdfContext.beginPage(mediaBox: &mediaBox)

            if let cgImage = compressedImage.cgImage {
                pdfContext.draw(cgImage, in: mediaBox)
            }

            pdfContext.endPage()

            // Update progress
            let pageProgress = Double(pageIndex + 1) / Double(pageCount)
            progress = pageProgress
            onProgress(.optimizing, pageProgress)
        }

        pdfContext.closePDF()

        // Stage 3: Saving
        currentStage = .downloading
        onProgress(.downloading, 0.5)

        // Write to file
        do {
            try (pdfData as Data).write(to: outputURL)
        } catch {
            throw CompressionError.saveFailed
        }

        onProgress(.downloading, 1.0)

        return outputURL
    }

    // MARK: - Analyze PDF
    func analyzePDF(at url: URL) async throws -> AnalysisResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw CompressionError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let pdfDocument = PDFDocument(url: url) else {
            throw CompressionError.invalidPDF
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw CompressionError.emptyPDF
        }

        // Analyze content
        var imageCount = 0
        var totalTextLength = 0

        for pageIndex in 0..<min(pageCount, 10) { // Sample first 10 pages
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Count annotations/images (simplified)
            imageCount += page.annotations.count

            // Get text content
            if let pageContent = page.string {
                totalTextLength += pageContent.count
            }
        }

        // Estimate based on content
        let avgTextPerPage = totalTextLength / max(pageCount, 1)
        let avgImagesPerPage = imageCount / max(min(pageCount, 10), 1)

        // Determine density and savings
        let imageDensity: AnalysisResult.ImageDensity
        let estimatedSavings: SavingsLevel

        if avgImagesPerPage > 5 || avgTextPerPage < 100 {
            imageDensity = .high
            estimatedSavings = .high
        } else if avgImagesPerPage > 2 || avgTextPerPage < 500 {
            imageDensity = .medium
            estimatedSavings = .medium
        } else {
            imageDensity = .low
            estimatedSavings = .low
        }

        // Check if already optimized (small file size per page)
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let sizePerPage = fileSize / Int64(max(pageCount, 1))
        let isAlreadyOptimized = sizePerPage < 50_000 // Less than 50KB per page

        return AnalysisResult(
            pageCount: pageCount,
            imageCount: imageCount * pageCount / max(min(pageCount, 10), 1),
            imageDensity: imageDensity,
            estimatedSavings: isAlreadyOptimized ? .low : estimatedSavings,
            isAlreadyOptimized: isAlreadyOptimized,
            originalDPI: 300 // Estimated
        )
    }

    // MARK: - Helper Methods
    private func getOutputURL(for sourceURL: URL) -> URL {
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let outputName = "\(fileName)_optimized.pdf"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(outputName)
    }
}

// MARK: - Compression Error
enum CompressionError: LocalizedError {
    case accessDenied
    case invalidPDF
    case emptyPDF
    case contextCreationFailed
    case saveFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Dosyaya erişim izni reddedildi"
        case .invalidPDF:
            return "Geçersiz veya bozuk PDF dosyası"
        case .emptyPDF:
            return "PDF dosyası boş"
        case .contextCreationFailed:
            return "PDF işleme hatası"
        case .saveFailed:
            return "Dosya kaydedilemedi"
        case .cancelled:
            return "İşlem iptal edildi"
        }
    }
}

// MARK: - File Info Extension
extension FileInfo {
    static func from(url: URL) throws -> FileInfo {
        guard url.startAccessingSecurityScopedResource() else {
            throw CompressionError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
        let fileSize = resourceValues.fileSize ?? 0

        // Get page count if PDF
        var pageCount: Int? = nil
        if url.pathExtension.lowercased() == "pdf" {
            if let pdfDocument = PDFDocument(url: url) {
                pageCount = pdfDocument.pageCount
            }
        }

        let fileType = FileType.from(extension: url.pathExtension)

        return FileInfo(
            name: url.lastPathComponent,
            url: url,
            size: Int64(fileSize),
            pageCount: pageCount,
            fileType: fileType
        )
    }
}
