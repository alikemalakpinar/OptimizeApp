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
import AVFoundation
import Compression

// MARK: - Compression Service
@MainActor
class PDFCompressionService: ObservableObject {
    static let shared = PDFCompressionService()

    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var currentStage: ProcessingStage = .preparing
    @Published var error: CompressionError?

    private init() {}

    // Prepare UI state for a new compression task so progress views
    // immediately reflect the upcoming run.
    func prepareForNewTask() {
        isProcessing = false
        progress = 0
        currentStage = .preparing
        error = nil
    }

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

    private func compressionLevel(for preset: CompressionPreset) -> CompressionLevel {
        switch preset.quality {
        case .low:
            return .mail
        case .medium:
            return .whatsapp
        case .high:
            return .quality
        case .custom:
            return .custom(targetMB: preset.targetSizeMB ?? 25)
        }
    }

    // MARK: - Universal Compression Entrypoint
    func compressFile(
        at sourceURL: URL,
        preset: CompressionPreset,
        onProgress: @escaping (ProcessingStage, Double) -> Void
    ) async throws -> URL {
        let fileType = FileType.from(extension: sourceURL.pathExtension)

        switch fileType {
        case .pdf:
            return try await compressPDF(at: sourceURL, preset: preset, onProgress: onProgress)
        case .image:
            return try await compressImageFile(at: sourceURL, preset: preset, onProgress: onProgress)
        case .video:
            return try await compressVideoFile(at: sourceURL, preset: preset, onProgress: onProgress)
        case .document, .unknown:
            return try compressBinaryFile(at: sourceURL, preset: preset, onProgress: onProgress)
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
        let level = compressionLevel(for: preset)

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

    // MARK: - Compress Images
    private func compressImageFile(
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
        }

        guard sourceURL.startAccessingSecurityScopedResource() else {
            error = .accessDenied
            throw CompressionError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        guard let image = UIImage(contentsOfFile: sourceURL.path) else {
            error = .invalidFile
            throw CompressionError.invalidFile
        }

        onProgress(.preparing, 1.0)

        currentStage = .optimizing
        let level = compressionLevel(for: preset)
        let targetSize = CGSize(
            width: image.size.width * level.scale,
            height: image.size.height * level.scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let compressedData = renderedImage.jpegData(compressionQuality: level.jpegQuality) else {
            error = .saveFailed
            throw CompressionError.saveFailed
        }

        currentStage = .downloading
        onProgress(.downloading, 0.4)

        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let outputURL = getOutputURL(for: sourceURL, preferredExtension: ext)
        try compressedData.write(to: outputURL, options: .atomic)

        onProgress(.downloading, 1.0)
        return outputURL
    }

    // MARK: - Compress Video
    private func compressVideoFile(
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
        }

        let level = compressionLevel(for: preset)
        guard sourceURL.startAccessingSecurityScopedResource() else {
            error = .accessDenied
            throw CompressionError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let asset = AVURLAsset(url: sourceURL, options: nil)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: exportPresetName(for: level)
        ) else {
            error = .contextCreationFailed
            throw CompressionError.contextCreationFailed
        }

        let outputURL = getOutputURL(for: sourceURL, preferredExtension: "mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        currentStage = .optimizing
        onProgress(.optimizing, 0.05)

        let progressTask = Task {
            while exportSession.status == .waiting || exportSession.status == .exporting {
                try await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    let current = Double(exportSession.progress)
                    self.progress = current
                    onProgress(.optimizing, current)
                }
            }
        }

        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                progressTask.cancel()

                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(throwing: CompressionError.exportFailed)
                case .cancelled:
                    continuation.resume(throwing: CompressionError.cancelled)
                default:
                    continuation.resume(throwing: CompressionError.unknown(underlying: exportSession.error))
                }
            }
        }

        currentStage = .downloading
        onProgress(.downloading, 1.0)

        return outputURL
    }

    // MARK: - Compress Generic Binary/Document
    private func compressBinaryFile(
        at sourceURL: URL,
        preset: CompressionPreset,
        onProgress: @escaping (ProcessingStage, Double) -> Void
    ) throws -> URL {
        isProcessing = true
        progress = 0
        currentStage = .preparing
        error = nil

        defer { isProcessing = false }

        guard sourceURL.startAccessingSecurityScopedResource() else {
            error = .accessDenied
            throw CompressionError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: sourceURL)
        onProgress(.preparing, 1.0)

        currentStage = .optimizing
        progress = 0.5
        onProgress(.optimizing, 0.5)

        let compressedData = try compressData(data, algorithm: COMPRESSION_LZFSE)

        currentStage = .downloading
        onProgress(.downloading, 0.8)

        let baseExtension = sourceURL.pathExtension.isEmpty ? "bin" : "\(sourceURL.pathExtension).lzfse"
        let outputURL = getOutputURL(for: sourceURL, preferredExtension: baseExtension)
        try compressedData.write(to: outputURL, options: .atomic)

        onProgress(.downloading, 1.0)
        return outputURL
    }

    private func exportPresetName(for level: CompressionLevel) -> String {
        switch level {
        case .mail:
            return AVAssetExportPreset640x480
        case .whatsapp:
            return AVAssetExportPresetMediumQuality
        case .quality:
            return AVAssetExportPresetHighestQuality
        case .custom(let targetMB):
            return targetMB < 20 ? AVAssetExportPresetLowQuality : AVAssetExportPresetMediumQuality
        }
    }

    // MARK: - Analyze
    func analyze(file: FileInfo) async throws -> AnalysisResult {
        switch file.fileType {
        case .pdf:
            return try await analyzePDF(at: file.url)
        case .image:
            return try analyzeImage(file: file)
        case .video:
            return analyzeVideo(file: file)
        case .document, .unknown:
            return analyzeGeneric(file: file)
        }
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

    private func analyzeImage(file: FileInfo) throws -> AnalysisResult {
        guard file.url.startAccessingSecurityScopedResource() else {
            throw CompressionError.accessDenied
        }
        defer { file.url.stopAccessingSecurityScopedResource() }

        guard let image = UIImage(contentsOfFile: file.url.path) else {
            throw CompressionError.invalidFile
        }

        let megapixels = (image.size.width * image.scale) * (image.size.height * image.scale) / 1_000_000
        let density: AnalysisResult.ImageDensity = megapixels > 3 ? .high : .medium
        let savings: SavingsLevel = file.sizeMB > 15 ? .high : .medium

        return AnalysisResult(
            pageCount: 1,
            imageCount: 1,
            imageDensity: density,
            estimatedSavings: savings,
            isAlreadyOptimized: file.sizeMB < 2,
            originalDPI: Int(image.scale * 72)
        )
    }

    private func analyzeVideo(file: FileInfo) -> AnalysisResult {
        if file.url.startAccessingSecurityScopedResource() {
            defer { file.url.stopAccessingSecurityScopedResource() }
        }

        let asset = AVURLAsset(url: file.url)
        let duration = CMTimeGetSeconds(asset.duration)
        let isLarge = file.sizeMB > 80 || duration > 120

        return AnalysisResult(
            pageCount: 1,
            imageCount: 0,
            imageDensity: isLarge ? .high : .medium,
            estimatedSavings: isLarge ? .high : .medium,
            isAlreadyOptimized: false,
            originalDPI: nil
        )
    }

    private func analyzeGeneric(file: FileInfo) -> AnalysisResult {
        if file.url.startAccessingSecurityScopedResource() {
            defer { file.url.stopAccessingSecurityScopedResource() }
        }

        let highSavings = file.sizeMB > 20

        return AnalysisResult(
            pageCount: 1,
            imageCount: 0,
            imageDensity: highSavings ? .high : .medium,
            estimatedSavings: highSavings ? .high : .medium,
            isAlreadyOptimized: file.sizeMB < 5,
            originalDPI: nil
        )
    }

    // MARK: - Helper Methods
    private func getOutputURL(for sourceURL: URL, preferredExtension: String? = nil) -> URL {
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = preferredExtension ?? sourceURL.pathExtension
        let safeExtension = ext.isEmpty ? "file" : ext
        let outputName = "\(fileName)_optimized.\(safeExtension)"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(outputName)
    }

    private func compressData(_ data: Data, algorithm: compression_algorithm) throws -> Data {
        let destinationBufferSize = compression_encode_scratch_buffer_size(algorithm)
        let scratchBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
        defer { scratchBuffer.deallocate() }

        let destinationCapacity = max(data.count, 1) * 2
        let destinationPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationCapacity)
        defer { destinationPointer.deallocate() }

        let compressedSize = data.withUnsafeBytes { (sourcePointer: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = sourcePointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }

            return compression_encode_buffer(
                destinationPointer,
                destinationCapacity,
                baseAddress,
                data.count,
                scratchBuffer,
                algorithm
            )
        }

        guard compressedSize > 0 else {
            throw CompressionError.saveFailed
        }

        return Data(bytes: destinationPointer, count: compressedSize)
    }
}

// MARK: - Compression Error
enum CompressionError: LocalizedError {
    case accessDenied
    case invalidPDF
    case invalidFile
    case emptyPDF
    case contextCreationFailed
    case saveFailed
    case cancelled
    case memoryPressure
    case fileTooLarge
    case pageProcessingFailed(page: Int)
    case timeout
    case exportFailed
    case unsupportedType
    case unknown(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "File access denied. Please select the file again."
        case .invalidPDF:
            return "Invalid or corrupted PDF file. Please ensure the file is not damaged."
        case .invalidFile:
            return "This file could not be read."
        case .emptyPDF:
            return "PDF file is empty or cannot be read."
        case .contextCreationFailed:
            return "Unable to start PDF processing. Your device may be low on memory."
        case .saveFailed:
            return "Could not save file. Please check your storage space."
        case .cancelled:
            return "Operation cancelled by user."
        case .memoryPressure:
            return "Insufficient memory. Please close some apps and try again."
        case .fileTooLarge:
            return "File too large. Please try files with less than 500 pages."
        case .pageProcessingFailed(let page):
            return "Page \(page + 1) could not be processed. The file may be corrupted."
        case .timeout:
            return "Operation timed out. Please try a smaller file."
        case .exportFailed:
            return "Video export failed. Please try a lower quality preset."
        case .unsupportedType:
            return "This file type is not supported yet."
        case .unknown(let underlying):
            if let error = underlying {
                return "Unexpected error: \(error.localizedDescription)"
            }
            return "An unexpected error occurred. Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Try selecting the file again."
        case .invalidPDF, .emptyPDF, .invalidFile:
            return "Select a different file."
        case .contextCreationFailed, .memoryPressure:
            return "Close other apps and try again."
        case .saveFailed:
            return "Free up storage space."
        case .fileTooLarge:
            return "Try splitting the file or select a smaller file."
        case .pageProcessingFailed:
            return "Try a different PDF file."
        case .timeout:
            return "Try a smaller file or lower quality setting."
        case .exportFailed:
            return "Try a lower resolution export."
        case .unsupportedType:
            return "Pick a PDF, image, video or document file."
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
