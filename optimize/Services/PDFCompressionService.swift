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

        defer {
            isProcessing = false
            // Force memory cleanup
            URLCache.shared.removeAllCachedResponses()
        }

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
            self.error = .accessDenied
            throw CompressionError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        guard let pdfDocument = PDFDocument(url: sourceURL) else {
            self.error = .invalidPDF
            throw CompressionError.invalidPDF
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            self.error = .emptyPDF
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
            self.error = .contextCreationFailed
            throw CompressionError.contextCreationFailed
        }

        // Process pages in batches to manage memory for large documents
        let batchSize = 10
        var processedPages = 0

        for batchStart in stride(from: 0, to: pageCount, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, pageCount)

            // Process batch within autoreleasepool to manage memory
            try autoreleasepool {
                for pageIndex in batchStart..<batchEnd {
                    guard let page = pdfDocument.page(at: pageIndex) else {
                        // Skip invalid pages but continue processing
                        processedPages += 1
                        continue
                    }

                    let pageRect = page.bounds(for: .mediaBox)

                    // Guard against invalid page dimensions
                    guard pageRect.width > 0 && pageRect.height > 0 else {
                        processedPages += 1
                        continue
                    }

                    let scaledRect = CGRect(
                        x: 0,
                        y: 0,
                        width: pageRect.width * level.scale,
                        height: pageRect.height * level.scale
                    )

                    // Render page to image with error handling
                    let renderer = UIGraphicsImageRenderer(size: scaledRect.size)
                    let pageImage = renderer.image { ctx in
                        UIColor.white.setFill()
                        ctx.fill(scaledRect)

                        ctx.cgContext.translateBy(x: 0, y: scaledRect.height)
                        ctx.cgContext.scaleBy(x: level.scale, y: -level.scale)

                        page.draw(with: .mediaBox, to: ctx.cgContext)
                    }

                    // Compress the image with fallback
                    let jpegData = pageImage.jpegData(compressionQuality: level.jpegQuality)
                    guard let compressedData = jpegData,
                          let compressedImage = UIImage(data: compressedData),
                          let cgImage = compressedImage.cgImage else {
                        // If compression fails, try with original image
                        if let originalCGImage = pageImage.cgImage {
                            var mediaBox = CGRect(origin: .zero, size: scaledRect.size)
                            pdfContext.beginPage(mediaBox: &mediaBox)
                            pdfContext.draw(originalCGImage, in: mediaBox)
                            pdfContext.endPage()
                        }
                        processedPages += 1
                        continue
                    }

                    // Add to PDF
                    var mediaBox = CGRect(origin: .zero, size: scaledRect.size)
                    pdfContext.beginPage(mediaBox: &mediaBox)
                    pdfContext.draw(cgImage, in: mediaBox)
                    pdfContext.endPage()

                    processedPages += 1

                    // Update progress
                    let pageProgress = Double(processedPages) / Double(pageCount)
                    progress = pageProgress
                    onProgress(.optimizing, pageProgress)
                }
            }

            // Yield to allow UI updates and prevent blocking
            await Task.yield()
        }

        pdfContext.closePDF()

        // Verify we processed at least some pages
        guard processedPages > 0 else {
            self.error = .contextCreationFailed
            throw CompressionError.contextCreationFailed
        }

        // Stage 3: Saving
        currentStage = .downloading
        onProgress(.downloading, 0.5)

        // Write to file with error handling
        do {
            let data = pdfData as Data
            guard !data.isEmpty else {
                self.error = .saveFailed
                throw CompressionError.saveFailed
            }
            try data.write(to: outputURL, options: .atomic)
        } catch {
            self.error = .saveFailed
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
    case memoryPressure
    case fileTooLarge
    case pageProcessingFailed(page: Int)
    case timeout
    case unknown(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Dosyaya erisim izni reddedildi. Lutfen dosyayi tekrar secin."
        case .invalidPDF:
            return "Gecersiz veya bozuk PDF dosyasi. Dosyanin zarar gormediginden emin olun."
        case .emptyPDF:
            return "PDF dosyasi bos veya okunamiyor."
        case .contextCreationFailed:
            return "PDF isleme baslatılamiyor. Cihazinizda yeterli bellek olmayabilir."
        case .saveFailed:
            return "Dosya kaydedilemedi. Depolama alanini kontrol edin."
        case .cancelled:
            return "Islem kullanici tarafindan iptal edildi."
        case .memoryPressure:
            return "Yetersiz bellek. Lutfen bazi uygulamalari kapatip tekrar deneyin."
        case .fileTooLarge:
            return "Dosya cok buyuk. 500 sayfadan kucuk dosyalari deneyin."
        case .pageProcessingFailed(let page):
            return "Sayfa \(page + 1) islenemedi. Dosya bozuk olabilir."
        case .timeout:
            return "Islem zaman asimina ugradi. Daha kucuk bir dosya deneyin."
        case .unknown(let underlying):
            if let error = underlying {
                return "Beklenmeyen hata: \(error.localizedDescription)"
            }
            return "Beklenmeyen bir hata olustu. Lutfen tekrar deneyin."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Dosyayi yeniden secmeyi deneyin."
        case .invalidPDF, .emptyPDF:
            return "Farkli bir PDF dosyasi secin."
        case .contextCreationFailed, .memoryPressure:
            return "Diger uygulamalari kapatin ve tekrar deneyin."
        case .saveFailed:
            return "Depolama alanini bosaltin."
        case .fileTooLarge:
            return "Dosyayi bolmeyi veya daha kucuk bir dosya secmeyi deneyin."
        case .pageProcessingFailed:
            return "Baska bir PDF dosyasi deneyin."
        case .timeout:
            return "Daha kucuk bir dosya veya daha dusuk kalite ayari deneyin."
        default:
            return nil
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
