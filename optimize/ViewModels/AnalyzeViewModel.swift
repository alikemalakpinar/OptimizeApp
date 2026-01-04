//
//  AnalyzeViewModel.swift
//  optimize
//
//  MVVM-C Architecture: ViewModel for file analysis
//  Extracted from AppCoordinator to reduce God Object anti-pattern
//
//  This ViewModel handles:
//  - File analysis state management
//  - Analysis result caching
//  - Error handling for analysis operations
//
//  The Coordinator only handles navigation, this handles business logic.
//

import Foundation
import Combine

// MARK: - Analysis State

enum AnalysisState: Equatable {
    case idle
    case analyzing
    case completed(AnalysisResult)
    case failed(String)

    static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.analyzing, .analyzing):
            return true
        case (.completed(let l), .completed(let r)):
            return l.pageCount == r.pageCount && l.imageCount == r.imageCount
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Analyze ViewModel Protocol

@MainActor
protocol AnalyzeViewModelProtocol: ObservableObject {
    var state: AnalysisState { get }
    var file: FileInfo? { get }
    var analysisResult: AnalysisResult? { get }

    func analyze(file: FileInfo) async
    func reset()
}

// MARK: - Analyze ViewModel

/// ViewModel for file analysis operations
/// Decouples analysis logic from navigation (AppCoordinator)
@MainActor
final class AnalyzeViewModel: ObservableObject, AnalyzeViewModelProtocol {

    // MARK: - Published State

    @Published private(set) var state: AnalysisState = .idle
    @Published private(set) var file: FileInfo?
    @Published private(set) var analysisResult: AnalysisResult?

    // MARK: - Dependencies (Injected)

    private let compressionService: CompressionServiceProtocol
    private let analytics: AnalyticsService

    // MARK: - Callbacks for Coordinator

    /// Called when analysis completes successfully
    var onAnalysisCompleted: ((FileInfo, AnalysisResult) -> Void)?

    /// Called when analysis fails
    var onAnalysisFailed: ((Error) -> Void)?

    // MARK: - Initialization

    init(
        compressionService: CompressionServiceProtocol,
        analytics: AnalyticsService
    ) {
        self.compressionService = compressionService
        self.analytics = analytics
    }

    // MARK: - Public API

    /// Start analyzing a file
    /// - Parameter file: The file to analyze
    func analyze(file: FileInfo) async {
        self.file = file
        state = .analyzing

        analytics.track(.fileAnalysisStarted)

        do {
            let result = try await compressionService.analyze(file: file)
            analysisResult = result
            state = .completed(result)

            analytics.track(.fileAnalysisCompleted)
            onAnalysisCompleted?(file, result)

        } catch {
            // Provide fallback analysis on error
            let fallbackResult = AnalysisResult(
                pageCount: file.pageCount ?? 1,
                imageCount: 0,
                imageDensity: .medium,
                estimatedSavings: .medium,
                isAlreadyOptimized: false,
                originalDPI: nil
            )

            analysisResult = fallbackResult
            state = .completed(fallbackResult)

            analytics.trackError(error, context: "file_analysis")

            // Still call completion with fallback - don't block user
            onAnalysisCompleted?(file, fallbackResult)
        }
    }

    /// Reset ViewModel state
    func reset() {
        state = .idle
        file = nil
        analysisResult = nil
    }
}
