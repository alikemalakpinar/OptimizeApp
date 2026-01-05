//
//  CompressionActivityManager.swift
//  optimize
//
//  Live Activity and Dynamic Island support for compression progress
//  Shows real-time compression status even when app is in background
//
//  MASTER LEVEL FEATURE:
//  - Dynamic Island integration (iPhone 14 Pro+)
//  - Lock Screen Live Activity
//  - Real-time progress updates
//  - Completion celebrations
//

import Foundation
import ActivityKit
import SwiftUI

// MARK: - Compression Activity Attributes

/// Defines the data model for compression Live Activity
struct CompressionActivityAttributes: ActivityAttributes {
    /// Static content that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Current compression progress (0.0 - 1.0)
        var progress: Double

        /// Current file being processed
        var currentFileName: String

        /// Number of completed files
        var completedFiles: Int

        /// Total number of files
        var totalFiles: Int

        /// Current stage of compression
        var stage: CompressionStage

        /// Bytes saved so far
        var bytesSaved: Int64

        /// Whether compression is complete
        var isComplete: Bool

        /// Error message if failed
        var errorMessage: String?
    }

    /// Static attributes that don't change
    var startTime: Date
    var isProUser: Bool
}

// MARK: - Compression Stage

enum CompressionStage: String, Codable {
    case preparing = "Hazırlanıyor"
    case analyzing = "Analiz Ediliyor"
    case compressing = "Sıkıştırılıyor"
    case optimizing = "Optimize Ediliyor"
    case finalizing = "Tamamlanıyor"
    case complete = "Tamamlandı"
    case failed = "Başarısız"

    var icon: String {
        switch self {
        case .preparing: return "doc.badge.gearshape"
        case .analyzing: return "magnifyingglass"
        case .compressing: return "arrow.down.right.and.arrow.up.left"
        case .optimizing: return "wand.and.stars"
        case .finalizing: return "checkmark.circle"
        case .complete: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .preparing: return .gray
        case .analyzing: return .blue
        case .compressing: return .purple
        case .optimizing: return .orange
        case .finalizing: return .green
        case .complete: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Compression Activity Manager

/// Manages Live Activity lifecycle for compression operations
@MainActor
final class CompressionActivityManager: ObservableObject {
    static let shared = CompressionActivityManager()

    /// Current active Live Activity
    private var currentActivity: Activity<CompressionActivityAttributes>?

    /// Whether Live Activities are supported on this device
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private init() {}

    // MARK: - Activity Lifecycle

    /// Start a new compression Live Activity
    /// - Parameters:
    ///   - totalFiles: Total number of files to compress
    ///   - isProUser: Whether user has Pro subscription
    func startActivity(totalFiles: Int, isProUser: Bool) {
        guard isSupported else { return }

        // End any existing activity first
        endActivity()

        let attributes = CompressionActivityAttributes(
            startTime: Date(),
            isProUser: isProUser
        )

        let initialState = CompressionActivityAttributes.ContentState(
            progress: 0,
            currentFileName: "",
            completedFiles: 0,
            totalFiles: totalFiles,
            stage: .preparing,
            bytesSaved: 0,
            isComplete: false,
            errorMessage: nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("[CompressionActivity] Failed to start: \(error)")
        }
    }

    /// Update the Live Activity with current progress
    /// - Parameters:
    ///   - progress: Current progress (0.0 - 1.0)
    ///   - currentFileName: Name of file being processed
    ///   - completedFiles: Number of completed files
    ///   - totalFiles: Total number of files
    ///   - stage: Current compression stage
    ///   - bytesSaved: Total bytes saved so far
    func updateActivity(
        progress: Double,
        currentFileName: String,
        completedFiles: Int,
        totalFiles: Int,
        stage: CompressionStage,
        bytesSaved: Int64
    ) {
        guard let activity = currentActivity else { return }

        let updatedState = CompressionActivityAttributes.ContentState(
            progress: progress,
            currentFileName: currentFileName,
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            stage: stage,
            bytesSaved: bytesSaved,
            isComplete: false,
            errorMessage: nil
        )

        Task {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )
        }
    }

    /// Complete the Live Activity with success
    /// - Parameter bytesSaved: Total bytes saved
    func completeActivity(bytesSaved: Int64, completedFiles: Int, totalFiles: Int) {
        guard let activity = currentActivity else { return }

        let finalState = CompressionActivityAttributes.ContentState(
            progress: 1.0,
            currentFileName: "",
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            stage: .complete,
            bytesSaved: bytesSaved,
            isComplete: true,
            errorMessage: nil
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 10) // Keep on screen for 10 seconds
            )
            await MainActor.run {
                currentActivity = nil
            }
        }
    }

    /// End the Live Activity with an error
    /// - Parameter error: Error message to display
    func failActivity(error: String) {
        guard let activity = currentActivity else { return }

        let failedState = CompressionActivityAttributes.ContentState(
            progress: 0,
            currentFileName: "",
            completedFiles: 0,
            totalFiles: 0,
            stage: .failed,
            bytesSaved: 0,
            isComplete: true,
            errorMessage: error
        )

        Task {
            await activity.end(
                ActivityContent(state: failedState, staleDate: nil),
                dismissalPolicy: .after(.now + 5)
            )
            await MainActor.run {
                currentActivity = nil
            }
        }
    }

    /// End the Live Activity immediately
    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run {
                currentActivity = nil
            }
        }
    }
}

// MARK: - Formatted Helpers

extension CompressionActivityAttributes.ContentState {
    /// Formatted bytes saved string
    var formattedBytesSaved: String {
        ByteCountFormatter.string(fromByteCount: bytesSaved, countStyle: .file)
    }

    /// Progress as percentage string
    var progressPercentage: String {
        "\(Int(progress * 100))%"
    }

    /// Files progress string (e.g., "2/5")
    var filesProgress: String {
        "\(completedFiles)/\(totalFiles)"
    }
}
