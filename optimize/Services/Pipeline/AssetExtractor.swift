//
//  AssetExtractor.swift
//  optimize
//
//  Created for Advanced PDF Reconstruction Pipeline.
//  The Surgeon: Physically extracts and separates image data from PDF pages
//  based on the analysis map. Performs MRC (Mixed Raster Content) layer separation.
//

import CoreImage
import PDFKit
import UIKit

// MARK: - Extracted Asset Models

enum AssetLayerType {
    case standard       // Standart görüntü (Fotoğraf vb.)
    case foregroundMask // MRC Ön Plan (Siyah/Beyaz Metin Maskesi)
    case backgroundBase // MRC Arka Plan (Renk ve Doku)
}

struct ExtractedAsset {
    let id = UUID()
    let image: UIImage
    let rect: CGRect            // PDF sayfasındaki orijinal konumu
    let layerType: AssetLayerType
    let optimizedIntent: RasterOptimizationIntent // Bu parça nasıl sıkıştırılmalı?
}

// MARK: - The Extractor Engine

final class AssetExtractor {

    // GPU tabanlı görüntü işleme bağlamı
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Ana Çıkarma Fonksiyonu
    /// Analiz raporunu alır ve fiziksel görüntü parçalarını (Assets) üretir.
    func extractAssets(from page: PDFPage, segmentation: PDFPageSegmentation) async -> [ExtractedAsset] {
        var assets: [ExtractedAsset] = []

        // Tüm sayfayı render etmiyoruz. Sadece tile (karo) bazlı çalışıyoruz.
        // Ancak performans için, önce sayfayı makul bir boyutta belleğe alıp oradan crop yapmak
        // (çok sayıda küçük draw call yapmaktan) daha hızlıdır.

        guard let fullPageImage = renderPageToImage(page, size: segmentation.pageSize) else { return [] }

        for tile in segmentation.tiles {
            // 1. İlgili parçayı kes (Crop)
            guard let tileImage = cropImage(fullPageImage, to: tile.rect) else { continue }

            // 2. İçeriğe göre işlem yap (Surgery)
            switch tile.dominantContent {

            case .scannedDocument:
                // Taranmış belge ise: Doğrudan Siyah-Beyaz Maskeye çevir
                if let binaryImage = createBinaryMask(from: tileImage) {
                    assets.append(ExtractedAsset(
                        image: binaryImage,
                        rect: tile.rect,
                        layerType: .foregroundMask,
                        optimizedIntent: .jbig2 // JBIG2 için hazırlandı
                    ))
                }

            case .mixed:
                // Karışık içerik (Renkli zemin üzerinde yazı): MRC Tekniği
                // A. Ön Planı (Yazıyı) Çıkar
                if let foreground = createBinaryMask(from: tileImage) {
                    assets.append(ExtractedAsset(
                        image: foreground,
                        rect: tile.rect,
                        layerType: .foregroundMask,
                        optimizedIntent: .jbig2
                    ))
                }

                // B. Arka Planı (Zemini) Çıkar
                // Yazıları arka plandan siliyoruz (Blur ile) ki JPEG sıkıştırması daha verimli olsun.
                if let background = createBackgroundLayer(from: tileImage) {
                    assets.append(ExtractedAsset(
                        image: background,
                        rect: tile.rect,
                        layerType: .backgroundBase,
                        optimizedIntent: .jpeg2000 // veya HEIF (High Compression)
                    ))
                }

            case .photograph:
                // Fotoğraf ise olduğu gibi al, renkleri koru
                assets.append(ExtractedAsset(
                    image: tileImage,
                    rect: tile.rect,
                    layerType: .standard,
                    optimizedIntent: .jpeg2000 // Kaliteli fotoğraf sıkıştırma
                ))

            case .mainlyText:
                // Metin ağırlıklı bölgeler genelde vektör kalmalı,
                // ancak raster extraction isteniyorsa standart davran.
                break
            }
        }

        return assets
    }

    // MARK: - Image Processing Magic (CoreImage)

    /// Görseli "Bi-tonal" (Sadece Siyah ve Beyaz) hale getirir.
    /// Adaptive Thresholding kullanarak gölgeli taranmış kağıtlardaki yazıları bile netleştirir.
    private func createBinaryMask(from image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // 1. Siyah Beyaza Çevir (Noir)
        let noir = CIFilter(name: "CIPhotoEffectNoir")
        noir?.setValue(ciImage, forKey: kCIInputImageKey)

        // 2. Kontrastı Patlat (Yazıyı zeminden ayırmak için)
        let contrast = CIFilter(name: "CIColorControls")
        contrast?.setValue(noir?.outputImage, forKey: kCIInputImageKey)
        contrast?.setValue(1.5, forKey: "inputContrast") // Yüksek kontrast
        contrast?.setValue(0.1, forKey: "inputBrightness")

        // 3. Thresholding (Eşikleme) - Keskin siyah beyaz ayrımı
        // Basit bir threshold yerine ColorMonochrome ile keskinleştirme yapıyoruz.
        let mono = CIFilter(name: "CIColorMonochrome")
        mono?.setValue(contrast?.outputImage, forKey: kCIInputImageKey)
        mono?.setValue(CIColor(color: .white), forKey: "inputColor")
        mono?.setValue(1.0, forKey: "inputIntensity")

        guard let output = mono?.outputImage,
              let cgResult = context.createCGImage(output, from: output.extent) else { return nil }

        return UIImage(cgImage: cgResult)
    }

    /// Görseldeki detayları (yazıları) yok edip sadece renkli arka planı bırakır.
    /// Bu sayede arka plan çok düşük kalitede sıkıştırılsa bile yazı bozulmaz (çünkü yazı ayrı katmanda).
    private func createBackgroundLayer(from image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Gaussian Blur uygula -> Yazılar erir, sadece renk kalır.
        let blur = CIFilter(name: "CIGaussianBlur")
        blur?.setValue(ciImage, forKey: kCIInputImageKey)
        blur?.setValue(10.0, forKey: "inputRadius") // Yüksek blur

        guard let output = blur?.outputImage else { return nil }

        // Blur işlemi kenarlarda boşluk yaratır, görseli hafifçe croplamak (clamp) gerekebilir.
        // Basitlik adına extent'i koruyarak çıktı alıyoruz.
        if let cgResult = context.createCGImage(output, from: ciImage.extent) {
            return UIImage(cgImage: cgResult)
        }
        return nil
    }

    // MARK: - Helper Utilities

    private func renderPageToImage(_ page: PDFPage, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)

            // Sayfayı analiz boyutuna uyacak şekilde scale ederek çiz
            let pageBounds = page.bounds(for: .mediaBox)
            let scaleX = size.width / pageBounds.width
            let scaleY = size.height / pageBounds.height
            ctx.cgContext.scaleBy(x: scaleX, y: scaleY)

            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }

    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        // UIImage koordinat sistemi ile PDF/Analiz koordinat sistemi uyumu
        // Tile rect'leri zaten Analizörde normalize edilip sonra piksele çevrilmişti.
        // Ancak UIImage scale faktörü (Retina 2x, 3x) dikkate alınmalı.

        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cgImage = image.cgImage?.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }
}

