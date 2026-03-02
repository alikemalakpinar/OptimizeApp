//
//  CompressionLiveActivity.swift
//  OptimizeWidget
//
//  Dynamic Island and Lock Screen Live Activity for compression progress.
//  Shows real-time progress when the app is in background.
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Activity Attributes (must match main app's definition)

struct CompressionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var currentFileName: String
        var completedFiles: Int
        var totalFiles: Int
        var stage: CompressionStage
        var bytesSaved: Int64
        var isComplete: Bool
        var errorMessage: String?

        var formattedBytesSaved: String {
            ByteCountFormatter.string(fromByteCount: bytesSaved, countStyle: .file)
        }

        var progressPercentage: String {
            "\(Int(progress * 100))%"
        }

        var filesProgress: String {
            "\(completedFiles)/\(totalFiles)"
        }
    }

    var startTime: Date
    var isProUser: Bool
}

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
}

// MARK: - Live Activity Widget

struct CompressionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompressionActivityAttributes.self) { context in
            // Lock Screen banner
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.stage.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.mint)
                        Text(context.state.stage.rawValue)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.progressPercentage)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.mint)
                }

                DynamicIslandExpandedRegion(.center) {
                    // Progress bar
                    VStack(spacing: 4) {
                        ProgressView(value: context.state.progress)
                            .tint(.mint)

                        if context.state.isComplete {
                            Text("\(context.state.formattedBytesSaved) tasarruf edildi!")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.mint)
                        } else {
                            Text(context.state.currentFileName)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Files progress
                        Label(context.state.filesProgress, systemImage: "doc.fill")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Bytes saved
                        if context.state.bytesSaved > 0 {
                            Label(context.state.formattedBytesSaved, systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.mint)
                        }
                    }
                }
            } compactLeading: {
                // Compact leading — icon
                Image(systemName: context.state.isComplete ? "checkmark.circle.fill" : "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(context.state.isComplete ? .green : .mint)
            } compactTrailing: {
                // Compact trailing — progress percent
                Text(context.state.progressPercentage)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.mint)
            } minimal: {
                // Minimal — just a gauge
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.circular)
                    .tint(.mint)
            }
        }
    }
}

// MARK: - Lock Screen Live Activity View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<CompressionActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Top row: stage + percentage
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: context.state.stage.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.mint)
                    Text(context.state.stage.rawValue)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }

                Spacer()

                Text(context.state.progressPercentage)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.mint)
            }

            // Progress bar
            ProgressView(value: context.state.progress)
                .tint(.mint)

            // Bottom row: file info + savings
            HStack {
                if context.state.isComplete {
                    Label("\(context.state.formattedBytesSaved) tasarruf!", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                } else {
                    Text(context.state.currentFileName)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(context.state.filesProgress)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.85))
    }
}
