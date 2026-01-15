//
//  PDFUltraRebuilder.swift
//  optimize
//
//  The "Secret Weapon" - Complete PDF reconstruction engine.
//  Tears apart PDFs and rebuilds them from scratch for maximum compression.
//
//  CAPABILITIES:
//  - 100% removal of incremental updates
//  - Ghost object elimination
//  - Embedded font removal (rasterization)
//  - Layer flattening
//  - Intelligent page-by-page compression
//  - Memory-safe streaming for large documents
//
//  PHILOSOPHY:
//  - "If in doubt, rebuild it"
//  - Maximum compression over editability
//  - Clean, linear output
//

import Foundation
import PDFKit
import UIKit
import CoreGraphics

// MARK: - Rebuild Result

struct PDFRebuildResult {
    let outputURL: URL
    let originalSize: Int64
    let rebuiltSize: Int64
    let pageCount: Int
    let rebuildMode: PDFRebuildMode
    let processingTime: TimeInterval

    var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return 1.0 - (Double(rebuiltSize) / Double(originalSize))
    }

    var savedBytes: Int64 {
        originalSize - rebuiltSize
    }
}

// MARK: - Rebuild Error

enum PDFRebuildError: Error, LocalizedError {
    case invalidPDF
    case accessDenied
    case outputFailed
    case memoryPressure
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "PDF dosyası geçersiz veya hasarlı"
        case .accessDenied:
            return "Dosyaya erişim izni yok"
        case .outputFailed:
            return "Çıktı dosyası oluşturulamadı"
        case .memoryPressure:
            return "Yetersiz bellek"
        case .cancelled:
            return "İşlem iptal edildi"
        }
    }
}

// MARK: - PDF Ultra Rebuilder

final class PDFUltraRebuilder {

    // MARK: - Singleton

    static let shared = PDFUltraRebuilder()

    // MARK: - Configuration

    private let memoryWarningThreshold: Int = 100 * 1024 * 1024 // 100MB

    // MARK: - Main Rebuild Method

    /// Completely rebuild PDF from scratch
    /// - Parameters:
    ///   - sourceURL: Input PDF URL
    ///   - outputURL: Output PDF URL
    ///   - profile: Optimization profile
    ///   - onProgress: Progress callback (0.0 - 1.0)
    /// - Returns: Rebuild result
    func rebuild(
        sourceURL: URL,
        outputURL: URL,
        profile: OptimizationProfile,
        onProgress: @escaping (Double) -> Void
    ) async throws -> PDFRebuildResult {
        let startTime = Date()

        // Access security-scoped resource
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw PDFRebuildError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        // Open source document
        guard let document = PDFDocument(url: sourceURL) else {
            throw PDFRebuildError.invalidPDF
        }

        let pageCount = document.pageCount
        let originalSize = getFileSize(sourceURL)

        // Choose rebuild strategy based on profile and page count
        if profile.pdfRebuildMode == .ultra || pageCount > 100 {
            try await rebuildWithStreaming(
                document: document,
                outputURL: outputURL,
                profile: profile,
                onProgress: onProgress
            )
        } else {
            try await rebuildWithRenderer(
                document: document,
                outputURL: outputURL,
                profile: profile,
                onProgress: onProgress
            )
        }

        let rebuiltSize = getFileSize(outputURL)
        let processingTime = Date().timeIntervalSince(startTime)

        return PDFRebuildResult(
            outputURL: outputURL,
            originalSize: originalSize,
            rebuiltSize: rebuiltSize,
            pageCount: pageCount,
            rebuildMode: profile.pdfRebuildMode,
            processingTime: processingTime
        )
    }

    // MARK: - Renderer-Based Rebuild (Best Quality)

    private func rebuildWithRenderer(
        document: PDFDocument,
        outputURL: URL,
        profile: OptimizationProfile,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        let pageCount = document.pageCount

        // Create PDF context
        guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: nil, nil) else {
            throw PDFRebuildError.outputFailed
        }

        for pageIndex in 0..<pageCount {
            try autoreleasepool {
                // Check for cancellation
                if Task.isCancelled {
                    throw PDFRebuildError.cancelled
                }

                guard let page = document.page(at: pageIndex) else { return }
                let bounds = page.bounds(for: .mediaBox)

                // Begin PDF page
                var mediaBox = bounds
                pdfContext.beginPage(mediaBox: &mediaBox)

                // Render based on mode
                if profile.pdfRebuildMode == .ultra {
                    // Rasterize the page
                    try renderPageAsImage(
                        page: page,
                        bounds: bounds,
                        context: pdfContext,
                        profile: profile
                    )
                } else {
                    // Draw page directly (preserves vectors)
                    pdfContext.saveGState()

                    // Flip coordinate system for PDF drawing
                    pdfContext.translateBy(x: 0, y: bounds.height)
                    pdfContext.scaleBy(x: 1, y: -1)

                    page.draw(with: .mediaBox, to: pdfContext)

                    pdfContext.restoreGState()
                }

                pdfContext.endPage()

                // Report progress
                onProgress(Double(pageIndex + 1) / Double(pageCount))

                // Memory pressure check
                if pageIndex % 10 == 0 {
                    cleanupMemory()
                }
            }
        }

        pdfContext.closePDF()
    }

    // MARK: - Streaming Rebuild (Memory Efficient)

    private func rebuildWithStreaming(
        document: PDFDocument,
        outputURL: URL,
        profile: OptimizationProfile,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        let pageCount = document.pageCount

        // Use PDFDocument for output (more memory efficient for large docs)
        let outputDocument = PDFDocument()

        // Process in batches
        let batchSize = 10
        var processedCount = 0

        for batchStart in stride(from: 0, to: pageCount, by: batchSize) {
            try autoreleasepool {
                let batchEnd = min(batchStart + batchSize, pageCount)

                for pageIndex in batchStart..<batchEnd {
                    if Task.isCancelled {
                        throw PDFRebuildError.cancelled
                    }

                    guard let page = document.page(at: pageIndex) else { continue }
                    let bounds = page.bounds(for: .mediaBox)

                    // Render page to image
                    let renderedImage = renderPageToImage(
                        page: page,
                        bounds: bounds,
                        profile: profile
                    )

                    // Compress the image
                    guard let compressedImage = compressRenderedImage(
                        renderedImage,
                        profile: profile
                    ) else { continue }

                    // Create new PDF page from image
                    if let newPage = PDFPage(image: compressedImage) {
                        outputDocument.insert(newPage, at: outputDocument.pageCount)
                    }

                    processedCount += 1
                    onProgress(Double(processedCount) / Double(pageCount))
                }

                // Force memory cleanup between batches
                cleanupMemory()
            }
        }

        // Write output
        guard outputDocument.write(to: outputURL) else {
            throw PDFRebuildError.outputFailed
        }
    }

    // MARK: - Page Rendering

    private func renderPageAsImage(
        page: PDFPage,
        bounds: CGRect,
        context: CGContext,
        profile: OptimizationProfile
    ) throws {
        let dpi = CGFloat(profile.targetDPI)
        let scale = dpi / 72.0

        let imageSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        // Render to image
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { ctx in
            // White background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))

            // Scale and draw
            ctx.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }

        // Compress the image
        guard let compressedData = image.jpegData(compressionQuality: profile.imageQuality),
              let compressedImage = UIImage(data: compressedData) else {
            // Fallback: draw original
            context.draw(image.cgImage!, in: bounds)
            return
        }

        // Draw compressed image into PDF context
        if let cgImage = compressedImage.cgImage {
            context.draw(cgImage, in: bounds)
        }
    }

    private func renderPageToImage(
        page: PDFPage,
        bounds: CGRect,
        profile: OptimizationProfile
    ) -> UIImage {
        let dpi = CGFloat(profile.targetDPI)
        let scale = dpi / 72.0

        // Limit maximum size to prevent memory issues
        let maxDimension: CGFloat = 3000
        let pageMaxDim = max(bounds.width, bounds.height) * scale
        let finalScale = pageMaxDim > maxDimension ? (maxDimension / pageMaxDim) * scale : scale

        let imageSize = CGSize(
            width: bounds.width * finalScale,
            height: bounds.height * finalScale
        )

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { ctx in
            // White background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))

            // Draw page
            ctx.cgContext.scaleBy(x: finalScale, y: finalScale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private func compressRenderedImage(
        _ image: UIImage,
        profile: OptimizationProfile
    ) -> UIImage? {
        // Determine quality based on profile
        let quality: CGFloat
        switch profile.pdfRebuildMode {
        case .safe:
            quality = 0.85
        case .smart:
            quality = 0.75
        case .ultra:
            quality = 0.60
        }

        guard let data = image.jpegData(compressionQuality: quality),
              let compressedImage = UIImage(data: data) else {
            return image // Return original if compression fails
        }

        return compressedImage
    }

    // MARK: - Memory Management

    private func cleanupMemory() {
        // Trigger autorelease pool drain
        autoreleasepool { }

        // Suggest garbage collection
        #if DEBUG
        print("PDFUltraRebuilder: Memory cleanup triggered")
        #endif
    }

    // MARK: - Helpers

    private func getFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }
}

// MARK: - Convenience Methods

extension PDFUltraRebuilder {

    /// Quick rebuild with balanced settings
    func quickRebuild(
        sourceURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws -> PDFRebuildResult {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        return try await rebuild(
            sourceURL: sourceURL,
            outputURL: outputURL,
            profile: .balanced,
            onProgress: onProgress
        )
    }

    /// Maximum compression rebuild
    func ultraRebuild(
        sourceURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws -> PDFRebuildResult {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        return try await rebuild(
            sourceURL: sourceURL,
            outputURL: outputURL,
            profile: .ultra,
            onProgress: onProgress
        )
    }

    /// Estimate rebuild potential without processing
    func estimateRebuildPotential(sourceURL: URL) async -> Double {
        let report = await PreflightAnalyzer.shared.analyze(url: sourceURL)
        return report.compressionPotential
    }
}

// MARK: - Safe Mode Optimizer

extension PDFUltraRebuilder {

    /// Safe mode: Clean without rasterizing (preserves vectors)
    func cleanPDF(
        sourceURL: URL,
        outputURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws -> PDFRebuildResult {
        let startTime = Date()

        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw PDFRebuildError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: sourceURL) else {
            throw PDFRebuildError.invalidPDF
        }

        let originalSize = getFileSize(sourceURL)

        // Simply re-write the PDF (removes incremental updates)
        let outputDocument = PDFDocument()

        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                outputDocument.insert(page, at: outputDocument.pageCount)
            }
            onProgress(Double(i + 1) / Double(document.pageCount))
        }

        guard outputDocument.write(to: outputURL) else {
            throw PDFRebuildError.outputFailed
        }

        let rebuiltSize = getFileSize(outputURL)

        return PDFRebuildResult(
            outputURL: outputURL,
            originalSize: originalSize,
            rebuiltSize: rebuiltSize,
            pageCount: document.pageCount,
            rebuildMode: .safe,
            processingTime: Date().timeIntervalSince(startTime)
        )
    }
}
