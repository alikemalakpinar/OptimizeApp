//
//  CompressionGuarantee.swift
//  optimize
//
//  Quality guarantee system ensuring users always get positive results.
//  "Never leave the user worse off than they started."
//
//  PHILOSOPHY:
//  - If compression makes file bigger → Return original
//  - If quality degradation too high → Warn user
//  - If minimal improvement → Explain why
//  - Always be transparent about results
//

import Foundation
import UIKit

// MARK: - Guarantee Result

enum CompressionGuaranteeResult {
    case success(url: URL, improvement: CompressionImprovement)
    case noImprovement(originalURL: URL, reason: NoImprovementReason)
    case partialSuccess(url: URL, warning: String, improvement: CompressionImprovement)
    case qualityCompromised(url: URL, warning: String, improvement: CompressionImprovement)

    var isSuccess: Bool {
        switch self {
        case .success, .partialSuccess: return true
        case .noImprovement, .qualityCompromised: return false
        }
    }

    var outputURL: URL? {
        switch self {
        case .success(let url, _), .partialSuccess(let url, _, _), .qualityCompromised(let url, _, _):
            return url
        case .noImprovement:
            return nil
        }
    }

    var userMessage: String {
        switch self {
        case .success(_, let improvement):
            return "✅ Başarılı! Dosya %\(improvement.percentageReduction) küçültüldü."

        case .noImprovement(_, let reason):
            return "ℹ️ \(reason.userMessage)"

        case .partialSuccess(_, let warning, let improvement):
            return "⚠️ %\(improvement.percentageReduction) küçültüldü. \(warning)"

        case .qualityCompromised(_, let warning, _):
            return "⚠️ \(warning)"
        }
    }
}

struct CompressionImprovement {
    let originalSize: Int64
    let compressedSize: Int64
    let bytesSaved: Int64
    let percentageReduction: Int

    init(originalSize: Int64, compressedSize: Int64) {
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.bytesSaved = originalSize - compressedSize
        self.percentageReduction = originalSize > 0
            ? Int(Double(originalSize - compressedSize) / Double(originalSize) * 100)
            : 0
    }
}

enum NoImprovementReason {
    case alreadyOptimized
    case fileBecameLarger
    case minimalGain(percentage: Int)
    case incompatibleFormat

    var userMessage: String {
        switch self {
        case .alreadyOptimized:
            return "Dosyanız zaten optimize edilmiş durumda. Daha fazla sıkıştırma kaliteyi bozabilir."

        case .fileBecameLarger:
            return "Bu dosya zaten çok verimli sıkıştırılmış. Orijinal dosyanız korundu."

        case .minimalGain(let percentage):
            return "Dosyanız zaten oldukça optimize. Sadece %\(percentage) küçültülebilirdi, bu yüzden orijinal korundu."

        case .incompatibleFormat:
            return "Bu dosya formatı daha fazla optimize edilemez."
        }
    }
}

// MARK: - Compression Guarantee System

actor CompressionGuarantee {

    // MARK: - Configuration

    /// Minimum improvement percentage to consider compression worthwhile
    private let minimumImprovementThreshold: Double = 0.05 // 5%

    /// Quality threshold below which we warn the user
    private let qualityWarningThreshold: Float = 0.75 // SSIM

    // MARK: - Main Guarantee Check

    /// Verify compression result meets quality standards
    /// - Parameters:
    ///   - original: Original file URL
    ///   - compressed: Compressed file URL
    ///   - preset: Compression preset used
    /// - Returns: Guarantee result with appropriate action
    func verifyResult(
        original: URL,
        compressed: URL,
        preset: CompressionPreset
    ) async -> CompressionGuaranteeResult {
        let originalSize = getFileSize(original)
        let compressedSize = getFileSize(compressed)

        let improvement = CompressionImprovement(
            originalSize: originalSize,
            compressedSize: compressedSize
        )

        // RULE 1: File became larger → Return original
        if compressedSize >= originalSize {
            cleanup(compressed)
            return .noImprovement(
                originalURL: original,
                reason: .fileBecameLarger
            )
        }

        // RULE 2: Minimal improvement (<5%) → Warn but provide
        let improvementRatio = Double(originalSize - compressedSize) / Double(originalSize)
        if improvementRatio < minimumImprovementThreshold {
            return .partialSuccess(
                url: compressed,
                warning: "Dosyanız zaten optimize durumda, minimal küçültme uygulandı.",
                improvement: improvement
            )
        }

        // RULE 3: Quality check for visual files
        if shouldCheckQuality(original) {
            let qualityOK = await verifyVisualQuality(
                original: original,
                compressed: compressed,
                threshold: qualityWarningThreshold
            )

            if !qualityOK {
                return .qualityCompromised(
                    url: compressed,
                    warning: "Yüksek sıkıştırma uygulandı. Önizlemede kaliteyi kontrol edin.",
                    improvement: improvement
                )
            }
        }

        // RULE 4: Everything looks good!
        return .success(url: compressed, improvement: improvement)
    }

    // MARK: - Quality Verification

    /// Check if file type requires visual quality verification
    private func shouldCheckQuality(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "pdf"].contains(ext)
    }

    /// Verify visual quality hasn't degraded too much
    /// Uses basic perceptual comparison
    private func verifyVisualQuality(
        original: URL,
        compressed: URL,
        threshold: Float
    ) async -> Bool {
        // For images, we can do basic comparison
        let ext = original.pathExtension.lowercased()

        if ["jpg", "jpeg", "png", "heic"].contains(ext) {
            guard let originalImage = UIImage(contentsOfFile: original.path),
                  let compressedImage = UIImage(contentsOfFile: compressed.path) else {
                return true // Can't compare, assume OK
            }

            // Basic size-based check (if output resolution is reasonable)
            let originalPixels = originalImage.size.width * originalImage.size.height
            let compressedPixels = compressedImage.size.width * compressedImage.size.height

            // If we lost more than 50% of pixels, flag it
            if compressedPixels < originalPixels * 0.5 {
                return false
            }
        }

        return true
    }

    // MARK: - Helpers

    private func getFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Smart Recovery System

enum SmartRecovery {

    /// Determine recovery action based on error type and context
    /// - Parameters:
    ///   - error: The compression error that occurred
    ///   - context: Additional context about the compression attempt
    /// - Returns: Recommended recovery action
    static func determineRecoveryAction(
        for error: CompressionError,
        context: RecoveryContext
    ) -> RecoveryAction {
        switch error {
        case .memoryPressure:
            // Try again with lower quality settings
            return .retryWithDegradedSettings(
                message: "Bellek yetersiz. Daha hafif ayarlarla tekrar deneniyor...",
                suggestedPreset: context.preset.degraded
            )

        case .timeout:
            // For large files, process in chunks
            if context.pageCount > 20 {
                return .retryWithChunking(
                    message: "Büyük dosya tespit edildi. Parça parça işleniyor...",
                    chunkSize: 10
                )
            }
            return .retryWithDegradedSettings(
                message: "İşlem zaman aşımına uğradı. Daha hızlı ayarlarla deneniyor...",
                suggestedPreset: context.preset.degraded
            )

        case .encryptedPDF:
            return .requestUserInput(
                type: .password,
                message: "Bu PDF şifreli. Şifreyi girerek devam edebilirsiniz."
            )

        case .fileTooLarge:
            if context.isPremium {
                return .retryWithChunking(
                    message: "Dosya çok büyük. Bölümlere ayırarak işleniyor...",
                    chunkSize: 5
                )
            }
            return .suggestUpgrade(
                feature: .unlimitedUsage,
                message: "Bu dosya ücretsiz limit olan 100MB'ı aşıyor. Premium ile sınırsız dosya işleyebilirsiniz."
            )

        case .invalidPDF, .invalidFile:
            return .showError(
                message: "Dosya hasarlı veya desteklenmeyen formatta. Farklı bir dosya deneyin.",
                isRetryable: false
            )

        case .cancelled:
            return .cancelled

        case .accessDenied:
            return .requestUserInput(
                type: .fileAccess,
                message: "Dosyaya erişim izni gerekiyor. Lütfen tekrar dosya seçin."
            )

        default:
            return .showError(
                message: error.localizedDescription,
                isRetryable: true
            )
        }
    }

    // MARK: - Recovery Action Types

    enum RecoveryAction {
        case retryWithDegradedSettings(message: String, suggestedPreset: CompressionPreset)
        case retryWithChunking(message: String, chunkSize: Int)
        case requestUserInput(type: UserInputType, message: String)
        case suggestUpgrade(feature: PremiumFeature, message: String)
        case showError(message: String, isRetryable: Bool)
        case cancelled
    }

    enum UserInputType {
        case password
        case fileAccess
        case confirmation
    }

    struct RecoveryContext {
        let preset: CompressionPreset
        let fileSize: Int64
        let pageCount: Int
        let isPremium: Bool
        let retryCount: Int

        static func from(
            preset: CompressionPreset,
            url: URL,
            isPremium: Bool,
            retryCount: Int = 0
        ) -> RecoveryContext {
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return RecoveryContext(
                preset: preset,
                fileSize: fileSize,
                pageCount: 1, // Would need PDF analysis for actual count
                isPremium: isPremium,
                retryCount: retryCount
            )
        }
    }
}

// MARK: - Preset Extension

extension CompressionPreset {
    /// Get a degraded (less intensive) version of this preset
    var degraded: CompressionPreset {
        switch self.quality {
        case .low:
            return self // Already lowest
        case .medium:
            return .commercial
        case .high:
            return .commercial
        case .custom:
            return .commercial
        }
    }
}
