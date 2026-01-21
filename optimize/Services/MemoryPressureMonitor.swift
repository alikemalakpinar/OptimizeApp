//
//  MemoryPressureMonitor.swift
//  optimize
//
//  Monitors system memory pressure to prevent OOM crashes.
//  Especially important for video compression which can be memory-intensive.
//
//  CRITICAL:
//  - Video files can't be loaded entirely into RAM
//  - Large PDFs need streaming processing
//  - Batch operations need serial processing
//
//  This monitor helps decide when to:
//  - Flush caches
//  - Pause batch processing
//  - Warn user about memory constraints
//

import Foundation
import os.log
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Memory Pressure Level

enum MemoryPressureLevel: Int, Comparable {
    case normal = 0
    case warning = 1
    case critical = 2
    case terminal = 3 // App will be killed soon

    static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Uyarı"
        case .critical: return "Kritik"
        case .terminal: return "Tehlikeli"
        }
    }

    var shouldPauseBatchProcessing: Bool {
        self >= .warning
    }

    var shouldFlushCaches: Bool {
        self >= .warning
    }

    var shouldStopNewOperations: Bool {
        self >= .critical
    }
}

// MARK: - Memory Info

struct MemoryInfo {
    let usedMemory: UInt64
    let freeMemory: UInt64
    let totalMemory: UInt64
    let pressure: MemoryPressureLevel

    var usedPercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100
    }

    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
    }

    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeMemory), countStyle: .memory)
    }

    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }
}

// MARK: - Memory Pressure Monitor

@MainActor
final class MemoryPressureMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = MemoryPressureMonitor()

    // MARK: - Published State

    @Published private(set) var currentPressure: MemoryPressureLevel = .normal
    @Published private(set) var memoryInfo: MemoryInfo?

    // MARK: - Callbacks

    var onMemoryWarning: (() -> Void)?
    var onCriticalMemory: (() -> Void)?

    // MARK: - Private

    private var pressureSource: DispatchSourceMemoryPressure?
    private var updateTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupMemoryPressureMonitoring()
        setupPeriodicUpdates()
        updateMemoryInfo()
    }

    deinit {
        pressureSource?.cancel()
        updateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupMemoryPressureMonitoring() {
        // Monitor system memory pressure events
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        pressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }

            let event = self.pressureSource?.data ?? []

            Task { @MainActor in
                if event.contains(.critical) {
                    self.currentPressure = .critical
                    self.onCriticalMemory?()
                    self.handleCriticalMemory()
                } else if event.contains(.warning) {
                    self.currentPressure = .warning
                    self.onMemoryWarning?()
                    self.handleMemoryWarning()
                }

                self.updateMemoryInfo()
            }
        }

        pressureSource?.resume()

        // Also listen to memory warnings
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUIKitMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }

    private func setupPeriodicUpdates() {
        // Update memory info every 5 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryInfo()
            }
        }
    }

    @objc private func handleUIKitMemoryWarning() {
        Task { @MainActor in
            currentPressure = .warning
            onMemoryWarning?()
            handleMemoryWarning()
            updateMemoryInfo()
        }
    }

    // MARK: - Memory Info

    private func updateMemoryInfo() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let totalMemory = ProcessInfo.processInfo.physicalMemory

        if result == KERN_SUCCESS {
            let usedMemory = UInt64(info.resident_size)
            let freeMemory = totalMemory > usedMemory ? totalMemory - usedMemory : 0

            // Determine pressure level based on usage
            let usedPercent = Double(usedMemory) / Double(totalMemory)
            let pressure: MemoryPressureLevel
            if usedPercent > 0.9 {
                pressure = .terminal
            } else if usedPercent > 0.8 {
                pressure = .critical
            } else if usedPercent > 0.7 {
                pressure = .warning
            } else {
                pressure = .normal
            }

            // Only update to normal if system hasn't signaled pressure
            if pressure < currentPressure && currentPressure != .normal {
                // Wait for system to clear pressure
            } else {
                currentPressure = pressure
            }

            memoryInfo = MemoryInfo(
                usedMemory: usedMemory,
                freeMemory: freeMemory,
                totalMemory: totalMemory,
                pressure: pressure
            )
        }
    }

    // MARK: - Handlers

    private func handleMemoryWarning() {
        #if DEBUG
        print("⚠️ [Memory] Warning - flushing caches")
        #endif

        // Flush thumbnail cache (async)
        Task {
            await ThumbnailCacheService.shared.clearCache()
        }

        // Request temp file cleanup (runs synchronously but off main thread internally if needed)
        TempFileCleanupService.shared.cleanupAllTempFiles()
    }

    private func handleCriticalMemory() {
        #if DEBUG
        print("🚨 [Memory] CRITICAL - aggressive cleanup")
        #endif

        // More aggressive cleanup
        URLCache.shared.removeAllCachedResponses()

        // Also clear thumbnail cache
        Task {
            await ThumbnailCacheService.shared.clearCache()
        }
    }

    // MARK: - Public API

    /// Check if it's safe to start a memory-intensive operation
    func canStartMemoryIntensiveOperation() -> Bool {
        updateMemoryInfo()
        return currentPressure < .critical
    }

    /// Get warning message if memory is constrained
    var warningMessage: String? {
        guard currentPressure >= .warning else { return nil }

        switch currentPressure {
        case .warning:
            return String(localized: "Cihaz belleği azalıyor. Büyük dosyalar yavaş işlenebilir.")
        case .critical, .terminal:
            return String(localized: "Bellek kritik seviyede düşük. Lütfen bazı uygulamaları kapatın.")
        case .normal:
            return nil
        }
    }

    /// Suggest maximum file size for current memory conditions
    var suggestedMaxFileSize: Int64 {
        guard let info = memoryInfo else {
            return 100_000_000 // 100 MB default
        }

        // Suggest file size as fraction of free memory
        // Leave room for processing overhead
        let safeSize = Int64(info.freeMemory) / 4

        // Cap at reasonable maximum
        return min(safeSize, 500_000_000) // 500 MB max
    }
}

// MARK: - Convenience for Batch Processing

extension MemoryPressureMonitor {

    /// Called between batch items to check if we should continue
    func shouldContinueBatchProcessing() -> Bool {
        updateMemoryInfo()
        return !currentPressure.shouldPauseBatchProcessing
    }

    /// Wait for memory pressure to ease
    func waitForMemoryRelief(timeout: TimeInterval = 30) async -> Bool {
        let startTime = Date()

        while currentPressure.shouldPauseBatchProcessing {
            if Date().timeIntervalSince(startTime) > timeout {
                return false
            }

            // Clear caches
            handleMemoryWarning()

            // Wait and check again
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            updateMemoryInfo()
        }

        return true
    }
}
