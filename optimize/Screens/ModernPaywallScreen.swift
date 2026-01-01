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
    @State private var iconScale: CGFloat = 1.0
    @Environment(\.colorScheme) private var colorScheme

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    var body: some View {
        ZStack {
            // MARK: - Premium Background
            PremiumPaywallBackground()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Spacer()

                    Button(action: {
                        Haptics.selection()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // MARK: - Hero Section
                        VStack(spacing: Spacing.lg) {
                            // Premium Icon with animation
                            ZStack {
                                // Outer glow
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.premiumPurple.opacity(0.2),
                                                Color.premiumBlue.opacity(0.1),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 140, height: 140)
                                    .scaleEffect(iconScale)
                                    .blur(radius: 20)

                                // Main circle
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.premiumPurple.opacity(0.15), Color.premiumBlue.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 90, height: 90)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.premiumPurple.opacity(0.4), Color.premiumBlue.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )

                                Image(systemName: "crown.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.premiumPurple, Color.premiumBlue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .padding(.top, Spacing.lg)

                            // Title - Premium Typography
                            VStack(spacing: Spacing.xs) {
                                Text("Premium'a Geç")
                                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)

                                Text("Sınırsız sıkıştırma gücünü aç")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
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

                    // CTA Button with Premium Gradient
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
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(AppStrings.ModernPaywall.startTrial)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.premiumPurple, Color.premiumBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                        .shadow(color: Color.premiumPurple.opacity(0.35), radius: 16, x: 0, y: 8)
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

// MARK: - Premium Paywall Background
struct PremiumPaywallBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base
            Color(.systemBackground)

            // Premium Aurora Effect
            GeometryReader { geometry in
                ZStack {
                    // Top left purple glow
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.premiumPurple.opacity(colorScheme == .dark ? 0.2 : 0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.7
                            )
                        )
                        .frame(width: geometry.size.width * 1.4, height: geometry.size.height * 0.6)
                        .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.15)

                    // Center blue accent
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.premiumBlue.opacity(colorScheme == .dark ? 0.15 : 0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height * 0.5)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.15)

                    // Bottom subtle mint
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.appMint.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.4
                            )
                        )
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.4)
                        .offset(x: -geometry.size.width * 0.1, y: geometry.size.height * 0.4)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Clean Paywall Background (Legacy)
struct CleanPaywallBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        PremiumPaywallBackground()
    }
}

// MARK: - Clean Trial Timeline
struct CleanTrialTimeline: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.premiumPurple)
                    Text("Deneme Süreciniz")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Spacer()
            }

            // Timeline Cards
            HStack(spacing: Spacing.sm) {
                TimelineCard(
                    day: "Bugün",
                    title: "Ücretsiz Başla",
                    icon: "gift.fill",
                    iconColor: .appMint,
                    isActive: true
                )

                // Arrow with gradient
                VStack(spacing: 2) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.premiumPurple.opacity(0.5), Color.premiumBlue.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("7 gün")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                TimelineCard(
                    day: "7. Gün",
                    title: "Abonelik",
                    icon: "crown.fill",
                    iconColor: .premiumPurple,
                    isActive: false
                )
            }

            // Trust message
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appMint)
                Text("5. gün hatırlatma bildirimi göndereceğiz")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 8)
            .background(Color.appMint.opacity(0.08))
            .clipShape(Capsule())
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
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 8, x: 0, y: 2)
    }
}

struct TimelineCard: View {
    let day: String
    let title: String
    let icon: String
    let iconColor: Color
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(isActive ? 0.15 : 0.08))
                    .frame(width: 48, height: 48)

                if isActive {
                    Circle()
                        .stroke(iconColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 48, height: 48)
                }

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            Text(day)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .primary : .secondary)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            isActive
                ? Color(colorScheme == .dark ? .tertiarySystemBackground : .systemGray6)
                : Color.clear
        )
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
                color: .premiumPurple
            )

            FeatureBentoCard(
                icon: "lock.shield.fill",
                title: "Güvenli",
                description: "Cihaz içi işlem",
                color: .premiumBlue
            )

            FeatureBentoCard(
                icon: "sparkles",
                title: "Reklamsız",
                description: "Temiz deneyim",
                color: .warmOrange
            )
        }
    }
}

struct FeatureBentoCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Icon with subtle background
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
            }

            Spacer()

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(description)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(Spacing.md)
        .frame(height: 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 8, x: 0, y: 2)
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
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.top, badge != nil ? 26 : 16)

                    Spacer()

                    Text(price)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .primary.opacity(0.8))

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 135)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)

                        if isSelected {
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.premiumPurple.opacity(0.06),
                                            Color.premiumBlue.opacity(0.03)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(
                            isSelected
                                ? LinearGradient(colors: [Color.premiumPurple, Color.premiumBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.cardBorder, Color.cardBorder], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: isSelected ? Color.premiumPurple.opacity(0.15) : Color.clear, radius: 12, x: 0, y: 4)

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [Color.appMint, Color.appTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .offset(y: -12)
                }

                // Selection indicator
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 18, height: 18)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.premiumPurple, Color.premiumBlue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
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
