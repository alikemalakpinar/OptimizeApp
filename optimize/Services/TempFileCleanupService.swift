//
//  TempFileCleanupService.swift
//  optimize
//
//  Systematic cleanup of temporary files to prevent app storage bloat.
//  Manages the lifecycle of temporary compression outputs.
//
//  CRITICAL: Without this, the app's "Documents & Data" can grow to 1GB+
//  as temporary files accumulate from compression operations.
//
//  CLEANUP STRATEGY:
//  1. On app launch: Clean files older than 24 hours
//  2. On app termination: Clean all orphaned temp files
//  3. After successful save/share: Clean the specific temp file
//  4. On low disk space: Aggressive cleanup of all temp files
//

import Foundation
import UIKit

// MARK: - Cleanup Statistics

struct CleanupStatistics {
    let filesDeleted: Int
    let bytesReclaimed: Int64
    let duration: TimeInterval

    var formattedBytesReclaimed: String {
        ByteCountFormatter.string(fromByteCount: bytesReclaimed, countStyle: .file)
    }
}

// MARK: - Temp File Cleanup Service

final class TempFileCleanupService {

    // MARK: - Singleton

    static let shared = TempFileCleanupService()

    // MARK: - Configuration

    /// Maximum age for temp files (24 hours)
    private let maxTempFileAge: TimeInterval = 24 * 60 * 60

    /// Known temp file patterns created by our app
    private let tempFilePatterns = [
        "_optimized_",
        "_compressed_",
        "_WhatsApp",
        "_Sosyal",
        "_HD",
        "_Orijinal",
        "_retry",
        "_temp_",
        "optimize_"
    ]

    /// Known temp file extensions
    private let tempFileExtensions = ["pdf", "mp4", "mov", "jpg", "jpeg", "png", "heic"]

    // MARK: - Directories

    private var tempDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    private var cachesDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    // MARK: - Initialization

    private init() {
        setupAppLifecycleObservers()
    }

    // MARK: - Lifecycle Observers

    private func setupAppLifecycleObservers() {
        // Clean on app launch (delayed to not block startup)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidFinishLaunching),
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )

        // Clean on app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        // Clean on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleAppDidFinishLaunching() {
        // Delay cleanup to not block app launch
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.cleanupOldTempFiles()
        }
    }

    @objc private func handleAppWillTerminate() {
        // Synchronous cleanup on termination
        cleanupAllTempFiles()
    }

    @objc private func handleMemoryWarning() {
        // Aggressive cleanup on memory warning
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.cleanupAllTempFiles()
        }
    }

    // MARK: - Public API

    /// Clean all temp files (aggressive)
    @discardableResult
    func cleanupAllTempFiles() -> CleanupStatistics {
        let startTime = Date()
        var deletedCount = 0
        var reclaimedBytes: Int64 = 0

        let directories = [tempDirectory, cachesDirectory].compactMap { $0 }

        for directory in directories {
            let (count, bytes) = cleanDirectory(directory, maxAge: nil)
            deletedCount += count
            reclaimedBytes += bytes
        }

        let duration = Date().timeIntervalSince(startTime)

        #if DEBUG
        if deletedCount > 0 {
            print("🧹 [TempCleanup] Deleted \(deletedCount) files, reclaimed \(ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file))")
        }
        #endif

        return CleanupStatistics(
            filesDeleted: deletedCount,
            bytesReclaimed: reclaimedBytes,
            duration: duration
        )
    }

    /// Clean temp files older than maxTempFileAge
    @discardableResult
    func cleanupOldTempFiles() -> CleanupStatistics {
        let startTime = Date()
        var deletedCount = 0
        var reclaimedBytes: Int64 = 0

        let directories = [tempDirectory, cachesDirectory].compactMap { $0 }

        for directory in directories {
            let (count, bytes) = cleanDirectory(directory, maxAge: maxTempFileAge)
            deletedCount += count
            reclaimedBytes += bytes
        }

        let duration = Date().timeIntervalSince(startTime)

        #if DEBUG
        if deletedCount > 0 {
            print("🧹 [TempCleanup] Cleaned \(deletedCount) old files, reclaimed \(ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file))")
        }
        #endif

        return CleanupStatistics(
            filesDeleted: deletedCount,
            bytesReclaimed: reclaimedBytes,
            duration: duration
        )
    }

    /// Delete a specific temp file after it's been saved/shared
    func deleteFile(at url: URL) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            try FileManager.default.removeItem(at: url)

            #if DEBUG
            print("🗑️ [TempCleanup] Deleted: \(url.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [TempCleanup] Failed to delete \(url.lastPathComponent): \(error)")
            #endif
        }
    }

    /// Get current temp storage usage
    func getTempStorageUsage() -> Int64 {
        var totalSize: Int64 = 0

        let directories = [tempDirectory, cachesDirectory].compactMap { $0 }

        for directory in directories {
            totalSize += calculateDirectorySize(directory)
        }

        return totalSize
    }

    /// Get formatted temp storage usage
    var formattedTempStorageUsage: String {
        ByteCountFormatter.string(fromByteCount: getTempStorageUsage(), countStyle: .file)
    }

    // MARK: - Private Helpers

    private func cleanDirectory(_ directory: URL, maxAge: TimeInterval?) -> (count: Int, bytes: Int64) {
        let fileManager = FileManager.default
        var deletedCount = 0
        var reclaimedBytes: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return (0, 0)
        }

        let now = Date()

        for case let fileURL as URL in enumerator {
            guard isOurTempFile(fileURL) else { continue }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey, .fileSizeKey, .isDirectoryKey])

                // Skip directories
                if resourceValues.isDirectory == true { continue }

                // Check age if maxAge is specified
                if let maxAge = maxAge,
                   let creationDate = resourceValues.creationDate {
                    let age = now.timeIntervalSince(creationDate)
                    if age < maxAge { continue }
                }

                let fileSize = Int64(resourceValues.fileSize ?? 0)

                try fileManager.removeItem(at: fileURL)

                deletedCount += 1
                reclaimedBytes += fileSize

            } catch {
                // Ignore errors, file might be in use
                continue
            }
        }

        return (deletedCount, reclaimedBytes)
    }

    private func isOurTempFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        // Check if extension matches
        guard tempFileExtensions.contains(ext) else { return false }

        // Check if filename contains our patterns
        for pattern in tempFilePatterns {
            if filename.contains(pattern.lowercased()) {
                return true
            }
        }

        return false
    }

    private func calculateDirectorySize(_ directory: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard isOurTempFile(fileURL) else { continue }

            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }
}

// MARK: - Convenience Extension for Result Cleanup

extension TempFileCleanupService {

    /// Mark a file for cleanup after user saves it elsewhere
    /// Call this after successful save to Files or Photos
    func markForCleanup(outputURL: URL, delay: TimeInterval = 5.0) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.deleteFile(at: outputURL)
        }
    }
}
