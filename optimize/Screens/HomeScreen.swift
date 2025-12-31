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
            // Header
            ScreenHeader(".optimize") {
                HeaderIconButton(systemName: "gearshape") {
                    onOpenSettings()
                }
            }

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    MembershipStatusCard(
                        status: subscriptionStatus,
                        onUpgrade: onUpgrade
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)

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
                                Text("Recent Activity")
                                    .font(.appSection)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button(action: {
                                    onOpenHistory()
                                }) {
                                    Text("View All")
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
struct BreathingCTACard: View {
    let isDropTargeted: Bool
    let onTap: () -> Void

    @State private var breathScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.3

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.md) {
                // Icon with breathing effect
                ZStack {
                    // Outer breathing rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Color.appAccent.opacity(0.15 - Double(index) * 0.04),
                                lineWidth: 1.5
                            )
                            .frame(
                                width: 80 + CGFloat(index) * 20,
                                height: 80 + CGFloat(index) * 20
                            )
                            .scaleEffect(breathScale + CGFloat(index) * 0.02)
                            .opacity(ringOpacity - Double(index) * 0.1)
                    }

                    // Main circle
                    Circle()
                        .fill(Color.appAccent.opacity(Opacity.subtle))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)

                    // Icon
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                        .symbolBounce(trigger: isDropTargeted)
                }

                // Text
                VStack(spacing: Spacing.xxs) {
                    Text(isDropTargeted ? "Drop File" : "Select File")
                        .font(.appTitle)
                        .foregroundStyle(.primary)

                    Text(isDropTargeted ? "Drop to optimize" : "Tap or drag file here")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        isDropTargeted ? Color.appAccent : Color.glassBorder,
                        lineWidth: isDropTargeted ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.pressable)
        .onAppear {
            startBreathingAnimation()
        }
    }

    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            breathScale = 1.08
            ringOpacity = 0.5
        }
    }
}

// MARK: - Conversion Highlights
struct ConversionHighlights: View {
    let totalSavedMB: Double
    let averageSaving: Int
    let bestSaving: Int?

    private var formattedTotal: String {
        if totalSavedMB >= 1000 {
            return String(format: "%.1f GB", totalSavedMB / 1000)
        }
        return String(format: "%.0f MB", totalSavedMB)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Optimize Performance")
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)
                        Text("Recommendations based on real savings")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Label("New", systemImage: "sparkles")
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.appAccent.opacity(Opacity.subtle))
                        .clipShape(Capsule())
                }

                HStack(spacing: Spacing.sm) {
                    HighlightCard(
                        icon: "arrow.down.to.line",
                        title: "Total saved",
                        value: formattedTotal
                    )

                    HighlightCard(
                        icon: "percent",
                        title: "Avg. savings",
                        value: "\(averageSaving)%"
                    )

                    HighlightCard(
                        icon: "rosette",
                        title: "Best result",
                        value: bestSaving.map { "\($0)%" } ?? "75%"
                    )
                }
            }
        }
    }
}

struct HighlightCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.appCaption)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - Empty History State
struct EmptyHistoryState: View {
    @State private var floatOffset: CGFloat = 0

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
                        .offset(y: floatOffset * 0.5)

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
                        .offset(y: floatOffset * 0.7)

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
                    .offset(y: floatOffset)
                }
            }
            .frame(height: 140)

            // Text
            VStack(spacing: Spacing.xs) {
                Text("Your Storage")
                    .font(.appTitle)
                    .foregroundStyle(.primary)

                Text("Awaits Relief")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appMint)

                Text("Select your first file and start the magic")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xxs)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.xl)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                floatOffset = -8
            }
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

    private var headline: String {
        status.isPro ? "Pro aktif" : "Ücretsiz plan"
    }

    private var detail: String {
        status.isPro
            ? "Reklamsız, sınırsız ve profesyonel sıkıştırma açık."
            : "Reklam yok. Bugün \(status.remainingUsage) ücretsiz kullanım hakkın kaldı."
    }

    private var badgeColor: Color {
        status.isPro ? .appMint : .appAccent
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(headline)
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)

                        Text(detail)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(status.isPro ? "PRO" : "FREE")
                        .font(.appCaptionMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(badgeColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: Spacing.sm) {
                    CapabilityPill(icon: "checkmark.shield.fill", text: "Reklamsız")
                    CapabilityPill(icon: "sparkles", text: "Akıllı profil")
                    CapabilityPill(icon: "doc.on.doc", text: "Tüm dosyalar")
                }

                if !status.isPro {
                    PrimaryButton(
                        title: "Pro'ya yükselt",
                        icon: "crown.fill"
                    ) {
                        onUpgrade()
                    }
                } else {
                    Text("Sınırsız optimizasyon, özel hedef boyutlar ve öncelikli işlem hazır.")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CapabilityPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.appCaptionMedium)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.appSurface)
        .clipShape(Capsule())
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
