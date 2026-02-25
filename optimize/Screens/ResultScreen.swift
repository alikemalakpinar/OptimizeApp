//
//  ResultScreen.swift
//  optimize
//
//  Premium compression result screen (Apple Intelligence aesthetic).
//
//  UI/UX DESIGN:
//  - Hero Typography: Saved size as the absolute hero (96pt heavy rounded with gradient)
//  - Fluid Background: Dark → bright success wipe transition ("weight being lifted")
//  - "GÜM" Effect: Scale bounce + heavy haptic on percentage reveal
//  - Floating translucent action buttons at bottom
//

import SwiftUI
import StoreKit
import UIKit

struct ResultScreen: View {
    let result: CompressionResult

    let onShare: () -> Void
    let onSave: () -> Void
    let onNewFile: () -> Void

    @State private var animateResults = false
    @State private var showPercentage = false
    @State private var showButtons = false
    @State private var backgroundRevealed = false
    @State private var heroScale: CGFloat = 0.5
    @State private var heroOpacity: Double = 0
    @State private var percentScale: CGFloat = 2.0
    @State private var shareButtonPulse = false

    var body: some View {
        ZStack {
            // Fluid background transition (dark → success color)
            FluidSuccessBackground(revealed: backgroundRevealed)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        Spacer(minLength: Spacing.xxl)

                        // Hero saved size (the absolute hero element)
                        heroSavedSize
                            .padding(.top, Spacing.xl)

                        // Percentage with "GÜM" effect
                        percentageView
                            .padding(.top, Spacing.xs)

                        // Before/After comparison bar
                        VisualComparisonCard(
                            originalSize: result.originalFile.sizeMB,
                            compressedSize: result.compressedSizeMB,
                            savingsPercent: result.savingsPercent,
                            animate: animateResults
                        )
                        .padding(.horizontal, Spacing.md)

                        // Quality assurance badge
                        QualityAssuranceBadge()
                            .padding(.horizontal, Spacing.md)

                        // Photo equivalent
                        photoEquivalentBadge
                            .padding(.horizontal, Spacing.md)

                        Spacer(minLength: Spacing.xl)
                    }
                }

                // Floating translucent action buttons
                floatingButtons
            }
        }
        .onAppear {
            triggerCelebration()
        }
    }

    // MARK: - Hero Saved Size

    private var heroSavedSize: some View {
        VStack(spacing: Spacing.xs) {
            // Tiny label above
            Text(AppStrings.ResultScreen.saved)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .opacity(heroOpacity)

            // Massive saved size - THE hero
            Text(formattedSavedSize)
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appMint, .appTeal, .premiumBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(heroScale)
                .opacity(heroOpacity)
                .padding(.horizontal, Spacing.md)

            // Subtitle
            Text(AppStrings.ResultScreen.featherText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .opacity(heroOpacity)
        }
    }

    // MARK: - Percentage with "GÜM" Effect

    private var percentageView: some View {
        HStack(spacing: Spacing.xs) {
            if showPercentage {
                Text("−\(result.savingsPercent)%")
                    .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(percentColor)
                    .scaleEffect(percentScale)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 50)
        .animation(.spring(duration: 0.4, bounce: 0.5), value: percentScale)
    }

    // MARK: - Photo Equivalent Badge

    private var photoEquivalentBadge: some View {
        Group {
            let savedMB = max(0, result.originalFile.sizeMB - result.compressedSizeMB)
            if savedMB >= 1.0 {
                let photoCount = max(1, Int(savedMB / 3.0))
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(AppStrings.ResultScreen.photoEquivalent(photoCount))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.appMint)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.appMint.opacity(0.1))
                .clipShape(Capsule())
                .opacity(animateResults ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(1.2), value: animateResults)
            }
        }
    }

    // MARK: - Floating Translucent Buttons

    private var floatingButtons: some View {
        VStack(spacing: Spacing.sm) {
            // Primary share button (pulsing)
            PulsingPrimaryButton(
                title: AppStrings.ResultScreen.share,
                icon: "square.and.arrow.up",
                isPulsing: shareButtonPulse
            ) {
                Haptics.impact()
                onShare()
            }

            // Secondary buttons in translucent row
            HStack(spacing: Spacing.sm) {
                Button(action: {
                    Haptics.selection()
                    onSave()
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                        Text(AppStrings.ResultScreen.saveFiles)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }

                Button(action: {
                    Haptics.selection()
                    onNewFile()
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text(AppStrings.ResultScreen.newFile)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .opacity(showButtons ? 1 : 0)
        .offset(y: showButtons ? 0 : 20)
        .animation(.spring(duration: 0.5, bounce: 0.3).delay(1.5), value: showButtons)
    }

    // MARK: - Celebration Sequence

    private func triggerCelebration() {
        // Play success sound
        SoundManager.shared.playSuccessSound()
        Haptics.success()

        // Step 1: Background wipe from dark → success
        withAnimation(.easeOut(duration: 0.8)) {
            backgroundRevealed = true
        }

        // Step 2: Hero size flies in with spring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(duration: 0.7, bounce: 0.4)) {
                heroScale = 1.0
                heroOpacity = 1.0
            }
        }

        // Step 3: Animate comparison bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateResults = true
            }
        }

        // Step 4: "GÜM" percentage reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(duration: 0.35, bounce: 0.6)) {
                showPercentage = true
                percentScale = 1.0
            }
            // Heavy haptic — the "GÜM" effect
            Haptics.impact(style: .heavy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Haptics.impact(style: .heavy)
            }
        }

        // Step 5: Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            showButtons = true
            shareButtonPulse = true
        }

        // Step 6: Request App Store review for high savings
        if result.savingsPercent > 40 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                requestAppStoreReview()
            }
        }
    }

    // MARK: - Helpers

    /// Format saved bytes as "1.4 GB" or "256 MB" — picks the largest appropriate unit
    private var formattedSavedSize: String {
        let savedBytes = result.originalFile.size - result.compressedSize
        guard savedBytes > 0 else { return "0 MB" }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = savedBytes >= 1_000_000_000 ? [.useGB] : [.useMB]
        formatter.includesUnit = true
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: savedBytes)
    }

    private var percentColor: Color {
        if result.savingsPercent >= 60 {
            return .appMint
        } else if result.savingsPercent >= 30 {
            return .premiumBlue
        } else {
            return .secondary
        }
    }

    private var compressedFileName: String {
        let name = result.originalFile.name
        let ext = (name as NSString).pathExtension
        let baseName = (name as NSString).deletingPathExtension
        return "\(baseName)_optimized.\(ext)"
    }

    private func requestAppStoreReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }

        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        }
    }
}

// MARK: - Fluid Success Background

/// Background that wipes from dark to bright success color, simulating "weight being lifted"
private struct FluidSuccessBackground: View {
    let revealed: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base dark layer
            Color.appBackground

            // Success gradient that reveals upward
            LinearGradient(
                colors: [
                    Color.appMint.opacity(colorScheme == .dark ? 0.15 : 0.08),
                    Color.appTeal.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    Color.appBackground
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .opacity(revealed ? 1 : 0)

            // Subtle radial glow at top-center
            RadialGradient(
                colors: [
                    Color.appMint.opacity(colorScheme == .dark ? 0.12 : 0.06),
                    .clear
                ],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .opacity(revealed ? 1 : 0)
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

// MARK: - Quality Assurance Badge

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
