//
//  ResultViewModel.swift
//  optimize
//
//  MVVM-C Architecture: ViewModel for compression result handling
//  Extracted from AppCoordinator to reduce God Object anti-pattern
//
//  This ViewModel handles:
//  - Share/Save operations
//  - App Store review prompt logic
//  - Post-compression flow (commitment screen trigger)
//
//  The Coordinator only handles navigation, this handles business logic.
//

import Foundation
import StoreKit
import UIKit

// MARK: - Result ViewModel Protocol

@MainActor
protocol ResultViewModelProtocol: ObservableObject {
    var result: CompressionResult? { get }
    var showShareSheet: Bool { get set }
    var showFileSaver: Bool { get set }

    func setResult(_ result: CompressionResult)
    func share()
    func save()
    func reset()
}

// MARK: - Result ViewModel

/// ViewModel for compression result handling
/// Manages post-compression operations like sharing, saving, and review prompts
@MainActor
final class ResultViewModel: ObservableObject, ResultViewModelProtocol {

    // MARK: - Published State

    @Published private(set) var result: CompressionResult?
    @Published var showShareSheet = false
    @Published var showFileSaver = false

    // MARK: - Keys for UserDefaults

    private let successCountKey = "successfulCompressionCount"
    private let pendingCommitmentKey = "pendingCommitmentAfterFirstCompression"
    private let hasSeenCommitmentKey = "hasSeenCommitment"

    // MARK: - Dependencies

    private let analytics: AnalyticsService

    // MARK: - Callbacks for Coordinator

    /// Called when commitment screen should be shown
    var onShouldShowCommitment: (() -> Void)?

    /// Called when share action is triggered
    var onShare: ((URL) -> Void)?

    /// Called when save action is triggered
    var onSave: ((URL) -> Void)?

    // MARK: - Initialization

    init(analytics: AnalyticsService) {
        self.analytics = analytics
    }

    // MARK: - Public API

    /// Set the compression result and trigger post-compression logic
    func setResult(_ result: CompressionResult) {
        self.result = result

        // Smart Review Prompt: Ask for review at optimal moments
        requestReviewIfAppropriate(savingsPercent: result.savingsPercent)

        // Check if commitment screen should be shown
        checkCommitmentFlow()
    }

    /// Trigger share action
    func share() {
        guard let result = result else { return }
        analytics.track(.fileShared)
        showShareSheet = true
        onShare?(result.compressedURL)
    }

    /// Trigger save action
    func save() {
        guard let result = result else { return }
        analytics.track(.fileSaved)
        showFileSaver = true
        onSave?(result.compressedURL)
    }

    /// Reset ViewModel state
    func reset() {
        result = nil
        showShareSheet = false
        showFileSaver = false
    }

    // MARK: - Smart Review Prompt

    /// Requests App Store review at optimal moments (3rd, 10th, 50th successful compression)
    /// Only triggers when savings are meaningful (>20%)
    private func requestReviewIfAppropriate(savingsPercent: Int) {
        // Only ask for review if user had a good experience (>20% savings)
        guard savingsPercent > 20 else { return }

        // Increment and get success count
        let successCount = UserDefaults.standard.integer(forKey: successCountKey) + 1
        UserDefaults.standard.set(successCount, forKey: successCountKey)

        // Request review at milestone counts: 3rd, 10th, 50th successful compression
        let reviewMilestones = [3, 10, 50]
        guard reviewMilestones.contains(successCount) else { return }

        // Delay to let the result screen render first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }

    // MARK: - Commitment Flow

    /// Checks if commitment screen should be shown after compression
    /// This provides better UX by showing commitment after user experiences value
    private func checkCommitmentFlow() {
        let isPending = UserDefaults.standard.bool(forKey: pendingCommitmentKey)
        let hasSeenCommitment = UserDefaults.standard.bool(forKey: hasSeenCommitmentKey)

        guard isPending && !hasSeenCommitment else { return }

        // Delay to let result screen render first
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.onShouldShowCommitment?()
        }
    }
}
