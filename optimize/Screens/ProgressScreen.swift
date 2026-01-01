//
//  ProgressScreen.swift
//  optimize
//
//  Processing progress screen with real compression feedback
//

import SwiftUI

struct ProgressScreen: View {
    let file: FileInfo
    let preset: CompressionPreset
    @ObservedObject var compressionService: UltimatePDFCompressionService
    let onCancel: () -> Void

    @State private var currentFactIndex = 0
    @State private var factOpacity: Double = 1
    @State private var factTimer: Timer?

    // Detailed progress state
    @State private var currentDetailIndex = 0
    @State private var detailOpacity: Double = 1
    @State private var detailTimer: Timer?
    @State private var lastHapticProgress: Double = 0

    // Fun facts / "Did you know" messages
    private let funFacts = [
        "Did you know? 40% of PDFs contain data invisible to the human eye.",
        "Currently putting your fonts on a diet...",
        "Every compressed MB makes a kitten happy. (Source: Us)",
        "Trimming the excess from your file...",
        "Applying digital detox...",
        "Saying goodbye to unnecessary pixels one by one...",
        "Mastering the art of fitting your file into an email...",
        "Hunting down invisible metadata..."
    ]

    private var completedStages: Set<ProcessingStage> {
        var stages: Set<ProcessingStage> = []
        switch compressionService.currentStage {
        case .preparing:
            break
        case .uploading:
            stages.insert(.preparing)
        case .optimizing:
            stages.insert(.preparing)
            stages.insert(.uploading)
        case .downloading:
            stages.insert(.preparing)
            stages.insert(.uploading)
            stages.insert(.optimizing)
        }
        return stages
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader("Processing")

            Spacer()

            VStack(spacing: Spacing.xl) {
                // Animated processing visual
                ProcessingAnimation(
                    stage: compressionService.currentStage,
                    progress: compressionService.progress
                )

                // File being processed
                HStack(spacing: Spacing.sm) {
                    Image(systemName: file.fileType.icon)
                        .foregroundStyle(Color.appAccent)
                    Text(file.name)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, Spacing.md)

                // Stage Timeline
                GlassCard {
                    StageTimeline(
                        currentStage: compressionService.currentStage,
                        completedStages: completedStages
                    )
                }
                .padding(.horizontal, Spacing.md)

                // Detailed progress card
                DetailedProgressCard(
                    stage: compressionService.currentStage,
                    progress: compressionService.progress,
                    currentDetailIndex: currentDetailIndex,
                    detailOpacity: detailOpacity
                )
                .padding(.horizontal, Spacing.md)

                // Progress percentage
                if compressionService.currentStage == .optimizing {
                    Text("\(Int(compressionService.progress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appMint)
                        .accessibilityLabel("Compression progress: \(Int(compressionService.progress * 100)) percent")
                }

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
                SecondaryButton(title: "Cancel", icon: "xmark") {
                    Haptics.warning()
                    factTimer?.invalidate()
                    onCancel()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .appBackgroundLayered()
        .onAppear {
            startFactRotation()
            startDetailRotation()
            Haptics.impact(style: .light) // Initial haptic on screen appear
        }
        .onDisappear {
            factTimer?.invalidate()
            detailTimer?.invalidate()
        }
        .onChange(of: compressionService.progress) { _, newProgress in
            triggerProgressHaptic(progress: newProgress)
        }
        .onChange(of: compressionService.currentStage) { _, newStage in
            // Reset detail index when stage changes
            currentDetailIndex = 0
            Haptics.impact(style: .medium) // Haptic on stage change
        }
    }

    private func startFactRotation() {
        let factsCount = funFacts.count
        factTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak factTimer] _ in
            Task { @MainActor in
                // Fade out
                withAnimation(.easeOut(duration: 0.3)) {
                    factOpacity = 0
                }

                // Change fact and fade in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                currentFactIndex = (currentFactIndex + 1) % factsCount
                withAnimation(.easeIn(duration: 0.3)) {
                    factOpacity = 1
                }
            }
        }
    }

    private func startDetailRotation() {
        detailTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak detailTimer] _ in
            Task { @MainActor [weak compressionService] in
                guard let service = compressionService else { return }
                let messages = service.currentStage.detailMessages
                guard !messages.isEmpty else { return }

                // Fade out
                withAnimation(.easeOut(duration: 0.2)) {
                    detailOpacity = 0
                }

                // Change detail and fade in
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                currentDetailIndex = (currentDetailIndex + 1) % messages.count
                withAnimation(.easeIn(duration: 0.2)) {
                    detailOpacity = 1
                }
            }
        }
    }

    private func triggerProgressHaptic(progress: Double) {
        // Trigger haptic every 25%
        let milestones: [Double] = [0.25, 0.50, 0.75, 1.0]

        for milestone in milestones {
            if lastHapticProgress < milestone && progress >= milestone {
                Haptics.impact(style: .soft)
                lastHapticProgress = progress
                break
            }
        }
    }
}

// MARK: - Detailed Progress Card
struct DetailedProgressCard: View {
    let stage: ProcessingStage
    let progress: Double
    let currentDetailIndex: Int
    let detailOpacity: Double

    private var currentMessage: String {
        let messages = stage.detailMessages
        guard !messages.isEmpty else { return "" }
        let safeIndex = currentDetailIndex % messages.count
        return messages[safeIndex]
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Animated dots indicator
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationScale(for: index))
                }
            }
            .frame(width: 30)

            // Detail message
            Text(currentMessage)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .opacity(detailOpacity)

            Spacer()

            // Stage indicator badge
            Text(stage.rawValue)
                .font(.caption2.bold())
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.appAccent.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.appSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private func animationScale(for index: Int) -> CGFloat {
        let phase = (Date().timeIntervalSince1970 * 3).truncatingRemainder(dividingBy: 3)
        let currentIndex = Int(phase)
        return currentIndex == index ? 1.3 : 0.8
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
                        Color.appAccent.opacity(Opacity.subtle - Double(index) * 0.03),
                        lineWidth: 2
                    )
                    .frame(width: 120 + CGFloat(index) * 30, height: 120 + CGFloat(index) * 30)
                    .rotationEffect(.degrees(rotation + Double(index) * 30))
            }

            // Progress ring (for optimizing stage)
            if stage == .optimizing {
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
                    .fill(Color.appAccent.opacity(Opacity.subtle))
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
    ProgressScreen(
        file: FileInfo(
            name: "Test.pdf",
            url: URL(fileURLWithPath: "/test.pdf"),
            size: 100_000_000,
            pageCount: 10,
            fileType: .pdf
        ),
        preset: CompressionPreset.defaultPresets[0],
        compressionService: UltimatePDFCompressionService.shared,
        onCancel: {}
    )
}
