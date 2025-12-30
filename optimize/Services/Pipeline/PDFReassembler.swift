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
}

final class PDFReassembler {

    /// Parçalanmış varlıkları alıp optimize edilmiş PDF dosyasını diske yazar.
    /// - Parameters:
    ///   - segmentationMap: Analizörden gelen sayfa bilgileri (Boyutlar vb.)
    ///   - assetMap: Her sayfa index'ine karşılık gelen çıkarılmış varlıklar
    ///   - outputURL: Dosyanın kaydedileceği yer
    func reassemble(
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

