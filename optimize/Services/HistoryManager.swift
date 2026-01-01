//
//  HistoryManager.swift
//  optimize
//
//  Persistent history storage using UserDefaults
//

import Foundation

// MARK: - History Manager
@MainActor
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    private let historyKey = "compressionHistory"
    private let maxHistoryItems = 100

    @Published var items: [HistoryItem] = []

    // Read retention days from UserDefaults (synced with SettingsScreen)
    private var retentionDays: Int {
        UserDefaults.standard.integer(forKey: "historyRetentionDays").nonZeroOr(30)
    }

    private init() {
        loadHistory()
        cleanupOldItems()
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
            saveHistory()
        }
    }

    // MARK: - Public Methods
    func addItem(_ item: HistoryItem) {
        items.insert(item, at: 0)

        // Limit history size
        if items.count > maxHistoryItems {
            items = Array(items.prefix(maxHistoryItems))
        }

        saveHistory()
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
        saveHistory()
    }

    func removeItem(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearAll() {
        items.removeAll()
        saveHistory()
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

    // MARK: - Persistence
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else {
            items = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([StoredHistoryItem].self, from: data)
            items = decoded.map { $0.toHistoryItem() }
        } catch {
            print("Failed to load history: \(error)")
            items = []
        }
    }

    private func saveHistory() {
        do {
            let stored = items.map { StoredHistoryItem(from: $0) }
            let data = try JSONEncoder().encode(stored)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("Failed to save history: \(error)")
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
