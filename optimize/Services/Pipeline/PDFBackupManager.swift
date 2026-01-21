//
//  PDFBackupManager.swift
//  optimize
//
//  Safe backup system for destructive PDF operations.
//  Ensures users can always recover their original files.
//
//  SAFETY FIRST:
//  - Always backup before PDFUltraRebuilder
//  - Timestamped backups with UUID for uniqueness
//  - Restore capability if operation fails
//  - Automatic cleanup of old backups (>7 days)
//

import Foundation
import PDFKit

// MARK: - PDF Backup Manager

final class PDFBackupManager {
    static let shared = PDFBackupManager()

    /// Backup folder in app's Documents directory
    private let backupFolderName = "OriginalBackups"

    /// Maximum age of backups before cleanup (7 days)
    private let maxBackupAge: TimeInterval = 7 * 24 * 60 * 60

    private init() {
        // Create backup folder on init
        createBackupFolderIfNeeded()
        // Schedule cleanup of old backups
        Task {
            await cleanupOldBackups()
        }
    }

    // MARK: - Backup Folder

    private var backupFolderURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(backupFolderName)
    }

    private func createBackupFolderIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: backupFolderURL.path) {
            try? fm.createDirectory(at: backupFolderURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Backup Operations

    /// Creates a safe backup of the original file before destructive operations.
    /// Returns the backup URL and a restore closure.
    ///
    /// - Parameter sourceURL: The original file to backup
    /// - Returns: Tuple of (backupURL, restoreClosure) or nil if backup failed
    func createBackup(for sourceURL: URL) -> (backupURL: URL, restore: () -> URL?)? {
        let fm = FileManager.default

        // Generate unique backup filename
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let uuid = UUID().uuidString.prefix(8)
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

        let backupName = "\(originalName)_backup_\(timestamp)_\(uuid).\(ext)"
        let backupURL = backupFolderURL.appendingPathComponent(backupName)

        do {
            // Copy original to backup location
            try fm.copyItem(at: sourceURL, to: backupURL)

            // Create restore closure
            let restoreClosure: () -> URL? = { [weak self] in
                self?.restoreFromBackup(backupURL: backupURL, to: sourceURL)
            }

            return (backupURL, restoreClosure)

        } catch {
            print("PDFBackupManager: Failed to create backup - \(error.localizedDescription)")
            return nil
        }
    }

    /// Restores a file from backup
    private func restoreFromBackup(backupURL: URL, to originalURL: URL) -> URL? {
        let fm = FileManager.default

        do {
            // Remove the (potentially corrupted) current file
            if fm.fileExists(atPath: originalURL.path) {
                try fm.removeItem(at: originalURL)
            }

            // Copy backup to original location
            try fm.copyItem(at: backupURL, to: originalURL)

            return originalURL
        } catch {
            print("PDFBackupManager: Failed to restore from backup - \(error.localizedDescription)")
            return nil
        }
    }

    /// Gets the most recent backup for a given original filename
    func getMostRecentBackup(for originalName: String) -> URL? {
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: backupFolderURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return nil
        }

        // Find backups matching the original name
        let matchingBackups = contents.filter { url in
            url.lastPathComponent.hasPrefix(originalName + "_backup_")
        }

        // Sort by creation date (newest first)
        let sorted = matchingBackups.sorted { url1, url2 in
            let date1 = (try? fm.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
            let date2 = (try? fm.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }

        return sorted.first
    }

    /// Lists all backups
    func listBackups() -> [BackupInfo] {
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: backupFolderURL,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return contents.compactMap { url -> BackupInfo? in
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let creationDate = attrs[.creationDate] as? Date,
                  let size = attrs[.size] as? Int64 else {
                return nil
            }

            // Parse original name from backup filename
            let filename = url.deletingPathExtension().lastPathComponent
            let originalName = filename.components(separatedBy: "_backup_").first ?? filename

            return BackupInfo(
                url: url,
                originalName: originalName,
                creationDate: creationDate,
                size: size
            )
        }.sorted { $0.creationDate > $1.creationDate }
    }

    /// Deletes a specific backup
    func deleteBackup(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Cleanup

    /// Removes backups older than maxBackupAge
    private func cleanupOldBackups() async {
        let fm = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-maxBackupAge)

        guard let contents = try? fm.contentsOfDirectory(
            at: backupFolderURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        for url in contents {
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let creationDate = attrs[.creationDate] as? Date,
               creationDate < cutoffDate {
                try? fm.removeItem(at: url)
            }
        }
    }
}

// MARK: - Backup Info

struct BackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let originalName: String
    let creationDate: Date
    let size: Int64

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
}

// MARK: - PDF Safety Checks

extension PDFBackupManager {

    /// Checks if a PDF is encrypted/password-protected
    static func isEncrypted(url: URL) -> Bool {
        guard let document = PDFDocument(url: url) else {
            return false
        }
        return document.isEncrypted
    }

    /// Checks if a PDF appears corrupted or unreadable
    static func isCorrupted(url: URL) -> Bool {
        // Try to load the PDF
        guard let document = PDFDocument(url: url) else {
            return true // Can't load = corrupted
        }

        // Check if it has at least one page
        if document.pageCount == 0 {
            return true
        }

        // Try to access the first page
        guard document.page(at: 0) != nil else {
            return true
        }

        return false
    }

    /// Validates PDF before destructive operations
    static func validateForDestructiveOperation(url: URL) -> PDFValidationResult {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failed(reason: "Dosya bulunamadı")
        }

        // Check if encrypted
        if isEncrypted(url: url) {
            return .failed(reason: "Şifreli PDF dosyaları işlenemez")
        }

        // Check if corrupted
        if isCorrupted(url: url) {
            return .failed(reason: "PDF dosyası okunamıyor veya bozuk")
        }

        return .valid
    }
}

// MARK: - Validation Result

enum PDFValidationResult {
    case valid
    case failed(reason: String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var failureReason: String? {
        if case .failed(let reason) = self { return reason }
        return nil
    }
}
