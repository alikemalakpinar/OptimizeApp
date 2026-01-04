//
//  ThumbnailCacheService.swift
//  optimize
//
//  Persistent thumbnail caching for fast file previews
//  Supports PDF, Images, Videos, Documents
//

import Foundation
import UIKit
import CryptoKit

// MARK: - Thumbnail Cache Service

@MainActor
final class ThumbnailCacheService: ObservableObject {
    static let shared = ThumbnailCacheService()

    // MARK: - Configuration

    /// Maximum cache size in bytes (100 MB default)
    private let maxCacheSize: Int64 = 100 * 1024 * 1024

    /// Maximum age for cached thumbnails (7 days)
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60

    /// Thumbnail dimensions
    private let thumbnailSize = CGSize(width: 300, height: 300)

    /// Cache directory name
    private let cacheDirectoryName = "ThumbnailCache"

    // MARK: - Memory Cache

    /// In-memory LRU cache for fast access
    private var memoryCache = NSCache<NSString, UIImage>()

    /// Metadata for disk cache entries
    @Published private(set) var cacheStats = CacheStats()

    // MARK: - Background Queue

    private let cacheQueue = DispatchQueue(label: "com.optimize.thumbnailcache", qos: .utility)

    // MARK: - Initialization

    private init() {
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB memory limit

        Task {
            await initializeCache()
        }
    }

    // MARK: - Public API

    /// Get thumbnail for URL (from cache or generate)
    func thumbnail(for url: URL, type: ThumbnailType = .auto) async -> UIImage? {
        let cacheKey = generateCacheKey(for: url)

        // Check memory cache first
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        // Check disk cache
        if let diskCached = await loadFromDisk(key: cacheKey) {
            memoryCache.setObject(diskCached, forKey: cacheKey as NSString)
            return diskCached
        }

        // Generate thumbnail
        let thumbnail = await generateThumbnail(for: url, type: type)

        if let thumbnail = thumbnail {
            // Cache in memory
            memoryCache.setObject(thumbnail, forKey: cacheKey as NSString)

            // Cache to disk
            await saveToDisk(image: thumbnail, key: cacheKey)
        }

        return thumbnail
    }

    /// Preload thumbnails for multiple URLs
    func preloadThumbnails(for urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls.prefix(10) { // Limit concurrent preloads
                group.addTask {
                    _ = await self.thumbnail(for: url)
                }
            }
        }
    }

    /// Clear all cached thumbnails
    func clearCache() async {
        memoryCache.removeAllObjects()

        await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                let cacheDir = self.getCacheDirectory()
                try? FileManager.default.removeItem(at: cacheDir)
                try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

                Task { @MainActor in
                    self.cacheStats = CacheStats()
                }

                continuation.resume()
            }
        }
    }

    /// Remove cached thumbnail for specific URL
    func removeThumbnail(for url: URL) async {
        let cacheKey = generateCacheKey(for: url)
        memoryCache.removeObject(forKey: cacheKey as NSString)

        await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                let filePath = self.getCacheDirectory().appendingPathComponent(cacheKey + ".jpg")
                try? FileManager.default.removeItem(at: filePath)
                continuation.resume()
            }
        }
    }

    // MARK: - Cache Key Generation

    private func generateCacheKey(for url: URL) -> String {
        // Use file path + modification date for cache key
        let path = url.path
        var modDate = ""

        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let date = attrs[.modificationDate] as? Date {
            modDate = String(date.timeIntervalSince1970)
        }

        let combined = path + modDate
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(32).description
    }

    // MARK: - Disk Cache Operations

    private func getCacheDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent(cacheDirectoryName)
    }

    private func initializeCache() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                let cacheDir = self.getCacheDirectory()

                // Create cache directory if needed
                if !FileManager.default.fileExists(atPath: cacheDir.path) {
                    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                }

                // Calculate stats and cleanup
                self.performCleanup()

                continuation.resume()
            }
        }
    }

    private func loadFromDisk(key: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let filePath = self.getCacheDirectory().appendingPathComponent(key + ".jpg")

                guard FileManager.default.fileExists(atPath: filePath.path),
                      let data = try? Data(contentsOf: filePath),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }

                // Update access time
                try? FileManager.default.setAttributes(
                    [.modificationDate: Date()],
                    ofItemAtPath: filePath.path
                )

                continuation.resume(returning: image)
            }
        }
    }

    private func saveToDisk(image: UIImage, key: String) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                let filePath = self.getCacheDirectory().appendingPathComponent(key + ".jpg")

                // Compress to JPEG for efficient storage
                guard let data = image.jpegData(compressionQuality: 0.8) else {
                    continuation.resume()
                    return
                }

                try? data.write(to: filePath, options: [.atomic])

                // Update stats
                Task { @MainActor in
                    self.cacheStats.itemCount += 1
                    self.cacheStats.totalSize += Int64(data.count)
                }

                // Check if cleanup needed
                if self.cacheStats.totalSize > self.maxCacheSize {
                    self.performCleanup()
                }

                continuation.resume()
            }
        }
    }

    private func performCleanup() {
        let cacheDir = getCacheDirectory()
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var totalSize: Int64 = 0
        var itemCount = 0
        var filesToDelete: [URL] = []
        let now = Date()

        // Collect files and check age
        var fileInfos: [(url: URL, date: Date, size: Int64)] = []

        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modDate = attrs.contentModificationDate,
                  let size = attrs.fileSize else { continue }

            let age = now.timeIntervalSince(modDate)

            if age > maxCacheAge {
                filesToDelete.append(file)
            } else {
                fileInfos.append((file, modDate, Int64(size)))
                totalSize += Int64(size)
                itemCount += 1
            }
        }

        // Delete old files
        for file in filesToDelete {
            try? fileManager.removeItem(at: file)
        }

        // If still over size limit, delete oldest files
        if totalSize > maxCacheSize {
            let sorted = fileInfos.sorted { $0.date < $1.date }
            var currentSize = totalSize

            for fileInfo in sorted {
                if currentSize <= maxCacheSize * 80 / 100 { // Target 80% of max
                    break
                }
                try? fileManager.removeItem(at: fileInfo.url)
                currentSize -= fileInfo.size
                itemCount -= 1
            }

            totalSize = currentSize
        }

        Task { @MainActor in
            self.cacheStats = CacheStats(itemCount: itemCount, totalSize: totalSize)
        }
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(for url: URL, type: ThumbnailType) async -> UIImage? {
        let actualType = type == .auto ? detectType(for: url) : type

        switch actualType {
        case .pdf:
            return await generatePDFThumbnail(url: url)
        case .image:
            return await generateImageThumbnail(url: url)
        case .video:
            return await generateVideoThumbnail(url: url)
        case .document:
            return await generateDocumentThumbnail(url: url)
        case .auto:
            return await generateGenericThumbnail(url: url)
        }
    }

    private func detectType(for url: URL) -> ThumbnailType {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif":
            return .image
        case "mp4", "mov", "avi", "mkv", "m4v", "webm", "3gp":
            return .video
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "keynote":
            return .document
        default:
            return .auto
        }
    }

    private func generatePDFThumbnail(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStop = url.startAccessingSecurityScopedResource()
                defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }

                guard let document = CGPDFDocument(url as CFURL),
                      let page = document.page(at: 1) else {
                    continuation.resume(returning: nil)
                    return
                }

                let bounds = page.getBoxRect(.mediaBox)
                let scale = min(300 / bounds.width, 300 / bounds.height, 2.0)
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))

                    ctx.cgContext.translateBy(x: 0, y: size.height)
                    ctx.cgContext.scaleBy(x: scale, y: -scale)
                    ctx.cgContext.drawPDFPage(page)
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func generateImageThumbnail(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStop = url.startAccessingSecurityScopedResource()
                defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }

                let options: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: 300,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]

                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }

    private func generateVideoThumbnail(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStop = url.startAccessingSecurityScopedResource()
                defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }

                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 300, height: 300)

                let time = CMTime(seconds: 1.0, preferredTimescale: 600)

                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } catch {
                    do {
                        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func generateDocumentThumbnail(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStop = url.startAccessingSecurityScopedResource()
                defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }

                // Use QuickLook thumbnail generator
                if #available(iOS 13.0, *) {
                    let request = QLThumbnailGenerator.Request(
                        fileAt: url,
                        size: CGSize(width: 300, height: 300),
                        scale: UIScreen.main.scale,
                        representationTypes: .thumbnail
                    )

                    QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, _, error in
                        if let thumbnail = thumbnail {
                            continuation.resume(returning: thumbnail.uiImage)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func generateGenericThumbnail(url: URL) async -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            UIColor.systemGray6.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let icon = UIImage(systemName: "doc.fill")?.withTintColor(.systemGray)
            let iconSize: CGFloat = 60
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            icon?.draw(in: iconRect)
        }
    }
}

// MARK: - Supporting Types

enum ThumbnailType {
    case auto
    case pdf
    case image
    case video
    case document
}

struct CacheStats: Equatable {
    var itemCount: Int = 0
    var totalSize: Int64 = 0

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - AVFoundation Import

import AVFoundation
import QuickLookThumbnailing
