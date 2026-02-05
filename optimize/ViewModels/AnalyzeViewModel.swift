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
        analysisResult = nil
        state = .analyzing

        analytics.track(.fileAnalysisStarted)

        do {
            let result = try await analyzeWithTimeout(file: file)
            analysisResult = result
            state = .completed(result)

            analytics.track(.fileAnalysisCompleted)
            onAnalysisCompleted?(file, result)

        } catch {
            // Surface error instead of masking as "completed"
            analytics.trackError(error, context: "file_analysis")
            analysisResult = nil
            state = .failed(error.localizedDescription)
            onAnalysisFailed?(error)
        }
    }

    // MARK: - Timeout Handling

    private func analyzeWithTimeout(file: FileInfo) async throws -> AnalysisResult {
        let timeoutSeconds: UInt64 = 20
        return try await withThrowingTaskGroup(of: AnalysisResult.self) { group in
            group.addTask { [compressionService] in
                try await compressionService.analyze(file: file)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw CompressionError.timeout
            }

            guard let result = try await group.next() else {
                throw CompressionError.unknown(underlying: nil)
            }
            group.cancelAll()
            return result
        }
    }

    /// Reset ViewModel state
    func reset() {
        state = .idle
        file = nil
        analysisResult = nil
    }
}
