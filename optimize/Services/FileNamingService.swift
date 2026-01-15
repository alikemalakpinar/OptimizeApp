//
//  FileNamingService.swift
//  optimize
//
//  User-friendly file naming system for compression outputs.
//
//  FEATURES:
//  - Multiple naming styles (optimized, timestamped, versioned)
//  - Special character sanitization
//  - Duplicate file handling
//  - Length limit enforcement (255 char max)
//

import Foundation

// MARK: - File Naming Service

enum FileNamingService {

    // MARK: - Naming Styles

    enum NamingStyle {
        case optimized          // Document_optimized.pdf
        case timestamped        // Document_2024-01-15_1430.pdf
        case versioned          // Document_v2.pdf
        case compact            // Document_opt.pdf (shorter suffix)
        case custom(String)     // Document_{custom}.pdf
    }

    // MARK: - Main API

    /// Generate user-friendly output filename
    /// - Parameters:
    ///   - originalURL: Source file URL
    ///   - style: Naming style to use
    ///   - destinationDirectory: Where file will be saved (for version checking)
    /// - Returns: Formatted filename string
    static func generateOutputName(
        from originalURL: URL,
        style: NamingStyle = .optimized,
        destinationDirectory: URL? = nil
    ) -> String {
        let baseName = sanitizeFileName(originalURL.deletingPathExtension().lastPathComponent)
        let ext = originalURL.pathExtension.lowercased()

        switch style {
        case .optimized:
            return "\(baseName)_optimized.\(ext.isEmpty ? "pdf" : ext)"

        case .timestamped:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HHmm"
            let timestamp = formatter.string(from: Date())
            return "\(baseName)_\(timestamp).\(ext.isEmpty ? "pdf" : ext)"

        case .versioned:
            let version = findNextVersion(
                baseName: baseName,
                ext: ext,
                in: destinationDirectory
            )
            return "\(baseName)_v\(version).\(ext.isEmpty ? "pdf" : ext)"

        case .compact:
            return "\(baseName)_opt.\(ext.isEmpty ? "pdf" : ext)"

        case .custom(let suffix):
            let safeSuffix = sanitizeFileName(suffix)
            return "\(baseName)_\(safeSuffix).\(ext.isEmpty ? "pdf" : ext)"
        }
    }

    /// Generate complete output URL in specified directory
    static func generateOutputURL(
        from originalURL: URL,
        style: NamingStyle = .optimized,
        in directory: URL? = nil
    ) -> URL {
        let destinationDir = directory ?? getDefaultOutputDirectory()
        let fileName = generateOutputName(from: originalURL, style: style, destinationDirectory: destinationDir)
        return destinationDir.appendingPathComponent(fileName)
    }

    // MARK: - Sanitization

    /// Remove dangerous/problematic characters from filename
    /// - Parameter name: Original filename
    /// - Returns: Sanitized filename safe for all platforms
    static func sanitizeFileName(_ name: String) -> String {
        // Characters that cause issues on iOS/macOS/Windows
        let illegalCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")

        var sanitized = name
            .components(separatedBy: illegalCharacters)
            .joined(separator: "_")

        // Remove leading/trailing whitespace and dots
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // Replace multiple consecutive underscores with single
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        // Enforce length limit (255 char filesystem limit, leave room for extension)
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
            // Don't cut off in middle of word if possible
            if let lastSpace = sanitized.lastIndex(of: "_") {
                sanitized = String(sanitized[..<lastSpace])
            }
        }

        // Ensure we have a valid name
        if sanitized.isEmpty {
            sanitized = "file_\(Date().timeIntervalSince1970)"
        }

        return sanitized
    }

    // MARK: - Version Finding

    /// Find the next available version number for a file
    private static func findNextVersion(baseName: String, ext: String, in directory: URL?) -> Int {
        let searchDir = directory ?? getDefaultOutputDirectory()

        var maxVersion = 0
        let pattern = "\(NSRegularExpression.escapedPattern(for: baseName))_v(\\d+)\\.\(ext)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return 1
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: searchDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for file in files {
                let fileName = file.lastPathComponent
                let range = NSRange(fileName.startIndex..., in: fileName)

                if let match = regex.firstMatch(in: fileName, options: [], range: range),
                   let versionRange = Range(match.range(at: 1), in: fileName),
                   let version = Int(fileName[versionRange]) {
                    maxVersion = max(maxVersion, version)
                }
            }
        } catch {
            // Directory doesn't exist or can't be read
        }

        return maxVersion + 1
    }

    // MARK: - Directory Helpers

    /// Get default output directory (Documents/Optimized)
    static func getDefaultOutputDirectory() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputDir = documentsURL.appendingPathComponent("Optimized", isDirectory: true)

        // Create if doesn't exist
        if !FileManager.default.fileExists(atPath: outputDir.path) {
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }

        return outputDir
    }

    /// Get temporary processing directory
    static func getTemporaryProcessingDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OptimizeApp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        return tempDir
    }

    // MARK: - Cleanup

    /// Clean up old temporary files
    static func cleanupTemporaryFiles(olderThan age: TimeInterval = 3600) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OptimizeApp", isDirectory: true)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoffDate = Date().addingTimeInterval(-age)

        for item in contents {
            guard let attributes = try? item.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = attributes.creationDate,
                  creationDate < cutoffDate else {
                continue
            }

            try? FileManager.default.removeItem(at: item)
        }
    }
}

// MARK: - Filename Display Formatting

extension FileNamingService {

    /// Format filename for display (truncate middle if too long)
    static func formatForDisplay(_ filename: String, maxLength: Int = 30) -> String {
        guard filename.count > maxLength else { return filename }

        let ext = (filename as NSString).pathExtension
        let name = (filename as NSString).deletingPathExtension

        let availableLength = maxLength - ext.count - 4 // "...".ext
        let prefixLength = availableLength / 2
        let suffixLength = availableLength - prefixLength

        let prefix = String(name.prefix(prefixLength))
        let suffix = String(name.suffix(suffixLength))

        return "\(prefix)...\(suffix).\(ext)"
    }

    /// Get human-readable file size string
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Calculate and format size reduction
    static func formatSizeReduction(original: Int64, compressed: Int64) -> String {
        guard original > 0 else { return "0%" }
        let reduction = Double(original - compressed) / Double(original) * 100
        return String(format: "%.0f%%", reduction)
    }
}
