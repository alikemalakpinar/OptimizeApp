//
//  ModernPaywallScreen.swift
//  optimize
//
//  Apple-Standard Premium Paywall
//  No scroll - Everything visible at once
//  Clean, minimal, conversion-focused design
//

import SwiftUI

struct ModernPaywallScreen: View {
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var animateContent = false
    @Environment(\.colorScheme) private var colorScheme

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    var body: some View {
        GeometryReader { geometry in
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
                    .padding(.top, Spacing.sm)

                    Spacer()

                    // Hero Section
                    VStack(spacing: Spacing.md) {
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
                                .frame(width: 72, height: 72)

                            Image(systemName: "crown.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.premiumPurple, Color.premiumBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        // Title
                        Text("Premium'a Geç")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)

                    Spacer()

                    // Features - Compact 2x2 Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        CompactFeatureCell(icon: "infinity", title: "Sınırsız", color: .appMint)
                        CompactFeatureCell(icon: "wand.and.stars", title: "Akıllı AI", color: .premiumPurple)
                        CompactFeatureCell(icon: "lock.shield.fill", title: "Güvenli", color: .premiumBlue)
                        CompactFeatureCell(icon: "sparkles", title: "Reklamsız", color: .warmOrange)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)

                    Spacer()

                    // Plan Selection - Compact Cards
                    HStack(spacing: 12) {
                        CompactPlanCard(
                            title: "Haftalık",
                            price: "₺39,99",
                            period: "/hafta",
                            isSelected: selectedPlan == .monthly,
                            badge: nil
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
                            badge: "%70 Tasarruf"
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
                    VStack(spacing: Spacing.md) {
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
                                    Text("7 Gün Ücretsiz Dene")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.premiumPurple, Color.premiumBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.premiumPurple.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .padding(.horizontal, Spacing.lg)

                        // Trial Info
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appMint)
                            Text("İstediğin zaman iptal et")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        // Footer Links
                        HStack(spacing: Spacing.lg) {
                            Button(action: {
                                Haptics.selection()
                                onRestore()
                            }) {
                                Text("Geri Yükle")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text("•")
                                .foregroundStyle(.quaternary)

                            Button(action: onPrivacy) {
                                Text("Gizlilik")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }

                            Text("•")
                                .foregroundStyle(.quaternary)

                            Button(action: onTerms) {
                                Text("Koşullar")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? Spacing.md : Spacing.lg)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
        }
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
                                Color.premiumPurple.opacity(colorScheme == .dark ? 0.15 : 0.08),
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
                                Color.premiumBlue.opacity(colorScheme == .dark ? 0.1 : 0.06),
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

// MARK: - Compact Feature Cell
private struct CompactFeatureCell: View {
    let icon: String
    let title: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
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

// MARK: - Compact Plan Card
private struct CompactPlanCard: View {
    let title: String
    let price: String
    let period: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            ZStack(alignment: .top) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, badge != nil ? 22 : 14)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(price)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(period)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected
                                ? LinearGradient(colors: [Color.premiumPurple, Color.premiumBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.cardBorder, Color.cardBorder], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: isSelected ? Color.premiumPurple.opacity(0.12) : .clear, radius: 8, x: 0, y: 4)

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [Color.appMint, Color.appTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .offset(y: -10)
                }

                // Checkmark
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.premiumPurple, Color.premiumBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .background(Circle().fill(Color(.systemBackground)).frame(width: 16, height: 16))
                                .padding(8)
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
