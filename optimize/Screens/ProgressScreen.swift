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
    @State private var showContent = false
    @State private var pulseAnimation = false

    @Environment(\.colorScheme) private var colorScheme

    // Fun facts / "Did you know" messages
    private let funFacts = [
        "Biliyor muydunuz? PDF'lerin %40'ı gözle görülemeyen veri içerir.",
        "Fontlarınızı diyete sokuyoruz...",
        "Her sıkıştırılan MB bir kedi mutlu ediyor. (Kaynak: Biz)",
        "Dosyanızdaki fazlalıkları kesiyoruz...",
        "Dijital detoks uyguluyoruz...",
        "Gereksiz piksellere tek tek veda ediyoruz...",
        "Dosyanızı e-postaya sığdırma sanatında ustalaşıyoruz...",
        "Görünmez metadata avına çıkıyoruz..."
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
        ZStack {
            // Enhanced background
            ProgressBackgroundGradient()

            VStack(spacing: 0) {
                // Header
                ScreenHeader("Processing")

                Spacer()

                VStack(spacing: Spacing.lg) {
                    // Enhanced circular progress visualization
                    EnhancedProcessingRing(
                        progress: compressionService.progress,
                        stage: compressionService.currentStage,
                        pulseAnimation: pulseAnimation
                    )
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.9)

                    // File info card
                    FileInfoCard(file: file)
                        .padding(.horizontal, Spacing.md)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)

                    // Stage Timeline - Enhanced
                    EnhancedStageTimeline(
                        currentStage: compressionService.currentStage,
                        completedStages: completedStages
                    )
                    .padding(.horizontal, Spacing.md)
                    .opacity(showContent ? 1 : 0)

                    // Detailed progress card
                    EnhancedDetailedProgressCard(
                        stage: compressionService.currentStage,
                        progress: compressionService.progress,
                        currentDetailIndex: currentDetailIndex,
                        detailOpacity: detailOpacity
                    )
                    .padding(.horizontal, Spacing.md)
                    .opacity(showContent ? 1 : 0)

                    // Progress percentage - Large and prominent
                    if compressionService.currentStage == .optimizing {
                        Text("\(Int(compressionService.progress * 100))%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appMint, Color.appTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .contentTransition(.numericText(value: compressionService.progress))
                            .accessibilityLabel("Sıkıştırma ilerlemesi: \(Int(compressionService.progress * 100)) yüzde")
                    }

                    // Fun fact card
                    EnhancedFunFactCard(
                        fact: funFacts[currentFactIndex],
                        opacity: factOpacity
                    )
                    .padding(.horizontal, Spacing.md)
                    .opacity(showContent ? 1 : 0)
                }

                Spacer()

                // Cancel button - Enhanced
                VStack(spacing: Spacing.sm) {
                    Button(action: {
                        Haptics.warning()
                        factTimer?.invalidate()
                        onCancel()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("İptal")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
        }
        .onAppear {
            startFactRotation()
            startDetailRotation()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            Haptics.impact(style: .light)
        }
        .onDisappear {
            factTimer?.invalidate()
            detailTimer?.invalidate()
        }
        .onChange(of: compressionService.progress) { oldProgress, newProgress in
            let oldMilestone = Int(oldProgress * 4)
            let newMilestone = Int(newProgress * 4)
            if newMilestone > oldMilestone {
                triggerProgressHaptic(progress: newProgress)
            }
        }
        .onChange(of: compressionService.currentStage) { _, newStage in
            currentDetailIndex = 0
            Haptics.impact(style: .medium)
        }
    }

    private func startFactRotation() {
        let factsCount = funFacts.count
        factTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
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
        detailTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
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

// MARK: - Progress Background Gradient
private struct ProgressBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)

            GeometryReader { geo in
                // Top teal gradient orb
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.appTeal.opacity(colorScheme == .dark ? 0.12 : 0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8, height: geo.size.height * 0.35)
                    .offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.05)

                // Bottom mint gradient
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.appMint.opacity(colorScheme == .dark ? 0.1 : 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.3
                        )
                    )
                    .frame(width: geo.size.width * 0.5, height: geo.size.height * 0.3)
                    .offset(x: 0, y: geo.size.height * 0.65)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Enhanced Processing Ring
private struct EnhancedProcessingRing: View {
    let progress: Double
    let stage: ProcessingStage
    let pulseAnimation: Bool

    @State private var rotation: Double = 0

    private var stageIcon: String {
        switch stage {
        case .preparing: return "doc.text.magnifyingglass"
        case .uploading: return "arrow.up.doc"
        case .optimizing: return "gearshape.2"
        case .downloading: return "checkmark.circle"
        }
    }

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.appTeal.opacity(0.2), Color.appMint.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 160, height: 160)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)

            // Background track
            Circle()
                .stroke(Color.appMint.opacity(0.15), lineWidth: 8)
                .frame(width: 130, height: 130)

            // Progress arc
            Circle()
                .trim(from: 0, to: stage == .optimizing ? progress : (stage == .downloading ? 1.0 : 0.0))
                .stroke(
                    LinearGradient(
                        colors: [Color.appMint, Color.appTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)

            // Inner circle with icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appMint.opacity(0.15), Color.appTeal.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                // Rotating inner decoration
                Circle()
                    .stroke(Color.appTeal.opacity(0.1), lineWidth: 1)
                    .frame(width: 85, height: 85)
                    .rotationEffect(.degrees(rotation))

                // Icon
                Image(systemName: stageIcon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appMint, Color.appTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - File Info Card
private struct FileInfoCard: View {
    let file: FileInfo
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // File icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.appAccent.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: file.fileType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }

            // File name
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(file.sizeFormatted)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Enhanced Stage Timeline
private struct EnhancedStageTimeline: View {
    let currentStage: ProcessingStage
    let completedStages: Set<ProcessingStage>
    @Environment(\.colorScheme) private var colorScheme

    private let stages: [ProcessingStage] = [.preparing, .uploading, .optimizing, .downloading]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(stages.indices, id: \.self) { index in
                let stage = stages[index]
                let isCompleted = completedStages.contains(stage)
                let isCurrent = currentStage == stage

                EnhancedTimelineStep(
                    icon: stage.icon,
                    label: stage.displayName,
                    isCompleted: isCompleted,
                    isCurrent: isCurrent
                )

                if index < stages.count - 1 {
                    TimelineStepConnector(isCompleted: completedStages.contains(stages[index + 1]) || currentStage == stages[index + 1])
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

private struct EnhancedTimelineStep: View {
    let icon: String
    let label: String
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        isCompleted ? Color.appMint.opacity(0.15) :
                        (isCurrent ? Color.appAccent.opacity(0.15) : Color.secondary.opacity(0.08))
                    )
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.appMint)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isCurrent ? Color.appAccent : .secondary)
                }
            }

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(isCompleted || isCurrent ? .primary : .tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineStepConnector: View {
    let isCompleted: Bool

    var body: some View {
        Rectangle()
            .fill(isCompleted ? Color.appMint.opacity(0.5) : Color.secondary.opacity(0.2))
            .frame(height: 2)
            .frame(maxWidth: 20)
    }
}

// MARK: - Enhanced Detailed Progress Card
private struct EnhancedDetailedProgressCard: View {
    let stage: ProcessingStage
    let progress: Double
    let currentDetailIndex: Int
    let detailOpacity: Double
    @Environment(\.colorScheme) private var colorScheme

    @State private var dotAnimating = false

    private var currentMessage: String {
        let messages = stage.detailMessages
        guard !messages.isEmpty else { return "" }
        let safeIndex = currentDetailIndex % messages.count
        return messages[safeIndex]
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Animated dots indicator
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.appMint)
                        .frame(width: 5, height: 5)
                        .scaleEffect(dotAnimating ? 1.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: dotAnimating
                        )
                }
            }
            .frame(width: 25)

            // Detail message
            Text(currentMessage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .opacity(detailOpacity)

            Spacer()

            // Stage badge
            Text(stage.rawValue)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appMint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.appMint.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
        .onAppear {
            dotAnimating = true
        }
    }
}

// MARK: - Enhanced Fun Fact Card
private struct EnhancedFunFactCard: View {
    let fact: String
    let opacity: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.goldAccent.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.goldAccent)
            }

            Text(fact)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
        )
        .opacity(opacity)
    }
}

// MARK: - Processing Stage Extensions
private extension ProcessingStage {
    var icon: String {
        switch self {
        case .preparing: return "doc.text.magnifyingglass"
        case .uploading: return "arrow.up.doc"
        case .optimizing: return "gearshape.2"
        case .downloading: return "checkmark.circle"
        }
    }

    var displayName: String {
        switch self {
        case .preparing: return "Hazırlık"
        case .uploading: return "Analiz"
        case .optimizing: return "Optimizasyon"
        case .downloading: return "Tamamlama"
        }
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
