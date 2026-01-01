//
//  CompressionTypes.swift
//  optimize
//
//  Shared compression types, errors and extensions
//
//  ENHANCED: Added user-friendly error wrapper with recovery suggestions
//

import Foundation
import PDFKit

// MARK: - Compression Error
enum CompressionError: LocalizedError {
    case accessDenied
    case invalidPDF
    case invalidFile
    case emptyPDF
    case encryptedPDF
    case contextCreationFailed
    case saveFailed
    case cancelled
    case memoryPressure
    case fileTooLarge
    case pageProcessingFailed(page: Int)
    case timeout
    case exportFailed
    case unsupportedType
    case unknown(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return AppStrings.ErrorMessage.accessDenied
        case .invalidPDF:
            return AppStrings.ErrorMessage.invalidPDF
        case .invalidFile:
            return AppStrings.ErrorMessage.invalidFile
        case .emptyPDF:
            return AppStrings.ErrorMessage.emptyPDF
        case .encryptedPDF:
            return AppStrings.ErrorMessage.encryptedPDF
        case .contextCreationFailed:
            return AppStrings.ErrorMessage.contextFailed
        case .saveFailed:
            return AppStrings.ErrorMessage.saveFailed
        case .cancelled:
            return AppStrings.ErrorMessage.cancelled
        case .memoryPressure:
            return AppStrings.ErrorMessage.memoryPressure
        case .fileTooLarge:
            return AppStrings.ErrorMessage.fileTooLarge
        case .pageProcessingFailed:
            return AppStrings.ErrorMessage.pageFailed
        case .timeout:
            return AppStrings.ErrorMessage.timeout
        case .exportFailed:
            return AppStrings.ErrorMessage.exportFailed
        case .unsupportedType:
            return AppStrings.ErrorMessage.unsupportedType
        case .unknown:
            return AppStrings.ErrorMessage.generic
        }
    }

    /// Recovery suggestion for the user
    var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return String(localized: "Dosyayı tekrar seçmeyi deneyin.", comment: "Recovery: Access denied")
        case .invalidPDF, .invalidFile:
            return String(localized: "Dosyanın bozuk olmadığından emin olun veya başka bir dosya deneyin.", comment: "Recovery: Invalid file")
        case .emptyPDF:
            return String(localized: "Dosyanın içerik barındırdığından emin olun.", comment: "Recovery: Empty PDF")
        case .encryptedPDF:
            return String(localized: "PDF'in şifresini kaldırıp tekrar deneyin. Preview veya Adobe Acrobat kullanabilirsiniz.", comment: "Recovery: Encrypted PDF")
        case .contextCreationFailed, .memoryPressure:
            return String(localized: "Bazı uygulamaları kapatıp tekrar deneyin veya cihazınızı yeniden başlatın.", comment: "Recovery: Memory issue")
        case .saveFailed:
            return String(localized: "Cihazınızda yeterli depolama alanı olduğundan emin olun.", comment: "Recovery: Save failed")
        case .cancelled:
            return nil
        case .fileTooLarge:
            return String(localized: "Dosyayı bölümlere ayırmayı veya daha küçük bir dosya seçmeyi deneyin.", comment: "Recovery: File too large")
        case .pageProcessingFailed(let page):
            return String(localized: "Sayfa \(page) işlenemedi. Dosya bozuk olabilir.", comment: "Recovery: Page failed")
        case .timeout:
            return String(localized: "Daha küçük bir dosya deneyin veya daha düşük kalite seçeneğini kullanın.", comment: "Recovery: Timeout")
        case .exportFailed:
            return String(localized: "Daha düşük kalite ayarı ile tekrar deneyin.", comment: "Recovery: Export failed")
        case .unsupportedType:
            return String(localized: "PDF, görüntü veya video dosyası seçin.", comment: "Recovery: Unsupported type")
        case .unknown:
            return String(localized: "Uygulamayı kapatıp tekrar açmayı deneyin.", comment: "Recovery: Unknown error")
        }
    }

    /// Whether this error is likely to be resolved by retry
    var isRetryable: Bool {
        switch self {
        case .contextCreationFailed, .saveFailed, .memoryPressure, .timeout, .pageProcessingFailed, .unknown, .exportFailed:
            return true
        case .accessDenied, .invalidPDF, .invalidFile, .emptyPDF, .encryptedPDF, .fileTooLarge, .unsupportedType, .cancelled:
            return false
        }
    }
}

// MARK: - User Friendly Error Wrapper

/// Wraps any error into a user-friendly format with actionable suggestions
/// Use this to convert technical errors into messages suitable for end users
struct UserFriendlyError {
    let title: String
    let message: String
    let suggestion: String?
    let isRetryable: Bool

    /// Create a user-friendly error from any Error
    init(_ error: Error) {
        if let compressionError = error as? CompressionError {
            self.title = String(localized: "İşlem Başarısız", comment: "Error title")
            self.message = compressionError.errorDescription ?? AppStrings.ErrorMessage.generic
            self.suggestion = compressionError.recoverySuggestion
            self.isRetryable = compressionError.isRetryable
        } else if let subscriptionError = error as? SubscriptionError {
            self.title = String(localized: "Abonelik Hatası", comment: "Subscription error title")
            self.message = subscriptionError.errorDescription ?? AppStrings.ErrorMessage.generic
            self.suggestion = nil
            self.isRetryable = false
        } else {
            // Generic error handling - avoid showing technical messages
            self.title = String(localized: "Bir Hata Oluştu", comment: "Generic error title")

            // Check for common system errors and provide user-friendly messages
            let nsError = error as NSError

            switch nsError.domain {
            case NSURLErrorDomain:
                self.message = String(localized: "İnternet bağlantınızı kontrol edin.", comment: "Network error")
                self.suggestion = String(localized: "Wi-Fi veya mobil veri bağlantınızı kontrol edin.", comment: "Network suggestion")
                self.isRetryable = true
            case NSCocoaErrorDomain where nsError.code == NSFileNoSuchFileError:
                self.message = String(localized: "Dosya bulunamadı.", comment: "File not found")
                self.suggestion = String(localized: "Dosyanın hala mevcut olduğundan emin olun.", comment: "File suggestion")
                self.isRetryable = false
            case NSCocoaErrorDomain where nsError.code == NSFileWriteOutOfSpaceError:
                self.message = String(localized: "Yetersiz depolama alanı.", comment: "Out of space")
                self.suggestion = String(localized: "Gereksiz dosyaları silerek yer açın.", comment: "Space suggestion")
                self.isRetryable = false
            default:
                self.message = AppStrings.ErrorMessage.generic
                self.suggestion = String(localized: "Uygulamayı kapatıp tekrar açmayı deneyin.", comment: "Generic suggestion")
                self.isRetryable = true
            }
        }
    }

    /// Combined message with suggestion for display
    var fullMessage: String {
        if let suggestion {
            return "\(message)\n\n\(suggestion)"
        }
        return message
    }
}

// MARK: - File Info Extension
extension FileInfo {
    static func from(url: URL) throws -> FileInfo {
        guard url.startAccessingSecurityScopedResource() else {
            throw CompressionError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
        let fileSize = resourceValues.fileSize ?? 0

        // Get page count if PDF
        var pageCount: Int? = nil
        if url.pathExtension.lowercased() == "pdf" {
            if let pdfDocument = PDFDocument(url: url) {
                pageCount = pdfDocument.pageCount
            }
        }

        let fileType = FileType.from(extension: url.pathExtension)

        return FileInfo(
            name: url.lastPathComponent,
            url: url,
            size: Int64(fileSize),
            pageCount: pageCount,
            fileType: fileType
        )
    }
}

// MARK: - Legacy Compatibility
// UltimatePDFCompressionService is now the main compression engine
// This typealias maintains backwards compatibility
typealias PDFCompressionService = UltimatePDFCompressionService
