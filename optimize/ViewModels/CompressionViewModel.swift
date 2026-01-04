//
//  CompressionViewModel.swift
//  optimize
//
//  MVVM-C Architecture: ViewModel for compression operations
//  Extracted from AppCoordinator to reduce God Object anti-pattern
//
//  This ViewModel handles:
//  - Compression state management
//  - Progress tracking
//  - Retry logic
//  - Error handling for compression operations
//
//  The Coordinator only handles navigation, this handles business logic.
//

import Foundation
import Combine

// MARK: - Compression Status

enum CompressionStatus: Equatable {
    case idle
    case preparing
    case compressing(progress: Double, stage: ProcessingStage)
    case success(CompressionResult)
    case failed(CompressionError)
    case cancelled

    static func == (lhs: CompressionStatus, rhs: CompressionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.cancelled, .cancelled):
            return true
        case (.compressing(let lProg, let lStage), .compressing(let rProg, let rStage)):
            return lProg == rProg && lStage == rStage
        case (.success(let l), .success(let r)):
            return l.id == r.id
        case (.failed(let l), .failed(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Compression ViewModel Protocol

@MainActor
protocol CompressionViewModelProtocol: ObservableObject {
    var status: CompressionStatus { get }
    var progress: Double { get }
    var currentStage: ProcessingStage { get }
    var canRetry: Bool { get }

    func compress(file: FileInfo, preset: CompressionPreset) async
    func retry() async
    func cancel()
    func reset()
}

// MARK: - Compression ViewModel

/// ViewModel for compression operations
/// Decouples compression logic from navigation (AppCoordinator)
///
/// Usage:
/// ```swift
/// let vm = CompressionViewModel(service: compressionService, history: historyManager, analytics: analytics)
/// vm.onCompressionCompleted = { result in
///     coordinator.navigateToResult(result)
/// }
/// await vm.compress(file: selectedFile, preset: selectedPreset)
/// ```
@MainActor
final class CompressionViewModel: ObservableObject, CompressionViewModelProtocol {

    // MARK: - Published State

    @Published private(set) var status: CompressionStatus = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentStage: ProcessingStage = .preparing

    // MARK: - Retry State

    private var retryCount = 0
    private let maxRetries = 2
    private var lastFile: FileInfo?
    private var lastPreset: CompressionPreset?
    private var lastError: CompressionError?

    var canRetry: Bool {
        guard case .failed(let error) = status else { return false }
        return retryCount < maxRetries && isRetryableError(error)
    }

    // MARK: - Dependencies (Injected)

    private let service: CompressionServiceProtocol
    private let historyManager: HistoryManagerProtocol
    private let subscriptionManager: SubscriptionManagerProtocol
    private let analytics: AnalyticsService

    // MARK: - Callbacks for Coordinator

    /// Called when compression completes successfully
    var onCompressionCompleted: ((CompressionResult) -> Void)?

    /// Called when compression fails and retry is available
    var onRetryAvailable: ((CompressionError) -> Void)?

    /// Called when compression fails permanently (no retry)
    var onCompressionFailed: ((CompressionError) -> Void)?

    /// Called when compression is cancelled
    var onCancelled: (() -> Void)?

    // MARK: - Initialization

    init(
        service: CompressionServiceProtocol,
        historyManager: HistoryManagerProtocol,
        subscriptionManager: SubscriptionManagerProtocol,
        analytics: AnalyticsService
    ) {
        self.service = service
        self.historyManager = historyManager
        self.subscriptionManager = subscriptionManager
        self.analytics = analytics
    }

    // MARK: - Public API

    /// Start compressing a file with the given preset
    /// - Parameters:
    ///   - file: The file to compress
    ///   - preset: The compression preset to use
    func compress(file: FileInfo, preset: CompressionPreset) async {
        lastFile = file
        lastPreset = preset
        lastError = nil

        // Check for extremely large files (500+ pages)
        if let pageCount = file.pageCount, pageCount > 500 {
            let error = CompressionError.fileTooLarge
            handleError(error, preset: preset)
            return
        }

        // Reset state
        status = .preparing
        progress = 0
        currentStage = .preparing

        // Track analytics
        analytics.trackPresetSelected(presetId: preset.id, isCustom: preset.quality == .custom)
        analytics.track(.compressionStarted, parameters: [
            "preset_id": preset.id,
            "file_size_mb": file.sizeMB
        ])

        // Prepare service
        await service.prepareForNewTask()

        do {
            let outputURL = try await service.compressFile(
                at: file.url,
                preset: preset
            ) { [weak self] stage, prog in
                Task { @MainActor in
                    self?.currentStage = stage
                    self?.progress = prog
                    self?.status = .compressing(progress: prog, stage: stage)
                }
            }

            // Get compressed file size
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let compressedSize = attributes[.size] as? Int64 ?? 0

            let result = CompressionResult(
                originalFile: file,
                compressedURL: outputURL,
                compressedSize: compressedSize
            )

            // Success!
            retryCount = 0
            status = .success(result)

            // Track analytics
            analytics.trackCompressionCompleted(
                originalSize: file.size,
                compressedSize: result.compressedSize,
                savingsPercent: result.savingsPercent,
                presetId: preset.id,
                duration: 0
            )

            // Add to history
            historyManager.addFromResult(result, presetId: preset.id)

            // Record successful compression for subscription tracking
            subscriptionManager.recordSuccessfulCompression()

            // Notify coordinator
            onCompressionCompleted?(result)

        } catch let error as CompressionError {
            handleError(error, preset: preset)

        } catch {
            let compressionError = CompressionError.unknown(underlying: error)
            handleError(compressionError, preset: preset)
        }
    }

    /// Retry the last failed compression
    func retry() async {
        guard let file = lastFile, let preset = lastPreset else { return }

        retryCount += 1
        analytics.track(.compressionRetried, parameters: ["retry_count": retryCount])

        await compress(file: file, preset: preset)
    }

    /// Cancel the current compression
    func cancel() {
        status = .cancelled
        retryCount = 0
        onCancelled?()
    }

    /// Reset ViewModel state
    func reset() {
        status = .idle
        progress = 0
        currentStage = .preparing
        retryCount = 0
        lastFile = nil
        lastPreset = nil
        lastError = nil
    }

    // MARK: - Private Helpers

    private func handleError(_ error: CompressionError, preset: CompressionPreset) {
        lastError = error
        status = .failed(error)

        analytics.trackCompressionFailed(error: error, presetId: preset.id)

        if canRetry {
            onRetryAvailable?(error)
        } else {
            retryCount = 0
            onCompressionFailed?(error)
        }
    }

    /// Determines if retry should be allowed for specific error types
    private func isRetryableError(_ error: CompressionError) -> Bool {
        switch error {
        case .accessDenied, .invalidPDF, .invalidFile, .emptyPDF, .encryptedPDF, .fileTooLarge, .unsupportedType:
            // These errors won't be fixed by retry
            return false
        case .contextCreationFailed, .saveFailed, .memoryPressure, .timeout, .pageProcessingFailed, .unknown, .cancelled, .exportFailed:
            // These might be fixed by retry
            return true
        }
    }
}

// MARK: - History Manager Protocol Extension
// Note: HistoryManagerProtocol is defined in HistoryManager.swift
// This extension adds conformance for the addFromResult method
