//
//  StageTimeline.swift
//  optimize
//
//  Progress timeline showing processing stages
//

import SwiftUI

enum ProcessingStage: String, CaseIterable, Identifiable {
    case preparing = "Preparing"
    case uploading = "Analyzing"
    case optimizing = "Optimizing"
    case downloading = "Completing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .preparing: return "doc.badge.gearshape"
        case .uploading: return "magnifyingglass"
        case .optimizing: return "wand.and.stars"
        case .downloading: return "checkmark.circle"
        }
    }

    /// Detailed sub-messages for each stage
    var detailMessages: [String] {
        switch self {
        case .preparing:
            return [
                "Reading file...",
                "Analyzing page structure...",
                "Checking security permissions..."
            ]
        case .uploading:
            return [
                "Scanning images...",
                "Detecting text layers...",
                "Determining optimization strategy..."
            ]
        case .optimizing:
            return [
                "Cleaning unnecessary metadata...",
                "Compressing images...",
                "Optimizing page sizes...",
                "Organizing font data...",
                "Repackaging PDF..."
            ]
        case .downloading:
            return [
                "Final checks...",
                "Saving file...",
                "Completing process..."
            ]
        }
    }
}

struct StageTimeline: View {
    let stages: [ProcessingStage]
    let currentStage: ProcessingStage
    let completedStages: Set<ProcessingStage>

    init(
        stages: [ProcessingStage] = ProcessingStage.allCases,
        currentStage: ProcessingStage,
        completedStages: Set<ProcessingStage> = []
    ) {
        self.stages = stages
        self.currentStage = currentStage
        self.completedStages = completedStages
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                StageRow(
                    stage: stage,
                    isActive: stage == currentStage,
                    isCompleted: completedStages.contains(stage),
                    isLast: index == stages.count - 1
                )
            }
        }
    }
}

struct StageRow: View {
    let stage: ProcessingStage
    let isActive: Bool
    let isCompleted: Bool
    let isLast: Bool

    @State private var isPulsing = false

    var stateColor: Color {
        if isCompleted {
            return .statusSuccess
        } else if isActive {
            return .appAccent
        } else {
            return .secondary.opacity(0.3)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Stage indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(stateColor)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: stage.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(stateColor)
                    }

                    // Pulse animation for active stage
                    if isActive && !isCompleted {
                        Circle()
                            .stroke(stateColor, lineWidth: 2)
                            .frame(width: 40, height: 40)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                            .opacity(isPulsing ? 0 : 1)
                    }
                }

                // Connecting line
                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? stateColor : Color.secondary.opacity(0.2))
                        .frame(width: 2, height: 24)
                }
            }

            // Stage text
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(stage.rawValue)
                    .font(isActive ? .appBodyMedium : .appBody)
                    .foregroundStyle(isActive || isCompleted ? .primary : .secondary)

                if isActive && !isCompleted {
                    Text("Processing...")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : Spacing.md)

            Spacer()
        }
        .onAppear {
            if isActive && !isCompleted {
                withAnimation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue && !isCompleted {
                isPulsing = false
                withAnimation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        // In progress
        GlassCard {
            StageTimeline(
                currentStage: .optimizing,
                completedStages: [.preparing, .uploading]
            )
        }

        // Just started
        GlassCard {
            StageTimeline(
                currentStage: .preparing,
                completedStages: []
            )
        }
    }
    .padding()
}
