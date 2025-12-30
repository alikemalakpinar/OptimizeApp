//
//  OnboardingScreen.swift
//  optimize
//
//  Onboarding flow with 3 pages - Enhanced with animations and compelling copy
//

import SwiftUI

struct OnboardingScreen: View {
    @State private var currentPage = 0
    @State private var showShimmer = false
    let onComplete: () -> Void

    // Enhanced pages with result-oriented copy
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "doc.zipper",
            iconAnimation: .compress,
            accentColor: .appAccent,
            title: "Dosyalar Artık\nEngel Değil",
            subtitle: "GB'larca veriyi kaliteden ödün vermeden MB'lara dönüştür. E-posta ve WhatsApp sınırlarına takılma."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            iconAnimation: .shield,
            accentColor: .appMint,
            title: "Tamamen Cihazında,\nTamamen Güvende",
            subtitle: "Dosyaların asla sunuculara gönderilmez. İnternet olmasa bile güvenle çalışır."
        ),
        OnboardingPage(
            icon: "bolt.fill",
            iconAnimation: .bolt,
            accentColor: .appTeal,
            title: "Tek Dokunuşla\nÖzgürleş",
            subtitle: "Karmaşık ayarlar yok. Dosyanı seç, küçült ve anında paylaş."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Pages
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page, isActive: currentPage == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Bottom section
            VStack(spacing: Spacing.lg) {
                // Custom page indicators with active animation
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? pages[currentPage].accentColor : Color.secondary.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(AppAnimation.spring, value: currentPage)
                    }
                }

                // Continue button with shimmer
                ShimmerButton(
                    title: currentPage == pages.count - 1 ? "Hadi Başlayalım" : "Devam",
                    accentColor: pages[currentPage].accentColor,
                    showShimmer: currentPage == pages.count - 1
                ) {
                    if currentPage < pages.count - 1 {
                        withAnimation(AppAnimation.spring) {
                            currentPage += 1
                        }
                        Haptics.selection()
                    } else {
                        Haptics.success()
                        onComplete()
                    }
                }
                .padding(.horizontal, Spacing.lg)

                // Skip button (only on non-last pages)
                if currentPage < pages.count - 1 {
                    Button(action: {
                        Haptics.selection()
                        onComplete()
                    }) {
                        Text("Şimdilik Geç")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Placeholder for layout consistency
                    Text(" ")
                        .font(.appCaption)
                }
            }
            .padding(.bottom, Spacing.xl)
        }
        .appBackgroundLayered()
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let iconAnimation: IconAnimationType
    let accentColor: Color
    let title: String
    let subtitle: String

    enum IconAnimationType {
        case compress
        case shield
        case bolt
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Animated Icon Container
            ZStack {
                // Background circles with animation
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(page.accentColor.opacity(0.08 - Double(index) * 0.02))
                        .frame(width: 160 + CGFloat(index) * 40, height: 160 + CGFloat(index) * 40)
                        .scaleEffect(1 + animationPhase * 0.05 * CGFloat(index + 1))
                }

                // Main icon circle
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 160, height: 160)

                // Animated icon based on type
                Group {
                    switch page.iconAnimation {
                    case .compress:
                        CompressAnimationIcon(color: page.accentColor, isActive: isActive)
                    case .shield:
                        ShieldAnimationIcon(color: page.accentColor, isActive: isActive)
                    case .bolt:
                        BoltAnimationIcon(color: page.accentColor, isActive: isActive)
                    }
                }
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            // Text content
            VStack(spacing: Spacing.md) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(page.subtitle)
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .lineSpacing(2)
            }
            .opacity(iconOpacity)

            Spacer()
            Spacer()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                resetAndAnimate()
            }
        }
        .onAppear {
            if isActive {
                resetAndAnimate()
            }
        }
    }

    private func resetAndAnimate() {
        iconScale = 0.8
        iconOpacity = 0
        animationPhase = 0

        withAnimation(AppAnimation.spring.delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            animationPhase = 1
        }
    }
}

// MARK: - Compress Animation Icon
struct CompressAnimationIcon: View {
    let color: Color
    let isActive: Bool
    @State private var compressionPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Document icon that compresses
            Image(systemName: "doc.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(color)
                .scaleEffect(y: 1 - compressionPhase * 0.3)

            // Compression arrows
            VStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color.opacity(0.6))
                    .offset(y: -40 + compressionPhase * 15)

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color.opacity(0.6))
                    .offset(y: 40 - compressionPhase * 15)
            }
            .frame(height: 120)
        }
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        compressionPhase = 0
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            compressionPhase = 1
        }
    }
}

// MARK: - Shield Animation Icon
struct ShieldAnimationIcon: View {
    let color: Color
    let isActive: Bool
    @State private var lockPhase: CGFloat = 0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(color.opacity(glowOpacity))
                .frame(width: 100, height: 100)
                .blur(radius: 20)

            // Shield with lock
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(1 + lockPhase * 0.05)
        }
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        lockPhase = 0
        glowOpacity = 0.3

        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            lockPhase = 1
            glowOpacity = 0.6
        }
    }
}

// MARK: - Bolt Animation Icon
struct BoltAnimationIcon: View {
    let color: Color
    let isActive: Bool
    @State private var boltOffset: CGFloat = 0
    @State private var trailOpacity: Double = 0

    var body: some View {
        ZStack {
            // Speed trail
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "bolt.fill")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(color.opacity(0.2 - Double(index) * 0.05))
                    .offset(x: CGFloat(index + 1) * -15, y: CGFloat(index + 1) * 8)
                    .opacity(trailOpacity)
            }

            // Main bolt
            Image(systemName: "bolt.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(color)
                .offset(x: boltOffset)
        }
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        boltOffset = 0
        trailOpacity = 0

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            boltOffset = 5
            trailOpacity = 1
        }
    }
}

// MARK: - Shimmer Button
struct ShimmerButton: View {
    let title: String
    let accentColor: Color
    let showShimmer: Bool
    let action: () -> Void

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(accentColor)

                // Shimmer overlay
                if showShimmer {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerPhase * 300 - 150)
                        .mask(
                            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        )
                }

                // Title
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundStyle(.white)
            }
            .frame(height: 56)
        }
        .buttonStyle(.pressable)
        .onAppear {
            if showShimmer {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
        }
        .onChange(of: showShimmer) { _, newValue in
            if newValue {
                shimmerPhase = 0
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
        }
    }
}

#Preview {
    OnboardingScreen {
        print("Onboarding complete")
    }
}
