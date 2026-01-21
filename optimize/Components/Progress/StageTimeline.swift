//
//  StageTimeline.swift
//  optimize
//
//  Progress timeline showing processing stages
//

import SwiftUI

enum ProcessingStage: String, CaseIterable, Identifiable {
    case preparing
    case uploading
    case optimizing
    case downloading

    var id: String { rawValue }

    /// Localized stage name
    var localizedName: String {
        switch self {
        case .preparing: return AppStrings.ProcessingStages.preparing
        case .uploading: return AppStrings.ProcessingStages.analyzing
        case .optimizing: return AppStrings.ProcessingStages.optimizing
        case .downloading: return AppStrings.ProcessingStages.completing
        }
    }

    var icon: String {
        switch self {
        case .preparing: return "doc.badge.gearshape"
        case .uploading: return "magnifyingglass"
        case .optimizing: return "wand.and.stars"
        case .downloading: return "checkmark.circle"
        }
    }

    /// Detailed sub-messages for each stage (localized, dynamic during processing)
    var detailMessages: [String] {
        switch self {
        case .preparing:
            return AppStrings.ProcessingStages.preparingDetails
        case .uploading:
            return AppStrings.ProcessingStages.analyzingDetails
        case .optimizing:
            return AppStrings.ProcessingStages.optimizingDetails
        case .downloading:
            return AppStrings.ProcessingStages.completingDetails
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
    var progress: Double = 0

    @State private var isPulsing = false
    @State private var currentMessageIndex = 0
    @State private var messageTimer: Timer?

    var stateColor: Color {
        if isCompleted {
            return .statusSuccess
        } else if isActive {
            return .appAccent
        } else {
            return .secondary.opacity(0.3)
        }
    }

    /// Current detail message based on progress or timer rotation
    var currentDetailMessage: String {
        let messages = stage.detailMessages
        guard !messages.isEmpty else { return "Processing..." }

        // If progress is available, use it to determine message
        if progress > 0 {
            let index = min(Int(progress * Double(messages.count)), messages.count - 1)
            return messages[index]
        }

        // Otherwise use timer-based rotation
        return messages[currentMessageIndex % messages.count]
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
                Text(stage.localizedName)
                    .font(isActive ? .appBodyMedium : .appBody)
                    .foregroundStyle(isActive || isCompleted ? .primary : .secondary)

                if isActive && !isCompleted {
                    // Dynamic message based on progress
                    Text(currentDetailMessage)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.3), value: currentMessageIndex)
                        .id(currentMessageIndex) // Force view update
                }
            }
            .padding(.bottom, isLast ? 0 : Spacing.md)

            Spacer()
        }
        .onAppear {
            if isActive && !isCompleted {
                // Pulse animation
                withAnimation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }

                // Message rotation timer (only if no progress tracking)
                startMessageRotation()
            }
        }
        .onDisappear {
            stopMessageRotation()
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
                startMessageRotation()
            } else {
                stopMessageRotation()
            }
        }
    }

    // MARK: - Message Rotation

    private func startMessageRotation() {
        guard progress == 0 else { return } // Don't use timer if progress is being tracked
        stopMessageRotation()

        messageTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMessageIndex += 1
            }
        }
    }

    private func stopMessageRotation() {
        messageTimer?.invalidate()
        messageTimer = nil
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
