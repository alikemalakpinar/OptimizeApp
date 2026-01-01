//
//  CompressionTypes.swift
//  optimize
//
//  Shared compression types, errors and extensions
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
