//
//  HomeScreen.swift
//  optimize
//
//  Main home screen with breathing CTA and real history
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeScreen: View {
    @ObservedObject var coordinator: AppCoordinator
    let subscriptionStatus: SubscriptionStatus
    @State private var ctaPulse = false
    @State private var isDropTargeted = false

    let onSelectFile: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onUpgrade: () -> Void

    init(
        coordinator: AppCoordinator,
        subscriptionStatus: SubscriptionStatus,
        onSelectFile: @escaping () -> Void,
        onOpenHistory: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onUpgrade: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.subscriptionStatus = subscriptionStatus
        self.onSelectFile = onSelectFile
        self.onOpenHistory = onOpenHistory
        self.onOpenSettings = onOpenSettings
        self.onUpgrade = onUpgrade
    }

    var recentHistory: [HistoryItem] {
        coordinator.historyManager.recentItems(limit: 3)
    }

    private var totalSavedMB: Double {
        coordinator.historyManager.items.reduce(0) { partial, item in
            partial + max(0, Double(item.originalSize - item.compressedSize) / 1_000_000)
        }
    }

    private var averageSavings: Int {
        let savings = coordinator.historyManager.items.map(\.savingsPercent)
        guard !savings.isEmpty else { return 68 }
        let total = savings.reduce(0, +)
        return Int(Double(total) / Double(savings.count))
    }

    private var bestSavings: Int? {
        coordinator.historyManager.items.map(\.savingsPercent).max()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Dynamic Greeting
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(".optimize") {
                    HeaderIconButton(systemName: "gearshape") {
                        onOpenSettings()
                    }
                }

                // Dynamic Greeting based on time of day
                DynamicGreetingView()
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    MembershipStatusCard(
                        status: subscriptionStatus,
                        onUpgrade: onUpgrade
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)

                    // Main CTA Section with Breathing Effect
                    VStack(spacing: Spacing.lg) {
                        // CTA Card with drop support
                        BreathingCTACard(
                            isDropTargeted: isDropTargeted,
                            onTap: {
                                Haptics.impact()
                                onSelectFile()
                            }
                        )
                        .accessibilityLabel("Select PDF file")
                        .accessibilityHint("Tap or drag and drop to select a PDF file")
                        .dropDestination(for: URL.self) { urls, _ in
                            if let url = urls.first {
                                Haptics.success()
                                coordinator.handlePickedFile(url)
                                return true
                            }
                            return false
                        } isTargeted: { targeted in
                            withAnimation(AppAnimation.spring) {
                                isDropTargeted = targeted
                            }
                        }

                        // Privacy badges
                        PrivacyBadge()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                    ConversionHighlights(
                        totalSavedMB: totalSavedMB,
                        averageSaving: averageSavings,
                        bestSaving: bestSavings
                    )
                    .padding(.horizontal, Spacing.md)

                    // Recent History Section or Empty State
                    if recentHistory.isEmpty {
                        EmptyHistoryState()
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.xl)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text(AppStrings.Home.recentActivity)
                                    .font(.appSection)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button(action: {
                                    onOpenHistory()
                                }) {
                                    Text(AppStrings.Home.viewAll)
                                        .font(.appCaptionMedium)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding(.horizontal, Spacing.md)

                            VStack(spacing: Spacing.xs) {
                                ForEach(Array(recentHistory.enumerated()), id: \.element.id) { index, item in
                                    HistoryRow(item: item)
                                        .staggeredAppearance(index: index)
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        }
                    }

                    Spacer(minLength: Spacing.xl)
                }
            }
        }
        .appBackgroundLayered()
    }
}

// MARK: - Breathing CTA Card
/// CTA card with breathing animation effect
/// ACCESSIBILITY: Respects reduceMotion preference - disables animations when enabled
/// PERFORMANCE: Pauses animation when app goes to background (saves CPU)
struct BreathingCTACard: View {
    let isDropTargeted: Bool
    let onTap: () -> Void

    @State private var breathScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.3
    @State private var isAnimating: Bool = false
    @State private var gradientRotation: Double = 0

    /// Accessibility: Check if user prefers reduced motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Scene phase for pausing animations in background
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.lg) {
                // Icon with breathing effect
                ZStack {
                    // Gradient background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.premiumPurple.opacity(0.15),
                                    Color.premiumBlue.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(breathScale * 1.2)
                        .blur(radius: 20)

                    // Outer breathing rings (hidden when reduceMotion is on)
                    if !reduceMotion {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.premiumPurple.opacity(0.2 - Double(index) * 0.05),
                                            Color.premiumBlue.opacity(0.15 - Double(index) * 0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2 - CGFloat(index) * 0.5
                                )
                                .frame(
                                    width: 88 + CGFloat(index) * 24,
                                    height: 88 + CGFloat(index) * 24
                                )
                                .scaleEffect(breathScale + CGFloat(index) * 0.02)
                                .opacity(ringOpacity - Double(index) * 0.08)
                        }
                    }

                    // Main circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.premiumPurple.opacity(0.15),
                                    Color.premiumBlue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.premiumPurple.opacity(0.4),
                                            Color.premiumBlue.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )

                    // Icon with gradient
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.premiumPurple, Color.premiumBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolBounce(trigger: reduceMotion ? false : isDropTargeted)
                }

                // Text
                VStack(spacing: Spacing.xs) {
                    Text(isDropTargeted ? AppStrings.Home.dropFile : AppStrings.Home.selectFile)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)

                    Text(isDropTargeted ? AppStrings.Home.dropHint : AppStrings.Home.selectHint)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl + Spacing.sm)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)

                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.premiumPurple.opacity(0.03),
                                    Color.premiumBlue.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(
                        isDropTargeted
                            ? LinearGradient(colors: [Color.premiumPurple, Color.premiumBlue], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.glassBorder, Color.glassBorder], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isDropTargeted ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.pressable)
        .onAppear {
            // Only start animation if reduceMotion is off and app is active
            if !reduceMotion && scenePhase == .active {
                startBreathingAnimation()
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            // Stop animation if user enables reduceMotion
            if newValue {
                stopBreathingAnimation()
            } else if scenePhase == .active {
                startBreathingAnimation()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // PERFORMANCE: Pause animation when app goes to background
            // This prevents unnecessary CPU usage
            switch newPhase {
            case .active:
                if !reduceMotion && !isAnimating {
                    startBreathingAnimation()
                }
            case .inactive, .background:
                stopBreathingAnimation()
            @unknown default:
                break
            }
        }
    }

    private func startBreathingAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            breathScale = 1.06
            ringOpacity = 0.5
        }
    }

    private func stopBreathingAnimation() {
        isAnimating = false

        withAnimation(.easeOut(duration: 0.3)) {
            breathScale = 1.0
            ringOpacity = 0.3
        }
    }
}

// MARK: - Conversion Highlights
struct ConversionHighlights: View {
    let totalSavedMB: Double
    let averageSaving: Int
    let bestSaving: Int?
    @Environment(\.colorScheme) private var colorScheme

    private var formattedTotal: String {
        if totalSavedMB >= 1000 {
            return String(format: "%.1f GB", totalSavedMB / 1000)
        }
        return String(format: "%.0f MB", totalSavedMB)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(AppStrings.Home.performanceTitle)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)
                    Text(AppStrings.Home.performanceSubtitle)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Live")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.appMint)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 5)
                .background(Color.appMint.opacity(0.12))
                .clipShape(Capsule())
            }

            // Bento Grid Layout
            HStack(spacing: Spacing.sm) {
                HighlightCard(
                    icon: "arrow.down.circle.fill",
                    title: AppStrings.Home.totalSaved,
                    value: formattedTotal,
                    accentColor: .appMint
                )

                HighlightCard(
                    icon: "percent",
                    title: AppStrings.Home.avgSavings,
                    value: "\(averageSaving)%",
                    accentColor: .premiumPurple
                )

                HighlightCard(
                    icon: "trophy.fill",
                    title: AppStrings.Home.bestResult,
                    value: bestSaving.map { "\($0)%" } ?? "—",
                    accentColor: .warmOrange
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, x: 0, y: 4)
    }
}

struct HighlightCard: View {
    let icon: String
    let title: String
    let value: String
    var accentColor: Color = .appAccent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accentColor)

            Spacer()

            // Value
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)

            // Title
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 90)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Empty History State
/// Empty state view with floating animation
/// ACCESSIBILITY: Respects reduceMotion preference
/// PERFORMANCE: Pauses animation when app goes to background
struct EmptyHistoryState: View {
    @State private var floatOffset: CGFloat = 0
    @State private var isAnimating: Bool = false

    /// Accessibility: Check if user prefers reduced motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Scene phase for pausing animations in background
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Floating illustration
            ZStack {
                // Background glow
                Circle()
                    .fill(Color.appAccent.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)

                // Floating documents illustration
                ZStack {
                    // Back document
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appSurface)
                        .frame(width: 50, height: 65)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                        .rotationEffect(.degrees(-15))
                        .offset(x: -20, y: 10)
                        .offset(y: reduceMotion ? 0 : floatOffset * 0.5)

                    // Middle document
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appSurface)
                        .frame(width: 55, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                        )
                        .rotationEffect(.degrees(5))
                        .offset(x: 15, y: -5)
                        .offset(y: reduceMotion ? 0 : floatOffset * 0.7)

                    // Front document with sparkle
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent.opacity(0.1), Color.appMint.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 75)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.appAccent.opacity(0.4), lineWidth: 1.5)
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.appAccent)
                    }
                    .offset(y: reduceMotion ? 0 : floatOffset)
                }
            }
            .frame(height: 140)

            // Text
            VStack(spacing: Spacing.xs) {
                Text(AppStrings.Home.storageTitle)
                    .font(.appTitle)
                    .foregroundStyle(.primary)

                Text(AppStrings.Home.storageSubtitle)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appMint)

                Text(AppStrings.Home.storageBody)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xxs)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.xl)
        .onAppear {
            // Only animate if reduceMotion is off and app is active
            if !reduceMotion && scenePhase == .active {
                startFloatingAnimation()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // PERFORMANCE: Pause animation when app goes to background
            switch newPhase {
            case .active:
                if !reduceMotion && !isAnimating {
                    startFloatingAnimation()
                }
            case .inactive, .background:
                stopFloatingAnimation()
            @unknown default:
                break
            }
        }
    }

    private func startFloatingAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            floatOffset = -8
        }
    }

    private func stopFloatingAnimation() {
        isAnimating = false

        withAnimation(.easeOut(duration: 0.3)) {
            floatOffset = 0
        }
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let item: HistoryItem
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap?()
        }) {
            HStack(spacing: Spacing.sm) {
                // File icon
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.appAccent.opacity(Opacity.subtle))
                        .frame(width: 44, height: 44)

                    Image(systemName: "doc.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                .accessibilityHidden(true)

                // File info
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.fileName)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: Spacing.xs) {
                        Text("\(item.originalSizeFormatted) → \(item.compressedSizeFormatted)")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)

                        Text(item.timeAgo)
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Savings badge with mint color
                Text("-\(item.savingsPercent)%")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.appMint)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.appMint.opacity(Opacity.subtle))
                    .clipShape(Capsule())
                    .accessibilityLabel("\(item.savingsPercent) percent saved")
            }
            .padding(Spacing.sm)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(item.fileName), compressed from \(item.originalSizeFormatted) to \(item.compressedSizeFormatted), \(item.savingsPercent) percent saved, \(item.timeAgo)")
        .accessibilityHint("Tap to view details")
    }
}

// MARK: - Membership Status
struct MembershipStatusCard: View {
    let status: SubscriptionStatus
    let onUpgrade: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var headline: String {
        status.isPro ? AppStrings.Home.proActive : AppStrings.Home.freePlan
    }

    private var detail: String {
        status.isPro
            ? AppStrings.Home.proDescription
            : AppStrings.Home.freeDescription(status.remainingUsage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: status.isPro
                                    ? [Color.appMint.opacity(0.2), Color.appTeal.opacity(0.1)]
                                    : [Color.premiumPurple.opacity(0.2), Color.premiumBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: status.isPro ? "crown.fill" : "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: status.isPro
                                    ? [Color.appMint, Color.appTeal]
                                    : [Color.premiumPurple, Color.premiumBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(headline)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Premium Badge
                Text(status.isPro ? "PRO" : "FREE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: status.isPro
                                ? [Color.appMint, Color.appTeal]
                                : [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }

            // Capability Pills
            HStack(spacing: Spacing.xs) {
                CapabilityPill(icon: "checkmark.shield.fill", text: AppStrings.Home.noAds, isActive: status.isPro)
                CapabilityPill(icon: "sparkles", text: AppStrings.Home.smartProfile, isActive: status.isPro)
                CapabilityPill(icon: "doc.on.doc", text: AppStrings.Home.allFiles, isActive: status.isPro)
            }

            if !status.isPro {
                // Upgrade Button with premium gradient
                Button(action: onUpgrade) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(AppStrings.Home.upgradeToPro)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .shadow(color: Color.premiumPurple.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.pressable)
            } else {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "infinity")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appMint)
                    Text(AppStrings.Home.unlimitedDescription)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: status.isPro
                            ? [Color.appMint.opacity(0.3), Color.appTeal.opacity(0.1)]
                            : [Color.premiumPurple.opacity(0.2), Color.premiumBlue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, x: 0, y: 4)
    }
}

struct CapabilityPill: View {
    let icon: String
    let text: String
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(isActive ? Color.appMint : .secondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(
            isActive
                ? Color.appMint.opacity(0.1)
                : Color(.tertiarySystemBackground)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? Color.appMint.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Dynamic Greeting View
/// Time-based personalized greeting that creates emotional connection with the user
/// Changes based on: Morning (5-12), Afternoon (12-17), Evening (17-21), Night (21-5), Weekend
struct DynamicGreetingView: View {
    @State private var greeting: (title: String, subtitle: String) = ("", "")
    @State private var iconName: String = "sun.max.fill"
    @State private var iconColor: Color = .warmOrange

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Animated icon
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(iconColor)
                .symbolBounce(trigger: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(greeting.subtitle)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            updateGreeting()
        }
    }

    private func updateGreeting() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date())

        // Weekend check (Saturday = 7, Sunday = 1)
        let isWeekend = weekday == 1 || weekday == 7

        if isWeekend {
            greeting = (AppStrings.Home.greetingWeekend, AppStrings.Home.greetingWeekendSubtitle)
            iconName = "sparkles"
            iconColor = .premiumPurple
        } else if hour >= 5 && hour < 12 {
            // Morning
            greeting = (AppStrings.Home.greetingMorning, AppStrings.Home.greetingMorningSubtitle)
            iconName = "sun.max.fill"
            iconColor = .warmOrange
        } else if hour >= 12 && hour < 17 {
            // Afternoon
            greeting = (AppStrings.Home.greetingAfternoon, AppStrings.Home.greetingAfternoonSubtitle)
            iconName = "sun.min.fill"
            iconColor = .warmOrange
        } else if hour >= 17 && hour < 21 {
            // Evening
            greeting = (AppStrings.Home.greetingEvening, AppStrings.Home.greetingEveningSubtitle)
            iconName = "sunset.fill"
            iconColor = .warmCoral
        } else {
            // Night (21-5)
            greeting = (AppStrings.Home.greetingNight, AppStrings.Home.greetingNightSubtitle)
            iconName = "moon.stars.fill"
            iconColor = .premiumIndigo
        }
    }
}

#Preview {
    HomeScreen(
        coordinator: AppCoordinator(),
        subscriptionStatus: .free,
        onSelectFile: {},
        onOpenHistory: {},
        onOpenSettings: {},
        onUpgrade: {}
    )
}
