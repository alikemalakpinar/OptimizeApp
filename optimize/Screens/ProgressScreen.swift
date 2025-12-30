//
//  ProgressScreen.swift
//  optimize
//
//  Processing progress screen with stage timeline
//

import SwiftUI

struct ProgressScreen: View {
    @State private var currentStage: ProcessingStage = .preparing
    @State private var completedStages: Set<ProcessingStage> = []
    @State private var progress: Double = 0

    let onCancel: () -> Void

    // Simulated progress for demo
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader("İşleniyor")

            Spacer()

            VStack(spacing: Spacing.xl) {
                // Stage Timeline
                GlassCard {
                    StageTimeline(
                        currentStage: currentStage,
                        completedStages: completedStages
                    )
                }
                .padding(.horizontal, Spacing.md)

                // Progress indicator (optional)
                if showProgressRing {
                    ProgressRing(progress: progress, size: 100)
                }

                // Hint text
                Text(hintText)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            // Cancel button
            VStack(spacing: Spacing.sm) {
                SecondaryButton(title: "İptal", icon: "xmark") {
                    Haptics.warning()
                    onCancel()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .appBackgroundLayered()
        .onAppear {
            startSimulatedProgress()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var showProgressRing: Bool {
        currentStage == .uploading || currentStage == .downloading
    }

    private var hintText: String {
        switch currentStage {
        case .preparing:
            return "Dosya hazırlanıyor..."
        case .uploading:
            return "Dosya yükleniyor. Bu işlem dosya boyutuna göre birkaç dakika sürebilir."
        case .optimizing:
            return "Dosya optimize ediliyor. Lütfen bekleyin..."
        case .downloading:
            return "Optimize edilmiş dosya indiriliyor..."
        }
    }

    // MARK: - Simulated Progress (Demo)
    private func startSimulatedProgress() {
        var elapsed: Double = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1

            withAnimation(AppAnimation.standard) {
                // Stage transitions
                if elapsed < 1.5 {
                    currentStage = .preparing
                    progress = 0
                } else if elapsed < 4 {
                    if currentStage == .preparing {
                        completedStages.insert(.preparing)
                    }
                    currentStage = .uploading
                    progress = min((elapsed - 1.5) / 2.5, 1.0)
                } else if elapsed < 7 {
                    if currentStage == .uploading {
                        completedStages.insert(.uploading)
                    }
                    currentStage = .optimizing
                    progress = 0
                } else if elapsed < 9 {
                    if currentStage == .optimizing {
                        completedStages.insert(.optimizing)
                    }
                    currentStage = .downloading
                    progress = min((elapsed - 7) / 2, 1.0)
                } else {
                    completedStages.insert(.downloading)
                    timer?.invalidate()
                }
            }
        }
    }
}

#Preview {
    ProgressScreen(onCancel: {})
}
