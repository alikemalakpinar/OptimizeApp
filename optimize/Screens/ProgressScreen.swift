//
//  ProgressScreen.swift
//  optimize
//
//  Processing progress screen with fun facts and haptic feedback
//

import SwiftUI

struct ProgressScreen: View {
    @State private var currentStage: ProcessingStage = .preparing
    @State private var completedStages: Set<ProcessingStage> = []
    @State private var progress: Double = 0
    @State private var currentFactIndex = 0
    @State private var factOpacity: Double = 1

    let onCancel: () -> Void

    // Simulated progress for demo
    @State private var timer: Timer?
    @State private var factTimer: Timer?

    // Fun facts / "Did you know" messages
    private let funFacts = [
        "Biliyor muydun? PDF'lerin %40'ı insan gözünün görmediği verilerden oluşur.",
        "Şu an dosyanın yazı tiplerini diyete sokuyoruz...",
        "Her sıkıştırılan MB, bir kediyi mutlu eder. (Kaynak: Biz)",
        "Optimize motorları tam güçle çalışıyor...",
        "Gereksiz piksellerle tek tek vedalaşıyoruz...",
        "Dosyanı e-postaya sığdırma sanatı icra ediliyor...",
        "Görünmez metadata'ları avlıyoruz..."
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader("İşleniyor")

            Spacer()

            VStack(spacing: Spacing.xl) {
                // Animated processing visual
                ProcessingAnimation(stage: currentStage, progress: progress)

                // Stage Timeline
                GlassCard {
                    StageTimeline(
                        currentStage: currentStage,
                        completedStages: completedStages
                    )
                }
                .padding(.horizontal, Spacing.md)

                // Fun fact card
                FunFactCard(
                    fact: funFacts[currentFactIndex],
                    opacity: factOpacity
                )
                .padding(.horizontal, Spacing.md)
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
            startFactRotation()
        }
        .onDisappear {
            timer?.invalidate()
            factTimer?.invalidate()
        }
    }

    // MARK: - Simulated Progress (Demo)
    private func startSimulatedProgress() {
        var elapsed: Double = 0
        var lastStage: ProcessingStage?

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1

            withAnimation(AppAnimation.standard) {
                // Stage transitions
                if elapsed < 1.5 {
                    currentStage = .preparing
                    progress = 0
                } else if elapsed < 4 {
                    if currentStage == .preparing && lastStage != .uploading {
                        completedStages.insert(.preparing)
                        Haptics.success() // Haptic on stage complete
                    }
                    currentStage = .uploading
                    progress = min((elapsed - 1.5) / 2.5, 1.0)
                } else if elapsed < 7 {
                    if currentStage == .uploading && lastStage != .optimizing {
                        completedStages.insert(.uploading)
                        Haptics.success()
                    }
                    currentStage = .optimizing
                    progress = 0
                } else if elapsed < 9 {
                    if currentStage == .optimizing && lastStage != .downloading {
                        completedStages.insert(.optimizing)
                        Haptics.success()
                    }
                    currentStage = .downloading
                    progress = min((elapsed - 7) / 2, 1.0)
                } else {
                    if !completedStages.contains(.downloading) {
                        completedStages.insert(.downloading)
                        Haptics.success()
                        SoundManager.shared.playSuccessSound()
                    }
                    timer?.invalidate()
                }

                lastStage = currentStage
            }
        }
    }

    private func startFactRotation() {
        factTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            // Fade out
            withAnimation(.easeOut(duration: 0.3)) {
                factOpacity = 0
            }

            // Change fact and fade in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentFactIndex = (currentFactIndex + 1) % funFacts.count
                withAnimation(.easeIn(duration: 0.3)) {
                    factOpacity = 1
                }
            }
        }
    }
}

// MARK: - Processing Animation
struct ProcessingAnimation: View {
    let stage: ProcessingStage
    let progress: Double

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer rotating rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        Color.appAccent.opacity(0.1 - Double(index) * 0.03),
                        lineWidth: 2
                    )
                    .frame(width: 120 + CGFloat(index) * 30, height: 120 + CGFloat(index) * 30)
                    .rotationEffect(.degrees(rotation + Double(index) * 30))
            }

            // Progress ring (for upload/download stages)
            if stage == .uploading || stage == .downloading {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.appMint, .appTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
            }

            // Center icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)

                Image(systemName: stageIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.appAccent)
                    .symbolPulse(isActive: true)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }

    private var stageIcon: String {
        switch stage {
        case .preparing: return "doc.text.magnifyingglass"
        case .uploading: return "arrow.up.circle"
        case .optimizing: return "gearshape.2"
        case .downloading: return "arrow.down.circle"
        }
    }
}

// MARK: - Fun Fact Card
struct FunFactCard: View {
    let fact: String
    let opacity: Double

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.goldAccent)

            Text(fact)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .opacity(opacity)
    }
}

#Preview {
    ProgressScreen(onCancel: {})
}
