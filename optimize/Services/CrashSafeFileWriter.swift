//
//  CrashSafeFileWriter.swift
//  optimize
//
//  Atomic file writing that prevents data corruption on crash/interrupt.
//  Uses write-to-temp-then-rename pattern for data integrity.
//
//  CRITICAL:
//  Without atomic writes, a crash during file save can:
//  - Create 0-byte files
//  - Create partially written (corrupted) files
//  - Leave the filesystem in inconsistent state
//
//  PATTERN:
//  1. Write to temporary file
//  2. Verify the write was successful
//  3. Atomically rename/move to final location
//  4. Clean up on failure
//

import Foundation

// MARK: - File Write Result

struct FileWriteResult {
    let url: URL
    let size: Int64
    let duration: TimeInterval

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - File Write Error

enum FileWriteError: LocalizedError {
    case sourceNotFound
    case destinationExists
    case insufficientSpace
    case writeFailed(underlying: Error)
    case verificationFailed
    case atomicMoveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            return String(localized: "Kaynak dosya bulunamadı.")
        case .destinationExists:
            return String(localized: "Hedef dosya zaten mevcut.")
        case .insufficientSpace:
            return String(localized: "Yetersiz depolama alanı.")
        case .writeFailed(let error):
            return String(localized: "Yazma hatası: \(error.localizedDescription)")
        case .verificationFailed:
            return String(localized: "Dosya doğrulaması başarısız. Tekrar deneyin.")
        case .atomicMoveFailed(let error):
            return String(localized: "Dosya taşıma hatası: \(error.localizedDescription)")
        }
    }
}

// MARK: - Crash Safe File Writer

final class CrashSafeFileWriter {

    // MARK: - Singleton

    static let shared = CrashSafeFileWriter()

    // MARK: - Configuration

    private let tempDirectory: URL

    // MARK: - Initialization

    private init() {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafeWrite", isDirectory: true)

        // Ensure temp directory exists
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public API

    /// Write data to file atomically
    func writeData(
        _ data: Data,
        to destinationURL: URL,
        overwrite: Bool = true
    ) throws -> FileWriteResult {
        let startTime = Date()

        // Check if destination exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            if !overwrite {
                throw FileWriteError.destinationExists
            }
        }

        // Check disk space
        let requiredSpace = Int64(data.count) + 100_000 // 100KB buffer
        try DiskSpaceGuard.ensureSpace(for: requiredSpace)

        // Create temp file
        let tempURL = createTempURL(for: destinationURL)

        do {
            // Write to temp
            try data.write(to: tempURL, options: .atomic)

            // Verify write
            guard verifyFile(at: tempURL, expectedSize: Int64(data.count)) else {
                try? FileManager.default.removeItem(at: tempURL)
                throw FileWriteError.verificationFailed
            }

            // Atomic move to destination
            try atomicMove(from: tempURL, to: destinationURL)

            let duration = Date().timeIntervalSince(startTime)

            return FileWriteResult(
                url: destinationURL,
                size: Int64(data.count),
                duration: duration
            )

        } catch let error as FileWriteError {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw FileWriteError.writeFailed(underlying: error)
        }
    }

    /// Copy file atomically
    func copyFile(
        from sourceURL: URL,
        to destinationURL: URL,
        overwrite: Bool = true
    ) throws -> FileWriteResult {
        let startTime = Date()

        // Verify source exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw FileWriteError.sourceNotFound
        }

        // Get source size
        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let sourceSize = sourceAttributes[.size] as? Int64 ?? 0

        // Check if destination exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            if !overwrite {
                throw FileWriteError.destinationExists
            }
        }

        // Check disk space
        try DiskSpaceGuard.ensureSpace(for: sourceSize)

        // Create temp file
        let tempURL = createTempURL(for: destinationURL)

        do {
            // Copy to temp
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)

            // Verify copy
            guard verifyFile(at: tempURL, expectedSize: sourceSize) else {
                try? FileManager.default.removeItem(at: tempURL)
                throw FileWriteError.verificationFailed
            }

            // Atomic move to destination
            try atomicMove(from: tempURL, to: destinationURL)

            let duration = Date().timeIntervalSince(startTime)

            return FileWriteResult(
                url: destinationURL,
                size: sourceSize,
                duration: duration
            )

        } catch let error as FileWriteError {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw FileWriteError.writeFailed(underlying: error)
        }
    }

    /// Move file atomically (with safety)
    func moveFile(
        from sourceURL: URL,
        to destinationURL: URL,
        overwrite: Bool = true
    ) throws -> FileWriteResult {
        let startTime = Date()

        // Verify source exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw FileWriteError.sourceNotFound
        }

        // Get source size
        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let sourceSize = sourceAttributes[.size] as? Int64 ?? 0

        // Check if destination exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            if !overwrite {
                throw FileWriteError.destinationExists
            }
            // Remove existing file
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            // Atomic move
            try atomicMove(from: sourceURL, to: destinationURL)

            let duration = Date().timeIntervalSince(startTime)

            return FileWriteResult(
                url: destinationURL,
                size: sourceSize,
                duration: duration
            )

        } catch {
            throw FileWriteError.atomicMoveFailed(underlying: error)
        }
    }

    // MARK: - Private Helpers

    private func createTempURL(for finalURL: URL) -> URL {
        let filename = finalURL.lastPathComponent
        let uuid = UUID().uuidString.prefix(8)
        return tempDirectory.appendingPathComponent("\(uuid)_\(filename)")
    }

    private func verifyFile(at url: URL, expectedSize: Int64) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let actualSize = attributes[.size] as? Int64 else {
            return false
        }

        return actualSize == expectedSize
    }

    private func atomicMove(from sourceURL: URL, to destinationURL: URL) throws {
        // Ensure destination directory exists
        let destinationDir = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: destinationDir,
            withIntermediateDirectories: true
        )

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        // Move (rename is atomic on same filesystem)
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    // MARK: - Cleanup

    /// Clean up any orphaned temp files
    func cleanupOrphanedTempFiles() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let now = Date()
        let maxAge: TimeInterval = 3600 // 1 hour

        for fileURL in contents {
            guard let attributes = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = attributes.creationDate else {
                continue
            }

            if now.timeIntervalSince(creationDate) > maxAge {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension CrashSafeFileWriter {

    /// Save compressed output safely
    func saveCompressionOutput(
        tempURL: URL,
        originalFilename: String,
        to directory: URL? = nil
    ) throws -> FileWriteResult {
        // Generate destination filename
        let name = (originalFilename as NSString).deletingPathExtension
        let ext = tempURL.pathExtension
        let timestamp = Int(Date().timeIntervalSince1970)
        let newFilename = "\(name)_optimized_\(timestamp).\(ext)"

        // Determine destination directory
        let destDir = directory ?? FileManager.default.temporaryDirectory

        let destinationURL = destDir.appendingPathComponent(newFilename)

        return try moveFile(from: tempURL, to: destinationURL)
    }
}
