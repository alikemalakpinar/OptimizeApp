//
//  SmartPDFAnalyzer.swift
//  optimize
//
//  Created for Advanced PDF Reconstruction Pipeline.
//  OPTIMIZED: Uses statistical sampling and fast-path vision for large files.
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

enum RasterOptimizationIntent: String {
    case preserveVector
    case jbig2
    case jpeg2000
    case heif
}

struct OCRTextElement {
    let text: String
    let normalizedRect: CGRect
}

struct PDFSegmentationTile: Identifiable {
    let id = UUID()
    let rect: CGRect
    let textCoverage: Double
    let imageCoverage: Double

    var dominantContent: PageContentType {
        if textCoverage > 0.55 { return .mainlyText }
        if imageCoverage > 0.55 { return .photograph }
        if textCoverage > 0.1 && imageCoverage > 0.1 { return .mixed }
        return .scannedDocument
    }
}

struct PDFPageSegmentation {
    let pageIndex: Int
    let pageSize: CGSize
    let classification: PageContentType
    let hasVectorTextLayer: Bool
    let tiles: [PDFSegmentationTile]
    let recommendedIntent: RasterOptimizationIntent
    let ocrData: [OCRTextElement]
    let textRects: [CGRect]
    let imageRects: [CGRect]
}

struct PDFAnalysisSummary {
    let totalPageCount: Int // Toplam sayfa sayısı (İşlenen + Atlanan)
    let sampledPages: [PDFPageSegmentation] // Sadece analiz edilenler

    // Backward compatibility
    var pages: [PDFPageSegmentation] { sampledPages }
    var pageCount: Int { totalPageCount }

    var dominantContent: PageContentType {
        let histogram = sampledPages.reduce(into: [PageContentType: Int]()) { partial, page in
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

    private let analysisQueue = DispatchQueue(label: "com.optimize.analysis", qos: .userInitiated)

    /// Maksimum analiz edilecek örnek sayfa sayısı
    private let maxSamplePages = 10

    /// Hızlı analiz için kullanılır (UI preview ve karar verme)
    func analyze(documentAt url: URL, tileSize: CGSize = CGSize(width: 512, height: 512)) async throws -> PDFAnalysisSummary {
        return try await analyzeInternal(documentAt: url, tileSize: tileSize, fullScan: false)
    }

    /// Tam sayfa analizi - Reassembly için tüm sayfaların detaylı haritasını çıkarır
    func analyzeFullDocument(
        documentAt url: URL,
        tileSize: CGSize = CGSize(width: 512, height: 512),
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> PDFAnalysisSummary {
        return try await analyzeInternal(documentAt: url, tileSize: tileSize, fullScan: true, onProgress: onProgress)
    }

    /// Ana Analiz Fonksiyonu (Internal)
    private func analyzeInternal(
        documentAt url: URL,
        tileSize: CGSize,
        fullScan: Bool,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> PDFAnalysisSummary {
        guard let document = PDFDocument(url: url) else { throw PDFAnalysisError.invalidDocument }
        let totalPageCount = document.pageCount

        // Örnekleme Stratejisi: fullScan ise tüm sayfalar, değilse sample al
        let pagesToAnalyze = fullScan ? Array(0..<totalPageCount) : determineSampleIndices(total: totalPageCount)
        let totalToProcess = pagesToAnalyze.count

        // CONCURRENCY: Sayfaları batch'ler halinde işle (bellek yönetimi için)
        var allSegments: [PDFPageSegmentation] = []
        let batchSize = fullScan ? 5 : 10 // Full scan'de daha küçük batch'ler

        for batchStart in stride(from: 0, to: pagesToAnalyze.count, by: batchSize) {
            try Task.checkCancellation() // İptal kontrolü

            let batchEnd = min(batchStart + batchSize, pagesToAnalyze.count)
            let batchIndices = Array(pagesToAnalyze[batchStart..<batchEnd])

            let results = try await withThrowingTaskGroup(of: PDFPageSegmentation.self) { group in
                for index in batchIndices {
                    group.addTask {
                        try Task.checkCancellation()
                        guard let page = document.page(at: index) else { throw PDFAnalysisError.renderFailed }
                        return try await self.analyzePage(page, index: index, tileSize: tileSize)
                    }
                }

                var segments: [PDFPageSegmentation] = []
                for try await result in group {
                    segments.append(result)
                }
                return segments
            }

            allSegments.append(contentsOf: results)

            // İlerleme raporu
            let progress = Double(batchEnd) / Double(totalToProcess)
            onProgress?(progress)

            // Bellek temizliği için yield
            await Task.yield()
        }

        return PDFAnalysisSummary(totalPageCount: totalPageCount, sampledPages: allSegments.sorted { $0.pageIndex < $1.pageIndex })
    }

    private func determineSampleIndices(total: Int) -> [Int] {
        if total <= maxSamplePages {
            return Array(0..<total)
        }

        // Büyük dosyalar için: İlk 3, Orta 4, Son 3
        var indices: Set<Int> = []

        // Baş
        indices.insert(0)
        if total > 1 { indices.insert(1) }
        if total > 2 { indices.insert(2) }

        // Son
        if total > 3 { indices.insert(total - 1) }
        if total > 4 { indices.insert(total - 2) }
        if total > 5 { indices.insert(total - 3) }

        // Orta
        let mid = total / 2
        indices.insert(mid)
        if mid > 0 { indices.insert(mid - 1) }
        if mid + 1 < total { indices.insert(mid + 1) }
        if mid + 2 < total { indices.insert(mid + 2) }

        return Array(indices).filter { $0 >= 0 && $0 < total }.sorted()
    }

    // MARK: - Private Processing Logic

    private func analyzePage(_ page: PDFPage, index: Int, tileSize: CGSize) async throws -> PDFPageSegmentation {
        // 1. Metin Katmanı Kontrolü (Hızlandırma)
        let hasVectorText = (page.string?.count ?? 0) > 10

        // 2. Akıllı Render (Çözünürlük Düşürüldü: 1024px yeterli)
        guard let cgImage = renderPageSmartly(page, targetSize: 1024) else { throw PDFAnalysisError.renderFailed }

        // 3. Vision ile İçerik Tespiti (Fast Mod veya Text Layer Varsa Skip)
        let (textRects, imageRects, ocrElements) = try await performVisionAnalysis(on: cgImage, skipOCR: hasVectorText)

        // 4. Veri Yorumlama
        let pageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Eğer vektör text varsa, coverage'ı tam kabul et (Vision çalıştırmadan)
        let textCoverage = hasVectorText ? 0.6 : calculateCoverage(of: textRects, in: pageSize)
        let imageCoverage = calculateCoverage(of: imageRects, in: pageSize)

        // 5. Sınıflandırma
        let classification = classifyContent(
            textCoverage: textCoverage,
            imageCoverage: imageCoverage,
            hasVectorText: hasVectorText
        )

        // 6. Tile (Karo) Bölütleme
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

    private func renderPageSmartly(_ page: PDFPage, targetSize: CGFloat) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)

        // Aspect ratio koru
        let scale = min(targetSize / bounds.width, targetSize / bounds.height)
        let finalScale = min(scale, 1.5) // Asla gereğinden fazla büyütme

        let renderSize = CGSize(width: bounds.width * finalScale, height: bounds.height * finalScale)

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: renderSize))

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: finalScale, y: -finalScale)

            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }.cgImage
    }

    private func performVisionAnalysis(on image: CGImage, skipOCR: Bool) async throws -> ([CGRect], [CGRect], [OCRTextElement]) {
        try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                var requests: [VNRequest] = []

                // RESİM/KUTU TANIMA (Her zaman çalışır)
                let rectRequest = VNDetectRectanglesRequest()
                rectRequest.minimumConfidence = 0.5
                rectRequest.maximumObservations = 0
                requests.append(rectRequest)

                // TEXT TANIMA (Sadece vektör text yoksa çalışır)
                var textRequest: VNRecognizeTextRequest?
                if !skipOCR {
                    let req = VNRecognizeTextRequest()
                    req.recognitionLevel = .fast // OPTIMIZATION: Accurate yerine Fast
                    req.usesLanguageCorrection = false // Hız için kapatıldı
                    requests.append(req)
                    textRequest = req
                }

                let handler = VNImageRequestHandler(cgImage: image, options: [:])

                do {
                    try handler.perform(requests)

                    // Sonuçları Topla
                    let imageRects = rectRequest.results?.map { $0.boundingBox } ?? []

                    var textRects: [CGRect] = []
                    var ocrElements: [OCRTextElement] = []

                    if let textReq = textRequest {
                        textRects = textReq.results?.map { $0.boundingBox } ?? []
                        ocrElements = textReq.results?.compactMap { observation -> OCRTextElement? in
                            guard let candidate = observation.topCandidates(1).first else { return nil }
                            return OCRTextElement(text: candidate.string, normalizedRect: observation.boundingBox)
                        } ?? []
                    }

                    continuation.resume(returning: (textRects, imageRects, ocrElements))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helper Logic

    private func calculateCoverage(of rects: [CGRect], in size: CGSize) -> Double {
        let occupiedArea = rects.reduce(0.0) { $0 + ($1.width * $1.height) }
        return min(occupiedArea, 1.0)
    }

    private func classifyContent(textCoverage: Double, imageCoverage: Double, hasVectorText: Bool) -> PageContentType {
        if hasVectorText && imageCoverage < 0.20 { return .mainlyText }
        if imageCoverage > 0.60 { return .photograph }
        if textCoverage > 0.30 && !hasVectorText { return .scannedDocument }
        return .mixed
    }

    private func recommendIntent(for type: PageContentType, hasVectorText: Bool) -> RasterOptimizationIntent {
        switch type {
        case .mainlyText:       return .preserveVector
        case .scannedDocument:  return .jbig2
        case .photograph:       return .jpeg2000
        case .mixed:            return hasVectorText ? .heif : .jpeg2000
        }
    }

    private func buildTiles(pageSize: CGSize, tileSize: CGSize, textRects: [CGRect], imageRects: [CGRect]) -> [PDFSegmentationTile] {
        var tiles: [PDFSegmentationTile] = []
        let cols = Int(ceil(pageSize.width / tileSize.width))
        let rows = Int(ceil(pageSize.height / tileSize.height))

        for r in 0..<rows {
            for c in 0..<cols {
                let xNorm = CGFloat(c) * tileSize.width / pageSize.width
                let yNorm = CGFloat(r) * tileSize.height / pageSize.height
                let wNorm = tileSize.width / pageSize.width
                let hNorm = tileSize.height / pageSize.height
                let tileRect = CGRect(x: xNorm, y: yNorm, width: wNorm, height: hNorm)

                // Basitleştirilmiş intersection (Hız için)
                let tileTextCov = intersectionCoverage(tile: tileRect, boxes: textRects)
                let tileImgCov = intersectionCoverage(tile: tileRect, boxes: imageRects)

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
        // Bu fonksiyon O(N*M) karmaşıklığında, çok kutu varsa yavaşlatır.
        // Hızlı analiz için eğer kutu sayısı > 50 ise sadece ilk 50'sine bakabiliriz.
        let limit = min(boxes.count, 50)
        var overlap: Double = 0
        for i in 0..<limit {
            let intersection = tile.intersection(boxes[i])
            if !intersection.isNull {
                overlap += intersection.width * intersection.height
            }
        }
        return min(overlap / (tile.width * tile.height), 1.0)
    }
}
