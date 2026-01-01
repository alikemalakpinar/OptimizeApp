//
//  ModernPaywallScreen.swift
//  optimize
//
//  Modern paywall design with feature preview and pricing card
//

import SwiftUI

struct ModernPaywallScreen: View {
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isLoading = false
    @State private var animateContent = false

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.6),
                    Color.blue.opacity(0.4),
                    Color.pink.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Blur overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(AppStrings.ModernPaywall.premiumTitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    CloseButton {
                        onDismiss()
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Feature Preview Image
                        FeaturePreviewCard()
                            .padding(.top, Spacing.lg)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)

                        // Feature Title
                        VStack(spacing: Spacing.xs) {
                            Text(AppStrings.ModernPaywall.featureTitle)
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)

                            Text(AppStrings.ModernPaywall.featureDescription)
                                .font(.appBody)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .opacity(animateContent ? 1 : 0)

                        // Pricing Card
                        PricingCard(
                            selectedPlan: $selectedPlan,
                            isLoading: isLoading,
                            onSubscribe: {
                                isLoading = true
                                onSubscribe(selectedPlan)
                            }
                        )
                        .padding(.horizontal, Spacing.lg)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 30)

                        // Cancel anytime text
                        Text(AppStrings.ModernPaywall.cancelAnytime)
                            .font(.appCaption)
                            .foregroundStyle(.appMint)
                            .opacity(animateContent ? 1 : 0)

                        // Restore & Links
                        VStack(spacing: Spacing.sm) {
                            Button(action: {
                                Haptics.selection()
                                onRestore()
                            }) {
                                Text(AppStrings.Paywall.restore)
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: Spacing.md) {
                                Button(action: onPrivacy) {
                                    Text(AppStrings.Settings.privacyPolicy)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }

                                Text("•")
                                    .foregroundStyle(.secondary.opacity(0.5))

                                Button(action: onTerms) {
                                    Text(AppStrings.Settings.termsOfService)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        // Extra bottom padding to avoid Home Indicator overlap on notched devices
                        .padding(.bottom, Spacing.xxl)
                        .padding(.bottom, Spacing.xl)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(AppAnimation.spring.delay(0.2)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Feature Preview Card
struct FeaturePreviewCard: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Preview image placeholder
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .overlay(
                    // Placeholder icon
                    Image(systemName: "doc.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.5))
                )

            // Duration badge
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "doc.badge.clock")
                    .font(.system(size: 12, weight: .medium))
                Text(AppStrings.ModernPaywall.unlimitedBadge)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(Spacing.md)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Pricing Card
struct PricingCard: View {
    @Binding var selectedPlan: SubscriptionPlan
    let isLoading: Bool
    let onSubscribe: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header with Popular badge
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(selectedPlan == .monthly ?
                         AppStrings.ModernPaywall.monthlyTitle :
                         AppStrings.ModernPaywall.yearlyTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(selectedPlan == .monthly ?
                         AppStrings.ModernPaywall.monthlySubtitle :
                         AppStrings.ModernPaywall.yearlySubtitle)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Popular badge
                Text(AppStrings.ModernPaywall.popularBadge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }

            // Plan toggle
            HStack(spacing: Spacing.sm) {
                PlanOptionButton(
                    title: AppStrings.Paywall.monthlyPlan,
                    isSelected: selectedPlan == .monthly
                ) {
                    withAnimation(AppAnimation.spring) {
                        selectedPlan = .monthly
                    }
                }

                PlanOptionButton(
                    title: AppStrings.Paywall.yearlyPlan,
                    subtitle: AppStrings.Paywall.savings,
                    isSelected: selectedPlan == .yearly
                ) {
                    withAnimation(AppAnimation.spring) {
                        selectedPlan = .yearly
                    }
                }
            }

            // Features
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PricingFeatureRow(text: AppStrings.ModernPaywall.feature1)
                PricingFeatureRow(text: AppStrings.ModernPaywall.feature2)
                PricingFeatureRow(text: AppStrings.ModernPaywall.feature3)
            }

            // Price
            VStack(spacing: Spacing.xxs) {
                Text(selectedPlan == .monthly ?
                     AppStrings.ModernPaywall.monthlyPrice :
                     AppStrings.ModernPaywall.yearlyPrice)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                Text(selectedPlan == .monthly ?
                     AppStrings.ModernPaywall.monthlyBilled :
                     AppStrings.ModernPaywall.yearlyBilled)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            // CTA Button
            Button(action: {
                Haptics.impact(style: .medium)
                onSubscribe()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(AppStrings.ModernPaywall.tryFree)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(isLoading)
        }
        .padding(Spacing.lg)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        // Reduced shadow radius to prevent clipping on screen edges
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Plan Option Button
struct PlanOptionButton: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? .appMint : .secondary)
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(isSelected ? Color.appSurface : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .stroke(isSelected ? Color.appAccent : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pricing Feature Row
struct PricingFeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)
                .background(Color.appSurface)
                .clipShape(Circle())

            Text(text)
                .font(.appBody)
                .foregroundStyle(.primary)

            Spacer()
        }
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
