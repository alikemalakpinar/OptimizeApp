//
//  LargePDFHandler.swift
//  optimize
//
//  Specialized handler for large PDFs (50+ pages) to prevent OOM crashes.
//
//  PROBLEM:
//  - Normal mode generates thumbnails for ALL pages
//  - 500 pages × 1MB each = 500MB RAM = iOS kills the app
//
//  SOLUTION:
//  - Skip thumbnail generation for large PDFs
//  - Process pages in batches with autoreleasepool
//  - Show simple file info instead of preview
//  - Use streaming compression (page-by-page)
//

import Foundation
import PDFKit
import UIKit

// MARK: - Large PDF Configuration

enum LargePDFConfig {
    /// Maximum pages before switching to "large PDF" mode
    static let thumbnailPageLimit = 50

    /// Maximum pages to show in preview grid
    static let previewPageLimit = 20

    /// Batch size for processing pages
    static let processingBatchSize = 10

    /// Memory warning threshold (bytes)
    static let memoryWarningThreshold: UInt64 = 200_000_000 // 200MB
}

// MARK: - PDF Size Category

enum PDFSizeCategory {
    case small      // < 20 pages - Full preview
    case medium     // 20-50 pages - Limited preview
    case large      // 50-200 pages - No preview, batch processing
    case massive    // 200+ pages - Streaming only

    static func from(pageCount: Int) -> PDFSizeCategory {
        switch pageCount {
        case 0..<20: return .small
        case 20..<50: return .medium
        case 50..<200: return .large
        default: return .massive
        }
    }

    var shouldGenerateThumbnails: Bool {
        switch self {
        case .small, .medium: return true
        case .large, .massive: return false
        }
    }

    var thumbnailLimit: Int {
        switch self {
        case .small: return 50
        case .medium: return 20
        case .large, .massive: return 0
        }
    }

    var processingStrategy: ProcessingStrategy {
        switch self {
        case .small: return .inMemory
        case .medium: return .batched(size: 20)
        case .large: return .batched(size: 10)
        case .massive: return .streaming
        }
    }

    var userMessage: String {
        switch self {
        case .small:
            return "Dosya analiz ediliyor..."
        case .medium:
            return "Orta boyutlu belge. Optimize ediliyor..."
        case .large:
            return "Büyük belge tespit edildi. Bellek korumalı modda işleniyor..."
        case .massive:
            return "Çok büyük belge! Akış modunda sayfa sayfa işleniyor..."
        }
    }
}

enum ProcessingStrategy {
    case inMemory
    case batched(size: Int)
    case streaming
}

// MARK: - Large PDF Handler

actor LargePDFHandler {

    // MARK: - PDF Analysis (Memory Safe)

    /// Analyze PDF without loading all pages into memory
    /// Returns basic info suitable for display
    struct PDFQuickInfo {
        let pageCount: Int
        let fileSize: Int64
        let sizeCategory: PDFSizeCategory
        let estimatedProcessingTime: TimeInterval
        let recommendedPreset: String
        let canShowPreview: Bool
        let firstPageThumbnail: UIImage?
    }

    func analyzePDF(url: URL) async -> PDFQuickInfo? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else { return nil }

        let pageCount = document.pageCount
        let fileSize = getFileSize(url)
        let category = PDFSizeCategory.from(pageCount: pageCount)

        // Only generate first page thumbnail for large PDFs
        var thumbnail: UIImage? = nil
        if let firstPage = document.page(at: 0) {
            thumbnail = generateThumbnail(for: firstPage, maxSize: 200)
        }

        // Estimate processing time (rough)
        let estimatedTime = Double(pageCount) * 0.1 + Double(fileSize) / 10_000_000

        return PDFQuickInfo(
            pageCount: pageCount,
            fileSize: fileSize,
            sizeCategory: category,
            estimatedProcessingTime: estimatedTime,
            recommendedPreset: category == .massive ? "Balanced" : "High Quality",
            canShowPreview: category.shouldGenerateThumbnails,
            firstPageThumbnail: thumbnail
        )
    }

    // MARK: - Thumbnail Generation (Limited)

    /// Generate thumbnails only up to the limit
    func generateLimitedThumbnails(
        url: URL,
        limit: Int,
        onProgress: @escaping (Int, Int) -> Void
    ) async -> [UIImage] {
        guard url.startAccessingSecurityScopedResource() else { return [] }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else { return [] }

        let pageCount = min(document.pageCount, limit)
        var thumbnails: [UIImage] = []
        thumbnails.reserveCapacity(pageCount)

        for i in 0..<pageCount {
            autoreleasepool {
                if let page = document.page(at: i),
                   let thumbnail = generateThumbnail(for: page, maxSize: 150) {
                    thumbnails.append(thumbnail)
                }
                onProgress(i + 1, pageCount)
            }
        }

        return thumbnails
    }

    // MARK: - Streaming Compression

    /// Process PDF page-by-page without loading entire document
    func compressLargePDF(
        sourceURL: URL,
        destinationURL: URL,
        quality: Float,
        onProgress: @escaping (Int, Int, String) -> Void
    ) async throws {
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw CompressionError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: sourceURL) else {
            throw CompressionError.invalidPDF
        }

        let pageCount = document.pageCount
        let category = PDFSizeCategory.from(pageCount: pageCount)

        // Create output PDF
        let outputDocument = PDFDocument()

        // Process in batches to manage memory
        let batchSize: Int
        switch category.processingStrategy {
        case .inMemory:
            batchSize = pageCount
        case .batched(let size):
            batchSize = size
        case .streaming:
            batchSize = 1
        }

        for batchStart in stride(from: 0, to: pageCount, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, pageCount)

            // Process batch with memory cleanup
            autoreleasepool {
                for i in batchStart..<batchEnd {
                    autoreleasepool {
                        guard let page = document.page(at: i) else { return }

                        // Compress page
                        if let compressedPage = compressPage(page, quality: quality) {
                            outputDocument.insert(compressedPage, at: outputDocument.pageCount)
                        } else {
                            // Fallback: use original page
                            outputDocument.insert(page, at: outputDocument.pageCount)
                        }

                        let statusMessage = category == .massive
                            ? "Sayfa \(i + 1)/\(pageCount) işleniyor..."
                            : "İşleniyor..."

                        onProgress(i + 1, pageCount, statusMessage)
                    }
                }
            }

            // Check memory pressure
            if isMemoryPressureHigh() {
                // Force garbage collection
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }

        // Write output
        outputDocument.write(to: destinationURL)
    }

    // MARK: - Helpers

    private func generateThumbnail(for page: PDFPage, maxSize: CGFloat) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(maxSize / bounds.width, maxSize / bounds.height)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private func compressPage(_ page: PDFPage, quality: Float) -> PDFPage? {
        let bounds = page.bounds(for: .mediaBox)

        // Render to image
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds.size))
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }

        // Compress
        guard let jpegData = image.jpegData(compressionQuality: CGFloat(quality)),
              let compressedImage = UIImage(data: jpegData) else {
            return nil
        }

        return PDFPage(image: compressedImage)
    }

    private func getFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private func isMemoryPressureHigh() -> Bool {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return info.resident_size > LargePDFConfig.memoryWarningThreshold
        }
        return false
    }
}

// MARK: - Large PDF Info Card (SwiftUI Component)

import SwiftUI

struct LargePDFInfoCard: View {
    let info: LargePDFHandler.PDFQuickInfo

    var body: some View {
        VStack(spacing: 16) {
            // Warning banner for massive PDFs
            if info.sizeCategory == .massive {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Çok büyük dosya - Özel işlem modu aktif")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(10)
            }

            HStack(spacing: 16) {
                // Thumbnail or placeholder
                if let thumbnail = info.firstPageThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 100)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(width: 80, height: 100)
                        .overlay(
                            Image(systemName: "doc.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("\(info.pageCount) sayfa", systemImage: "doc.on.doc")
                        Spacer()
                        Label(formatBytes(info.fileSize), systemImage: "externaldrive")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                    Text(info.sizeCategory.userMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    if !info.canShowPreview {
                        Text("Önizleme: Devre dışı (bellek koruma)")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
