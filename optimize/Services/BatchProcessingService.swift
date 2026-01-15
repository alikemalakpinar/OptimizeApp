//
//  BatchProcessingService.swift
//  optimize
//
//  Batch file compression with queue management
//  Supports parallel processing, progress tracking, and cancellation
//
//  MASTER LEVEL ARCHITECTURE:
//  - Premium-gated batch processing
//  - Dynamic concurrent task limits based on subscription
//  - Background task support for Pro users
//  - Queue size limits for free tier
//

import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Batch Processing Service

@MainActor
final class BatchProcessingService: ObservableObject {
    static let shared = BatchProcessingService()

    // MARK: - Dependencies

    private let subscriptionManager: SubscriptionManager

    // MARK: - Configuration

    /// Maximum concurrent compressions - DYNAMIC based on subscription
    private var maxConcurrentTasks: Int {
        subscriptionManager.maxConcurrentOperations
    }

    /// Maximum queue size for free users
    private var maxQueueSize: Int {
        subscriptionManager.maxBatchQueueSize
    }

    // MARK: - Published State

    @Published private(set) var queue: [BatchItem] = []
    @Published private(set) var completedItems: [BatchItem] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var currentProgress: BatchProgress = .idle

    /// Indicates if queue is at capacity for free users
    @Published private(set) var isQueueAtLimit = false

    // MARK: - Private State

    private var processingTask: Task<Void, Never>?
    private var itemTasks: [UUID: Task<Void, Never>] = [:]

    /// Background task identifier for iOS background execution
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Initialization

    private init(subscriptionManager: SubscriptionManager = .shared) {
        self.subscriptionManager = subscriptionManager
    }

    // MARK: - Public API

    /// Add files to the batch queue
    /// Returns: Number of files actually added (may be limited for free users)
    @discardableResult
    func addFiles(_ urls: [URL], preset: CompressionPreset = CompressionPreset.defaultPresets[1]) -> Int {
        // Calculate how many files we can add
        let currentCount = queue.count
        let availableSlots = max(0, maxQueueSize - currentCount)

        // For free users, limit the number of files
        let filesToAdd: [URL]
        if !subscriptionManager.canPerformBatchProcessing {
            filesToAdd = Array(urls.prefix(availableSlots))
            isQueueAtLimit = filesToAdd.count < urls.count || (currentCount + filesToAdd.count) >= maxQueueSize
        } else {
            filesToAdd = urls
            isQueueAtLimit = false
        }

        let newItems = filesToAdd.map { url in
            BatchItem(
                id: UUID(),
                sourceURL: url,
                fileName: url.lastPathComponent,
                fileSize: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
                preset: preset,
                status: .pending
            )
        }

        queue.append(contentsOf: newItems)
        updateProgress()

        return newItems.count
    }

    /// Add single file to queue
    func addFile(_ url: URL, preset: CompressionPreset = CompressionPreset.defaultPresets[1]) {
        addFiles([url], preset: preset)
    }

    /// Check if batch processing is available for the user
    /// Returns true if available, false if paywall should be shown
    func checkBatchAccess() -> Bool {
        // If queue has more than 2 items, batch processing is needed
        if queue.count > 2 && !subscriptionManager.canPerformBatchProcessing {
            // Trigger paywall notification
            subscriptionManager.checkFeatureAccess(.batchProcessing)
            return false
        }
        return true
    }

    /// Start processing the queue
    /// Returns: true if processing started, false if blocked by subscription
    @discardableResult
    func startProcessing() -> Bool {
        guard !isProcessing, !queue.isEmpty else { return false }

        // PREMIUM CHECK: If queue has more than 2 items, require Pro
        if queue.count > 2 && !subscriptionManager.canPerformBatchProcessing {
            // Trigger paywall for batch processing
            subscriptionManager.checkFeatureAccess(.batchProcessing)
            return false
        }

        isProcessing = true

        // BACKGROUND TASK: Request background execution time (Pro feature)
        beginBackgroundTask()

        processingTask = Task {
            await processQueue()
            endBackgroundTask()
        }

        return true
    }

    // MARK: - Background Task Management

    /// Begin background task to continue processing when app is minimized
    private func beginBackgroundTask() {
        guard subscriptionManager.canProcessInBackground else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "BatchCompression") { [weak self] in
            // System is about to terminate - clean up
            self?.endBackgroundTask()
        }
    }

    /// End background task
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    /// Pause processing (current items continue, no new items start)
    func pauseProcessing() {
        isProcessing = false
        processingTask?.cancel()
        processingTask = nil
    }

    /// Cancel all pending items
    func cancelAll() {
        pauseProcessing()

        // Cancel running tasks
        for (_, task) in itemTasks {
            task.cancel()
        }
        itemTasks.removeAll()

        // Mark in-progress items as cancelled
        for index in queue.indices {
            if queue[index].status == .processing {
                queue[index].status = .cancelled
            }
        }

        // Move cancelled and pending to completed
        let cancelled = queue.filter { $0.status == .cancelled || $0.status == .pending }
        for var item in cancelled {
            item.status = .cancelled
            completedItems.append(item)
        }

        queue.removeAll { $0.status == .cancelled || $0.status == .pending }
        updateProgress()
    }

    /// Remove specific item from queue
    func removeItem(_ item: BatchItem) {
        if let index = queue.firstIndex(where: { $0.id == item.id }) {
            if queue[index].status == .processing {
                itemTasks[item.id]?.cancel()
                itemTasks.removeValue(forKey: item.id)
            }
            queue.remove(at: index)
            updateProgress()
        }
    }

    /// Retry failed items
    func retryFailed() {
        let failedItems = completedItems.filter { $0.status == .failed }
        completedItems.removeAll { $0.status == .failed }

        for var item in failedItems {
            item.status = .pending
            item.error = nil
            queue.append(item)
        }

        if !queue.isEmpty && !isProcessing {
            startProcessing()
        }
    }

    /// Clear completed items
    func clearCompleted() {
        completedItems.removeAll { $0.status == .completed }
        updateProgress()
    }

    /// Change preset for pending item
    func updatePreset(for itemId: UUID, preset: CompressionPreset) {
        if let index = queue.firstIndex(where: { $0.id == itemId && $0.status == .pending }) {
            queue[index].preset = preset
        }
    }

    // MARK: - Queue Processing

    private func processQueue() async {
        while isProcessing && !queue.isEmpty {
            // Find pending items
            let pendingCount = queue.filter { $0.status == .pending }.count
            let processingCount = queue.filter { $0.status == .processing }.count

            if pendingCount == 0 && processingCount == 0 {
                break
            }

            // Start new tasks if under limit
            let slotsAvailable = maxConcurrentTasks - processingCount

            if slotsAvailable > 0 {
                let itemsToStart = queue
                    .filter { $0.status == .pending }
                    .prefix(slotsAvailable)

                for item in itemsToStart {
                    await startProcessingItem(item)
                }
            }

            // Wait a bit before checking again
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        isProcessing = false
        updateProgress()
    }

    private func startProcessingItem(_ item: BatchItem) async {
        guard let index = queue.firstIndex(where: { $0.id == item.id }) else { return }

        queue[index].status = .processing
        queue[index].startTime = Date()
        updateProgress()

        let task = Task {
            await processItem(item)
        }

        itemTasks[item.id] = task
    }

    private func processItem(_ item: BatchItem) async {
        defer {
            itemTasks.removeValue(forKey: item.id)
        }

        do {
            // Access security-scoped resource
            let shouldStop = item.sourceURL.startAccessingSecurityScopedResource()
            defer { if shouldStop { item.sourceURL.stopAccessingSecurityScopedResource() } }

            // Get compression service
            let compressionService = UltimatePDFCompressionService.shared

            // Compress file
            let compressedURL = try await compressionService.compressFile(
                at: item.sourceURL,
                preset: item.preset,
                onProgress: { [weak self] _, progress in
                    Task { @MainActor in
                        self?.updateItemProgress(item.id, progress: progress)
                    }
                }
            )

            // Create result from compressed file
            let compressedSize = (try? FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64) ?? 0
            let originalFileInfo = FileInfo(
                name: item.fileName,
                url: item.sourceURL,
                size: item.fileSize
            )
            let result = CompressionResult(
                originalFile: originalFileInfo,
                compressedURL: compressedURL,
                compressedSize: compressedSize
            )

            // Mark as completed
            await MainActor.run {
                if let index = queue.firstIndex(where: { $0.id == item.id }) {
                    var completedItem = queue[index]
                    completedItem.status = .completed
                    completedItem.result = result
                    completedItem.endTime = Date()
                    completedItems.insert(completedItem, at: 0)
                    queue.remove(at: index)
                    updateProgress()

                    // Add to history
                    HistoryManager.shared.addFromResult(result, presetId: item.preset.id)
                }
            }

        } catch {
            // Mark as failed
            await MainActor.run {
                if let index = queue.firstIndex(where: { $0.id == item.id }) {
                    var failedItem = queue[index]
                    failedItem.status = .failed
                    failedItem.error = error.localizedDescription
                    failedItem.endTime = Date()
                    completedItems.insert(failedItem, at: 0)
                    queue.remove(at: index)
                    updateProgress()
                }
            }
        }
    }

    private func updateItemProgress(_ itemId: UUID, progress: Double) {
        if let index = queue.firstIndex(where: { $0.id == itemId }) {
            queue[index].progress = progress
        }
    }

    private func updateProgress() {
        let total = queue.count + completedItems.count
        let completed = completedItems.filter { $0.status == .completed }.count
        let failed = completedItems.filter { $0.status == .failed }.count
        let processing = queue.filter { $0.status == .processing }.count
        let pending = queue.filter { $0.status == .pending }.count

        let totalSaved = completedItems
            .filter { $0.status == .completed }
            .compactMap { $0.result }
            .reduce(Int64(0)) { $0 + ($1.originalFile.size - $1.compressedSize) }

        currentProgress = BatchProgress(
            total: total,
            completed: completed,
            failed: failed,
            processing: processing,
            pending: pending,
            totalBytesSaved: totalSaved
        )
    }
}

// MARK: - Supporting Types

struct BatchItem: Identifiable, Equatable {
    let id: UUID
    let sourceURL: URL
    let fileName: String
    let fileSize: Int64
    var preset: CompressionPreset
    var status: BatchItemStatus
    var progress: Double = 0
    var result: CompressionResult?
    var error: String?
    var startTime: Date?
    var endTime: Date?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        if duration < 60 {
            return String(format: "%.1f sn", duration)
        } else {
            return String(format: "%.1f dk", duration / 60)
        }
    }

    static func == (lhs: BatchItem, rhs: BatchItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.progress == rhs.progress
    }
}

enum BatchItemStatus: String, CaseIterable {
    case pending = "Bekliyor"
    case processing = "Isleniyor"
    case completed = "Tamamlandi"
    case failed = "Basarisiz"
    case cancelled = "Iptal Edildi"

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

struct BatchProgress: Equatable {
    var total: Int = 0
    var completed: Int = 0
    var failed: Int = 0
    var processing: Int = 0
    var pending: Int = 0
    var totalBytesSaved: Int64 = 0

    static let idle = BatchProgress()

    var isIdle: Bool {
        total == 0
    }

    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var formattedSaved: String {
        ByteCountFormatter.string(fromByteCount: totalBytesSaved, countStyle: .file)
    }

    var summary: String {
        if isIdle {
            return "Kuyruk bos"
        }
        return "\(completed)/\(total) tamamlandi"
    }
}

// MARK: - Video Batch Processing Extension (v4.0)

extension BatchProcessingService {

    /// Add video files with specific quality preset
    /// - Parameters:
    ///   - urls: Video file URLs
    ///   - quality: Video compression quality (default: .whatsapp for maximum compatibility)
    @discardableResult
    func addVideos(_ urls: [URL], quality: VideoQualityPreset = .whatsapp) -> Int {
        // Calculate how many files we can add
        let currentCount = queue.count
        let availableSlots = max(0, maxQueueSize - currentCount)

        // For free users, limit the number of files
        let filesToAdd: [URL]
        if !subscriptionManager.canPerformBatchProcessing {
            filesToAdd = Array(urls.prefix(availableSlots))
            isQueueAtLimit = filesToAdd.count < urls.count || (currentCount + filesToAdd.count) >= maxQueueSize
        } else {
            filesToAdd = urls
            isQueueAtLimit = false
        }

        // Create video batch items with a special video preset
        let videoPreset = CompressionPreset(
            id: "video_\(quality.id)",
            name: "Video \(quality.name)",
            description: quality.subtitle,
            icon: quality.icon,
            targetSizeMB: nil,
            quality: quality == .original ? .high : (quality == .hd ? .medium : .low),
            isProOnly: false
        )

        let newItems = filesToAdd.map { url in
            BatchItem(
                id: UUID(),
                sourceURL: url,
                fileName: url.lastPathComponent,
                fileSize: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
                preset: videoPreset,
                status: .pending
            )
        }

        queue.append(contentsOf: newItems)
        updateProgress()

        return newItems.count
    }

    /// Process video item using VideoCompressionService
    func processVideoItem(_ item: BatchItem, quality: VideoQualityPreset) async throws -> URL {
        let videoService = VideoCompressionService()

        let result = try await videoService.compress(
            inputURL: item.sourceURL,
            preset: quality
        ) { progress in
            Task { @MainActor in
                self.updateItemProgress(item.id, progress: progress)
            }
        }

        return result.outputURL
    }

    /// Batch compress all videos in queue with specified quality
    func compressAllVideos(quality: VideoQualityPreset = .whatsapp) async {
        let videoItems = queue.filter { item in
            let ext = item.sourceURL.pathExtension.lowercased()
            return ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext)
        }

        guard !videoItems.isEmpty else { return }

        for item in videoItems {
            if let index = queue.firstIndex(where: { $0.id == item.id }) {
                queue[index].status = .processing
                queue[index].startTime = Date()
            }

            do {
                let outputURL = try await processVideoItem(item, quality: quality)

                // Get compressed size
                let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

                // Create result
                let originalFileInfo = FileInfo(
                    name: item.fileName,
                    url: item.sourceURL,
                    size: item.fileSize
                )
                let result = CompressionResult(
                    originalFile: originalFileInfo,
                    compressedURL: outputURL,
                    compressedSize: compressedSize
                )

                // Mark as completed
                await MainActor.run {
                    if let index = queue.firstIndex(where: { $0.id == item.id }) {
                        var completedItem = queue[index]
                        completedItem.status = .completed
                        completedItem.result = result
                        completedItem.endTime = Date()
                        completedItems.insert(completedItem, at: 0)
                        queue.remove(at: index)
                        updateProgress()

                        // Haptic feedback
                        HapticManager.shared.trigger(.complete)
                    }
                }

            } catch {
                await MainActor.run {
                    if let index = queue.firstIndex(where: { $0.id == item.id }) {
                        var failedItem = queue[index]
                        failedItem.status = .failed
                        failedItem.error = error.localizedDescription
                        failedItem.endTime = Date()
                        completedItems.insert(failedItem, at: 0)
                        queue.remove(at: index)
                        updateProgress()

                        // Haptic feedback
                        HapticManager.shared.trigger(.error)
                    }
                }
            }
        }
    }
}

// MARK: - OptimizationProfile Batch Support

extension BatchProcessingService {

    /// Add files with OptimizationProfile instead of preset
    @discardableResult
    func addFiles(_ urls: [URL], profile: OptimizationProfile) -> Int {
        let preset = CompressionPreset.from(profile: profile)
        return addFiles(urls, preset: preset)
    }

    /// Process item with OptimizationProfile
    func processItemWithProfile(_ item: BatchItem, profile: OptimizationProfile) async throws -> CompressionResult {
        // Access security-scoped resource
        let shouldStop = item.sourceURL.startAccessingSecurityScopedResource()
        defer { if shouldStop { item.sourceURL.stopAccessingSecurityScopedResource() } }

        let fileType = FileType.from(extension: item.sourceURL.pathExtension)

        let outputURL: URL

        switch fileType {
        case .pdf:
            // Use profile-aware PDF compression
            let pdfService = UltimatePDFCompressionService.shared
            outputURL = try await pdfService.compressPDF(
                at: item.sourceURL,
                profile: profile
            ) { [weak self] _, progress in
                Task { @MainActor in
                    self?.updateItemProgress(item.id, progress: progress)
                }
            }

        case .image:
            // Use smart encode with profile
            guard let data = ImageIODownsampler.smartEncode(url: item.sourceURL, profile: profile) else {
                throw CompressionError.saveFailed
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(item.fileName)_optimized")
                .appendingPathExtension("jpg")
            try data.write(to: tempURL)
            outputURL = tempURL

        case .video:
            // Use video service with profile
            let videoService = VideoCompressionService()
            let result = try await videoService.compress(
                inputURL: item.sourceURL,
                preset: profile.videoResolution.toVideoQualityPreset
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.updateItemProgress(item.id, progress: progress)
                }
            }
            outputURL = result.outputURL

        default:
            // Use default compression
            let compressionService = UltimatePDFCompressionService.shared
            outputURL = try await compressionService.compressFile(
                at: item.sourceURL,
                preset: CompressionPreset.from(profile: profile)
            ) { [weak self] _, progress in
                Task { @MainActor in
                    self?.updateItemProgress(item.id, progress: progress)
                }
            }
        }

        // Create result
        let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        let originalFileInfo = FileInfo(
            name: item.fileName,
            url: item.sourceURL,
            size: item.fileSize
        )

        return CompressionResult(
            originalFile: originalFileInfo,
            compressedURL: outputURL,
            compressedSize: compressedSize
        )
    }
}

// MARK: - VideoResolution Extension

extension VideoResolution {
    var toVideoQualityPreset: VideoQualityPreset {
        switch self {
        case .sd480p: return .whatsapp
        case .hd720p: return .social
        case .hd1080p: return .hd
        case .uhd4k: return .original
        }
    }
}
