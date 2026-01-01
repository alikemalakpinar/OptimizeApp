//
//  ResultScreen.swift
//  optimize
//
//  Compression result screen with confetti and visual comparison
//

import SwiftUI

struct ResultScreen: View {
    let result: CompressionResult

    let onShare: () -> Void
    let onSave: () -> Void
    let onNewFile: () -> Void

    @State private var showConfetti = false
    @State private var animateResults = false
    @State private var shareButtonPulse = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Animated Success header
                        EnhancedSuccessHeader(savingsPercent: result.savingsPercent)
                            .padding(.top, Spacing.xl)

                        // Visual comparison bar
                        VisualComparisonCard(
                            originalSize: result.originalFile.sizeMB,
                            compressedSize: result.compressedSizeMB,
                            savingsPercent: result.savingsPercent,
                            animate: animateResults
                        )
                        .padding(.horizontal, Spacing.md)

                        // Before/After visual comparison slider
                        BeforeAfterSlider(
                            originalURL: result.originalFile.url,
                            compressedURL: result.compressedURL
                        )
                        .padding(.horizontal, Spacing.md)

                        // Result numbers
                        EnhancedResultNumbers(
                            fromSizeMB: result.originalFile.sizeMB,
                            toSizeMB: result.compressedSizeMB,
                            percentSaved: result.savingsPercent,
                            animate: animateResults
                        )
                        .padding(.horizontal, Spacing.md)

                        // Output file info
                        OutputFileInfo(fileName: compressedFileName)
                            .padding(.horizontal, Spacing.md)

                        // Privacy reminder
                        PrivacyBadge()
                            .padding(.horizontal, Spacing.md)

                        Spacer(minLength: Spacing.xl)
                    }
                }

                // Action buttons
                VStack(spacing: Spacing.sm) {
                    // Pulsing share button
                    PulsingPrimaryButton(
                        title: "Share Now",
                        icon: "square.and.arrow.up",
                        isPulsing: shareButtonPulse
                    ) {
                        Haptics.impact()
                        onShare()
                    }

                    SecondaryButton(title: "Save to Files", icon: "square.and.arrow.down") {
                        onSave()
                    }

                    TextButton(title: "Select new file", icon: "arrow.counterclockwise") {
                        onNewFile()
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(Color.appBackground)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .appBackgroundLayered()
        .onAppear {
            triggerCelebration()
        }
    }

    private var compressedFileName: String {
        let name = result.originalFile.name
        let ext = (name as NSString).pathExtension
        let baseName = (name as NSString).deletingPathExtension
        return "\(baseName)_optimized.\(ext)"
    }

    private func triggerCelebration() {
        // Play success sound
        SoundManager.shared.playSuccessSound()
        Haptics.success()

        // Show confetti
        withAnimation {
            showConfetti = true
        }

        // Animate results after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateResults = true
            }
        }

        // Start share button pulsing after results animate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            shareButtonPulse = true
        }
    }
}

// MARK: - Enhanced Success Header
struct EnhancedSuccessHeader: View {
    let savingsPercent: Int

    @State private var checkScale: CGFloat = 0
    @State private var titleOpacity: Double = 0

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Animated checkmark
            ZStack {
                // Glow
                Circle()
                    .fill(Color.appMint.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                // Circle background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.appMint, .appTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(checkScale)

            // Title
            VStack(spacing: Spacing.xs) {
                Text("Great Job!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Your file is now light as a feather")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }
            .opacity(titleOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                checkScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
                titleOpacity = 1.0
            }
        }
    }
}

// MARK: - Visual Comparison Card
struct VisualComparisonCard: View {
    let originalSize: Double
    let compressedSize: Double
    let savingsPercent: Int
    let animate: Bool

    private var compressedRatio: CGFloat {
        guard originalSize > 0 else { return 0 }
        let ratio = compressedSize / originalSize
        return CGFloat(min(max(ratio, 0), 1))
    }

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                // Before bar
                HStack(spacing: Spacing.sm) {
                    Text("Before")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)

                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: animate ? geometry.size.width : 0)
                    }
                    .frame(height: 24)

                    Text(String(format: "%.1f MB", originalSize))
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                }

                // After bar (animated)
                HStack(spacing: Spacing.sm) {
                    Text("After")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)

                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.appMint, .appTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: animate ? geometry.size.width * compressedRatio : 0)
                    }
                    .frame(height: 24)

                    Text(String(format: "%.1f MB", compressedSize))
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.appMint)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animate)
    }
}

// MARK: - Enhanced Result Numbers
struct EnhancedResultNumbers: View {
    let fromSizeMB: Double
    let toSizeMB: Double
    let percentSaved: Int
    let animate: Bool

    @State private var displayedPercent: Int = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Giant percentage
            Text("\(displayedPercent)%")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appMint, .appTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Saved")
                .font(.appTitle)
                .foregroundStyle(.secondary)
        }
        .onChange(of: animate) { _, newValue in
            if newValue {
                animatePercentage()
            }
        }
    }

    private func animatePercentage() {
        guard percentSaved > 0 else {
            displayedPercent = 0
            return
        }

        let duration: Double = 1.0
        let steps = min(max(percentSaved, 1), 50) // Cap at 50 steps for performance
        let stepValue = Double(percentSaved) / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration / Double(steps)) * Double(step)) {
                let value = Int(round(stepValue * Double(step)))
                displayedPercent = min(value, percentSaved)
            }
        }
    }
}

// MARK: - Pulsing Primary Button
struct PulsingPrimaryButton: View {
    let title: String
    let icon: String
    var isPulsing: Bool = false
    let action: () -> Void

    @State private var glowOpacity: Double = 0.3

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.appBodyMedium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.appMint, .appTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color.appMint.opacity(glowOpacity), radius: 12)
        }
        .buttonStyle(.pressable)
        .onAppear {
            if isPulsing {
                startPulsing()
            }
        }
        .onChange(of: isPulsing) { _, newValue in
            if newValue {
                startPulsing()
            }
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            glowOpacity = 0.6
        }
    }
}

#Preview {
    ResultScreen(
        result: CompressionResult(
            originalFile: FileInfo(
                name: "Rapor_2024.pdf",
                url: URL(fileURLWithPath: "/test.pdf"),
                size: 300_000_000,
                pageCount: 84,
                fileType: .pdf
            ),
            compressedURL: URL(fileURLWithPath: "/compressed.pdf"),
            compressedSize: 92_000_000
        ),
        onShare: {},
        onSave: {},
        onNewFile: {}
    )
}
