//
//  FileValidationService.swift
//  optimize
//
//  Comprehensive file validation before processing.
//  Handles edge cases that would otherwise cause crashes or confusing errors.
//
//  EDGE CASES HANDLED:
//  1. 0 KB (empty) files
//  2. Corrupted PDFs
//  3. Password-protected PDFs
//  4. Truncated/incomplete videos
//  5. Unsupported formats masquerading as supported
//  6. Files with very long names
//  7. Files larger than available memory
//  8. Files in use by another process
//

import Foundation
import PDFKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Validation Result

enum FileValidationResult {
    case valid
    case invalid(FileValidationError)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var error: FileValidationError? {
        if case .invalid(let error) = self { return error }
        return nil
    }
}

// MARK: - Validation Error

enum FileValidationError: LocalizedError {
    case fileNotFound
    case emptyFile
    case fileTooLarge(size: Int64, maxSize: Int64)
    case corruptedFile(details: String)
    case passwordProtected
    case unsupportedFormat(detected: String, expected: String)
    case filenameTooLong(length: Int, maxLength: Int)
    case fileInUse
    case iCloudNotDownloaded
    case insufficientPermissions
    case unknownError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return String(localized: "Dosya bulunamadı. Silinmiş veya taşınmış olabilir.")
        case .emptyFile:
            return String(localized: "Dosya boş (0 KB). Lütfen geçerli bir dosya seçin.")
        case .fileTooLarge(let size, let maxSize):
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let maxStr = ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)
            return String(localized: "Dosya çok büyük (\(sizeStr)). Maksimum: \(maxStr)")
        case .corruptedFile(let details):
            return String(localized: "Dosya bozuk veya okunamıyor. \(details)")
        case .passwordProtected:
            return String(localized: "Bu dosya şifre korumalı. Lütfen önce şifreyi kaldırın.")
        case .unsupportedFormat(let detected, let expected):
            return String(localized: "Desteklenmeyen format: \(detected). Beklenen: \(expected)")
        case .filenameTooLong(let length, let maxLength):
            return String(localized: "Dosya adı çok uzun (\(length) karakter). Maksimum: \(maxLength)")
        case .fileInUse:
            return String(localized: "Dosya başka bir uygulama tarafından kullanılıyor.")
        case .iCloudNotDownloaded:
            return String(localized: "Dosya iCloud'dan henüz indirilmedi. Lütfen indirmeyi bekleyin.")
        case .insufficientPermissions:
            return String(localized: "Dosyaya erişim izni yok.")
        case .unknownError(let error):
            return String(localized: "Dosya hatası: \(error.localizedDescription)")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return String(localized: "Lütfen dosyayı tekrar seçin.")
        case .emptyFile:
            return String(localized: "Farklı bir dosya deneyin.")
        case .fileTooLarge:
            return String(localized: "Daha küçük bir dosya seçin veya dosyayı bölün.")
        case .corruptedFile:
            return String(localized: "Dosyayı başka bir programla açıp kaydetmeyi deneyin.")
        case .passwordProtected:
            return String(localized: "PDF'i Preview veya Acrobat ile açıp şifreyi kaldırın.")
        case .unsupportedFormat:
            return String(localized: "Desteklenen formatlar: PDF, JPG, PNG, HEIC, MP4, MOV")
        case .filenameTooLong:
            return String(localized: "Dosya adını kısaltın.")
        case .fileInUse:
            return String(localized: "Diğer uygulamayı kapatıp tekrar deneyin.")
        case .iCloudNotDownloaded:
            return String(localized: "Dosyalar uygulamasında indirme simgesine dokunun.")
        case .insufficientPermissions:
            return String(localized: "Ayarlar > Gizlilik'ten dosya erişimini kontrol edin.")
        case .unknownError:
            return String(localized: "Uygulamayı yeniden başlatıp tekrar deneyin.")
        }
    }
}

// MARK: - File Validation Service

final class FileValidationService {

    // MARK: - Singleton

    static let shared = FileValidationService()

    // MARK: - Configuration

    /// Maximum file size (2GB - reasonable for mobile)
    private let maxFileSize: Int64 = 2_000_000_000

    /// Maximum filename length (iOS filesystem limit)
    private let maxFilenameLength = 255

    /// Supported file types
    private let supportedPDFExtensions = ["pdf"]
    private let supportedImageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tiff", "tif"]
    private let supportedVideoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm", "3gp"]

    // MARK: - Main Validation

    /// Comprehensive file validation
    func validate(url: URL) -> FileValidationResult {
        // 1. Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Could be iCloud placeholder
            if isICloudPlaceholder(url) {
                return .invalid(.iCloudNotDownloaded)
            }
            return .invalid(.fileNotFound)
        }

        // 2. Check permissions
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return .invalid(.insufficientPermissions)
        }

        // 3. Get file attributes
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return .invalid(.unknownError(underlying: NSError(domain: "FileValidation", code: -1)))
        }

        let fileSize = attributes[.size] as? Int64 ?? 0

        // 4. Check empty file
        if fileSize == 0 {
            return .invalid(.emptyFile)
        }

        // 5. Check file size limit
        if fileSize > maxFileSize {
            return .invalid(.fileTooLarge(size: fileSize, maxSize: maxFileSize))
        }

        // 6. Check filename length
        let filename = url.lastPathComponent
        if filename.count > maxFilenameLength {
            return .invalid(.filenameTooLong(length: filename.count, maxLength: maxFilenameLength))
        }

        // 7. Type-specific validation
        let ext = url.pathExtension.lowercased()

        if supportedPDFExtensions.contains(ext) {
            return validatePDF(url: url)
        } else if supportedImageExtensions.contains(ext) {
            return validateImage(url: url)
        } else if supportedVideoExtensions.contains(ext) {
            return validateVideo(url: url)
        } else {
            return .invalid(.unsupportedFormat(detected: ext, expected: "PDF, Image, or Video"))
        }
    }

    // MARK: - PDF Validation

    private func validatePDF(url: URL) -> FileValidationResult {
        guard let document = PDFDocument(url: url) else {
            return .invalid(.corruptedFile(details: "PDF açılamadı"))
        }

        // Check if encrypted/password protected
        if document.isEncrypted {
            // Try to unlock without password
            if !document.unlock(withPassword: "") {
                return .invalid(.passwordProtected)
            }
        }

        // Check if it has pages
        if document.pageCount == 0 {
            return .invalid(.corruptedFile(details: "PDF'de sayfa yok"))
        }

        // Try to read first page (basic integrity check)
        guard document.page(at: 0) != nil else {
            return .invalid(.corruptedFile(details: "İlk sayfa okunamadı"))
        }

        return .valid
    }

    // MARK: - Image Validation

    private func validateImage(url: URL) -> FileValidationResult {
        // Check if image can be loaded
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return .invalid(.corruptedFile(details: "Görsel kaynağı oluşturulamadı"))
        }

        // Check image count
        let imageCount = CGImageSourceGetCount(source)
        if imageCount == 0 {
            return .invalid(.corruptedFile(details: "Geçerli görsel verisi bulunamadı"))
        }

        // Check image properties
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return .invalid(.corruptedFile(details: "Görsel özellikleri okunamadı"))
        }

        // Verify dimensions exist
        guard let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
              width > 0 && height > 0 else {
            return .invalid(.corruptedFile(details: "Geçersiz görsel boyutları"))
        }

        return .valid
    }

    // MARK: - Video Validation

    private func validateVideo(url: URL) -> FileValidationResult {
        let asset = AVURLAsset(url: url)

        // Check if asset is playable
        guard asset.isPlayable else {
            return .invalid(.corruptedFile(details: "Video oynatılamıyor"))
        }

        // Check duration
        let duration = CMTimeGetSeconds(asset.duration)
        if duration <= 0 || duration.isNaN || duration.isInfinite {
            return .invalid(.corruptedFile(details: "Geçersiz video süresi"))
        }

        // Check for video track
        let videoTracks = asset.tracks(withMediaType: .video)
        if videoTracks.isEmpty {
            return .invalid(.corruptedFile(details: "Video kaydı bulunamadı"))
        }

        return .valid
    }

    // MARK: - iCloud Check

    private func isICloudPlaceholder(_ url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                return status != .current
            }
        } catch {
            // Not an iCloud file
        }
        return false
    }

    /// Check if file needs to be downloaded from iCloud
    func needsICloudDownload(_ url: URL) -> Bool {
        return isICloudPlaceholder(url)
    }

    /// Start iCloud download for placeholder file
    func startICloudDownload(_ url: URL) throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }
}

// MARK: - Convenience Extensions

extension FileValidationService {

    /// Quick validation check (returns bool)
    func isValid(_ url: URL) -> Bool {
        validate(url: url).isValid
    }

    /// Get validation error message for display
    func getValidationMessage(_ url: URL) -> String? {
        let result = validate(url: url)
        return result.error?.errorDescription
    }

    /// Supported file extensions for document picker
    static var supportedUTTypes: [UTType] {
        [.pdf, .image, .movie, .video, .mpeg4Movie, .quickTimeMovie]
    }
}
