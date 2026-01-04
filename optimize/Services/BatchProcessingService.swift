//
//  BatchProcessingService.swift
//  optimize
//
//  Batch file compression with queue management
//  Supports parallel processing, progress tracking, and cancellation
//

import Foundation
import SwiftUI
import Combine

// MARK: - Batch Processing Service

@MainActor
final class BatchProcessingService: ObservableObject {
    static let shared = BatchProcessingService()

    // MARK: - Configuration

    /// Maximum concurrent compressions
    private let maxConcurrentTasks = 3

    // MARK: - Published State

    @Published private(set) var queue: [BatchItem] = []
    @Published private(set) var completedItems: [BatchItem] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var currentProgress: BatchProgress = .idle

    // MARK: - Private State

    private var processingTask: Task<Void, Never>?
    private var itemTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Add files to the batch queue
    func addFiles(_ urls: [URL], preset: CompressionPreset = CompressionPreset.defaultPresets[1]) {
        let newItems = urls.map { url in
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
    }

    /// Add single file to queue
    func addFile(_ url: URL, preset: CompressionPreset = CompressionPreset.defaultPresets[1]) {
        addFiles([url], preset: preset)
    }

    /// Start processing the queue
    func startProcessing() {
        guard !isProcessing, !queue.isEmpty else { return }

        isProcessing = true
        processingTask = Task {
            await processQueue()
        }
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
