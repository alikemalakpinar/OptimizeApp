//
//  ModernPaywallScreen.swift
//  optimize
//
//  Modern paywall with glassmorphism design inspired by Retro app
//

import SwiftUI

struct ModernPaywallScreen: View {
    @State private var selectedPlan: SubscriptionPlan = .yearly // Default to yearly (anchor pricing)
    @State private var isLoading = false
    @State private var animateContent = false

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    var body: some View {
        ZStack {
            // MARK: - Background
            PaywallBackground()

            VStack(spacing: 0) {
                // MARK: - Header with close button
                HStack {
                    Text(AppStrings.ModernPaywall.premiumTitle)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer()

                    Button(action: {
                        Haptics.selection()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // MARK: - Feature Preview Card
                        FeaturePreviewImage()
                            .padding(.top, Spacing.lg)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)

                        // MARK: - Title Section
                        VStack(spacing: Spacing.sm) {
                            Text(AppStrings.ModernPaywall.featureTitle)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text(AppStrings.ModernPaywall.featureDescription)
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .opacity(animateContent ? 1 : 0)

                        Spacer(minLength: Spacing.md)
                    }
                }

                // MARK: - Bottom Panel with Glass Effect
                VStack(spacing: Spacing.lg) {
                    // MARK: - Trial Timeline (Trust Builder)
                    // Shows exactly when charges happen - reduces "forgot to cancel" anxiety
                    TrialTimelineView()
                        .padding(.horizontal, Spacing.md)

                    // Plan Cards
                    HStack(spacing: Spacing.sm) {
                        // Weekly Plan
                        PaywallPlanCard(
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

                        // Yearly Plan (Best Value)
                        PaywallPlanCard(
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
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else {
                                Text(AppStrings.ModernPaywall.startTrial)
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                        .shadow(color: .white.opacity(0.3), radius: 12, x: 0, y: 0)
                    }
                    .buttonStyle(.pressable)
                    .disabled(isLoading)
                    .padding(.horizontal, Spacing.md)

                    // Footer
                    VStack(spacing: Spacing.sm) {
                        Button(action: {
                            Haptics.selection()
                            onRestore()
                        }) {
                            Text(AppStrings.Paywall.restore)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        HStack(spacing: Spacing.md) {
                            Button(action: onPrivacy) {
                                Text(AppStrings.Settings.privacyPolicy)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))

                            Button(action: onTerms) {
                                Text(AppStrings.Settings.termsOfService)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        Text(AppStrings.ModernPaywall.cancelAnytime)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appMint)
                            .padding(.top, Spacing.xxs)
                    }
                    .padding(.bottom, Spacing.xl)
                }
                .padding(.top, Spacing.lg)
                .background(
                    // Gradient fade from transparent to glass
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3), .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .background(.ultraThinMaterial.opacity(0.5))
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

// MARK: - Paywall Background
struct PaywallBackground: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.8),
                    Color.blue.opacity(0.6),
                    Color.pink.opacity(0.5),
                    Color.orange.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Overlay blur
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.3))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Feature Preview Image
struct FeaturePreviewImage: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Preview card with glass effect
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.4),
                            Color.purple.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .overlay(
                    // Document icon placeholder
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(.white.opacity(0.6))

                        Text("PDF, Görsel, Video")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )

            // Unlimited badge
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "infinity")
                    .font(.system(size: 12, weight: .medium))
                Text(AppStrings.ModernPaywall.unlimitedBadge)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(Spacing.md)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Plan Card
struct PaywallPlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            ZStack(alignment: .top) {
                // Card background
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .stroke(
                                isSelected ? Color.appMint : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                VStack(spacing: Spacing.xs) {
                    // Title
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                        .padding(.top, badge != nil ? 28 : 20)

                    Spacer()

                    // Price
                    Text(price)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    // Subtitle
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, Spacing.sm)
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
                                .font(.system(size: 20))
                                .foregroundStyle(Color.appMint)
                                .background(Circle().fill(.white).frame(width: 14, height: 14))
                                .padding(Spacing.sm)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 140)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trial Timeline View (Trust Builder)
/// Shows users exactly when charges happen - reduces subscription anxiety
/// Psychology: "We'll remind you before charging" builds trust
struct TrialTimelineView: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            // Timeline header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .medium))
                Text("Deneme Süreciniz")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))

            // Timeline points
            HStack(spacing: 0) {
                // Day 1: Today
                TimelinePoint(
                    day: "Bugün",
                    text: "Pro Başlar",
                    icon: "lock.open.fill",
                    iconColor: .appMint,
                    isFirst: true
                )

                TimelineLine()

                // Day 5: Reminder
                TimelinePoint(
                    day: "5. Gün",
                    text: "Hatırlatma",
                    icon: "bell.fill",
                    iconColor: .yellow,
                    isFirst: false
                )

                TimelineLine()

                // Day 7: Subscription starts
                TimelinePoint(
                    day: "7. Gün",
                    text: "Abonelik",
                    icon: "star.fill",
                    iconColor: .appMint,
                    isFirst: false
                )
            }

            // Trust message
            Text("5. gün hatırlatma e-postası göndereceğiz")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct TimelinePoint: View {
    let day: String
    let text: String
    let icon: String
    let iconColor: Color
    let isFirst: Bool

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Day label
            Text(day)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)

            // Description
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct TimelineLine: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .frame(maxWidth: 40)
            .offset(y: -12) // Align with icon center
    }
}

// MARK: - Lifetime Plan Card (Anchor Pricing / Decoy Effect)
/// High-priced lifetime option makes yearly plan seem like a better deal
struct LifetimePlanBadge: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                // Crown icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.goldAccent)

                Text("Ömür Boyu")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)

                Text("₺999")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Tek Ödeme")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.goldAccent.opacity(0.3),
                                Color.orange.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        isSelected ? Color.goldAccent : Color.white.opacity(0.2),
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
