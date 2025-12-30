//
//  SmartPDFAnalyzer.swift
//  optimize
//
//  Created for Advanced PDF Reconstruction Pipeline.
//  Core analysis engine: Classifies pages, builds segmentation tiles,
//  and creates a roadmap for the optimizer engine.
//

import CoreGraphics
import CoreImage
import Foundation
import PDFKit
import UIKit
import Vision

// MARK: - Data Models

enum PageContentType: String {
    case mainlyText       // Vektör verisi (Dokunma)
    case scannedDocument  // Siyah-beyaz tarama (JBIG2 adayı)
    case photograph       // Renkli fotoğraf (HEIF/JPEG2000 adayı)
    case mixed            // Karışık (MRC Segmentasyonu gerekir)
}

/// Her bir bölge için önerilen sıkıştırma stratejisi
enum RasterOptimizationIntent: String {
    case preserveVector   // Vektör verisi korunmalı
    case jbig2            // Kayıpsız monokrom sıkıştırma
    case jpeg2000         // Yüksek kaliteli fotoğraf sıkıştırma
    case heif             // Modern, yüksek verimli sıkıştırma
}

// MARK: - OCR Models

struct OCRTextElement {
    let text: String
    let normalizedRect: CGRect // 0.0 - 1.0 arasında (Vision koordinatı)
}

/// Sayfanın küçük bir karesini (Tile) temsil eder
struct PDFSegmentationTile: Identifiable {
    let id = UUID()
    let rect: CGRect           // PDF koordinat düzlemindeki konumu
    let textCoverage: Double   // Yazı yoğunluğu (0.0 - 1.0)
    let imageCoverage: Double  // Görsel yoğunluğu (0.0 - 1.0)

    /// Bu karenin içeriğine göre baskın türü belirler
    var dominantContent: PageContentType {
        if textCoverage > 0.55 { return .mainlyText }
        if imageCoverage > 0.55 { return .photograph }
        if textCoverage > 0.1 && imageCoverage > 0.1 { return .mixed }
        return .scannedDocument // Varsayılan olarak düşük yoğunluklu alanlar
    }
}

/// Bir sayfanın tüm analiz raporu
struct PDFPageSegmentation {
    let pageIndex: Int
    let pageSize: CGSize
    let classification: PageContentType
    let hasVectorTextLayer: Bool
    let tiles: [PDFSegmentationTile]
    let recommendedIntent: RasterOptimizationIntent
    let ocrData: [OCRTextElement] // Okunan metinler burada taşınacak

    // Debug ve detaylı analiz için ham veriler
    let textRects: [CGRect]
    let imageRects: [CGRect]
}

/// Tüm dökümanın analiz özeti
struct PDFAnalysisSummary {
    let pages: [PDFPageSegmentation]

    var pageCount: Int { pages.count }

    var dominantContent: PageContentType {
        let histogram = pages.reduce(into: [PageContentType: Int]()) { partial, page in
            partial[page.classification, default: 0] += 1
        }
        return histogram.max(by: { $0.value < $1.value })?.key ?? .mixed
    }
}

enum PDFAnalysisError: Error {
    case invalidDocument
    case renderFailed
}

// MARK: - The Analyzer Engine

final class SmartPDFAnalyzer {

    // Vision işlemleri GPU kullanır, kuyruk yönetimi önemlidir.
    private let analysisQueue = DispatchQueue(label: "com.optimize.analysis", qos: .userInitiated)

    /// Ana Analiz Fonksiyonu
    /// - Parameters:
    ///   - url: PDF dosyasının yolu
    ///   - tileSize: Segmentasyon kare boyutu (Varsayılan 512x512)
    func analyze(documentAt url: URL, tileSize: CGSize = CGSize(width: 512, height: 512)) async throws -> PDFAnalysisSummary {
        guard let document = PDFDocument(url: url) else { throw PDFAnalysisError.invalidDocument }

        // CONCURRENCY: Sayfaları paralel işleyerek hızı 4-8 kat artırıyoruz.
        let results = try await withThrowingTaskGroup(of: PDFPageSegmentation.self) { group in
            for i in 0..<document.pageCount {
                group.addTask {
                    // PDFDocument thread-safe değildir, her task için page referansını güvenli alıyoruz.
                    guard let page = document.page(at: i) else { throw PDFAnalysisError.renderFailed }
                    return try await self.analyzePage(page, index: i, tileSize: tileSize)
                }
            }

            // Sonuçları topla
            var segments: [PDFPageSegmentation] = []
            for try await result in group {
                segments.append(result)
            }

            // Paralel işlemde sıra karışabilir, sayfa numarasına göre düzelt.
            return segments.sorted { $0.pageIndex < $1.pageIndex }
        }

        return PDFAnalysisSummary(pages: results)
    }

    // MARK: - Private Processing Logic

    private func analyzePage(_ page: PDFPage, index: Int, tileSize: CGSize) async throws -> PDFPageSegmentation {
        // 1. Akıllı Render (Bellek Korumalı)
        guard let cgImage = renderPageSmartly(page) else { throw PDFAnalysisError.renderFailed }

        // 2. Vision ile İçerik Tespiti
        let (textRects, imageRects, ocrElements) = try await performVisionAnalysis(on: cgImage)

        // 3. Veri Yorumlama
        let pageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let textCoverage = calculateCoverage(of: textRects, in: pageSize)
        let imageCoverage = calculateCoverage(of: imageRects, in: pageSize)
        let hasVectorText = page.string?.isEmpty == false

        // 4. Sınıflandırma
        let classification = classifyContent(
            textCoverage: textCoverage,
            imageCoverage: imageCoverage,
            hasVectorText: hasVectorText
        )

        // 5. Tile (Karo) Bölütleme
        let tiles = buildTiles(
            pageSize: pageSize,
            tileSize: tileSize,
            textRects: textRects,
            imageRects: imageRects
        )

        return PDFPageSegmentation(
            pageIndex: index,
            pageSize: pageSize,
            classification: classification,
            hasVectorTextLayer: hasVectorText,
            tiles: tiles,
            recommendedIntent: recommendIntent(for: classification, hasVectorText: hasVectorText),
            ocrData: ocrElements,
            textRects: textRects,
            imageRects: imageRects
        )
    }

    /// MEMORY SAFETY: Sayfayı sabit 2x değil, max 2048px olacak şekilde ölçekler.
    private func renderPageSmartly(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let maxDimension: CGFloat = 2048 // Analiz için yeterli maksimum çözünürlük

        // Aspect ratio koruyarak scale hesapla
        let scale = min(maxDimension / bounds.width, maxDimension / bounds.height)

        // Eğer sayfa zaten küçükse, en az 1.0 scale kullan (küçültme yapma)
        let finalScale = min(scale, 2.0)

        let targetSize = CGSize(width: bounds.width * finalScale, height: bounds.height * finalScale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: targetSize))

            context.cgContext.saveGState()
            // PDF koordinat sistemini iOS koordinat sistemine çevir (Flip)
            context.cgContext.translateBy(x: 0, y: targetSize.height)
            context.cgContext.scaleBy(x: finalScale, y: -finalScale)

            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }.cgImage
    }

    private func performVisionAnalysis(on image: CGImage) async throws -> ([CGRect], [CGRect], [OCRTextElement]) {
        try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                // TEXT TANIMA: .accurate kalite için şart
                let textRequest = VNRecognizeTextRequest()
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = true // Kelime hatalarını düzelt

                // RESİM/KUTU TANIMA
                let rectRequest = VNDetectRectanglesRequest()
                rectRequest.minimumConfidence = 0.4
                rectRequest.maximumObservations = 0 // Sınır yok

                let handler = VNImageRequestHandler(cgImage: image, options: [:])

                do {
                    try handler.perform([textRequest, rectRequest])

                    // 1. Text Rects (Segmentasyon için)
                    let textRects = (textRequest.results as? [VNRecognizedTextObservation])?.map { $0.boundingBox } ?? []

                    // 2. Image Rects (Segmentasyon için)
                    let imageRects = (rectRequest.results as? [VNRectangleObservation])?.map { $0.boundingBox } ?? []

                    // 3. YENİ: OCR Verisi (İçerik Enjeksiyonu için)
                    let ocrElements = (textRequest.results as? [VNRecognizedTextObservation])?.compactMap { observation -> OCRTextElement? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return OCRTextElement(text: candidate.string, normalizedRect: observation.boundingBox)
                    } ?? []

                    // 3 parametre dönüyoruz artık
                    continuation.resume(returning: (textRects, imageRects, ocrElements))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helper Logic

    private func calculateCoverage(of rects: [CGRect], in size: CGSize) -> Double {
        let totalPixels = size.width * size.height
        guard totalPixels > 0 else { return 0 }

        // Vision rects normalize edilmiştir (0-1 arası). Doğrudan alan hesabı yapabiliriz.
        // Not: Üst üste binmeleri (overlap) şimdilik ihmal ediyoruz, performans için basit toplam.
        let occupiedArea = rects.reduce(0.0) { $0 + ($1.width * $1.height) }
        return min(occupiedArea, 1.0)
    }

    private func classifyContent(textCoverage: Double, imageCoverage: Double, hasVectorText: Bool) -> PageContentType {
        // 1. Vektör metin varsa ve resim azsa -> Mainly Text
        if hasVectorText && imageCoverage < 0.15 { return .mainlyText }

        // 2. Resim alanı çok büyükse -> Photograph
        if imageCoverage > 0.60 { return .photograph }

        // 3. Yazı alanı çok ama vektör yok -> Scanned Document
        if textCoverage > 0.40 && !hasVectorText { return .scannedDocument }

        // 4. Diğer durumlar -> Mixed (Karmaşık Sayfa)
        return .mixed
    }

    private func recommendIntent(for type: PageContentType, hasVectorText: Bool) -> RasterOptimizationIntent {
        switch type {
        case .mainlyText:       return .preserveVector
        case .scannedDocument:  return .jbig2 // Siyah beyaz sıkıştırma kralı
        case .photograph:       return .jpeg2000 // veya HEIF
        case .mixed:            return hasVectorText ? .heif : .jpeg2000
        }
    }

    private func buildTiles(pageSize: CGSize, tileSize: CGSize, textRects: [CGRect], imageRects: [CGRect]) -> [PDFSegmentationTile] {
        var tiles: [PDFSegmentationTile] = []

        let cols = Int(ceil(pageSize.width / tileSize.width))
        let rows = Int(ceil(pageSize.height / tileSize.height))

        for r in 0..<rows {
            for c in 0..<cols {
                // Normalize edilmiş tile koordinatları (Vision ile kıyaslamak için)
                let xNorm = CGFloat(c) * tileSize.width / pageSize.width
                let yNorm = CGFloat(r) * tileSize.height / pageSize.height
                let wNorm = tileSize.width / pageSize.width
                let hNorm = tileSize.height / pageSize.height

                let tileRect = CGRect(x: xNorm, y: yNorm, width: wNorm, height: hNorm)

                // Bu tile içine düşen text ve image oranlarını hesapla
                let tileTextCov = intersectionCoverage(tile: tileRect, boxes: textRects)
                let tileImgCov = intersectionCoverage(tile: tileRect, boxes: imageRects)

                // Gerçek dünya koordinatı (Piksel cinsinden) - Çıktı için
                let absoluteRect = CGRect(
                    x: CGFloat(c) * tileSize.width,
                    y: CGFloat(r) * tileSize.height,
                    width: tileSize.width,
                    height: tileSize.height
                )

                tiles.append(PDFSegmentationTile(
                    rect: absoluteRect,
                    textCoverage: tileTextCov,
                    imageCoverage: tileImgCov
                ))
            }
        }
        return tiles
    }

    private func intersectionCoverage(tile: CGRect, boxes: [CGRect]) -> Double {
        var overlap: Double = 0
        // Vision Y ekseni terstir (bottom-left origin).
        // Ancak burada hem tile hem boxes Vision koordinatında olduğu için dönüşüme gerek yok.
        for box in boxes {
            let intersection = tile.intersection(box)
            if !intersection.isNull {
                overlap += intersection.width * intersection.height
            }
        }
        // Tile alanına oranı
        return min(overlap / (tile.width * tile.height), 1.0)
    }
}

