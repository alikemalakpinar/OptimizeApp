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

    private init() {
        loadHistory()
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
