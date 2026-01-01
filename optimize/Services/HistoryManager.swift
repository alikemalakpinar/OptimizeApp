//
//  HistoryManager.swift
//  optimize
//
//  Persistent history storage
//
//  CRITICAL FIX: Migrated from UserDefaults to file system storage.
//  UserDefaults is NOT designed for list/collection data storage.
//  Storing hundreds of history items in UserDefaults causes:
//  - Slow app launch times (UserDefaults loads synchronously on app start)
//  - Potential "watchdog kill" on slow devices
//  - plist file corruption risk
//
//  New implementation:
//  - Stores history as JSON in Documents directory
//  - Async save on background queue (non-blocking)
//  - Automatic migration from UserDefaults for existing users
//

import Foundation

// MARK: - History Manager Protocol (Dependency Injection)

/// Protocol for history management - enables testability and mocking
protocol HistoryManagerProtocol: AnyObject {
    var items: [HistoryItem] { get }
    var totalBytesSaved: Int64 { get }
    var totalSavedFormatted: String { get }
    var totalFilesProcessed: Int { get }
    var averageSavingsPercent: Int { get }

    func addItem(_ item: HistoryItem)
    func addFromResult(_ result: CompressionResult, presetId: String)
    func removeItem(at index: Int)
    func removeItem(_ item: HistoryItem)
    func clearAll()
    func recentItems(limit: Int) -> [HistoryItem]
}

// MARK: - History Manager

@MainActor
class HistoryManager: ObservableObject, HistoryManagerProtocol {
    static let shared = HistoryManager()

    // MARK: - Configuration

    private let maxHistoryItems = 100

    /// File name for history storage
    private let historyFileName = "compression_history.json"

    /// Legacy UserDefaults key for migration
    private let legacyHistoryKey = "compressionHistory"

    // MARK: - Background Queue for Async Saves

    /// Background queue for non-blocking file operations
    private let saveQueue = DispatchQueue(label: "com.optimize.history.save", qos: .utility)

    /// Debounce timer to batch rapid saves
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5

    // MARK: - Published State

    @Published var items: [HistoryItem] = []

    // MARK: - Settings

    /// Read retention days from UserDefaults (synced with SettingsScreen)
    private var retentionDays: Int {
        UserDefaults.standard.integer(forKey: "historyRetentionDays").nonZeroOr(30)
    }

    // MARK: - Initialization

    private init() {
        loadHistory()
        cleanupOldItems()
    }

    // MARK: - File System Paths

    /// URL for history file in Documents directory
    private func getHistoryFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(historyFileName)
    }

    // MARK: - Cleanup Old Items Based on Retention Setting

    func cleanupOldItems() {
        let calendar = Calendar.current
        let now = Date()

        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? now

        let originalCount = items.count
        items.removeAll { item in
            item.processedAt < cutoffDate
        }

        if items.count != originalCount {
            saveHistoryAsync()
        }
    }

    // MARK: - Public Methods

    func addItem(_ item: HistoryItem) {
        items.insert(item, at: 0)

        // Limit history size
        if items.count > maxHistoryItems {
            items = Array(items.prefix(maxHistoryItems))
        }

        saveHistoryAsync()
    }

    func addFromResult(_ result: CompressionResult, presetId: String) {
        let item = HistoryItem(
            id: UUID(),
            fileName: result.originalFile.name,
            originalSize: result.originalFile.size,
            compressedSize: result.compressedSize,
            savingsPercent: result.savingsPercent,
            processedAt: result.processedAt,
            presetUsed: presetId
        )
        addItem(item)
    }

    func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items.remove(at: index)
        saveHistoryAsync()
    }

    func removeItem(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistoryAsync()
    }

    func clearAll() {
        items.removeAll()
        saveHistoryAsync()
    }

    func recentItems(limit: Int = 3) -> [HistoryItem] {
        Array(items.prefix(limit))
    }

    // MARK: - Statistics for Gamification

    /// Total bytes saved across all compressions
    var totalBytesSaved: Int64 {
        items.reduce(0) { $0 + ($1.originalSize - $1.compressedSize) }
    }

    /// Total bytes saved formatted as string (e.g., "1.2 GB")
    var totalSavedFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalBytesSaved, countStyle: .file)
    }

    /// Total number of files processed
    var totalFilesProcessed: Int {
        items.count
    }

    /// Average savings percentage across all compressions
    var averageSavingsPercent: Int {
        guard !items.isEmpty else { return 0 }
        let total = items.reduce(0) { $0 + $1.savingsPercent }
        return total / items.count
    }

    // MARK: - Persistence (File System Based)

    /// Load history from file system
    /// Falls back to UserDefaults migration for existing users
    private func loadHistory() {
        let fileURL = getHistoryFileURL()

        // Try loading from file system first
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([StoredHistoryItem].self, from: data)
                items = decoded.map { $0.toHistoryItem() }
                return
            } catch {
                print("HistoryManager: Failed to load from file: \(error)")
            }
        }

        // Migration: Check UserDefaults for legacy data
        if let legacyData = UserDefaults.standard.data(forKey: legacyHistoryKey) {
            do {
                let decoded = try JSONDecoder().decode([StoredHistoryItem].self, from: legacyData)
                items = decoded.map { $0.toHistoryItem() }

                // Migrate to file system
                saveHistoryAsync()

                // Clean up UserDefaults after successful migration
                UserDefaults.standard.removeObject(forKey: legacyHistoryKey)
                print("HistoryManager: Successfully migrated from UserDefaults to file system")
            } catch {
                print("HistoryManager: Failed to migrate from UserDefaults: \(error)")
                items = []
            }
        } else {
            items = []
        }
    }

    /// Save history asynchronously to file system
    /// Uses debouncing to batch rapid saves
    private func saveHistoryAsync() {
        // Cancel any pending save
        saveWorkItem?.cancel()

        // Capture current items for background save
        let itemsToSave = items.map { StoredHistoryItem(from: $0) }
        let fileURL = getHistoryFileURL()

        // Create new debounced work item
        let workItem = DispatchWorkItem { [weak self] in
            guard self != nil else { return }

            do {
                let data = try JSONEncoder().encode(itemsToSave)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                print("HistoryManager: Failed to save history: \(error)")
            }
        }

        saveWorkItem = workItem

        // Schedule save after debounce interval
        saveQueue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    /// Force immediate save (for app termination)
    func saveImmediately() {
        saveWorkItem?.cancel()

        let itemsToSave = items.map { StoredHistoryItem(from: $0) }
        let fileURL = getHistoryFileURL()

        do {
            let data = try JSONEncoder().encode(itemsToSave)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("HistoryManager: Failed to save history immediately: \(error)")
        }
    }
}

// MARK: - Storable History Item (Codable)

private struct StoredHistoryItem: Codable {
    let id: String
    let fileName: String
    let originalSize: Int64
    let compressedSize: Int64
    let savingsPercent: Int
    let processedAt: Date
    let presetUsed: String

    init(from item: HistoryItem) {
        self.id = item.id.uuidString
        self.fileName = item.fileName
        self.originalSize = item.originalSize
        self.compressedSize = item.compressedSize
        self.savingsPercent = item.savingsPercent
        self.processedAt = item.processedAt
        self.presetUsed = item.presetUsed
    }

    func toHistoryItem() -> HistoryItem {
        HistoryItem(
            id: UUID(uuidString: id) ?? UUID(),
            fileName: fileName,
            originalSize: originalSize,
            compressedSize: compressedSize,
            savingsPercent: savingsPercent,
            processedAt: processedAt,
            presetUsed: presetUsed
        )
    }
}

// MARK: - Int Extension for Default Value

private extension Int {
    func nonZeroOr(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}
