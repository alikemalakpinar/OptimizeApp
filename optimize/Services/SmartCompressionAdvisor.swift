//
//  SmartCompressionAdvisor.swift
//  optimize
//
//  AI-like system that analyzes files and recommends optimal compression settings.
//  This is the "Magic Button" brain - users don't need to understand DPI or quality settings.
//
//  PHILOSOPHY:
//  - Analyze first, compress later
//  - Explain reasoning to build trust
//  - Never over-compress (quality guarantee)
//  - Learn from file characteristics
//

import Foundation
import PDFKit
import UIKit

// MARK: - Recommendation Model

struct CompressionRecommendation {
    let preset: RecommendedPreset
    let confidence: Float           // 0.0 - 1.0
    let reasoning: String           // Human-readable explanation
    let expectedSavings: ClosedRange<Int>  // Percentage range (e.g., 40...60)
    let qualityImpact: QualityImpact
    let analysisDetails: AnalysisDetails

    enum QualityImpact: String {
        case none = "Kalite kaybı yok"
        case minimal = "Fark edilmez düzeyde"
        case moderate = "Hafif değişiklik"
        case significant = "Belirgin değişiklik"

        var emoji: String {
            switch self {
            case .none: return "✨"
            case .minimal: return "👍"
            case .moderate: return "⚠️"
            case .significant: return "🔻"
            }
        }
    }

    struct AnalysisDetails {
        let contentType: ContentType
        let hasImages: Bool
        let hasText: Bool
        let isScanned: Bool
        let pageCount: Int
        let estimatedImageRatio: Float
    }

    enum ContentType: String {
        case textDocument = "Metin Belgesi"
        case scannedDocument = "Taranmış Belge"
        case photoDocument = "Fotoğraf Belgesi"
        case mixedContent = "Karma İçerik"
        case image = "Görsel"
        case unknown = "Bilinmeyen"
    }

    enum RecommendedPreset {
        case smart          // Auto-selected based on content
        case balanced       // Good compression, good quality
        case maximum        // Aggressive compression
        case highQuality    // Minimal compression, best quality
        case custom(Float)  // Specific quality target

        var displayName: String {
            switch self {
            case .smart: return "Akıllı Mod"
            case .balanced: return "Dengeli"
            case .maximum: return "Maksimum Sıkıştırma"
            case .highQuality: return "Yüksek Kalite"
            case .custom(let q): return "Özel (%\(Int(q * 100)))"
            }
        }

        var icon: String {
            switch self {
            case .smart: return "wand.and.stars"
            case .balanced: return "slider.horizontal.3"
            case .maximum: return "arrow.down.circle.fill"
            case .highQuality: return "sparkles"
            case .custom: return "gearshape"
            }
        }
    }
}

// MARK: - Smart Compression Advisor

actor SmartCompressionAdvisor {

    // MARK: - Main Analysis API

    /// Analyze file and return compression recommendation
    /// - Parameter url: File URL to analyze
    /// - Returns: Detailed compression recommendation
    func analyzeAndRecommend(url: URL) async -> CompressionRecommendation {
        let fileSize = getFileSize(url)
        let fileType = url.pathExtension.lowercased()

        // Route to appropriate analyzer
        switch fileType {
        case "pdf":
            return await analyzePDF(url: url, fileSize: fileSize)
        case "jpg", "jpeg", "heic", "heif":
            return analyzeJPEGImage(url: url, fileSize: fileSize)
        case "png":
            return analyzePNGImage(url: url, fileSize: fileSize)
        default:
            return defaultRecommendation(fileSize: fileSize, type: .unknown)
        }
    }

    // MARK: - PDF Analysis

    private func analyzePDF(url: URL, fileSize: Int64) async -> CompressionRecommendation {
        guard let document = PDFDocument(url: url) else {
            return defaultRecommendation(fileSize: fileSize, type: .unknown)
        }

        let pageCount = document.pageCount

        // Sample pages for analysis (max 5 pages for performance)
        let samplesToAnalyze = min(5, pageCount)
        var hasImages = false
        var hasText = false
        var isScanned = false
        var totalImageRatio: Float = 0

        for i in 0..<samplesToAnalyze {
            if let page = document.page(at: i) {
                let analysis = analyzePageContent(page)
                hasImages = hasImages || analysis.hasImages
                hasText = hasText || analysis.hasText
                isScanned = isScanned || analysis.isScanned
                totalImageRatio += analysis.imageRatio
            }
        }

        let avgImageRatio = totalImageRatio / Float(samplesToAnalyze)

        // Determine content type
        let contentType: CompressionRecommendation.ContentType
        if isScanned {
            contentType = .scannedDocument
        } else if avgImageRatio > 0.7 {
            contentType = .photoDocument
        } else if avgImageRatio < 0.2 && hasText {
            contentType = .textDocument
        } else {
            contentType = .mixedContent
        }

        let details = CompressionRecommendation.AnalysisDetails(
            contentType: contentType,
            hasImages: hasImages,
            hasText: hasText,
            isScanned: isScanned,
            pageCount: pageCount,
            estimatedImageRatio: avgImageRatio
        )

        // Generate recommendation based on analysis
        return generatePDFRecommendation(
            fileSize: fileSize,
            contentType: contentType,
            details: details
        )
    }

    private func analyzePageContent(_ page: PDFPage) -> PageAnalysis {
        let bounds = page.bounds(for: .mediaBox)
        let area = bounds.width * bounds.height

        // Simple heuristics based on page characteristics
        // Large pages with uniform content = likely scanned
        let isLikelyScanned = area > 500_000 // ~A4 at 150+ DPI

        // Check for text content
        let pageString = page.string ?? ""
        let hasSignificantText = pageString.count > 100

        // Estimate image ratio (rough heuristic)
        // In reality, would need to parse PDF structure
        let imageRatio: Float = isLikelyScanned ? 0.9 : (hasSignificantText ? 0.3 : 0.5)

        return PageAnalysis(
            hasImages: true, // Conservative assumption
            hasText: hasSignificantText,
            isScanned: isLikelyScanned && !hasSignificantText,
            imageRatio: imageRatio
        )
    }

    private func generatePDFRecommendation(
        fileSize: Int64,
        contentType: CompressionRecommendation.ContentType,
        details: CompressionRecommendation.AnalysisDetails
    ) -> CompressionRecommendation {

        switch contentType {
        case .textDocument:
            return CompressionRecommendation(
                preset: .highQuality,
                confidence: 0.95,
                reasoning: "Metin ağırlıklı belge tespit edildi. Vektörler korunarak minimum sıkıştırma uygulanacak, böylece yazılar net kalacak.",
                expectedSavings: 15...35,
                qualityImpact: .none,
                analysisDetails: details
            )

        case .scannedDocument:
            return CompressionRecommendation(
                preset: .balanced,
                confidence: 0.85,
                reasoning: "Taranmış belge tespit edildi. MRC teknolojisi ile metin netliği korunarak arka plan optimize edilecek.",
                expectedSavings: 50...70,
                qualityImpact: .minimal,
                analysisDetails: details
            )

        case .photoDocument:
            let isLarge = fileSize > 10_000_000 // 10MB+
            return CompressionRecommendation(
                preset: isLarge ? .maximum : .balanced,
                confidence: 0.9,
                reasoning: isLarge
                    ? "Büyük fotoğraf belgesi tespit edildi. Agresif sıkıştırma ile maksimum boyut azaltma sağlanacak."
                    : "Fotoğraf ağırlıklı belge. Görsel kaliteyi koruyarak optimize edilecek.",
                expectedSavings: isLarge ? 60...80 : 40...60,
                qualityImpact: isLarge ? .moderate : .minimal,
                analysisDetails: details
            )

        case .mixedContent:
            return CompressionRecommendation(
                preset: .balanced,
                confidence: 0.8,
                reasoning: "Karma içerikli belge. Metin ve görseller dengeli şekilde optimize edilecek.",
                expectedSavings: 35...55,
                qualityImpact: .minimal,
                analysisDetails: details
            )

        case .image, .unknown:
            return defaultRecommendation(fileSize: fileSize, type: contentType)
        }
    }

    // MARK: - Image Analysis

    private func analyzeJPEGImage(url: URL, fileSize: Int64) -> CompressionRecommendation {
        let details = CompressionRecommendation.AnalysisDetails(
            contentType: .image,
            hasImages: true,
            hasText: false,
            isScanned: false,
            pageCount: 1,
            estimatedImageRatio: 1.0
        )

        // Check if already optimized (small file = likely already compressed)
        if fileSize < 500_000 { // <500KB
            return CompressionRecommendation(
                preset: .highQuality,
                confidence: 0.7,
                reasoning: "Görsel zaten optimize edilmiş görünüyor. Minimal sıkıştırma ile kalite korunacak.",
                expectedSavings: 5...20,
                qualityImpact: .none,
                analysisDetails: details
            )
        }

        // Large image
        if fileSize > 5_000_000 { // >5MB
            return CompressionRecommendation(
                preset: .balanced,
                confidence: 0.9,
                reasoning: "Yüksek çözünürlüklü görsel. DPI düşürme ve kaliteli sıkıştırma uygulanacak.",
                expectedSavings: 50...75,
                qualityImpact: .minimal,
                analysisDetails: details
            )
        }

        // Medium image
        return CompressionRecommendation(
            preset: .balanced,
            confidence: 0.85,
            reasoning: "Standart görsel. Kalite ve boyut dengesi optimize edilecek.",
            expectedSavings: 30...50,
            qualityImpact: .minimal,
            analysisDetails: details
        )
    }

    private func analyzePNGImage(url: URL, fileSize: Int64) -> CompressionRecommendation {
        let details = CompressionRecommendation.AnalysisDetails(
            contentType: .image,
            hasImages: true,
            hasText: false,
            isScanned: false,
            pageCount: 1,
            estimatedImageRatio: 1.0
        )

        // PNG'ler genellikle şeffaflık için kullanılır
        return CompressionRecommendation(
            preset: .balanced,
            confidence: 0.8,
            reasoning: "PNG görseli. Şeffaflık kontrol edilecek; şeffaflık yoksa JPEG'e dönüştürülecek.",
            expectedSavings: 40...70,
            qualityImpact: .minimal,
            analysisDetails: details
        )
    }

    // MARK: - Helpers

    private func defaultRecommendation(
        fileSize: Int64,
        type: CompressionRecommendation.ContentType
    ) -> CompressionRecommendation {
        let details = CompressionRecommendation.AnalysisDetails(
            contentType: type,
            hasImages: true,
            hasText: false,
            isScanned: false,
            pageCount: 1,
            estimatedImageRatio: 0.5
        )

        return CompressionRecommendation(
            preset: .balanced,
            confidence: 0.6,
            reasoning: "Dosya analiz edildi. Varsayılan dengeli sıkıştırma uygulanacak.",
            expectedSavings: 30...50,
            qualityImpact: .minimal,
            analysisDetails: details
        )
    }

    private func getFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private struct PageAnalysis {
        let hasImages: Bool
        let hasText: Bool
        let isScanned: Bool
        let imageRatio: Float
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct RecommendationCard: View {
    let recommendation: CompressionRecommendation
    var onAccept: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))

                Text("Öneri: \(recommendation.preset.displayName)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Spacer()

                // Confidence indicator
                Text("\(Int(recommendation.confidence * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(6)
            }

            // Reasoning
            Text(recommendation.reasoning)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)

            Divider()

            // Stats row
            HStack(spacing: 16) {
                // Expected savings
                Label {
                    Text("~%\(recommendation.expectedSavings.lowerBound)-\(recommendation.expectedSavings.upperBound)")
                        .font(.system(size: 12, weight: .medium))
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.appMint)
                }

                // Quality impact
                Label {
                    Text(recommendation.qualityImpact.rawValue)
                        .font(.system(size: 12, weight: .medium))
                } icon: {
                    Text(recommendation.qualityImpact.emoji)
                }

                Spacer()
            }
            .foregroundColor(.primary.opacity(0.8))

            // Accept button
            if let onAccept = onAccept {
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: recommendation.preset.icon)
                        Text("Bu Ayarı Kullan")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appMint)
                    .cornerRadius(10)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
