//
//  DiskSpaceGuard.swift
//  optimize
//
//  Pre-operation disk space validation to prevent crashes and data corruption.
//  Checks available storage before compression operations.
//
//  CRITICAL: This prevents:
//  - Crash when disk is full during write operations
//  - Corrupt output files from incomplete writes
//  - Poor UX when user discovers failure after long processing
//

import Foundation

// MARK: - Disk Space Error

enum DiskSpaceError: LocalizedError {
    case insufficientSpace(required: Int64, available: Int64)
    case unableToCheckSpace
    case criticallyLow(available: Int64)

    var errorDescription: String? {
        switch self {
        case .insufficientSpace(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let requiredStr = formatter.string(fromByteCount: required)
            let availableStr = formatter.string(fromByteCount: available)
            return String(localized: "Yetersiz depolama alanı. Gereken: \(requiredStr), Mevcut: \(availableStr)")

        case .unableToCheckSpace:
            return String(localized: "Depolama alanı kontrol edilemedi.")

        case .criticallyLow(let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let availableStr = formatter.string(fromByteCount: available)
            return String(localized: "Depolama alanı kritik seviyede düşük: \(availableStr). Lütfen yer açın.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .insufficientSpace, .criticallyLow:
            return String(localized: "Ayarlar > Genel > iPhone Depolama Alanı'ndan gereksiz dosyaları silebilirsiniz.")
        case .unableToCheckSpace:
            return nil
        }
    }
}

// MARK: - Disk Space Result

struct DiskSpaceInfo {
    let totalCapacity: Int64
    let availableCapacity: Int64
    let availableCapacityForImportantUsage: Int64
    let availableCapacityForOpportunisticUsage: Int64

    var usedCapacity: Int64 {
        totalCapacity - availableCapacity
    }

    var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity) * 100
    }

    var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: availableCapacity, countStyle: .file)
    }

    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
    }

    /// True if storage is critically low (< 500MB)
    var isCriticallyLow: Bool {
        availableCapacity < 500_000_000 // 500 MB
    }

    /// True if storage is low (< 1GB)
    var isLow: Bool {
        availableCapacity < 1_000_000_000 // 1 GB
    }
}

// MARK: - Disk Space Guard

final class DiskSpaceGuard {

    /// Minimum required space buffer (100 MB) to ensure safe operation
    private static let minimumBufferSpace: Int64 = 100_000_000

    /// Critical threshold below which we warn the user (500 MB)
    private static let criticalThreshold: Int64 = 500_000_000

    // MARK: - Public API

    /// Get current disk space information
    /// - Returns: DiskSpaceInfo with all capacity details
    static func getCurrentDiskSpace() -> DiskSpaceInfo? {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())

        do {
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityForOpportunisticUsageKey
            ])

            return DiskSpaceInfo(
                totalCapacity: Int64(values.volumeTotalCapacity ?? 0),
                availableCapacity: Int64(values.volumeAvailableCapacity ?? 0),
                availableCapacityForImportantUsage: Int64(values.volumeAvailableCapacityForImportantUsage ?? 0),
                availableCapacityForOpportunisticUsage: Int64(values.volumeAvailableCapacityForOpportunisticUsage ?? 0)
            )
        } catch {
            #if DEBUG
            print("❌ [DiskSpaceGuard] Failed to get disk space: \(error)")
            #endif
            return nil
        }
    }

    /// Check if there's enough space for an operation
    /// - Parameters:
    ///   - requiredSpace: Estimated space needed for the operation
    ///   - safetyMultiplier: Multiplier for safety buffer (default 1.5x)
    /// - Throws: DiskSpaceError if insufficient space
    static func ensureSpace(
        for requiredSpace: Int64,
        safetyMultiplier: Double = 1.5
    ) throws {
        guard let diskInfo = getCurrentDiskSpace() else {
            throw DiskSpaceError.unableToCheckSpace
        }

        // Check for critically low space first
        if diskInfo.isCriticallyLow {
            throw DiskSpaceError.criticallyLow(available: diskInfo.availableCapacity)
        }

        // Calculate required space with safety buffer
        let safeRequiredSpace = Int64(Double(requiredSpace) * safetyMultiplier) + minimumBufferSpace

        // Use "important usage" capacity for more accurate check
        let availableForUse = diskInfo.availableCapacityForImportantUsage

        if availableForUse < safeRequiredSpace {
            throw DiskSpaceError.insufficientSpace(
                required: safeRequiredSpace,
                available: availableForUse
            )
        }

        #if DEBUG
        print("✅ [DiskSpaceGuard] Space check passed: \(diskInfo.formattedAvailable) available")
        #endif
    }

    /// Check space before file compression
    /// - Parameter inputFileSize: Size of input file in bytes
    /// - Throws: DiskSpaceError if insufficient space
    static func ensureSpaceForCompression(inputFileSize: Int64) throws {
        // For compression, we need roughly:
        // - 1x input size for temporary working copy
        // - Up to 1x for output (worst case, no compression)
        // Total: ~2x input + buffer
        let estimatedRequired = inputFileSize * 2
        try ensureSpace(for: estimatedRequired, safetyMultiplier: 1.2)
    }

    /// Check space before batch processing
    /// - Parameter totalInputSize: Combined size of all input files
    /// - Throws: DiskSpaceError if insufficient space
    static func ensureSpaceForBatch(totalInputSize: Int64) throws {
        // For batch, we process serially but keep outputs
        // Need space for all outputs + working space
        let estimatedRequired = totalInputSize * 2
        try ensureSpace(for: estimatedRequired, safetyMultiplier: 1.3)
    }

    /// Check if space is getting low (for warning, not blocking)
    /// - Returns: Warning message if space is low, nil otherwise
    static func checkForLowSpaceWarning() -> String? {
        guard let diskInfo = getCurrentDiskSpace() else { return nil }

        if diskInfo.isCriticallyLow {
            return String(localized: "Depolama alanı kritik seviyede düşük (\(diskInfo.formattedAvailable)). Sorunsuz işlem için yer açmanızı öneririz.")
        } else if diskInfo.isLow {
            return String(localized: "Depolama alanı azalıyor (\(diskInfo.formattedAvailable)). Büyük dosyalar için yeterli alan olmayabilir.")
        }

        return nil
    }
}

// MARK: - Convenience Extensions

extension DiskSpaceGuard {

    /// Quick check that returns a boolean (for UI state)
    static func hasEnoughSpace(for bytes: Int64) -> Bool {
        do {
            try ensureSpace(for: bytes)
            return true
        } catch {
            return false
        }
    }

    /// Get human-readable available space string
    static var availableSpaceFormatted: String {
        getCurrentDiskSpace()?.formattedAvailable ?? "—"
    }
}
