//
//  PDFReassembler.swift
//  optimize
//
//  Created for Advanced PDF Reconstruction Pipeline.
//  The Builder: Takes separated assets (backgrounds & masks) and reconstructs
//  a brand new, optimized PDF file using CoreGraphics layering techniques.
//

import PDFKit
import UIKit

enum ReconstructionError: Error {
    case writeFailed
    case emptyDocument
    case cancelled
}

/// Orijinal sayfa bilgisi - Vektör metin sayfaları için kullanılır
struct OriginalPageReference {
    let pageIndex: Int
    let page: PDFPage
}

final class PDFReassembler {

    /// Parçalanmış varlıkları alıp optimize edilmiş PDF dosyasını diske yazar.
    /// - Parameters:
    ///   - segmentationMap: Analizörden gelen sayfa bilgileri (Boyutlar vb.)
    ///   - assetMap: Her sayfa index'ine karşılık gelen çıkarılmış varlıklar
    ///   - originalPages: Vektör koruma için orijinal sayfalar (mainlyText sayfaları için)
    ///   - outputURL: Dosyanın kaydedileceği yer
    ///   - onProgress: İlerleme callback'i
    func reassemble(
        segmentationMap: PDFAnalysisSummary,
        assetMap: [Int: [ExtractedAsset]],
        originalPages: [Int: OriginalPageReference] = [:],
        to outputURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) throws {
        let totalPages = segmentationMap.totalPageCount

        // Hybrid yaklaşım: Hem asset tabanlı rendering hem de orijinal sayfa kopyalama
        // PDFDocument kullanarak hibrit çıktı oluştur
        let outputDocument = PDFDocument()

        for pageIndex in 0..<totalPages {
            try Task.checkCancellation()

            // Önce orijinal sayfayı kontrol et (vektör koruma)
            if let originalRef = originalPages[pageIndex] {
                // Vektör metin sayfası - orijinali koru
                if let copiedPage = originalRef.page.copy() as? PDFPage {
                    outputDocument.insert(copiedPage, at: outputDocument.pageCount)
                    onProgress?(Double(pageIndex + 1) / Double(totalPages))
                    continue
                }
            }

            // Asset tabanlı sayfa bulundu mu?
            let pageInfo = segmentationMap.pages.first { $0.pageIndex == pageIndex }

            if let pageInfo = pageInfo, let assets = assetMap[pageIndex], !assets.isEmpty {
                // Asset tabanlı render
                let pageData = try renderAssetPage(
                    pageInfo: pageInfo,
                    assets: assets
                )

                if let tempDoc = PDFDocument(data: pageData),
                   let renderedPage = tempDoc.page(at: 0) {
                    outputDocument.insert(renderedPage, at: outputDocument.pageCount)
                }
            } else if let pageInfo = pageInfo {
                // Boş sayfa (fallback)
                let emptyPageData = try renderEmptyPage(size: pageInfo.pageSize)
                if let tempDoc = PDFDocument(data: emptyPageData),
                   let emptyPage = tempDoc.page(at: 0) {
                    outputDocument.insert(emptyPage, at: outputDocument.pageCount)
                }
            }

            onProgress?(Double(pageIndex + 1) / Double(totalPages))
        }

        // Dosyaya yaz
        guard outputDocument.pageCount > 0 else {
            throw ReconstructionError.emptyDocument
        }

        guard outputDocument.write(to: outputURL) else {
            throw ReconstructionError.writeFailed
        }
    }

    /// Eski API uyumluluğu için wrapper (orijinal sayfa desteği olmadan)
    func reassembleLegacy(
        segmentationMap: PDFAnalysisSummary,
        assetMap: [Int: [ExtractedAsset]],
        to outputURL: URL
    ) throws {

        // 1. PDF Renderer Hazırlığı
        // PDF metadata'sını temizliyoruz (Daha az byte)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Optimized Reconstruction Engine",
            kCGPDFContextAuthor as String: "AI Pipeline"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: .zero, format: format)

        // 2. Yazma İşlemi
        try renderer.writePDF(to: outputURL) { context in

            for pageInfo in segmentationMap.pages {
                guard let assets = assetMap[pageInfo.pageIndex], !assets.isEmpty else {
                    // Eğer sayfada hiç asset yoksa (örn: tamamen vektör metin),
                    // Orijinal sayfayı kopyalamak gerekebilir.
                    // Ancak bu pipeline 'Reconstruction' olduğu için boş geçersek sayfa silinir.
                    // Güvenlik için boş beyaz sayfa ekliyoruz:
                    context.beginPage(withBounds: CGRect(origin: .zero, size: pageInfo.pageSize), pageInfo: [:])
                    continue
                }

                // Yeni sayfayı başlat (Boyut Analizden gelir)
                context.beginPage(withBounds: CGRect(origin: .zero, size: pageInfo.pageSize), pageInfo: [:])
                let cgContext = context.cgContext

                // Koordinat Sistemi Düzeltmesi
                // PDF (Sol-Alt) vs UIKit (Sol-Üst). Renderer UIKit koordinatlarını kullanır,
                // ancak Asset rect'lerimiz zaten UIKit uyumlu hesaplanmıştı.
                // Yine de çizim yönünü garantiye almak iyidir.

                // Katmanlama (Layering): Önce arka plan, sonra metin maskeleri çizilmelidir.
                let sortedAssets = assets.sorted { a1, a2 in
                    // Background önce gelir (z-index mantığı)
                    return a1.layerType == .backgroundBase && a2.layerType != .backgroundBase
                }

                for asset in sortedAssets {
                    drawAsset(asset, in: cgContext)
                }

                // ASSET ÇİZİMİ BİTTİKTEN SONRA:
                // OCR Katmanını Enjekte Et
                if !pageInfo.ocrData.isEmpty {
                    injectInvisibleText(
                        data: pageInfo.ocrData,
                        pageSize: pageInfo.pageSize,
                        context: cgContext
                    )
                }
            }
        }
    }

    // MARK: - Private Rendering Helpers

    private func renderAssetPage(pageInfo: PDFPageSegmentation, assets: [ExtractedAsset]) throws -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Optimize App",
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageInfo.pageSize), format: format)

        return renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext

            // Katmanlama (Layering): Önce arka plan, sonra metin maskeleri
            let sortedAssets = assets.sorted { a1, a2 in
                return a1.layerType == .backgroundBase && a2.layerType != .backgroundBase
            }

            for asset in sortedAssets {
                drawAsset(asset, in: cgContext)
            }

            // OCR Katmanını Enjekte Et
            if !pageInfo.ocrData.isEmpty {
                injectInvisibleText(
                    data: pageInfo.ocrData,
                    pageSize: pageInfo.pageSize,
                    context: cgContext
                )
            }
        }
    }

    private func renderEmptyPage(size: CGSize) throws -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size), format: format)

        return renderer.pdfData { context in
            context.beginPage()
            // Boş beyaz sayfa
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Drawing Logic

    private func drawAsset(_ asset: ExtractedAsset, in context: CGContext) {

        switch asset.layerType {

        case .standard, .backgroundBase:
            // Standart Resim Çizimi (JPEG/Arka Plan)
            // Kalite kontrolü: AssetExtractor'da zaten blur/resize yapılmıştı.
            // Burada tekrar compress etmeye gerek yok, renderer otomatik jpeg sıkıştırır.
            asset.image.draw(in: asset.rect)

        case .foregroundMask:
            // --- THE MAGIC TRICK (Masking) ---
            // Siyah beyaz maskeyi "resim" olarak çizersek gri kenarlar oluşur.
            // Bunun yerine "Clip to Mask" yapıp içini saf SİYAH (0,0,0) ile dolduruyoruz.
            // Bu, taranmış metni "Vektör gibi" keskinleştirir.

            context.saveGState()

            // 1. Koordinat dönüşümü (Maskeleme için gerekli)
            // CGContext maskeleme işlemi Y eksenini ters bekleyebilir, duruma göre flip gerekebilir.
            // Şimdilik standart UIKit draw rect kullanıyoruz.

            // Maskenin uygulanacağı alan
            let maskRect = asset.rect

            // 2. Resmi Maskeye Çevir (CGImage)
            guard let maskCg = asset.image.cgImage else {
                context.restoreGState()
                return
            }

            // 3. Clip (Kes)
            // Not: iOS maskelemede beyazı şeffaf, siyahı dolu kabul edebilir veya tam tersi.
            // Genelde mask image: Siyah kısımlar maskelenir (gösterilir), beyazlar atılır.
            context.clip(to: maskRect, mask: maskCg)

            // 4. Boya (Fill)
            // Sadece Siyah (Metin Rengi)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(maskRect)

            context.restoreGState()
        }
    }

    // MARK: - Text Injection Magic

    /// Görünmez (Seçilebilir) Metin Katmanı Çizer
    private func injectInvisibleText(data: [OCRTextElement], pageSize: CGSize, context: CGContext) {
        context.saveGState()

        // 1. Görünmez Render Modu (Invisible)
        // Metin oradadır, seçilebilir ama gözle görülmez (Görselin üstüne biner)
        context.setTextDrawingMode(.invisible)

        // 2. Koordinat Sistemi Ayarı
        // Vision koordinatları (0,0 sol-alt) -> PDF koordinatlarına uyarlıyoruz.
        // PDF Context zaten sol-alt orijinli olabilir ama text matrix'i garantiye alalım.

        for element in data {
            // Vision rect (0..1) -> PDF Point
            // Vision'da Y ekseni alttan başlar (0 alt, 1 üst).
            // PDF'te de Y alttan başlar. Dönüşüm düz:
            let rect = CGRect(
                x: element.normalizedRect.minX * pageSize.width,
                y: element.normalizedRect.minY * pageSize.height,
                width: element.normalizedRect.width * pageSize.width,
                height: element.normalizedRect.height * pageSize.height
            )

            // Font Büyüklüğünü Hesapla
            // Vision bize bounding box verir, font size'ı buna uydurmalıyız.
            // Basit bir yaklaşımla rect yüksekliğini font size kabul ediyoruz.
            let fontSize = rect.height * 0.9 // Biraz marj bırak

            // Font Ayarla (Sistem fontu yeterli, görünmez olduğu için tipi önemli değil)
            // Sadece karakter genişliklerinin (metrics) yaklaşık tutması lazım.
            let font = UIFont.systemFont(ofSize: fontSize)

            // CoreGraphics ile Yazı Yazma
            // UIKit string drawing (NSAttributedString) PDF context üzerinde daha kolaydır.
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.clear // Ekstra güvenlik (zaten invisible modda ama)
            ]

            let attributedString = NSAttributedString(string: element.text, attributes: attributes)

            // Yazıyı tam kutunun içine oturtmak için
            // Vision bounding box bazen kelimeye çok yapışıktır, dikey ortalama yapalım.
            let textRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y + (rect.height - fontSize) / 2, // Dikey ortala
                width: rect.width,
                height: rect.height
            )

            // UIGraphicsPushContext ile UIKit drawing metodlarını CGContext içinde kullanma
            UIGraphicsPushContext(context)
            attributedString.draw(in: textRect)
            UIGraphicsPopContext()
        }

        context.restoreGState()
    }
}

