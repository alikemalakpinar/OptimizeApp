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
            return AppStrings.Error.accessDenied
        case .invalidPDF:
            return AppStrings.Error.invalidPDF
        case .invalidFile:
            return AppStrings.Error.invalidFile
        case .emptyPDF:
            return AppStrings.Error.emptyPDF
        case .encryptedPDF:
            return AppStrings.Error.encryptedPDF
        case .contextCreationFailed:
            return AppStrings.Error.contextFailed
        case .saveFailed:
            return AppStrings.Error.saveFailed
        case .cancelled:
            return AppStrings.Error.cancelled
        case .memoryPressure:
            return AppStrings.Error.memoryPressure
        case .fileTooLarge:
            return AppStrings.Error.fileTooLarge
        case .pageProcessingFailed:
            return AppStrings.Error.pageFailed
        case .timeout:
            return AppStrings.Error.timeout
        case .exportFailed:
            return AppStrings.Error.exportFailed
        case .unsupportedType:
            return AppStrings.Error.unsupportedType
        case .unknown:
            return AppStrings.Error.generic
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
