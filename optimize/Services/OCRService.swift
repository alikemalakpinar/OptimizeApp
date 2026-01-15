//
//  OCRService.swift
//  optimize
//
//  Advanced OCR (Optical Character Recognition) using Apple's Vision framework.
//  Extracts text from images and PDFs with high accuracy.
//
//  FEATURES:
//  - Multi-language support (Turkish, English, German, French, etc.)
//  - PDF page-by-page text extraction
//  - Confidence scoring
//  - Text block detection with positioning
//  - Export to TXT, RTF, or searchable PDF
//

import Vision
import UIKit
import PDFKit

// MARK: - OCR Result

struct OCRResult {
    let text: String
    let blocks: [TextBlock]
    let confidence: Float
    let language: String?
    let processingTime: TimeInterval

    struct TextBlock {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }

    var characterCount: Int {
        text.count
    }
}

// MARK: - OCR Page Result (for PDFs)

struct OCRPageResult {
    let pageNumber: Int
    let result: OCRResult
}

// MARK: - OCR Document Result

struct OCRDocumentResult {
    let pages: [OCRPageResult]
    let totalProcessingTime: TimeInterval

    var fullText: String {
        pages.map { $0.result.text }.joined(separator: "\n\n---\n\n")
    }

    var averageConfidence: Float {
        guard !pages.isEmpty else { return 0 }
        return pages.map { $0.result.confidence }.reduce(0, +) / Float(pages.count)
    }

    var totalWordCount: Int {
        pages.map { $0.result.wordCount }.reduce(0, +)
    }
}

// MARK: - OCR Error

enum OCRError: LocalizedError {
    case imageLoadFailed
    case pdfLoadFailed
    case recognitionFailed(Error)
    case noTextFound
    case cancelled
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            return "Görsel yüklenemedi"
        case .pdfLoadFailed:
            return "PDF açılamadı"
        case .recognitionFailed(let error):
            return "Metin tanıma başarısız: \(error.localizedDescription)"
        case .noTextFound:
            return "Metin bulunamadı"
        case .cancelled:
            return "İşlem iptal edildi"
        case .unsupportedFormat:
            return "Desteklenmeyen dosya formatı"
        }
    }
}

// MARK: - OCR Language

enum OCRLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr-TR"
    case english = "en-US"
    case german = "de-DE"
    case french = "fr-FR"
    case spanish = "es-ES"
    case italian = "it-IT"
    case automatic = "auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .italian: return "Italiano"
        case .automatic: return "Otomatik"
        }
    }

    var flag: String {
        switch self {
        case .turkish: return "🇹🇷"
        case .english: return "🇺🇸"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .italian: return "🇮🇹"
        case .automatic: return "🌐"
        }
    }
}

// MARK: - OCR Service

actor OCRService {

    // MARK: - Configuration

    private let recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    private let usesLanguageCorrection: Bool = true

    // MARK: - Supported Formats

    static let supportedImageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp"]
    static let supportedExtensions = supportedImageExtensions + ["pdf"]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Image OCR

    /// Extract text from an image
    func recognizeText(
        in image: UIImage,
        language: OCRLanguage = .automatic,
        progress: @escaping (Double) -> Void = { _ in }
    ) async throws -> OCRResult {

        let startTime = Date()

        guard let cgImage = image.cgImage else {
            throw OCRError.imageLoadFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let blocks = observations.compactMap { observation -> OCRResult.TextBlock? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    return OCRResult.TextBlock(
                        text: topCandidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: topCandidate.confidence
                    )
                }

                let fullText = blocks.map { $0.text }.joined(separator: "\n")
                let avgConfidence = blocks.isEmpty ? 0 : blocks.map { $0.confidence }.reduce(0, +) / Float(blocks.count)

                let result = OCRResult(
                    text: fullText,
                    blocks: blocks,
                    confidence: avgConfidence,
                    language: language.rawValue,
                    processingTime: Date().timeIntervalSince(startTime)
                )

                continuation.resume(returning: result)
            }

            // Configure request
            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = usesLanguageCorrection

            if language != .automatic {
                request.recognitionLanguages = [language.rawValue]
            }

            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    /// Extract text from image URL
    func recognizeText(
        from url: URL,
        language: OCRLanguage = .automatic,
        progress: @escaping (Double) -> Void = { _ in }
    ) async throws -> OCRResult {

        guard url.startAccessingSecurityScopedResource() else {
            throw OCRError.imageLoadFailed
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let image = UIImage(contentsOfFile: url.path) else {
            throw OCRError.imageLoadFailed
        }

        return try await recognizeText(in: image, language: language, progress: progress)
    }

    // MARK: - PDF OCR

    /// Extract text from PDF document
    func recognizeText(
        in pdfURL: URL,
        language: OCRLanguage = .automatic,
        progress: @escaping (Int, Int, Double) -> Void = { _, _, _ in } // (currentPage, totalPages, pageProgress)
    ) async throws -> OCRDocumentResult {

        guard pdfURL.startAccessingSecurityScopedResource() else {
            throw OCRError.pdfLoadFailed
        }
        defer { pdfURL.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: pdfURL) else {
            throw OCRError.pdfLoadFailed
        }

        let startTime = Date()
        var pageResults: [OCRPageResult] = []
        let totalPages = document.pageCount

        for pageIndex in 0..<totalPages {
            try await Task.yield() // Allow cancellation

            guard let page = document.page(at: pageIndex) else { continue }

            // Render page to image
            let image = await renderPageToImage(page: page)

            guard let pageImage = image else { continue }

            // Perform OCR on page
            do {
                let result = try await recognizeText(
                    in: pageImage,
                    language: language,
                    progress: { p in
                        progress(pageIndex + 1, totalPages, p)
                    }
                )

                pageResults.append(OCRPageResult(pageNumber: pageIndex + 1, result: result))
            } catch {
                // Continue with next page even if this one fails
                continue
            }

            progress(pageIndex + 1, totalPages, 1.0)
        }

        if pageResults.isEmpty {
            throw OCRError.noTextFound
        }

        return OCRDocumentResult(
            pages: pageResults,
            totalProcessingTime: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Export

    /// Export OCR result to text file
    func exportToText(result: OCRDocumentResult, filename: String) async throws -> URL {
        let text = result.fullText
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).txt")

        try text.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    /// Create searchable PDF from OCR result
    func createSearchablePDF(
        originalPDF: URL,
        ocrResult: OCRDocumentResult
    ) async throws -> URL {

        guard originalPDF.startAccessingSecurityScopedResource() else {
            throw OCRError.pdfLoadFailed
        }
        defer { originalPDF.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: originalPDF) else {
            throw OCRError.pdfLoadFailed
        }

        // Note: Creating truly searchable PDFs requires embedding text layer
        // This is a simplified version that adds annotations

        for pageResult in ocrResult.pages {
            guard let page = document.page(at: pageResult.pageNumber - 1) else { continue }

            // Add invisible text annotation for searchability
            // In production, you'd embed actual text layer
            let bounds = page.bounds(for: .mediaBox)

            let annotation = PDFAnnotation(
                bounds: bounds,
                forType: .freeText,
                withProperties: nil
            )
            annotation.contents = pageResult.result.text
            annotation.color = .clear
            page.addAnnotation(annotation)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(originalPDF.deletingPathExtension().lastPathComponent)_searchable.pdf")

        document.write(to: outputURL)
        return outputURL
    }

    // MARK: - Helpers

    private func renderPageToImage(page: PDFPage) async -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)

        // Render at 2x for better OCR accuracy
        let scale: CGFloat = 2.0
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
}

// MARK: - Quick Text Detection

extension OCRService {

    /// Quick check if image contains text (faster than full OCR)
    func containsText(in image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let request = VNDetectTextRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
            return !(request.results?.isEmpty ?? true)
        } catch {
            return false
        }
    }

    /// Detect text regions without full recognition
    func detectTextRegions(in image: UIImage) async -> [CGRect] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = false

        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
            return request.results?.map { $0.boundingBox } ?? []
        } catch {
            return []
        }
    }
}
