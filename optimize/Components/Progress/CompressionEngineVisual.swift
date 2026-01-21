//
//  CompressionEngineVisual.swift
//  optimize
//
//  Sci-Fi Compression Engine Visualization
//  Creates an impressive "working hard" feel during file processing
//
//  Design Philosophy:
//  - Industrial/mechanical aesthetic with rotating gears
//  - Energy flow visualization showing "compression in action"
//  - Stage-specific animations and iconography
//  - Dramatic but not overwhelming - respects the content
//

import SwiftUI

// MARK: - Compression Engine Visual

/// Main compression engine visualization component
/// Use this for progress screens to show "the engine is working"
struct CompressionEngineVisual: View {
    let progress: Double
    let stage: ProcessingStage
    var size: CGFloat = 200

    @State private var outerRotation: Double = 0
    @State private var middleRotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var energyFlow: Double = 0
    @State private var particlePhase: Double = 0

    @Environment(\.colorScheme) private var colorScheme

    // Brand colors
    private let primaryColor = Color.appMint
    private let secondaryColor = Color.appTeal
    private let accentColor = Color.premiumBlue

    var body: some View {
        ZStack {
            // LAYER 1: Outer ambient glow
            ambientGlow

            // LAYER 2: Outer gear ring
            outerGearRing

            // LAYER 3: Middle energy ring
            middleEnergyRing

            // LAYER 4: Progress track
            progressTrack

            // LAYER 5: Inner core
            innerCore

            // LAYER 6: Energy particles (when optimizing)
            if stage == .optimizing {
                energyParticles
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        ZStack {
            // Soft outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(0.15),
                            primaryColor.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(pulseScale)

            // Accent glow for premium feel
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size, height: size)
        }
    }

    // MARK: - Outer Gear Ring

    private var outerGearRing: some View {
        ZStack {
            // Gear teeth pattern
            ForEach(0..<16, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(primaryColor.opacity(0.2))
                    .frame(width: 4, height: size * 0.08)
                    .offset(y: -size * 0.42)
                    .rotationEffect(.degrees(Double(index) * 22.5))
            }

            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(0.4),
                            secondaryColor.opacity(0.2),
                            primaryColor.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size * 0.88, height: size * 0.88)
        }
        .rotationEffect(.degrees(outerRotation))
    }

    // MARK: - Middle Energy Ring

    private var middleEnergyRing: some View {
        ZStack {
            // Dashed energy ring
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .foregroundStyle(secondaryColor.opacity(0.3))
                .frame(width: size * 0.72, height: size * 0.72)

            // Energy flow segments
            ForEach(0..<8, id: \.self) { index in
                EnergySegment(
                    color: primaryColor,
                    isActive: shouldActivateSegment(index)
                )
                .frame(width: size * 0.08, height: size * 0.03)
                .offset(y: -size * 0.34)
                .rotationEffect(.degrees(Double(index) * 45 + energyFlow))
            }
        }
        .rotationEffect(.degrees(middleRotation))
    }

    // MARK: - Progress Track

    private var progressTrack: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    primaryColor.opacity(0.1),
                    lineWidth: size * 0.04
                )
                .frame(width: size * 0.56, height: size * 0.56)

            // Progress arc
            Circle()
                .trim(from: 0, to: effectiveProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            primaryColor,
                            secondaryColor,
                            primaryColor.opacity(0.8)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(
                        lineWidth: size * 0.04,
                        lineCap: .round
                    )
                )
                .frame(width: size * 0.56, height: size * 0.56)
                .rotationEffect(.degrees(-90))
                .shadow(color: primaryColor.opacity(0.5), radius: 4)

            // Progress endpoint glow
            if effectiveProgress > 0.05 {
                Circle()
                    .fill(primaryColor)
                    .frame(width: size * 0.02, height: size * 0.02)
                    .offset(y: -size * 0.28)
                    .rotationEffect(.degrees(effectiveProgress * 360 - 90))
                    .glow(color: primaryColor, radius: 6, animated: false)
            }
        }
    }

    // MARK: - Inner Core

    private var innerCore: some View {
        ZStack {
            // Inner glow circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(0.2),
                            primaryColor.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.2
                    )
                )
                .frame(width: size * 0.42, height: size * 0.42)

            // Inner ring
            Circle()
                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                .frame(width: size * 0.38, height: size * 0.38)
                .rotationEffect(.degrees(innerRotation))

            // Core background
            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color(.systemBackground)
                        : Color.white
                )
                .frame(width: size * 0.32, height: size * 0.32)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.3), secondaryColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            // Stage icon
            stageIcon
        }
    }

    // MARK: - Stage Icon

    private var stageIcon: some View {
        Image(systemName: stage.engineIcon)
            .font(.system(size: size * 0.12, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .symbolEffect(.pulse, isActive: stage == .optimizing)
    }

    // MARK: - Energy Particles

    private var energyParticles: some View {
        ForEach(0..<6, id: \.self) { index in
            Circle()
                .fill(primaryColor)
                .frame(width: 4, height: 4)
                .offset(y: -size * (0.2 + particlePhase * 0.15))
                .rotationEffect(.degrees(Double(index) * 60 + particlePhase * 180))
                .opacity(1 - particlePhase)
        }
    }

    // MARK: - Helpers

    private var effectiveProgress: Double {
        switch stage {
        case .preparing: return 0.1
        case .uploading: return 0.25
        case .optimizing: return 0.25 + progress * 0.65
        case .downloading: return 1.0
        }
    }

    private func shouldActivateSegment(_ index: Int) -> Bool {
        let activeCount = Int(progress * 8) + 1
        return index < activeCount
    }

    private func startAnimations() {
        // Outer ring - slow rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            outerRotation = 360
        }

        // Middle ring - counter-rotation
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            middleRotation = -360
        }

        // Inner ring - fast rotation
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            innerRotation = 360
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }

        // Energy flow
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            energyFlow = 360
        }

        // Particle animation
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            particlePhase = 1
        }
    }
}

// MARK: - Energy Segment

private struct EnergySegment: View {
    let color: Color
    let isActive: Bool

    @State private var glowing = false

    var body: some View {
        Capsule()
            .fill(color.opacity(isActive ? 0.8 : 0.2))
            .shadow(color: isActive ? color.opacity(0.6) : .clear, radius: 3)
            .scaleEffect(isActive && glowing ? 1.2 : 1.0)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        glowing = true
                    }
                }
            }
    }
}

// MARK: - Processing Stage Extension

extension ProcessingStage {
    /// Icon for compression engine visualization
    var engineIcon: String {
        switch self {
        case .preparing: return "doc.text.magnifyingglass"
        case .uploading: return "arrow.up.doc.fill"
        case .optimizing: return "gearshape.2.fill"
        case .downloading: return "checkmark.seal.fill"
        }
    }

    /// Processing stage description for engine display
    var engineDescription: String {
        switch self {
        case .preparing: return "Dosya Analizi"
        case .uploading: return "Veri İşleme"
        case .optimizing: return "Sıkıştırma Motoru"
        case .downloading: return "Tamamlanıyor"
        }
    }
}

// MARK: - Compression Stats Display

/// Displays real-time compression statistics below the engine
struct CompressionStatsDisplay: View {
    let originalSize: Int64
    let progress: Double
    let stage: ProcessingStage

    @State private var estimatedSaving: Int = 0
    @State private var displayedProgress: Double = 0

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Stage label
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color.appMint)
                    .frame(width: 8, height: 8)
                    .opacity(stage == .optimizing ? 1 : 0.5)

                Text(stage.engineDescription)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            // Progress percentage
            if stage == .optimizing {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appMint, Color.appTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .contentTransition(.numericText(value: progress))
                    .animation(.spring(response: 0.3), value: progress)
            }

            // Estimated savings indicator
            if progress > 0.3 && stage == .optimizing {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appMint)

                    Text("Tahmini Tasarruf: ~\(estimatedSavingText)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Color.appMint.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .onChange(of: progress) { _, newValue in
            updateEstimatedSaving(progress: newValue)
        }
    }

    private var estimatedSavingText: String {
        let savingBytes = Int64(Double(originalSize) * 0.4 * progress) // Estimated 40% savings
        return ByteCountFormatter.string(fromByteCount: savingBytes, countStyle: .file)
    }

    private func updateEstimatedSaving(progress: Double) {
        let baseSaving = 30 + Int(progress * 20) // 30-50% estimated
        withAnimation(.spring(response: 0.3)) {
            estimatedSaving = baseSaving
        }
    }
}

// MARK: - Preview

#Preview("Compression Engine") {
    VStack(spacing: 40) {
        CompressionEngineVisual(
            progress: 0.65,
            stage: .optimizing,
            size: 200
        )

        CompressionStatsDisplay(
            originalSize: 50_000_000,
            progress: 0.65,
            stage: .optimizing
        )
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("All Stages") {
    HStack(spacing: 20) {
        ForEach([ProcessingStage.preparing, .uploading, .optimizing, .downloading], id: \.self) { stage in
            VStack {
                CompressionEngineVisual(
                    progress: 0.5,
                    stage: stage,
                    size: 100
                )
                Text(stage.rawValue)
                    .font(.caption)
            }
        }
    }
    .padding()
}
