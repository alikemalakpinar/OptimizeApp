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

    // MARK: - Cancellation Control
    private var activeCompressionID = UUID()
    private var cancellationRequested = false

    // MARK: - Page Limits (Unified Policy)
    // Free users: Limited to 100 pages (reasonable for personal use)
    // Pro users: Unlimited (no artificial cap)
    // This policy is shared between Home and Batch flows for consistency
    private let freeUserPageLimit: Int = 100
    private let proUserPageLimit: Int = .max  // Effectively unlimited

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

    // MARK: - Progress Updates

    private struct WeakBox<T: AnyObject>: @unchecked Sendable {
        weak var value: T?
        init(_ value: T) {
            self.value = value
        }
    }

    private func applyProgress(stage: ProcessingStage, progress: Double, operationID: UUID) {
        guard activeCompressionID == operationID,
              cancellationRequested == false,
              Task.isCancelled == false else {
            return
        }

        currentStage = stage
        self.progress = progress
        status = .compressing(progress: progress, stage: stage)
    }

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
        let operationID = beginCompression(file: file, preset: preset)

        guard await validatePreCompression(file: file, preset: preset) else { return }

        // Track analytics
        analytics.trackPresetSelected(presetId: preset.id, isCustom: preset.quality == .custom)
        analytics.track(.compressionStarted, parameters: [
            "preset_id": preset.id,
            "file_size_mb": file.sizeMB
        ])

        // Prepare service
        service.prepareForNewTask()

        do {
            let selfBox = WeakBox(self)
            let outputURL = try await service.compressFile(
                at: file.url,
                preset: preset
            ) { stage, prog in
                Task { @MainActor in
                    selfBox.value?.applyProgress(stage: stage, progress: prog, operationID: operationID)
                }
            }

            guard isOperationValid(operationID) else { return }

            finalizeSuccess(file: file, outputURL: outputURL, presetId: preset.id, preset: preset)

        } catch let error as CompressionError {
            guard isOperationValid(operationID) else { return }
            handleError(error, preset: preset)

        } catch {
            guard isOperationValid(operationID) else { return }
            handleError(.unknown(underlying: error), preset: preset)
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
        cancellationRequested = true
        activeCompressionID = UUID() // Invalidate any in-flight callbacks
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

    // MARK: - Shared Compression Helpers (DRY)

    /// Initialize a new compression operation and return its ID.
    /// Call this at the start of every compress method.
    private func beginCompression(file: FileInfo, preset: CompressionPreset) -> UUID {
        cancellationRequested = false
        let operationID = UUID()
        activeCompressionID = operationID
        lastFile = file
        lastPreset = preset
        lastError = nil
        return operationID
    }

    /// Check if the given operation is still the active one and hasn't been cancelled.
    private func isOperationValid(_ operationID: UUID) -> Bool {
        activeCompressionID == operationID
            && !cancellationRequested
            && !Task.isCancelled
    }

    /// Common pre-compression validation: entitlement, page limits, disk space.
    /// Returns true if compression should proceed, false if blocked (error already handled).
    private func validatePreCompression(
        file: FileInfo,
        preset: CompressionPreset,
        allowLargeFileOverride: Bool = false
    ) async -> Bool {
        // Entitlement verification for Pro users
        if subscriptionManager.status.isPro {
            let isEntitled = await subscriptionManager.verifyEntitlementForCriticalOperation()
            if !isEntitled {
                NotificationCenter.default.post(
                    name: .showPaywallForFeature,
                    object: nil,
                    userInfo: ["feature": PremiumFeature.unlimitedUsage]
                )
                handleError(.accessDenied, preset: preset)
                return false
            }
        }

        // Page count limits
        if let pageCount = file.pageCount {
            let isPro = subscriptionManager.status.isPro
            let pageLimit = isPro ? proUserPageLimit : freeUserPageLimit

            if pageCount > pageLimit && !allowLargeFileOverride {
                if !isPro {
                    NotificationCenter.default.post(
                        name: .showPaywallForFeature,
                        object: nil,
                        userInfo: [
                            "feature": PremiumFeature.unlimitedUsage,
                            "context": PaywallContext(
                                title: "Büyük PDF Desteği",
                                subtitle: "\(pageCount) sayfalık PDF, ücretsiz \(freeUserPageLimit) sayfa limitini aşıyor.",
                                icon: "doc.badge.plus",
                                highlights: [
                                    "Sınırsız sayfa desteği",
                                    "500+ sayfalık PDF işleme",
                                    "Profesyonel belge optimizasyonu",
                                    "Öncelikli işlem kuyruğu"
                                ],
                                limitDescription: "Ücretsiz: \(freeUserPageLimit) sayfa • Pro: Sınırsız",
                                ctaText: "Sınırsız PDF İşlemeyi Aç"
                            )
                        ]
                    )
                }
                handleError(.fileTooLarge, preset: preset)
                return false
            }
        }

        // Reset state
        status = .preparing
        progress = 0
        currentStage = .preparing

        // Disk space check
        do {
            try DiskSpaceGuard.ensureSpaceForCompression(inputFileSize: file.size)
        } catch let error as DiskSpaceError {
            #if DEBUG
            print("❌ [Compression] Disk space check failed: \(error.localizedDescription)")
            #endif
            handleError(.saveFailed, preset: preset)
            return false
        } catch {
            // Non-disk-space error, continue anyway
        }

        return true
    }

    /// Common post-compression success handling.
    /// Creates the result, tracks analytics, updates history, and notifies the coordinator.
    private func finalizeSuccess(
        file: FileInfo,
        outputURL: URL,
        presetId: String,
        preset: CompressionPreset
    ) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let compressedSize = attributes?[FileAttributeKey.size] as? Int64 ?? 0

        let result = CompressionResult(
            originalFile: file,
            compressedURL: outputURL,
            compressedSize: compressedSize
        )

        retryCount = 0
        status = .success(result)

        analytics.trackCompressionCompleted(
            originalSize: file.size,
            compressedSize: result.compressedSize,
            savingsPercent: result.savingsPercent,
            presetId: presetId,
            duration: 0
        )

        historyManager.addFromResult(result, presetId: presetId)
        subscriptionManager.recordSuccessfulCompression()
        onCompressionCompleted?(result)
    }

    // MARK: - Private Helpers

    private func handleError(_ error: CompressionError, preset: CompressionPreset) {
        lastError = error

        // Treat 'alreadyOptimized' as a unique UX flow, not a hard failure.
        // Show a success result with 0% savings so the UI can display
        // "Already Optimized" messaging instead of an error screen.
        if case .alreadyOptimized = error, let file = lastFile {
            let result = CompressionResult(
                originalFile: file,
                compressedURL: file.url,
                compressedSize: file.size
            )
            status = .success(result)
            onCompressionCompleted?(result)
            return
        }

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
        case .accessDenied, .invalidPDF, .invalidFile, .emptyPDF, .encryptedPDF, .fileTooLarge, .unsupportedType, .alreadyOptimized:
            // These errors won't be fixed by retry
            return false
        case .contextCreationFailed, .saveFailed, .memoryPressure, .timeout, .pageProcessingFailed, .unknown, .cancelled, .exportFailed:
            // These might be fixed by retry
            return true
        }
    }
}

// MARK: - OptimizationProfile Support (v4.0)

extension CompressionViewModel {

    /// Compress with OptimizationProfile for advanced control
    /// Uses new Preflight → Optimize → Sanitize pipeline
    func compress(file: FileInfo, profile: OptimizationProfile) async {
        let safePreset = CompressionPreset.from(profile: profile)
        let operationID = beginCompression(file: file, preset: safePreset)

        // For Pro users with Ultra strategy, allow large files (streaming mode)
        let isPro = subscriptionManager.status.isPro
        let allowLargeFile = isPro && profile.strategy == .ultra

        guard await validatePreCompression(
            file: file,
            preset: safePreset,
            allowLargeFileOverride: allowLargeFile
        ) else { return }

        // Track analytics with profile info
        analytics.track(.compressionStarted, parameters: [
            "profile_strategy": profile.strategy.rawValue,
            "file_size_mb": file.sizeMB,
            "strip_metadata": profile.stripMetadata,
            "convert_srgb": profile.convertToSRGB
        ])

        // Prepare service
        service.prepareForNewTask()

        // Preflight analysis
        let preflightReport = await PreflightAnalyzer.shared.analyze(url: file.url)

        // Log preflight results
        analytics.track(.fileAnalysisCompleted, parameters: [
            "analysis_type": "preflight",
            "compression_potential": preflightReport.compressionPotential,
            "has_invisible_garbage": preflightReport.hasInvisibleGarbage,
            "suggested_strategy": preflightReport.suggestedStrategy.rawValue
        ])

        do {
            // Use PDF compression with profile if it's a PDF
            let fileType = FileType.from(extension: file.url.pathExtension)
            let outputURL: URL

            let selfBox = WeakBox(self)
            if fileType == .pdf, let pdfService = service as? UltimatePDFCompressionService {
                outputURL = try await pdfService.compressPDF(
                    at: file.url,
                    profile: profile
                ) { stage, prog in
                    Task { @MainActor in
                        selfBox.value?.applyProgress(stage: stage, progress: prog, operationID: operationID)
                    }
                }
            } else {
                // For other file types, use preset-based compression
                outputURL = try await service.compressFile(
                    at: file.url,
                    preset: safePreset
                ) { stage, prog in
                    Task { @MainActor in
                        selfBox.value?.applyProgress(stage: stage, progress: prog, operationID: operationID)
                    }
                }
            }

            guard isOperationValid(operationID) else { return }

            finalizeSuccess(file: file, outputURL: outputURL, presetId: profile.strategy.rawValue, preset: safePreset)

            // Haptic feedback for profile-based compression
            HapticManager.shared.trigger(.celebration)

        } catch let error as CompressionError {
            guard isOperationValid(operationID) else { return }
            handleError(error, preset: safePreset)

        } catch {
            guard isOperationValid(operationID) else { return }
            handleError(.unknown(underlying: error), preset: safePreset)
        }
    }

    /// Get recommended profile based on file analysis
    func getRecommendedProfile(for file: FileInfo) async -> OptimizationProfile {
        let report = await PreflightAnalyzer.shared.analyze(url: file.url)
        switch report.suggestedStrategy {
        case .quick:
            return .quick
        case .balanced:
            return .balanced
        case .ultra:
            return .ultra
        }
    }
}

// MARK: - History Manager Protocol Extension
// Note: HistoryManagerProtocol is defined in HistoryManager.swift
// This extension adds conformance for the addFromResult method
