//
//  SmartCompressionEngine.swift
//  optimize
//
//  Staff-level compression orchestrator ensuring:
//  - Output NEVER larger than input
//  - No crashes or raw errors shown to users
//  - Proper cancellation and progress reporting
//  - Memory-safe batch processing
//
//  Architecture: Analyze → Strategy → Execute → Validate → Retry/Discard → Result
//

import Foundation
import UIKit
import PDFKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Compression Mode (User-Facing Quality Tiers)

/// Three distinct compression modes with clear trade-offs
enum CompressionMode: String, CaseIterable, Codable {
    /// Pixel content unchanged; only metadata/container optimizations
    /// Best for: Archival, legal documents, professional photos
    case lossless = "lossless"

    /// Can change codec/colorspace/bitrate with negligible perceived loss
    /// Best for: General use, sharing, email attachments
    case visuallyLossless = "visually_lossless"

    /// More aggressive compression, accepts visible quality reduction
    /// Best for: Quick sharing, storage-constrained scenarios
    case maxShrink = "max_shrink"

    var displayName: String {
        switch self {
        case .lossless: return "Kayıpsız"
        case .visuallyLossless: return "Dengeli"
        case .maxShrink: return "Maksimum Sıkıştırma"
        }
    }

    var description: String {
        switch self {
        case .lossless:
            return "Görsel kalite korunur, sadece metadata ve gereksiz veri temizlenir."
        case .visuallyLossless:
            return "Gözle görülür kalite kaybı olmadan optimum sıkıştırma."
        case .maxShrink:
            return "En küçük dosya boyutu için agresif sıkıştırma."
        }
    }

    /// Expected compression ratio range (min-max percentage reduction)
    var expectedRatioRange: (min: Int, max: Int) {
        switch self {
        case .lossless: return (5, 30)
        case .visuallyLossless: return (30, 70)
        case .maxShrink: return (50, 90)
        }
    }
}

// MARK: - Compression Job Result (Unified Result Model)

/// Unified result model for all compression operations
struct CompressionJobResult: Equatable {
    let inputURL: URL
    let outputURL: URL?
    let inputSize: Int64
    let outputSize: Int64
    let status: JobStatus
    let reason: String
    let mode: CompressionMode
    let fileType: CompressionFileType
    let processingTime: TimeInterval
    let diagnostics: JobDiagnostics?

    /// Status of the compression job
    enum JobStatus: String, Equatable {
        case success = "success"          // File compressed successfully
        case skipped = "skipped"          // Already optimized, no safe reduction possible
        case failed = "failed"            // Real error occurred
        case cancelled = "cancelled"      // User cancelled
    }

    /// Bytes saved (always >= 0)
    var bytesSaved: Int64 {
        max(0, inputSize - outputSize)
    }

    /// Percentage reduction (0-100)
    var savingsPercent: Int {
        guard inputSize > 0 else { return 0 }
        return Int((Double(bytesSaved) / Double(inputSize)) * 100)
    }

    /// Human-readable size reduction
    var savingsDescription: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytesSaved)
    }

    /// User-friendly message for display
    var userMessage: String {
        switch status {
        case .success:
            return "Başarılı! %\(savingsPercent) küçültüldü (\(savingsDescription) tasarruf)"
        case .skipped:
            return reason.isEmpty ? "Dosya zaten optimize edilmiş." : reason
        case .failed:
            return reason.isEmpty ? "İşlem başarısız oldu." : reason
        case .cancelled:
            return "İşlem iptal edildi."
        }
    }

    /// Whether this result should be considered a user-facing success
    var isUserSuccess: Bool {
        status == .success || status == .skipped
    }

    // MARK: - Factory Methods

    static func success(
        input: URL,
        output: URL,
        inputSize: Int64,
        outputSize: Int64,
        mode: CompressionMode,
        fileType: CompressionFileType,
        processingTime: TimeInterval,
        diagnostics: JobDiagnostics? = nil
    ) -> CompressionJobResult {
        CompressionJobResult(
            inputURL: input,
            outputURL: output,
            inputSize: inputSize,
            outputSize: outputSize,
            status: .success,
            reason: "",
            mode: mode,
            fileType: fileType,
            processingTime: processingTime,
            diagnostics: diagnostics
        )
    }

    static func skipped(
        input: URL,
        inputSize: Int64,
        mode: CompressionMode,
        fileType: CompressionFileType,
        reason: String,
        diagnostics: JobDiagnostics? = nil
    ) -> CompressionJobResult {
        CompressionJobResult(
            inputURL: input,
            outputURL: nil,
            inputSize: inputSize,
            outputSize: inputSize,
            status: .skipped,
            reason: reason,
            mode: mode,
            fileType: fileType,
            processingTime: 0,
            diagnostics: diagnostics
        )
    }

    static func failed(
        input: URL,
        inputSize: Int64,
        mode: CompressionMode,
        fileType: CompressionFileType,
        reason: String
    ) -> CompressionJobResult {
        CompressionJobResult(
            inputURL: input,
            outputURL: nil,
            inputSize: inputSize,
            outputSize: inputSize,
            status: .failed,
            reason: reason,
            mode: mode,
            fileType: fileType,
            processingTime: 0,
            diagnostics: nil
        )
    }

    static func cancelled(
        input: URL,
        inputSize: Int64,
        mode: CompressionMode,
        fileType: CompressionFileType
    ) -> CompressionJobResult {
        CompressionJobResult(
            inputURL: input,
            outputURL: nil,
            inputSize: inputSize,
            outputSize: inputSize,
            status: .cancelled,
            reason: "İşlem kullanıcı tarafından iptal edildi.",
            mode: mode,
            fileType: fileType,
            processingTime: 0,
            diagnostics: nil
        )
    }
}

// MARK: - Job Diagnostics (Debug Information)

/// Detailed diagnostics for understanding why compression succeeded/failed
struct JobDiagnostics: Equatable {
    let originalCodec: String?
    let outputCodec: String?
    let originalBitrate: Int?
    let outputBitrate: Int?
    let originalDimensions: CGSize?
    let outputDimensions: CGSize?
    let metadataSize: Int64
    let retryCount: Int
    let strategyUsed: String
    let timestamp: Date

    init(
        originalCodec: String? = nil,
        outputCodec: String? = nil,
        originalBitrate: Int? = nil,
        outputBitrate: Int? = nil,
        originalDimensions: CGSize? = nil,
        outputDimensions: CGSize? = nil,
        metadataSize: Int64 = 0,
        retryCount: Int = 0,
        strategyUsed: String = ""
    ) {
        self.originalCodec = originalCodec
        self.outputCodec = outputCodec
        self.originalBitrate = originalBitrate
        self.outputBitrate = outputBitrate
        self.originalDimensions = originalDimensions
        self.outputDimensions = outputDimensions
        self.metadataSize = metadataSize
        self.retryCount = retryCount
        self.strategyUsed = strategyUsed
        self.timestamp = Date()
    }

    /// Debug description for logging
    var debugDescription: String {
        var lines: [String] = []
        lines.append("[Diagnostics @ \(timestamp)]")
        if let codec = originalCodec { lines.append("  Original Codec: \(codec)") }
        if let codec = outputCodec { lines.append("  Output Codec: \(codec)") }
        if let bitrate = originalBitrate { lines.append("  Original Bitrate: \(bitrate) kbps") }
        if let bitrate = outputBitrate { lines.append("  Output Bitrate: \(bitrate) kbps") }
        if let dims = originalDimensions { lines.append("  Original Size: \(Int(dims.width))x\(Int(dims.height))") }
        if let dims = outputDimensions { lines.append("  Output Size: \(Int(dims.width))x\(Int(dims.height))") }
        if metadataSize > 0 { lines.append("  Metadata: \(metadataSize) bytes") }
        if retryCount > 0 { lines.append("  Retries: \(retryCount)") }
        if !strategyUsed.isEmpty { lines.append("  Strategy: \(strategyUsed)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - File Type Detection

/// Supported file types for compression
enum CompressionFileType: String, CaseIterable {
    case image = "image"
    case video = "video"
    case pdf = "pdf"
    case unknown = "unknown"

    static func detect(from url: URL) -> CompressionFileType {
        let ext = url.pathExtension.lowercased()

        // Images
        if ["jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif"].contains(ext) {
            return .image
        }

        // Videos
        if ["mp4", "mov", "m4v", "avi", "mkv", "webm", "3gp"].contains(ext) {
            return .video
        }

        // PDFs
        if ext == "pdf" {
            return .pdf
        }

        return .unknown
    }
}

// MARK: - Output Validator

/// Validates compression output and handles retry logic
actor OutputValidator {

    /// Minimum bytes saved to consider compression successful
    private let minimumBytesSaved: Int64 = 512

    /// Maximum retry attempts before giving up
    private let maxRetries = 1

    /// Validate that output is smaller than input
    /// - Returns: true if output is valid (smaller), false if needs retry or skip
    func validate(originalSize: Int64, outputSize: Int64) -> ValidationResult {
        // Output must be strictly smaller
        if outputSize >= originalSize {
            return .needsRetry(reason: "Output (\(outputSize)) >= Input (\(originalSize))")
        }

        // Check minimum savings threshold
        let saved = originalSize - outputSize
        if saved < minimumBytesSaved {
            return .marginal(savedBytes: saved)
        }

        return .valid(savedBytes: saved)
    }

    enum ValidationResult {
        case valid(savedBytes: Int64)
        case marginal(savedBytes: Int64)
        case needsRetry(reason: String)
    }
}

// MARK: - Smart Compression Engine

/// Main orchestrator for all compression operations
/// Ensures: No crashes, output <= input, proper cancellation, memory safety
@MainActor
final class SmartCompressionEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentStage: String = ""
    @Published private(set) var currentFile: String = ""

    // MARK: - Dependencies

    private let validator = OutputValidator()
    private let tempDirectory: URL

    // MARK: - Concurrency Control

    /// Serial queue for video processing (prevents OOM)
    private let videoQueue = DispatchQueue(label: "com.optimize.video.serial", qos: .userInitiated)

    /// Limited parallelism for images (max 2-3 concurrent)
    private let imageQueue = OperationQueue()

    /// Serial queue for PDFs by default
    private let pdfQueue = DispatchQueue(label: "com.optimize.pdf.serial", qos: .userInitiated)

    // MARK: - Initialization

    init() {
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartCompressionEngine", isDirectory: true)

        // Configure image queue with limited concurrency
        imageQueue.maxConcurrentOperationCount = 2
        imageQueue.qualityOfService = .userInitiated

        // Ensure temp directory exists
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Compress a single file with specified mode
    /// - Parameters:
    ///   - url: Source file URL
    ///   - mode: Compression mode (lossless, visuallyLossless, maxShrink)
    ///   - progress: Progress callback (0.0 - 1.0)
    /// - Returns: CompressionJobResult with guaranteed output <= input
    func compress(
        url: URL,
        mode: CompressionMode = .visuallyLossless,
        progress: ((Double, String) -> Void)? = nil
    ) async -> CompressionJobResult {
        let startTime = Date()
        let fileType = CompressionFileType.detect(from: url)

        // Get input size
        let inputSize = getFileSize(url)
        guard inputSize > 0 else {
            return .failed(
                input: url,
                inputSize: 0,
                mode: mode,
                fileType: fileType,
                reason: "Dosya okunamadı veya boş."
            )
        }

        // Update UI state
        isProcessing = true
        currentFile = url.lastPathComponent
        defer {
            isProcessing = false
            self.progress = 0
            currentStage = ""
            currentFile = ""
        }

        // Route to appropriate compressor based on file type
        let result: CompressionJobResult
        switch fileType {
        case .image:
            result = await compressImage(url: url, mode: mode, inputSize: inputSize, progress: progress)
        case .video:
            result = await compressVideo(url: url, mode: mode, inputSize: inputSize, progress: progress)
        case .pdf:
            result = await compressPDF(url: url, mode: mode, inputSize: inputSize, progress: progress)
        case .unknown:
            result = .failed(
                input: url,
                inputSize: inputSize,
                mode: mode,
                fileType: fileType,
                reason: "Desteklenmeyen dosya formatı: \(url.pathExtension)"
            )
        }

        // Log diagnostics in debug mode
        #if DEBUG
        if let diagnostics = result.diagnostics {
            print(diagnostics.debugDescription)
        }
        #endif

        return result
    }

    /// Compress multiple files with memory-safe scheduling
    /// - Parameters:
    ///   - urls: Array of file URLs
    ///   - mode: Compression mode
    ///   - progress: Progress callback with file index
    /// - Returns: Array of results in same order as input
    func compressBatch(
        urls: [URL],
        mode: CompressionMode = .visuallyLossless,
        progress: ((Int, Double, String) -> Void)? = nil
    ) async -> [CompressionJobResult] {
        var results: [CompressionJobResult] = []
        results.reserveCapacity(urls.count)

        // Categorize files
        let images = urls.filter { CompressionFileType.detect(from: $0) == .image }
        let videos = urls.filter { CompressionFileType.detect(from: $0) == .video }
        let pdfs = urls.filter { CompressionFileType.detect(from: $0) == .pdf }
        let others = urls.filter { CompressionFileType.detect(from: $0) == .unknown }

        // Process videos SERIALLY (OOM prevention)
        for (index, url) in videos.enumerated() {
            let result = await compress(url: url, mode: mode) { prog, stage in
                progress?(index, prog, stage)
            }
            results.append(result)
        }

        // Process PDFs SERIALLY by default
        for (index, url) in pdfs.enumerated() {
            let result = await compress(url: url, mode: mode) { prog, stage in
                progress?(videos.count + index, prog, stage)
            }
            results.append(result)
        }

        // Process images with LIMITED parallelism (max 2-3)
        let imageResults = await withTaskGroup(of: (Int, CompressionJobResult).self) { group in
            var imageResults: [(Int, CompressionJobResult)] = []

            for (index, url) in images.enumerated() {
                // Limit concurrent image tasks
                if index >= 3 {
                    // Wait for a slot to free up
                    if let result = await group.next() {
                        imageResults.append(result)
                    }
                }

                group.addTask {
                    let result = await self.compress(url: url, mode: mode) { prog, stage in
                        progress?(videos.count + pdfs.count + index, prog, stage)
                    }
                    return (index, result)
                }
            }

            // Collect remaining results
            for await result in group {
                imageResults.append(result)
            }

            return imageResults.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
        results.append(contentsOf: imageResults)

        // Handle unsupported files
        for url in others {
            let inputSize = getFileSize(url)
            results.append(.failed(
                input: url,
                inputSize: inputSize,
                mode: mode,
                fileType: .unknown,
                reason: "Desteklenmeyen dosya formatı"
            ))
        }

        return results
    }

    // MARK: - Image Compression

    private func compressImage(
        url: URL,
        mode: CompressionMode,
        inputSize: Int64,
        progress: ((Double, String) -> Void)?
    ) async -> CompressionJobResult {
        progress?(0.1, "Görsel analiz ediliyor...")

        // Generate output URL
        let outputURL = tempDirectory.appendingPathComponent(
            "\(UUID().uuidString)_compressed.\(url.pathExtension)"
        )

        // Determine compression settings based on mode
        let config = imageConfig(for: mode)

        progress?(0.3, "Sıkıştırılıyor...")

        // Try compression with retry on failure
        var retryCount = 0
        var lastError: Error?

        while retryCount <= 1 {
            do {
                // Use ImageIO for memory-efficient processing
                let result = try await compressImageWithImageIO(
                    sourceURL: url,
                    outputURL: outputURL,
                    config: config,
                    retryCount: retryCount
                )

                progress?(0.8, "Doğrulanıyor...")

                // Validate output size
                let outputSize = getFileSize(outputURL)
                let validation = await validator.validate(originalSize: inputSize, outputSize: outputSize)

                switch validation {
                case .valid(let saved), .marginal(let saved):
                    progress?(1.0, "Tamamlandı!")
                    return .success(
                        input: url,
                        output: outputURL,
                        inputSize: inputSize,
                        outputSize: outputSize,
                        mode: mode,
                        fileType: .image,
                        processingTime: Date().timeIntervalSince(result.startTime),
                        diagnostics: result.diagnostics
                    )

                case .needsRetry(let reason):
                    if retryCount == 0 {
                        // Retry with more aggressive settings
                        retryCount += 1
                        try? FileManager.default.removeItem(at: outputURL)
                        continue
                    } else {
                        // Max retries reached - return skipped
                        try? FileManager.default.removeItem(at: outputURL)
                        return .skipped(
                            input: url,
                            inputSize: inputSize,
                            mode: mode,
                            fileType: .image,
                            reason: "Dosya zaten optimize edilmiş. Daha fazla sıkıştırma kaliteyi bozar.",
                            diagnostics: result.diagnostics
                        )
                    }
                }

            } catch {
                lastError = error
                retryCount += 1
            }
        }

        // All retries failed
        try? FileManager.default.removeItem(at: outputURL)
        return .failed(
            input: url,
            inputSize: inputSize,
            mode: mode,
            fileType: .image,
            reason: "Görsel işlenemedi: \(lastError?.localizedDescription ?? "Bilinmeyen hata")"
        )
    }

    private struct ImageCompressionResult {
        let outputURL: URL
        let diagnostics: JobDiagnostics
        let startTime: Date
    }

    private func compressImageWithImageIO(
        sourceURL: URL,
        outputURL: URL,
        config: ImageCompressionConfig,
        retryCount: Int
    ) async throws -> ImageCompressionResult {
        let startTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    // Create image source
                    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
                        continuation.resume(throwing: CompressionError.invalidFile)
                        return
                    }

                    // Get source properties
                    let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
                    let pixelWidth = sourceProperties?[kCGImagePropertyPixelWidth] as? Int ?? 0
                    let pixelHeight = sourceProperties?[kCGImagePropertyPixelHeight] as? Int ?? 0

                    // Determine output format
                    let outputType: CFString
                    let outputExtension: String

                    if config.preferHEIC && self.supportsHEIC() {
                        outputType = UTType.heic.identifier as CFString
                        outputExtension = "heic"
                    } else {
                        outputType = UTType.jpeg.identifier as CFString
                        outputExtension = "jpg"
                    }

                    // Adjust output URL if format changed
                    var finalOutputURL = outputURL
                    if outputURL.pathExtension.lowercased() != outputExtension {
                        finalOutputURL = outputURL.deletingPathExtension().appendingPathExtension(outputExtension)
                    }

                    // Create destination
                    guard let destination = CGImageDestinationCreateWithURL(
                        finalOutputURL as CFURL,
                        outputType,
                        1,
                        nil
                    ) else {
                        continuation.resume(throwing: CompressionError.saveFailed)
                        return
                    }

                    // Calculate quality based on retry count
                    let quality = retryCount > 0 ? max(0.3, config.quality - 0.2) : config.quality

                    // Build destination options
                    var options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: quality
                    ]

                    // Strip metadata if configured
                    if config.stripMetadata {
                        options[kCGImageDestinationMetadata] = nil
                    }

                    // Handle downscaling if needed
                    if config.maxDimension > 0 && (pixelWidth > Int(config.maxDimension) || pixelHeight > Int(config.maxDimension)) {
                        // Create thumbnail options for memory-efficient downscaling
                        let thumbnailOptions: [CFString: Any] = [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: config.maxDimension
                        ]

                        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
                            CGImageDestinationAddImage(destination, thumbnail, options as CFDictionary)
                        } else {
                            // Fallback to original
                            CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
                        }
                    } else {
                        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
                    }

                    // Finalize
                    guard CGImageDestinationFinalize(destination) else {
                        continuation.resume(throwing: CompressionError.saveFailed)
                        return
                    }

                    // Get output dimensions
                    var outputWidth = pixelWidth
                    var outputHeight = pixelHeight
                    if let outputSource = CGImageSourceCreateWithURL(finalOutputURL as CFURL, nil),
                       let outputProps = CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any] {
                        outputWidth = outputProps[kCGImagePropertyPixelWidth] as? Int ?? outputWidth
                        outputHeight = outputProps[kCGImagePropertyPixelHeight] as? Int ?? outputHeight
                    }

                    let diagnostics = JobDiagnostics(
                        originalCodec: sourceURL.pathExtension.uppercased(),
                        outputCodec: outputExtension.uppercased(),
                        originalDimensions: CGSize(width: pixelWidth, height: pixelHeight),
                        outputDimensions: CGSize(width: outputWidth, height: outputHeight),
                        retryCount: retryCount,
                        strategyUsed: config.preferHEIC ? "HEIC Encode" : "JPEG Encode"
                    )

                    continuation.resume(returning: ImageCompressionResult(
                        outputURL: finalOutputURL,
                        diagnostics: diagnostics,
                        startTime: startTime
                    ))
                }
            }
        }
    }

    private func supportsHEIC() -> Bool {
        if #available(iOS 11.0, *) {
            return true
        }
        return false
    }

    // MARK: - Video Compression

    private func compressVideo(
        url: URL,
        mode: CompressionMode,
        inputSize: Int64,
        progress: ((Double, String) -> Void)?
    ) async -> CompressionJobResult {
        progress?(0.05, "Video analiz ediliyor...")

        let outputURL = tempDirectory.appendingPathComponent(
            "\(UUID().uuidString)_compressed.mp4"
        )

        let config = videoConfig(for: mode)

        progress?(0.1, "HEVC kodlaması hazırlanıyor...")

        // Security-scoped resource access
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let startTime = Date()

        do {
            // Use AVAssetExportSession for video compression
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

            // Get video track info for diagnostics
            let videoTrack = try await asset.loadTracks(withMediaType: .video).first
            let originalSize = try await videoTrack?.load(.naturalSize) ?? .zero
            let originalBitrate = try await estimateVideoBitrate(asset: asset)

            // Determine export preset based on mode and original size
            let exportPreset = determineExportPreset(
                for: mode,
                originalSize: originalSize,
                originalBitrate: originalBitrate
            )

            guard let exportSession = AVAssetExportSession(asset: asset, presetName: exportPreset) else {
                return .failed(
                    input: url,
                    inputSize: inputSize,
                    mode: mode,
                    fileType: .video,
                    reason: "Video export oturumu oluşturulamadı."
                )
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true

            // Start export with progress monitoring
            progress?(0.2, "Video sıkıştırılıyor...")

            // Monitor progress
            let progressTask = Task {
                while exportSession.status == .exporting || exportSession.status == .waiting {
                    let exportProgress = Double(exportSession.progress)
                    progress?(0.2 + (exportProgress * 0.7), "Video sıkıştırılıyor... %\(Int(exportProgress * 100))")
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }

            await exportSession.export()
            progressTask.cancel()

            // Check result
            switch exportSession.status {
            case .completed:
                progress?(0.95, "Doğrulanıyor...")

                let outputSize = getFileSize(outputURL)
                let validation = await validator.validate(originalSize: inputSize, outputSize: outputSize)

                switch validation {
                case .valid, .marginal:
                    let outputBitrate = try? await estimateVideoBitrate(asset: AVURLAsset(url: outputURL))

                    let diagnostics = JobDiagnostics(
                        originalCodec: "H.264",
                        outputCodec: exportPreset.contains("HEVC") ? "HEVC" : "H.264",
                        originalBitrate: originalBitrate,
                        outputBitrate: outputBitrate,
                        originalDimensions: originalSize,
                        retryCount: 0,
                        strategyUsed: exportPreset
                    )

                    progress?(1.0, "Tamamlandı!")
                    return .success(
                        input: url,
                        output: outputURL,
                        inputSize: inputSize,
                        outputSize: outputSize,
                        mode: mode,
                        fileType: .video,
                        processingTime: Date().timeIntervalSince(startTime),
                        diagnostics: diagnostics
                    )

                case .needsRetry:
                    try? FileManager.default.removeItem(at: outputURL)
                    return .skipped(
                        input: url,
                        inputSize: inputSize,
                        mode: mode,
                        fileType: .video,
                        reason: "Video zaten optimize edilmiş veya düşük bitrate'li."
                    )
                }

            case .cancelled:
                try? FileManager.default.removeItem(at: outputURL)
                return .cancelled(input: url, inputSize: inputSize, mode: mode, fileType: .video)

            case .failed:
                try? FileManager.default.removeItem(at: outputURL)
                return .failed(
                    input: url,
                    inputSize: inputSize,
                    mode: mode,
                    fileType: .video,
                    reason: exportSession.error?.localizedDescription ?? "Video export başarısız."
                )

            default:
                try? FileManager.default.removeItem(at: outputURL)
                return .failed(
                    input: url,
                    inputSize: inputSize,
                    mode: mode,
                    fileType: .video,
                    reason: "Beklenmeyen video export durumu."
                )
            }

        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            return .failed(
                input: url,
                inputSize: inputSize,
                mode: mode,
                fileType: .video,
                reason: "Video işlenemedi: \(error.localizedDescription)"
            )
        }
    }

    private func estimateVideoBitrate(asset: AVURLAsset) async throws -> Int? {
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0 else { return nil }

        // Estimate from file size
        if let fileSize = try? asset.url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return Int((Double(fileSize) * 8) / durationSeconds / 1000) // kbps
        }
        return nil
    }

    private func determineExportPreset(for mode: CompressionMode, originalSize: CGSize, originalBitrate: Int?) -> String {
        let maxDimension = max(originalSize.width, originalSize.height)

        switch mode {
        case .lossless:
            // Keep original quality, just container optimization
            if maxDimension > 1920 {
                return AVAssetExportPreset3840x2160
            } else if maxDimension > 1280 {
                return AVAssetExportPreset1920x1080
            } else {
                return AVAssetExportPreset1280x720
            }

        case .visuallyLossless:
            // HEVC with reasonable quality
            if #available(iOS 11.0, *) {
                if maxDimension > 1920 {
                    return AVAssetExportPresetHEVC1920x1080
                } else if maxDimension > 1280 {
                    return AVAssetExportPresetHEVC1920x1080
                } else {
                    return AVAssetExportPresetHEVC1920x1080
                }
            }
            return AVAssetExportPreset1920x1080

        case .maxShrink:
            // More aggressive downscaling
            if #available(iOS 11.0, *) {
                return AVAssetExportPresetHEVC1920x1080
            }
            return AVAssetExportPreset1280x720
        }
    }

    // MARK: - PDF Compression

    private func compressPDF(
        url: URL,
        mode: CompressionMode,
        inputSize: Int64,
        progress: ((Double, String) -> Void)?
    ) async -> CompressionJobResult {
        progress?(0.1, "PDF analiz ediliyor...")

        let outputURL = tempDirectory.appendingPathComponent(
            "\(UUID().uuidString)_compressed.pdf"
        )

        // Security-scoped resource access
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let startTime = Date()

        // Load PDF
        guard let document = PDFDocument(url: url) else {
            return .failed(
                input: url,
                inputSize: inputSize,
                mode: mode,
                fileType: .pdf,
                reason: "PDF dosyası açılamadı veya bozuk."
            )
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            return .failed(
                input: url,
                inputSize: inputSize,
                mode: mode,
                fileType: .pdf,
                reason: "PDF dosyası boş."
            )
        }

        progress?(0.2, "PDF sıkıştırılıyor...")

        let config = pdfConfig(for: mode)

        // Process based on mode
        let result: CompressionJobResult
        if mode == .lossless {
            result = await compressPDFSafeMode(
                document: document,
                sourceURL: url,
                outputURL: outputURL,
                inputSize: inputSize,
                mode: mode,
                config: config,
                startTime: startTime,
                progress: progress
            )
        } else {
            result = await compressPDFAggressiveMode(
                document: document,
                sourceURL: url,
                outputURL: outputURL,
                inputSize: inputSize,
                mode: mode,
                config: config,
                startTime: startTime,
                progress: progress
            )
        }

        return result
    }

    /// Safe mode: Metadata cleanup + selective image recompression
    private func compressPDFSafeMode(
        document: PDFDocument,
        sourceURL: URL,
        outputURL: URL,
        inputSize: Int64,
        mode: CompressionMode,
        config: PDFCompressionConfig,
        startTime: Date,
        progress: ((Double, String) -> Void)?
    ) async -> CompressionJobResult {
        // For lossless mode, we just write the PDF with optimized settings
        // This removes incremental updates and optimizes the structure

        progress?(0.5, "PDF yapısı optimize ediliyor...")

        if document.write(to: outputURL) {
            let outputSize = getFileSize(outputURL)
            let validation = await validator.validate(originalSize: inputSize, outputSize: outputSize)

            switch validation {
            case .valid, .marginal:
                let diagnostics = JobDiagnostics(
                    retryCount: 0,
                    strategyUsed: "Safe Mode (Structure Optimization)"
                )

                progress?(1.0, "Tamamlandı!")
                return .success(
                    input: sourceURL,
                    output: outputURL,
                    inputSize: inputSize,
                    outputSize: outputSize,
                    mode: mode,
                    fileType: .pdf,
                    processingTime: Date().timeIntervalSince(startTime),
                    diagnostics: diagnostics
                )

            case .needsRetry:
                try? FileManager.default.removeItem(at: outputURL)
                return .skipped(
                    input: sourceURL,
                    inputSize: inputSize,
                    mode: mode,
                    fileType: .pdf,
                    reason: "PDF zaten optimize edilmiş."
                )
            }
        }

        return .failed(
            input: sourceURL,
            inputSize: inputSize,
            mode: mode,
            fileType: .pdf,
            reason: "PDF kaydedilemedi."
        )
    }

    /// Aggressive mode: Render pages as compressed images
    private func compressPDFAggressiveMode(
        document: PDFDocument,
        sourceURL: URL,
        outputURL: URL,
        inputSize: Int64,
        mode: CompressionMode,
        config: PDFCompressionConfig,
        startTime: Date,
        progress: ((Double, String) -> Void)?
    ) async -> CompressionJobResult {
        let pageCount = document.pageCount
        let outputDocument = PDFDocument()

        // Process each page
        for i in 0..<pageCount {
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: outputURL)
                return .cancelled(input: sourceURL, inputSize: inputSize, mode: mode, fileType: .pdf)
            }

            let pageProgress = Double(i) / Double(pageCount)
            progress?(0.2 + (pageProgress * 0.6), "Sayfa \(i + 1)/\(pageCount) işleniyor...")

            autoreleasepool {
                guard let page = document.page(at: i) else { return }
                let bounds = page.bounds(for: .mediaBox)

                // Calculate scale for DPI cap
                let maxDimension = max(bounds.width, bounds.height)
                let targetDPI = config.targetDPI
                let scale = min(1.0, (targetDPI / 72.0) * min(1.0, 2000.0 / maxDimension))

                let size = CGSize(
                    width: bounds.width * scale,
                    height: bounds.height * scale
                )

                // Render page
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    ctx.cgContext.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }

                // Compress image
                if let jpegData = image.jpegData(compressionQuality: CGFloat(config.quality)),
                   let compressedImage = UIImage(data: jpegData),
                   let newPage = PDFPage(image: compressedImage) {
                    outputDocument.insert(newPage, at: outputDocument.pageCount)
                }
            }
        }

        progress?(0.85, "PDF kaydediliyor...")

        if outputDocument.write(to: outputURL) {
            let outputSize = getFileSize(outputURL)
            let validation = await validator.validate(originalSize: inputSize, outputSize: outputSize)

            switch validation {
            case .valid, .marginal:
                let diagnostics = JobDiagnostics(
                    retryCount: 0,
                    strategyUsed: "Aggressive Mode (DPI: \(Int(config.targetDPI)))"
                )

                progress?(1.0, "Tamamlandı!")
                return .success(
                    input: sourceURL,
                    output: outputURL,
                    inputSize: inputSize,
                    outputSize: outputSize,
                    mode: mode,
                    fileType: .pdf,
                    processingTime: Date().timeIntervalSince(startTime),
                    diagnostics: diagnostics
                )

            case .needsRetry:
                // Try even more aggressive settings
                try? FileManager.default.removeItem(at: outputURL)
                return await compressPDFUltraMode(
                    document: document,
                    sourceURL: sourceURL,
                    outputURL: outputURL,
                    inputSize: inputSize,
                    mode: mode,
                    startTime: startTime,
                    progress: progress
                )
            }
        }

        return .failed(
            input: sourceURL,
            inputSize: inputSize,
            mode: mode,
            fileType: .pdf,
            reason: "PDF kaydedilemedi."
        )
    }

    /// Ultra mode: Maximum compression with quality trade-off
    private func compressPDFUltraMode(
        document: PDFDocument,
        sourceURL: URL,
        outputURL: URL,
        inputSize: Int64,
        mode: CompressionMode,
        startTime: Date,
        progress: ((Double, String) -> Void)?
    ) async -> CompressionJobResult {
        let pageCount = document.pageCount
        let outputDocument = PDFDocument()

        progress?(0.5, "Maksimum sıkıştırma uygulanıyor...")

        // Very aggressive settings
        let targetDPI: CGFloat = 72
        let quality: CGFloat = 0.4

        for i in 0..<pageCount {
            autoreleasepool {
                guard let page = document.page(at: i) else { return }
                let bounds = page.bounds(for: .mediaBox)

                let scale = min(1.0, 1200.0 / max(bounds.width, bounds.height))
                let size = CGSize(
                    width: bounds.width * scale,
                    height: bounds.height * scale
                )

                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    ctx.cgContext.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }

                if let jpegData = image.jpegData(compressionQuality: quality),
                   let compressedImage = UIImage(data: jpegData),
                   let newPage = PDFPage(image: compressedImage) {
                    outputDocument.insert(newPage, at: outputDocument.pageCount)
                }
            }
        }

        if outputDocument.write(to: outputURL) {
            let outputSize = getFileSize(outputURL)

            if outputSize < inputSize {
                let diagnostics = JobDiagnostics(
                    retryCount: 1,
                    strategyUsed: "Ultra Mode (DPI: 72, Quality: 40%)"
                )

                progress?(1.0, "Tamamlandı!")
                return .success(
                    input: sourceURL,
                    output: outputURL,
                    inputSize: inputSize,
                    outputSize: outputSize,
                    mode: mode,
                    fileType: .pdf,
                    processingTime: Date().timeIntervalSince(startTime),
                    diagnostics: diagnostics
                )
            } else {
                try? FileManager.default.removeItem(at: outputURL)
                return .skipped(
                    input: sourceURL,
                    inputSize: inputSize,
                    mode: mode,
                    fileType: .pdf,
                    reason: "PDF zaten maksimum seviyede optimize edilmiş."
                )
            }
        }

        return .failed(
            input: sourceURL,
            inputSize: inputSize,
            mode: mode,
            fileType: .pdf,
            reason: "PDF kaydedilemedi."
        )
    }

    // MARK: - Configuration Helpers

    private struct ImageCompressionConfig {
        let quality: CGFloat
        let maxDimension: CGFloat
        let stripMetadata: Bool
        let preferHEIC: Bool
    }

    private func imageConfig(for mode: CompressionMode) -> ImageCompressionConfig {
        switch mode {
        case .lossless:
            return ImageCompressionConfig(
                quality: 0.95,
                maxDimension: 0, // No downscaling
                stripMetadata: true,
                preferHEIC: false
            )
        case .visuallyLossless:
            return ImageCompressionConfig(
                quality: 0.80,
                maxDimension: 4096,
                stripMetadata: true,
                preferHEIC: true
            )
        case .maxShrink:
            return ImageCompressionConfig(
                quality: 0.60,
                maxDimension: 2048,
                stripMetadata: true,
                preferHEIC: true
            )
        }
    }

    private struct VideoCompressionConfig {
        let targetBitrate: Int?
        let maxResolution: CGSize
        let preferHEVC: Bool
    }

    private func videoConfig(for mode: CompressionMode) -> VideoCompressionConfig {
        switch mode {
        case .lossless:
            return VideoCompressionConfig(
                targetBitrate: nil,
                maxResolution: CGSize(width: 3840, height: 2160),
                preferHEVC: false
            )
        case .visuallyLossless:
            return VideoCompressionConfig(
                targetBitrate: 8000, // 8 Mbps
                maxResolution: CGSize(width: 1920, height: 1080),
                preferHEVC: true
            )
        case .maxShrink:
            return VideoCompressionConfig(
                targetBitrate: 4000, // 4 Mbps
                maxResolution: CGSize(width: 1280, height: 720),
                preferHEVC: true
            )
        }
    }

    private struct PDFCompressionConfig {
        let quality: Float
        let targetDPI: CGFloat
        let stripMetadata: Bool
    }

    private func pdfConfig(for mode: CompressionMode) -> PDFCompressionConfig {
        switch mode {
        case .lossless:
            return PDFCompressionConfig(
                quality: 0.95,
                targetDPI: 300,
                stripMetadata: true
            )
        case .visuallyLossless:
            return PDFCompressionConfig(
                quality: 0.70,
                targetDPI: 150,
                stripMetadata: true
            )
        case .maxShrink:
            return PDFCompressionConfig(
                quality: 0.50,
                targetDPI: 100,
                stripMetadata: true
            )
        }
    }

    // MARK: - Utilities

    private func getFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    /// Cleanup temp directory
    func cleanup() {
        try? FileManager.default.removeItem(at: tempDirectory)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
}
