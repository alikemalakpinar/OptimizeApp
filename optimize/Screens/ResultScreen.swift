//
//  ResultScreen.swift
//  optimize
//
//  Compression result screen with confetti, victory stamp and visual comparison
//

import SwiftUI
import UIKit
import StoreKit

struct ResultScreen: View {
    let result: CompressionResult

    let onShare: () -> Void
    let onSave: () -> Void
    let onNewFile: () -> Void

    @State private var showConfetti = false
    @State private var animateResults = false
    @State private var shareButtonPulse = false
    @State private var showVictoryStamp = false
    @State private var screenShakeOffset: CGFloat = 0  // ENHANCED: Screen shake effect

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Animated Success header with Victory Stamp
                        ZStack {
                            EnhancedSuccessHeader(savingsPercent: result.savingsPercent)

                            // Victory Stamp overlay - appears for high savings
                            // ENHANCED: Now triggers screen shake on impact
                            if showVictoryStamp && result.savingsPercent >= 40 {
                                VictoryStampView(
                                    savingsPercent: result.savingsPercent,
                                    onStampImpact: triggerScreenShake
                                )
                                .offset(x: 80, y: -20)
                            }
                        }
                        .padding(.top, Spacing.xl)

                        // Visual comparison bar
                        VisualComparisonCard(
                            originalSize: result.originalFile.sizeMB,
                            compressedSize: result.compressedSizeMB,
                            savingsPercent: result.savingsPercent,
                            animate: animateResults
                        )
                        .padding(.horizontal, Spacing.md)

                        // ENHANCED: Quality assurance badge - addresses "is my file corrupted?" concern
                        QualityAssuranceBadge()
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
                        title: AppStrings.ResultScreen.share,
                        icon: "square.and.arrow.up",
                        isPulsing: shareButtonPulse
                    ) {
                        Haptics.impact()
                        onShare()
                    }

                    SecondaryButton(title: AppStrings.ResultScreen.saveFiles, icon: "square.and.arrow.down") {
                        onSave()
                    }

                    TextButton(title: AppStrings.ResultScreen.newFile, icon: "arrow.counterclockwise") {
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
        // ENHANCED: Screen shake effect for dramatic stamp impact
        .offset(x: screenShakeOffset)
        .appBackgroundLayered()
        .onAppear {
            triggerCelebration()
        }
    }

    /// ENHANCED: Screen shake effect when victory stamp impacts
    /// Creates a "GÜM" effect with heavy haptic and visual shake
    private func triggerScreenShake() {
        // Heavy haptic feedback - the "GÜM" effect
        Haptics.impact(style: .heavy)

        // Screen shake animation sequence
        withAnimation(.linear(duration: 0.05)) {
            screenShakeOffset = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.linear(duration: 0.05)) {
                screenShakeOffset = -6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.linear(duration: 0.05)) {
                screenShakeOffset = 4
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.linear(duration: 0.05)) {
                screenShakeOffset = -2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.linear(duration: 0.05)) {
                screenShakeOffset = 0
            }
        }

        // Second heavy haptic after shake for extra impact
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Haptics.impact(style: .heavy)
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

        // Show Victory Stamp for high savings (40%+) with dramatic "stamp" effect
        if result.savingsPercent >= 40 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    showVictoryStamp = true
                }
                // Heavy haptic feedback - the "GÜM" effect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    Haptics.impact(style: .heavy)
                }
            }
        }

        // Start share button pulsing after results animate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            shareButtonPulse = true
        }

        // Request App Store review if savings are significant (>40%)
        if result.savingsPercent > 40 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                requestAppStoreReview()
            }
        }
    }

    private func requestAppStoreReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
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
                Text(AppStrings.ResultScreen.greatJob)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(AppStrings.ResultScreen.featherText)
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
                    Text(AppStrings.ResultScreen.before)
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
                    Text(AppStrings.ResultScreen.after)
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

            Text(AppStrings.ResultScreen.saved)
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

// MARK: - Victory Stamp View
/// Premium "OPTIMIZED" stamp animation that appears for high savings (40%+)
/// Creates a "dopamine hit" moment with spring animation, screen shake and haptic feedback
/// ENHANCED: Added screen shake effect and stronger visual impact
struct VictoryStampView: View {
    let savingsPercent: Int
    var onStampImpact: (() -> Void)? = nil

    @State private var scale: CGFloat = 2.5
    @State private var opacity: Double = 0.0
    @State private var rotation: Double = -25
    @State private var showImpactRing = false

    /// Dynamic stamp text based on savings level - Localized
    private var stampText: String {
        if savingsPercent >= 80 {
            return AppStrings.VictoryStamp.legendary
        } else if savingsPercent >= 60 {
            return AppStrings.VictoryStamp.amazing
        } else {
            return AppStrings.VictoryStamp.optimized
        }
    }

    /// Dynamic color based on savings level
    private var stampColor: Color {
        if savingsPercent >= 80 {
            return Color.warmOrange
        } else if savingsPercent >= 60 {
            return Color.premiumPurple
        } else {
            return Color.appMint
        }
    }

    var body: some View {
        ZStack {
            // Impact ring animation - expands outward on stamp
            if showImpactRing {
                Circle()
                    .stroke(stampColor.opacity(0.5), lineWidth: 3)
                    .frame(width: 150, height: 150)
                    .scaleEffect(showImpactRing ? 1.5 : 0.5)
                    .opacity(showImpactRing ? 0 : 1)
            }

            // Outer stamp circle with serrated edge effect
            Circle()
                .strokeBorder(stampColor, lineWidth: 3)
                .frame(width: 100, height: 100)
                .overlay(
                    // Inner dashed circle for authentic stamp look
                    Circle()
                        .strokeBorder(stampColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 88, height: 88)
                )

            // Stamp text with serif font for official/premium feel
            VStack(spacing: 2) {
                Text(stampText)
                    .font(.system(size: savingsPercent >= 80 ? 11 : 13, weight: .black, design: .serif))
                    .tracking(1.5)
                    .foregroundStyle(stampColor)

                // Savings percentage badge
                Text("\(savingsPercent)%")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(stampColor)

                // Small decorative line
                Rectangle()
                    .fill(stampColor.opacity(0.5))
                    .frame(width: 40, height: 1)
            }
        }
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            // ENHANCED: "GÜM" stamp effect - dramatic spring animation with impact ring
            withAnimation(.spring(response: 0.35, dampingFraction: 0.4, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
                rotation = -15
            }

            // Show impact ring expanding outward
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showImpactRing = true
                }
                // Trigger screen shake callback
                onStampImpact?()
            }
        }
    }
}

// MARK: - Quality Assurance Badge
/// Shows user that quality is preserved - addresses "my file is corrupted?" concern
struct QualityAssuranceBadge: View {
    @State private var showCheck = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.appMint.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: showCheck ? "checkmark.shield.fill" : "shield")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appMint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.QualityBadge.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(AppStrings.QualityBadge.description)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showCheck = true
                }
            }
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
