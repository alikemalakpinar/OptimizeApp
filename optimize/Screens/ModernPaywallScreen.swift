//
//  ModernPaywallScreen.swift
//  optimize
//
//  Clean Paywall Design - Consistent with app's Paper/Glass aesthetic
//  Serif headlines + Light theme + Trust-building timeline
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
        ZStack {
            // MARK: - Clean Background
            CleanPaywallBackground()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Spacer()

                    Button(action: {
                        Haptics.selection()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // MARK: - Hero Section
                        VStack(spacing: Spacing.md) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appMint.opacity(0.2), Color.appTeal.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)

                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.appMint, Color.appTeal],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .padding(.top, Spacing.lg)

                            // Title - Serif Font for Premium Feel
                            Text("Limitleri Kaldır.")
                                .font(.displayTitle)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)

                            Text("Profesyoneller için tasarlandı.")
                                .font(.uiBody)
                                .foregroundStyle(.secondary)
                        }
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                        // MARK: - Timeline (Trust Builder)
                        CleanTrialTimeline()
                            .padding(.horizontal, Spacing.md)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 15)

                        // MARK: - Features Bento Grid
                        FeaturesBentoGrid()
                            .padding(.horizontal, Spacing.md)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 10)

                        Spacer(minLength: Spacing.xl)
                    }
                }

                // MARK: - Bottom Panel
                VStack(spacing: Spacing.lg) {
                    // Plan Cards
                    HStack(spacing: Spacing.sm) {
                        CleanPlanCard(
                            title: AppStrings.ModernPaywall.weeklyTitle,
                            price: AppStrings.ModernPaywall.weeklyPrice,
                            subtitle: AppStrings.ModernPaywall.weeklySubtitle,
                            isSelected: selectedPlan == .monthly,
                            badge: nil
                        ) {
                            withAnimation(AppAnimation.spring) {
                                selectedPlan = .monthly
                            }
                        }

                        CleanPlanCard(
                            title: AppStrings.ModernPaywall.yearlyTitle,
                            price: AppStrings.ModernPaywall.yearlyPrice,
                            subtitle: AppStrings.ModernPaywall.yearlySubtitle,
                            isSelected: selectedPlan == .yearly,
                            badge: AppStrings.ModernPaywall.yearlySavings
                        ) {
                            withAnimation(AppAnimation.spring) {
                                selectedPlan = .yearly
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)

                    // CTA Button
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
                                Text(AppStrings.ModernPaywall.startTrial)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.appMint, Color.appTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                        .shadow(color: Color.appMint.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.pressable)
                    .disabled(isLoading)
                    .padding(.horizontal, Spacing.md)

                    // Footer
                    VStack(spacing: Spacing.xs) {
                        Button(action: {
                            Haptics.selection()
                            onRestore()
                        }) {
                            Text(AppStrings.Paywall.restore)
                                .font(.uiCaption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: Spacing.md) {
                            Button(action: onPrivacy) {
                                Text(AppStrings.Settings.privacyPolicy)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }

                            Text("•")
                                .foregroundStyle(.quaternary)

                            Button(action: onTerms) {
                                Text(AppStrings.Settings.termsOfService)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Text(AppStrings.ModernPaywall.cancelAnytime)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.appMint)
                    }
                    .padding(.bottom, Spacing.lg)
                }
                .padding(.top, Spacing.lg)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: -10)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .onAppear {
            withAnimation(AppAnimation.spring.delay(0.2)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Clean Paywall Background
struct CleanPaywallBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base
            Color(.systemBackground)

            // Subtle Aurora Effect
            GeometryReader { geometry in
                ZStack {
                    // Top gradient blob
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.appMint.opacity(colorScheme == .dark ? 0.15 : 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.6
                            )
                        )
                        .frame(width: geometry.size.width * 1.2, height: geometry.size.height * 0.5)
                        .offset(x: -geometry.size.width * 0.1, y: -geometry.size.height * 0.1)

                    // Secondary accent
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.appAccent.opacity(colorScheme == .dark ? 0.1 : 0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.4)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.2)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Clean Trial Timeline
struct CleanTrialTimeline: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(Color.appMint)
                Text("Deneme Süreciniz")
                    .font(.uiBodyBold)
                Spacer()
            }

            // Timeline Cards
            HStack(spacing: Spacing.sm) {
                TimelineCard(
                    day: "Bugün",
                    title: "Ücretsiz",
                    icon: "lock.open.fill",
                    iconColor: .appMint,
                    isActive: true
                )

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                TimelineCard(
                    day: "7. Gün",
                    title: "Abonelik",
                    icon: "star.fill",
                    iconColor: .appAccent,
                    isActive: false
                )
            }

            // Trust message
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "bell.badge.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.appMint)
                Text("5. gün hatırlatma bildirimi göndereceğiz")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }
}

struct TimelineCard: View {
    let day: String
    let title: String
    let icon: String
    let iconColor: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(isActive ? 0.15 : 0.08))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            Text(day)
                .font(.uiCaptionBold)
                .foregroundStyle(isActive ? .primary : .secondary)

            Text(title)
                .font(.uiCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(isActive ? Color(.tertiarySystemBackground) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - Features Bento Grid
struct FeaturesBentoGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            FeatureBentoCard(
                icon: "infinity",
                title: "Sınırsız",
                description: "Dosya boyutu limiti yok",
                color: .appMint
            )

            FeatureBentoCard(
                icon: "wand.and.stars",
                title: "Smart AI",
                description: "Akıllı sıkıştırma",
                color: .purple
            )

            FeatureBentoCard(
                icon: "lock.shield.fill",
                title: "Güvenli",
                description: "Cihaz içi işlem",
                color: .appAccent
            )

            FeatureBentoCard(
                icon: "xmark.circle.fill",
                title: "Reklamsız",
                description: "Temiz deneyim",
                color: .orange
            )
        }
    }
}

struct FeatureBentoCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)

            Spacer()

            Text(title)
                .font(.uiBodyBold)
                .foregroundStyle(.primary)

            Text(description)
                .font(.uiCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(Spacing.md)
        .frame(height: 110)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Clean Plan Card
struct CleanPlanCard: View {
    let title: String
    let price: String
    let subtitle: String
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
                // Card Content
                VStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(.uiBodyBold)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.top, badge != nil ? 24 : 16)

                    Spacer()

                    Text(price)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.uiCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .background(
                    isSelected
                        ? Color(.tertiarySystemBackground)
                        : Color(.secondarySystemBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(
                            isSelected ? Color.appMint : Color.cardBorder,
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.appMint)
                        .clipShape(Capsule())
                        .offset(y: -10)
                }

                // Selection indicator
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.appMint)
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 16, height: 16)
                                )
                                .padding(Spacing.sm)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lifetime Plan Option
struct CleanLifetimePlan: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Crown Icon
                ZStack {
                    Circle()
                        .fill(Color.goldAccent.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.goldAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ömür Boyu")
                        .font(.uiBodyBold)
                        .foregroundStyle(.primary)

                    Text("Tek seferlik ödeme")
                        .font(.uiCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("₺999")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        isSelected ? Color.goldAccent : Color.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

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
