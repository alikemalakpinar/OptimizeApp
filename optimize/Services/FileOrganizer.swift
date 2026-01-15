//
//  FileOrganizer.swift
//  optimize
//
//  Internal file management system for organizing compressed files.
//  Provides folder creation, file organization, and quick access features.
//
//  FEATURES:
//  - Custom folder creation and management
//  - Automatic file categorization (PDF, Images, Videos)
//  - Recent files quick access
//  - Favorites system
//  - Storage analytics
//

import Foundation
import UIKit

// MARK: - File Category

enum FileCategory: String, CaseIterable, Identifiable, Codable {
    case pdf = "PDF"
    case image = "Görseller"
    case video = "Videolar"
    case document = "Belgeler"
    case other = "Diğer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .document: return "doc.text.fill"
        case .other: return "folder.fill"
        }
    }

    var color: String {
        switch self {
        case .pdf: return "red"
        case .image: return "green"
        case .video: return "purple"
        case .document: return "blue"
        case .other: return "gray"
        }
    }

    static func category(for url: URL) -> FileCategory {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff":
            return .image
        case "mp4", "mov", "m4v", "avi", "mkv", "webm":
            return .video
        case "doc", "docx", "txt", "rtf", "pages":
            return .document
        default:
            return .other
        }
    }
}

// MARK: - Organized File

struct OrganizedFile: Identifiable, Codable {
    let id: UUID
    let originalName: String
    let compressedName: String
    let originalURL: URL
    let compressedURL: URL
    let category: FileCategory
    let originalSize: Int64
    let compressedSize: Int64
    let compressionDate: Date
    var isFavorite: Bool
    var folderID: UUID?
    var tags: [String]

    init(
        originalName: String,
        compressedName: String,
        originalURL: URL,
        compressedURL: URL,
        originalSize: Int64,
        compressedSize: Int64
    ) {
        self.id = UUID()
        self.originalName = originalName
        self.compressedName = compressedName
        self.originalURL = originalURL
        self.compressedURL = compressedURL
        self.category = FileCategory.category(for: originalURL)
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.compressionDate = Date()
        self.isFavorite = false
        self.folderID = nil
        self.tags = []
    }

    var savedBytes: Int64 {
        originalSize - compressedSize
    }

    var savedPercentage: Int {
        guard originalSize > 0 else { return 0 }
        return Int(Double(savedBytes) / Double(originalSize) * 100)
    }

    var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    var formattedSavedBytes: String {
        ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
    }
}

// MARK: - File Folder

struct FileFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    let createdDate: Date
    var fileIDs: [UUID]

    init(name: String, icon: String = "folder.fill", color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.createdDate = Date()
        self.fileIDs = []
    }

    var fileCount: Int { fileIDs.count }
}

// MARK: - Storage Stats

struct StorageStats {
    let totalOriginalSize: Int64
    let totalCompressedSize: Int64
    let totalSavedBytes: Int64
    let fileCount: Int
    let categoryBreakdown: [FileCategory: Int]

    var savedPercentage: Int {
        guard totalOriginalSize > 0 else { return 0 }
        return Int(Double(totalSavedBytes) / Double(totalOriginalSize) * 100)
    }

    var formattedTotalSaved: String {
        ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file)
    }

    /// Convert to relatable units
    var equivalentPhotos: Int {
        // Average photo ~3MB
        Int(totalSavedBytes / (3 * 1024 * 1024))
    }

    var equivalentSongs: Int {
        // Average song ~4MB
        Int(totalSavedBytes / (4 * 1024 * 1024))
    }

    var equivalentVideos: Int {
        // Average 1-min video ~10MB
        Int(totalSavedBytes / (10 * 1024 * 1024))
    }
}

// MARK: - File Organizer

actor FileOrganizer {

    // MARK: - Storage

    private var files: [OrganizedFile] = []
    private var folders: [FileFolder] = []

    private let userDefaults = UserDefaults.standard
    private let filesKey = "organized_files"
    private let foldersKey = "organized_folders"

    // MARK: - Initialization

    init() {
        Task {
            await loadData()
        }
    }

    // MARK: - File Management

    /// Add a new compressed file
    func addFile(_ file: OrganizedFile) {
        files.append(file)
        saveData()
    }

    /// Get all files
    func getAllFiles() -> [OrganizedFile] {
        files.sorted { $0.compressionDate > $1.compressionDate }
    }

    /// Get files by category
    func getFiles(category: FileCategory) -> [OrganizedFile] {
        files.filter { $0.category == category }
            .sorted { $0.compressionDate > $1.compressionDate }
    }

    /// Get files in folder
    func getFiles(in folderID: UUID) -> [OrganizedFile] {
        files.filter { $0.folderID == folderID }
            .sorted { $0.compressionDate > $1.compressionDate }
    }

    /// Get favorite files
    func getFavorites() -> [OrganizedFile] {
        files.filter { $0.isFavorite }
            .sorted { $0.compressionDate > $1.compressionDate }
    }

    /// Get recent files
    func getRecentFiles(limit: Int = 10) -> [OrganizedFile] {
        Array(files.sorted { $0.compressionDate > $1.compressionDate }.prefix(limit))
    }

    /// Toggle favorite
    func toggleFavorite(fileID: UUID) {
        if let index = files.firstIndex(where: { $0.id == fileID }) {
            files[index].isFavorite.toggle()
            saveData()
        }
    }

    /// Move file to folder
    func moveToFolder(fileID: UUID, folderID: UUID?) {
        if let index = files.firstIndex(where: { $0.id == fileID }) {
            files[index].folderID = folderID
            saveData()
        }
    }

    /// Delete file
    func deleteFile(fileID: UUID) {
        files.removeAll { $0.id == fileID }
        saveData()
    }

    /// Add tags to file
    func addTags(fileID: UUID, tags: [String]) {
        if let index = files.firstIndex(where: { $0.id == fileID }) {
            files[index].tags.append(contentsOf: tags)
            saveData()
        }
    }

    // MARK: - Folder Management

    /// Create new folder
    func createFolder(name: String, icon: String = "folder.fill", color: String = "blue") -> FileFolder {
        let folder = FileFolder(name: name, icon: icon, color: color)
        folders.append(folder)
        saveData()
        return folder
    }

    /// Get all folders
    func getAllFolders() -> [FileFolder] {
        folders.sorted { $0.createdDate > $1.createdDate }
    }

    /// Rename folder
    func renameFolder(folderID: UUID, newName: String) {
        if let index = folders.firstIndex(where: { $0.id == folderID }) {
            folders[index].name = newName
            saveData()
        }
    }

    /// Delete folder (files move to uncategorized)
    func deleteFolder(folderID: UUID) {
        // Move files out of folder
        for i in files.indices {
            if files[i].folderID == folderID {
                files[i].folderID = nil
            }
        }
        folders.removeAll { $0.id == folderID }
        saveData()
    }

    // MARK: - Statistics

    /// Get storage statistics
    func getStats() -> StorageStats {
        let totalOriginal = files.reduce(0) { $0 + $1.originalSize }
        let totalCompressed = files.reduce(0) { $0 + $1.compressedSize }

        var categoryBreakdown: [FileCategory: Int] = [:]
        for category in FileCategory.allCases {
            categoryBreakdown[category] = files.filter { $0.category == category }.count
        }

        return StorageStats(
            totalOriginalSize: totalOriginal,
            totalCompressedSize: totalCompressed,
            totalSavedBytes: totalOriginal - totalCompressed,
            fileCount: files.count,
            categoryBreakdown: categoryBreakdown
        )
    }

    /// Get motivational message based on savings
    func getMotivationalMessage() -> String {
        let stats = getStats()

        if stats.equivalentPhotos > 0 {
            return "🎉 \(stats.formattedTotalSaved) tasarruf! Bu \(stats.equivalentPhotos) fotoğraf daha çekebileceğin anlamına geliyor."
        } else if stats.equivalentSongs > 0 {
            return "🎵 \(stats.formattedTotalSaved) kazandın! \(stats.equivalentSongs) şarkı daha indirebilirsin."
        } else if stats.totalSavedBytes > 0 {
            return "✨ Şimdiye kadar \(stats.formattedTotalSaved) tasarruf ettin!"
        } else {
            return "İlk dosyanı sıkıştırarak başla!"
        }
    }

    // MARK: - Search

    /// Search files by name or tags
    func search(query: String) -> [OrganizedFile] {
        let lowercasedQuery = query.lowercased()
        return files.filter {
            $0.originalName.lowercased().contains(lowercasedQuery) ||
            $0.compressedName.lowercased().contains(lowercasedQuery) ||
            $0.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    // MARK: - Persistence

    private func saveData() {
        if let filesData = try? JSONEncoder().encode(files) {
            userDefaults.set(filesData, forKey: filesKey)
        }
        if let foldersData = try? JSONEncoder().encode(folders) {
            userDefaults.set(foldersData, forKey: foldersKey)
        }
    }

    private func loadData() {
        if let filesData = userDefaults.data(forKey: filesKey),
           let loadedFiles = try? JSONDecoder().decode([OrganizedFile].self, from: filesData) {
            files = loadedFiles
        }
        if let foldersData = userDefaults.data(forKey: foldersKey),
           let loadedFolders = try? JSONDecoder().decode([FileFolder].self, from: foldersData) {
            folders = loadedFolders
        }
    }

    /// Clear all data
    func clearAll() {
        files = []
        folders = []
        userDefaults.removeObject(forKey: filesKey)
        userDefaults.removeObject(forKey: foldersKey)
    }
}

// MARK: - Drag & Drop Support

extension OrganizedFile {
    /// Create drag item for file
    var dragItem: NSItemProvider {
        NSItemProvider(object: compressedURL as NSURL)
    }
}
