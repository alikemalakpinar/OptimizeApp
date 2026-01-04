//
//  ModernPaywallScreen.swift
//  optimize
//
//  Apple-Standard Premium Paywall v2.0
//  No scroll - Everything visible at once
//  Timeline + Social Proof + Conversion-focused design
//

import SwiftUI

struct ModernPaywallScreen: View {
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var animateContent = false
    @State private var animateTimeline = false
    @Environment(\.colorScheme) private var colorScheme

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 700

            ZStack {
                // Background
                ApplePaywallBackground()

                VStack(spacing: 0) {
                    // Close Button
                    HStack {
                        Spacer()
                        Button(action: {
                            Haptics.selection()
                            onDismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)

                    // Hero Section - Compact
                    VStack(spacing: isCompact ? 6 : Spacing.sm) {
                        // Premium Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.premiumPurple.opacity(0.2), Color.premiumBlue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: isCompact ? 56 : 64, height: isCompact ? 56 : 64)

                            Image(systemName: "crown.fill")
                                .font(.system(size: isCompact ? 24 : 28, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.premiumPurple, Color.premiumBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Premium'a Geç")
                            .font(.system(size: isCompact ? 22 : 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                    .padding(.top, isCompact ? 4 : Spacing.sm)

                    Spacer().frame(height: isCompact ? 8 : 16)

                    // Timeline Section (NEW)
                    TrialTimelineView(isCompact: isCompact)
                        .padding(.horizontal, Spacing.lg)
                        .opacity(animateTimeline ? 1 : 0)
                        .offset(y: animateTimeline ? 0 : 10)

                    Spacer().frame(height: isCompact ? 8 : 14)

                    // Social Proof (NEW)
                    SocialProofBar(isCompact: isCompact)
                        .padding(.horizontal, Spacing.lg)
                        .opacity(animateContent ? 1 : 0)

                    Spacer().frame(height: isCompact ? 8 : 14)

                    // Plan Selection - Compact Cards
                    HStack(spacing: 10) {
                        CompactPlanCard(
                            title: "Haftalık",
                            price: "₺39,99",
                            period: "/hafta",
                            isSelected: selectedPlan == .monthly,
                            badge: nil,
                            isCompact: isCompact
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedPlan = .monthly
                            }
                        }

                        CompactPlanCard(
                            title: "Yıllık",
                            price: "₺249,99",
                            period: "/yıl",
                            isSelected: selectedPlan == .yearly,
                            badge: "%70 Tasarruf",
                            isCompact: isCompact
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedPlan = .yearly
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .opacity(animateContent ? 1 : 0)

                    Spacer()

                    // CTA Section
                    VStack(spacing: isCompact ? 8 : Spacing.sm) {
                        // Main CTA Button
                        Button(action: {
                            Haptics.impact(style: .medium)
                            isLoading = true
                            onSubscribe(selectedPlan)
                        }) {
                            HStack(spacing: Spacing.sm) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("7 Gün Ücretsiz Başla")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: isCompact ? 48 : 52)
                            .background(
                                LinearGradient(
                                    colors: [Color.premiumPurple, Color.premiumBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.premiumPurple.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .padding(.horizontal, Spacing.lg)

                        // Price info after trial
                        Text("7 gün sonra \(selectedPlan == .yearly ? "₺249,99/yıl" : "₺39,99/hafta")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)

                        // Trial Info
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appMint)
                            Text("İstediğin zaman iptal et")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        // Footer Links
                        HStack(spacing: Spacing.md) {
                            Button(action: {
                                Haptics.selection()
                                onRestore()
                            }) {
                                Text("Geri Yükle")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text("•")
                                .foregroundStyle(.quaternary)
                                .font(.system(size: 10))

                            Button(action: onPrivacy) {
                                Text("Gizlilik")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }

                            Text("•")
                                .foregroundStyle(.quaternary)
                                .font(.system(size: 10))

                            Button(action: onTerms) {
                                Text("Koşullar")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 8 : Spacing.md)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
                animateTimeline = true
            }
        }
    }
}

// MARK: - Trial Timeline View (NEW - Blinkist Style)

private struct TrialTimelineView: View {
    let isCompact: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Day 1 - Today
            TimelineStep(
                day: "Bugün",
                title: "Başla",
                icon: "play.fill",
                color: .appMint,
                isFirst: true,
                isLast: false,
                isCompact: isCompact
            )

            // Connection line
            TimelineConnector()

            // Day 5 - Reminder
            TimelineStep(
                day: "5. Gün",
                title: "Hatırlatma",
                icon: "bell.fill",
                color: .warmOrange,
                isFirst: false,
                isLast: false,
                isCompact: isCompact
            )

            // Connection line
            TimelineConnector()

            // Day 7 - Billing
            TimelineStep(
                day: "7. Gün",
                title: "Ödeme",
                icon: "creditcard.fill",
                color: .premiumPurple,
                isFirst: false,
                isLast: true,
                isCompact: isCompact
            )
        }
        .padding(.vertical, isCompact ? 10 : 12)
        .padding(.horizontal, isCompact ? 12 : 16)
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

private struct TimelineStep: View {
    let day: String
    let title: String
    let icon: String
    let color: Color
    let isFirst: Bool
    let isLast: Bool
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 4 : 6) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)

                Image(systemName: icon)
                    .font(.system(size: isCompact ? 11 : 13, weight: .semibold))
                    .foregroundStyle(color)
            }

            // Day label
            Text(day)
                .font(.system(size: isCompact ? 9 : 10, weight: .bold, design: .rounded))
                .foregroundStyle(isFirst ? color : .secondary)

            // Title
            Text(title)
                .font(.system(size: isCompact ? 9 : 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineConnector: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.appMint.opacity(0.5), Color.premiumPurple.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .frame(maxWidth: 30)
    }
}

// MARK: - Social Proof Bar (NEW)

private struct SocialProofBar: View {
    let isCompact: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: isCompact ? 12 : 16) {
            // App Store Rating
            SocialProofItem(
                icon: "star.fill",
                value: "4.8",
                label: "Puan",
                color: .yellow,
                isCompact: isCompact
            )

            Divider()
                .frame(height: isCompact ? 24 : 28)

            // Users
            SocialProofItem(
                icon: "person.2.fill",
                value: "50K+",
                label: "Kullanıcı",
                color: .premiumBlue,
                isCompact: isCompact
            )

            Divider()
                .frame(height: isCompact ? 24 : 28)

            // Saved Space
            SocialProofItem(
                icon: "arrow.down.circle.fill",
                value: "2TB+",
                label: "Tasarruf",
                color: .appMint,
                isCompact: isCompact
            )
        }
        .padding(.vertical, isCompact ? 8 : 10)
        .padding(.horizontal, isCompact ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground).opacity(0.5) : .white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

private struct SocialProofItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(color)

                Text(value)
                    .font(.system(size: isCompact ? 13 : 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text(label)
                .font(.system(size: isCompact ? 9 : 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Apple-Style Background
private struct ApplePaywallBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)

            // Subtle gradient orbs
            GeometryReader { geo in
                // Top purple glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.premiumPurple.opacity(colorScheme == .dark ? 0.12 : 0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width * 0.8, height: geo.size.height * 0.4)
                    .offset(x: -geo.size.width * 0.1, y: -geo.size.height * 0.05)

                // Bottom blue accent
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.premiumBlue.opacity(colorScheme == .dark ? 0.08 : 0.04),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.3)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.5)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Compact Plan Card (Updated)

private struct CompactPlanCard: View {
    let title: String
    let price: String
    let period: String
    let isSelected: Bool
    let badge: String?
    var isCompact: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            ZStack(alignment: .top) {
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: isCompact ? 11 : 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, badge != nil ? (isCompact ? 18 : 20) : (isCompact ? 10 : 12))

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(price)
                            .font(.system(size: isCompact ? 18 : 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(period)
                            .font(.system(size: isCompact ? 9 : 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: isCompact ? 80 : 90)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.premiumPurple.opacity(0.05), Color.premiumBlue.opacity(0.02)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected
                                ? LinearGradient(colors: [Color.premiumPurple, Color.premiumBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.cardBorder, Color.cardBorder], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: isSelected ? Color.premiumPurple.opacity(0.1) : .clear, radius: 6, x: 0, y: 3)

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: isCompact ? 8 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color.appMint, Color.appTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .offset(y: -8)
                }

                // Checkmark
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: isCompact ? 16 : 18))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.premiumPurple, Color.premiumBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .background(Circle().fill(Color(.systemBackground)).frame(width: 12, height: 12))
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ModernPaywallScreen(
        onSubscribe: { plan in print("Subscribe: \(plan)") },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
}

#Preview("Dark Mode") {
    ModernPaywallScreen(
        onSubscribe: { plan in print("Subscribe: \(plan)") },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Compact (iPhone SE)") {
    ModernPaywallScreen(
        onSubscribe: { plan in print("Subscribe: \(plan)") },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
    .previewDevice("iPhone SE (3rd generation)")
}
