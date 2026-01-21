//
//  CompressionLogger.swift
//  optimize
//
//  Debug-only logging utility for diagnosing compression issues.
//  Helps understand why a file didn't shrink (codec, dimensions, metadata, bitrate).
//
//  USAGE:
//  - Only active in DEBUG builds
//  - Logs to console with [Compression] prefix
//  - Includes timing, file analysis, and strategy decisions
//

import Foundation
import os.log

// Note: There are two FileType enums in the optimize module:
// 1. Compression FileType (in SmartCompressionEngine.swift): .image, .video, .pdf, .unknown
//    - This one has a String raw value (conforms to RawRepresentable)
// 2. UI FileType (in FileCard.swift): .pdf, .image, .video, .document, .unknown
//    - This one has no raw value
// 
// To resolve the ambiguity, we use the specific FileType from SmartCompressionEngine
// by referencing it with its full context where needed.

// MARK: - Compression Logger

/// Debug-only logging for compression diagnostics
enum CompressionLogger {

    /// Log categories
    private static let subsystem = "com.optimize.compression"

    /// OSLog instances for structured logging
    private static let analysisLog = OSLog(subsystem: subsystem, category: "Analysis")
    private static let strategyLog = OSLog(subsystem: subsystem, category: "Strategy")
    private static let executionLog = OSLog(subsystem: subsystem, category: "Execution")
    private static let validationLog = OSLog(subsystem: subsystem, category: "Validation")

    // MARK: - Analysis Logging

    /// Log file analysis results
    static func logAnalysis<T: RawRepresentable>(
        url: URL,
        fileType: T,
        size: Int64,
        metadata: [String: Any]? = nil
    ) where T.RawValue == String {
        #if DEBUG
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        os_log(
            "[Analysis] File: %{public}@ | Type: %{public}@ | Size: %{public}@",
            log: analysisLog,
            type: .debug,
            url.lastPathComponent,
            fileType.rawValue,
            sizeFormatted
        )

        if let metadata = metadata {
            for (key, value) in metadata.prefix(10) {
                os_log(
                    "[Analysis]   %{public}@: %{public}@",
                    log: analysisLog,
                    type: .debug,
                    key,
                    String(describing: value)
                )
            }
        }
        #endif
    }

    /// Log image-specific analysis
    static func logImageAnalysis(
        url: URL,
        dimensions: CGSize,
        colorSpace: String?,
        hasAlpha: Bool,
        originalCodec: String?
    ) {
        #if DEBUG
        os_log(
            "[Image] %{public}@ | %dx%d | ColorSpace: %{public}@ | Alpha: %{public}@ | Codec: %{public}@",
            log: analysisLog,
            type: .debug,
            url.lastPathComponent,
            Int(dimensions.width),
            Int(dimensions.height),
            colorSpace ?? "Unknown",
            hasAlpha ? "Yes" : "No",
            originalCodec ?? "Unknown"
        )
        #endif
    }

    /// Log video-specific analysis
    static func logVideoAnalysis(
        url: URL,
        duration: TimeInterval,
        resolution: CGSize,
        bitrate: Int?,
        codec: String?,
        frameRate: Float?
    ) {
        #if DEBUG
        os_log(
            "[Video] %{public}@ | %.1fs | %dx%d | %d kbps | %{public}@ | %.1f fps",
            log: analysisLog,
            type: .debug,
            url.lastPathComponent,
            duration,
            Int(resolution.width),
            Int(resolution.height),
            bitrate ?? 0,
            codec ?? "Unknown",
            frameRate ?? 0
        )
        #endif
    }

    /// Log PDF-specific analysis
    static func logPDFAnalysis(
        url: URL,
        pageCount: Int,
        hasText: Bool,
        hasImages: Bool,
        isScanned: Bool
    ) {
        #if DEBUG
        os_log(
            "[PDF] %{public}@ | %d pages | Text: %{public}@ | Images: %{public}@ | Scanned: %{public}@",
            log: analysisLog,
            type: .debug,
            url.lastPathComponent,
            pageCount,
            hasText ? "Yes" : "No",
            hasImages ? "Yes" : "No",
            isScanned ? "Yes" : "No"
        )
        #endif
    }

    // MARK: - Strategy Logging

    /// Log compression strategy decision
    static func logStrategy<M: RawRepresentable, F: RawRepresentable>(
        mode: M,
        fileType: F,
        strategy: String,
        reason: String
    ) where M.RawValue == String, F.RawValue == String {
        #if DEBUG
        os_log(
            "[Strategy] Mode: %{public}@ | Type: %{public}@ | Strategy: %{public}@ | Reason: %{public}@",
            log: strategyLog,
            type: .info,
            mode.rawValue,
            fileType.rawValue,
            strategy,
            reason
        )
        #endif
    }

    /// Log retry decision
    static func logRetry(
        attempt: Int,
        previousSize: Int64,
        targetSize: Int64,
        newStrategy: String
    ) {
        #if DEBUG
        os_log(
            "[Retry] Attempt #%d | Previous: %lld bytes | Target: <%lld bytes | New Strategy: %{public}@",
            log: strategyLog,
            type: .info,
            attempt,
            previousSize,
            targetSize,
            newStrategy
        )
        #endif
    }

    // MARK: - Execution Logging

    /// Log compression start
    static func logStart<M: RawRepresentable>(url: URL, mode: M) where M.RawValue == String {
        #if DEBUG
        os_log(
            "[Start] %{public}@ | Mode: %{public}@",
            log: executionLog,
            type: .info,
            url.lastPathComponent,
            mode.rawValue
        )
        #endif
    }

    /// Log compression progress
    static func logProgress(url: URL, progress: Double, stage: String) {
        #if DEBUG
        os_log(
            "[Progress] %{public}@ | %.0f%% | %{public}@",
            log: executionLog,
            type: .debug,
            url.lastPathComponent,
            progress * 100,
            stage
        )
        #endif
    }

    /// Log compression completion
    static func logComplete(
        url: URL,
        inputSize: Int64,
        outputSize: Int64,
        duration: TimeInterval,
        strategy: String
    ) {
        #if DEBUG
        let savings = inputSize - outputSize
        let savingsPercent = inputSize > 0 ? Double(savings) / Double(inputSize) * 100 : 0
        let inputFormatted = ByteCountFormatter.string(fromByteCount: inputSize, countStyle: .file)
        let outputFormatted = ByteCountFormatter.string(fromByteCount: outputSize, countStyle: .file)

        os_log(
            "[Complete] %{public}@ | %{public}@ → %{public}@ (%.1f%% saved) | %.2fs | Strategy: %{public}@",
            log: executionLog,
            type: .info,
            url.lastPathComponent,
            inputFormatted,
            outputFormatted,
            savingsPercent,
            duration,
            strategy
        )
        #endif
    }

    /// Log compression error
    static func logError(url: URL, error: Error) {
        #if DEBUG
        os_log(
            "[Error] %{public}@ | %{public}@",
            log: executionLog,
            type: .error,
            url.lastPathComponent,
            error.localizedDescription
        )
        #endif
    }

    // MARK: - Validation Logging

    /// Log validation result
    static func logValidation(
        inputSize: Int64,
        outputSize: Int64,
        result: String,
        willRetry: Bool
    ) {
        #if DEBUG
        let inputFormatted = ByteCountFormatter.string(fromByteCount: inputSize, countStyle: .file)
        let outputFormatted = ByteCountFormatter.string(fromByteCount: outputSize, countStyle: .file)

        os_log(
            "[Validation] Input: %{public}@ | Output: %{public}@ | Result: %{public}@ | Retry: %{public}@",
            log: validationLog,
            type: .info,
            inputFormatted,
            outputFormatted,
            result,
            willRetry ? "Yes" : "No"
        )
        #endif
    }

    /// Log skip reason (when file cannot be reduced further)
    static func logSkip(url: URL, reason: String, diagnostics: [String: Any]? = nil) {
        #if DEBUG
        os_log(
            "[Skip] %{public}@ | Reason: %{public}@",
            log: validationLog,
            type: .info,
            url.lastPathComponent,
            reason
        )

        if let diagnostics = diagnostics {
            for (key, value) in diagnostics.prefix(5) {
                os_log(
                    "[Skip]   %{public}@: %{public}@",
                    log: validationLog,
                    type: .debug,
                    key,
                    String(describing: value)
                )
            }
        }
        #endif
    }

    // MARK: - Batch Logging

    /// Log batch processing start
    static func logBatchStart(fileCount: Int, videoCount: Int, pdfCount: Int, imageCount: Int) {
        #if DEBUG
        os_log(
            "[Batch] Starting | Total: %d | Videos: %d (serial) | PDFs: %d (serial) | Images: %d (parallel)",
            log: executionLog,
            type: .info,
            fileCount,
            videoCount,
            pdfCount,
            imageCount
        )
        #endif
    }

    /// Log batch processing complete
    static func logBatchComplete(
        total: Int,
        succeeded: Int,
        skipped: Int,
        failed: Int,
        totalSaved: Int64,
        duration: TimeInterval
    ) {
        #if DEBUG
        let savedFormatted = ByteCountFormatter.string(fromByteCount: totalSaved, countStyle: .file)

        os_log(
            "[Batch] Complete | Total: %d | Success: %d | Skipped: %d | Failed: %d | Saved: %{public}@ | Duration: %.1fs",
            log: executionLog,
            type: .info,
            total,
            succeeded,
            skipped,
            failed,
            savedFormatted,
            duration
        )
        #endif
    }

    // MARK: - Memory Logging

    /// Log memory usage (for debugging OOM issues)
    static func logMemory(context: String) {
        #if DEBUG
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / (1024 * 1024)
            os_log(
                "[Memory] %{public}@ | Used: %.1f MB",
                log: executionLog,
                type: .debug,
                context,
                usedMB
            )
        }
        #endif
    }
}

// MARK: - Debug Print Extension

extension CompressionJobResult {

    /// Print detailed debug information
    func debugPrint() {
        #if DEBUG
        print("""
        ╔══════════════════════════════════════════╗
        ║ CompressionJobResult                     ║
        ╠══════════════════════════════════════════╣
        ║ File: \(inputURL.lastPathComponent)
        ║ Type: \(fileType.rawValue)
        ║ Mode: \(mode.rawValue)
        ║ Status: \(status.rawValue)
        ║ Input: \(ByteCountFormatter.string(fromByteCount: inputSize, countStyle: .file))
        ║ Output: \(ByteCountFormatter.string(fromByteCount: outputSize, countStyle: .file))
        ║ Saved: \(savingsPercent)% (\(savingsDescription))
        ║ Time: \(String(format: "%.2f", processingTime))s
        ║ Reason: \(reason.isEmpty ? "-" : reason)
        ╚══════════════════════════════════════════╝
        """)

        if let diagnostics = diagnostics {
            print(diagnostics.debugDescription)
        }
        #endif
    }
}
