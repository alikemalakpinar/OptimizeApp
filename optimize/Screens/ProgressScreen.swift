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
    @ObservedObject var compressionService: PDFCompressionService
    let onCancel: () -> Void

    @State private var currentFactIndex = 0
    @State private var factOpacity: Double = 1
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
            ScreenHeader("İşleniyor")

            Spacer()

            VStack(spacing: Spacing.xl) {
                // Animated processing visual
                ProcessingAnimation(
                    stage: compressionService.currentStage,
                    progress: compressionService.progress
                )

                // File being processed
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "doc.fill")
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

                // Progress percentage
                if compressionService.currentStage == .optimizing {
                    Text("\(Int(compressionService.progress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appMint)
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
                SecondaryButton(title: "İptal", icon: "xmark") {
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
        }
        .onDisappear {
            factTimer?.invalidate()
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
    ProgressScreen(
        file: FileInfo(
            name: "Test.pdf",
            url: URL(fileURLWithPath: "/test.pdf"),
            size: 100_000_000,
            pageCount: 10,
            fileType: .pdf
        ),
        preset: CompressionPreset.defaultPresets[0],
        compressionService: PDFCompressionService.shared,
        onCancel: {}
    )
}
