//
//  PaywallScreen.swift
//  optimize
//
//  Modern subscription paywall with trial flow design
//

import SwiftUI

struct PaywallScreen: View {
    var context: PaywallContext? = nil
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var isRestoring = false
    @State private var animateContent = false
    @State private var showCloseButton = false

    var limitExceeded: Bool = false
    var currentFileSize: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    // Dynamic display properties
    private var displayIcon: String {
        context?.icon ?? "crown.fill"
    }

    private var displayTitle: String {
        context?.title ?? AppStrings.Paywall.header
    }

    var body: some View {
        ZStack {
            // Premium gradient background
            PaywallBackgroundGradient()

            VStack(spacing: 0) {
                // Header with delayed close button
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
                    .opacity(showCloseButton ? 1 : 0)
                    .disabled(!showCloseButton)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Hero Icon with Glow
                        PaywallHeroIcon(icon: displayIcon)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)

                        // Context-aware title section
                        VStack(spacing: Spacing.xs) {
                            Text(displayTitle)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)

                            if let subtitle = context?.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Spacing.lg)
                            }
                        }
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 15)

                        // Trial Timeline - Enhanced
                        EnhancedTrialTimeline(selectedPlan: selectedPlan)
                            .padding(.horizontal, Spacing.md)
                            .opacity(animateContent ? 1 : 0)

                        // Social Proof Bar
                        EnhancedSocialProofBar()
                            .padding(.horizontal, Spacing.md)
                            .opacity(animateContent ? 1 : 0)

                        // Plan Selection Cards
                        EnhancedPlanSelector(selectedPlan: $selectedPlan)
                            .padding(.horizontal, Spacing.md)
                            .opacity(animateContent ? 1 : 0)

                        // Feature highlights
                        if let highlights = context?.highlights, !highlights.isEmpty {
                            FeatureHighlightsGrid(features: highlights)
                                .padding(.horizontal, Spacing.md)
                                .opacity(animateContent ? 1 : 0)
                        }

                        Spacer(minLength: Spacing.lg)
                    }
                    .padding(.top, Spacing.md)
                }

                // Bottom CTA Section - Enhanced
                VStack(spacing: Spacing.sm) {
                    // Premium CTA Button
                    PremiumCTAButton(
                        title: context?.ctaText ?? AppStrings.Paywall.startPro,
                        isLoading: isLoading
                    ) {
                        isLoading = true
                        Haptics.impact(style: .medium)
                        onSubscribe(selectedPlan)
                    }
                    .padding(.horizontal, Spacing.md)

                    // Trust indicators
                    HStack(spacing: Spacing.lg) {
                        TrustIndicator(icon: "checkmark.shield.fill", text: "Güvenli Ödeme")
                        TrustIndicator(icon: "arrow.uturn.backward.circle", text: "İstediğin Zaman İptal")
                    }

                    // Footer actions
                    HStack(spacing: Spacing.md) {
                        Button(action: {
                            Haptics.selection()
                            isRestoring = true
                            onRestore()
                        }) {
                            HStack(spacing: 4) {
                                if isRestoring {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                                        .scaleEffect(0.6)
                                }
                                Text("Geri Yükle")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .disabled(isRestoring)

                        Text("•").foregroundStyle(.quaternary).font(.system(size: 10))

                        Button(action: onPrivacy) {
                            Text("Gizlilik")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }

                        Text("•").foregroundStyle(.quaternary).font(.system(size: 10))

                        Button(action: onTerms) {
                            Text("Koşullar")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -5)
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
            // Delay close button for better conversion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showCloseButton = true }
            }
        }
    }
}

// MARK: - Paywall Background Gradient
private struct PaywallBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)

            // Top gradient orb
            GeometryReader { geo in
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
                    .offset(x: -geo.size.width * 0.1, y: -geo.size.height * 0.1)

                // Bottom accent
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.appMint.opacity(colorScheme == .dark ? 0.1 : 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.3
                        )
                    )
                    .frame(width: geo.size.width * 0.5, height: geo.size.height * 0.25)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.6)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Paywall Hero Icon
private struct PaywallHeroIcon: View {
    let icon: String
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Animated glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.premiumPurple.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(glowPulse ? 1.2 : 1.0)
                .blur(radius: 15)

            // Icon background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.premiumPurple.opacity(0.2), Color.premiumBlue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.premiumPurple, Color.premiumBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Enhanced Trial Timeline
private struct EnhancedTrialTimeline: View {
    let selectedPlan: SubscriptionPlan
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            TimelineStepView(
                icon: "play.fill",
                day: "Bugün",
                label: "Başla",
                color: .appMint,
                isFirst: true
            )

            TimelineConnectorLine()

            TimelineStepView(
                icon: "bell.fill",
                day: "5. Gün",
                label: "Hatırlatma",
                color: .warmOrange,
                isFirst: false
            )

            TimelineConnectorLine()

            TimelineStepView(
                icon: "creditcard.fill",
                day: "7. Gün",
                label: "Ödeme",
                color: .premiumPurple,
                isFirst: false
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

private struct TimelineStepView: View {
    let icon: String
    let day: String
    let label: String
    let color: Color
    let isFirst: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(day)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isFirst ? color : .secondary)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineConnectorLine: View {
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

// MARK: - Enhanced Social Proof Bar
private struct EnhancedSocialProofBar: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ProofItem(icon: "star.fill", value: "4.8", label: "Puan", color: .yellow)
            Divider().frame(height: 28)
            ProofItem(icon: "person.2.fill", value: "50K+", label: "Kullanıcı", color: .premiumBlue)
            Divider().frame(height: 28)
            ProofItem(icon: "arrow.down.circle.fill", value: "2TB+", label: "Tasarruf", color: .appMint)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground).opacity(0.6) : .white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

private struct ProofItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Enhanced Plan Selector
private struct EnhancedPlanSelector: View {
    @Binding var selectedPlan: SubscriptionPlan
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            EnhancedPlanCard(
                title: "Haftalık",
                price: "--",
                period: "/hafta",
                badge: nil,
                isSelected: selectedPlan == .monthly
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPlan = .monthly
                }
            }

            EnhancedPlanCard(
                title: "Yıllık",
                price: "--",
                period: "/yıl",
                badge: "%70 Tasarruf",
                isSelected: selectedPlan == .yearly
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPlan = .yearly
                }
            }
        }
    }
}

private struct EnhancedPlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let isSelected: Bool
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
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, badge != nil ? 22 : 14)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(price)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(period)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 95)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.premiumPurple.opacity(0.08), Color.premiumBlue.opacity(0.04)],
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
                .shadow(color: isSelected ? Color.premiumPurple.opacity(0.15) : .clear, radius: 8, x: 0, y: 4)

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
                                .background(Circle().fill(Color(.systemBackground)).frame(width: 14, height: 14))
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

// MARK: - Feature Highlights Grid
private struct FeatureHighlightsGrid: View {
    let features: [String]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(features, id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appMint)

                    Text(feature)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.appMint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Premium CTA Button
private struct PremiumCTAButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    @State private var glowOpacity: Double = 0.3

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(title)
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
            .shadow(color: Color.premiumPurple.opacity(glowOpacity), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.5
            }
        }
    }
}

// MARK: - Trust Indicator
private struct TrustIndicator: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Trust Badge
struct TrustBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - App Icon Header
struct AppIconHeader: View {
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0

    var body: some View {
        VStack(spacing: Spacing.md) {
            // App Icon with glow effect
            ZStack {
                // Glow
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                // App Icon
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }
}

// MARK: - Plan Toggle
struct PlanToggle: View {
    @Binding var selectedPlan: SubscriptionPlan

    var body: some View {
        HStack(spacing: 0) {
            // Yearly Option
            PlanToggleOption(
                title: AppStrings.Paywall.yearlyPlan,
                subtitle: AppStrings.Paywall.savings,
                isSelected: selectedPlan == .yearly
            ) {
                withAnimation(AppAnimation.spring) {
                    selectedPlan = .yearly
                }
            }

            // Monthly Option
            PlanToggleOption(
                title: AppStrings.Paywall.monthlyPlan,
                subtitle: nil,
                isSelected: selectedPlan == .monthly
            ) {
                withAnimation(AppAnimation.spring) {
                    selectedPlan = .monthly
                }
            }
        }
        .padding(4)
        .background(Color.appSurface)
        .clipShape(Capsule())
    }
}

struct PlanToggleOption: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.appMint : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.appBackground : Color.clear)
                    .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trial Timeline
struct TrialTimeline: View {
    let selectedPlan: SubscriptionPlan

    var body: some View {
        VStack(spacing: 0) {
            // Step 1: Today
            TimelineStep(
                icon: "checkmark.circle.fill",
                iconColor: .appAccent,
                title: AppStrings.Paywall.today,
                description: AppStrings.Paywall.todayDesc,
                isFirst: true,
                isLast: false
            )

            // Step 2: Reminder
            TimelineStep(
                icon: "bell.fill",
                iconColor: .appAccent,
                title: AppStrings.Paywall.anytime,
                description: AppStrings.Paywall.anytimeDesc,
                isFirst: false,
                isLast: false
            )

            // Step 3: Charge
            TimelineStep(
                icon: "creditcard.fill",
                iconColor: .appAccent,
                title: selectedPlan == .yearly ? AppStrings.Paywall.renewal : AppStrings.Paywall.renewal,
                description: selectedPlan == .yearly ?
                    AppStrings.Paywall.renewalDescYearly :
                    AppStrings.Paywall.renewalDescMonthly,
                isFirst: false,
                isLast: true
            )
        }
        .padding(Spacing.lg)
        .background(Color.appSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct TimelineStep: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Timeline line and icon
            VStack(spacing: 0) {
                // Top line
                if !isFirst {
                    Rectangle()
                        .fill(Color.appAccent.opacity(0.3))
                        .frame(width: 2, height: 20)
                } else {
                    Color.clear
                        .frame(width: 2, height: 20)
                }

                // Icon circle
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                // Bottom line
                if !isLast {
                    Rectangle()
                        .fill(Color.appAccent.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                } else {
                    Color.clear
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 36)

            // Content
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(.vertical, Spacing.sm)

            Spacer()
        }
    }
}

// MARK: - Social Proof Banner
struct SocialProofBanner: View {
    @State private var count: Int = 0
    private let targetCount = 47500

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Stars
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.goldAccent)
                }
            }

            Divider()
                .frame(height: 20)

            // Counter
            HStack(spacing: Spacing.xxs) {
                Text("\(count.formatted())+")
                    .font(.system(.callout, design: .rounded).monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(AppStrings.Paywall.filesOptimized)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.appSurface)
        .clipShape(Capsule())
        .onAppear {
            animateCounter()
        }
    }

    private func animateCounter() {
        let duration: Double = 1.5
        let steps = 30
        let increment = targetCount / steps

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration / Double(steps)) * Double(step)) {
                withAnimation {
                    count = min(step * increment, targetCount)
                }
            }
        }
    }
}

struct PaywallContextView: View {
    let context: PaywallContext

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(context.title)
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                Text(context.subtitle)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)

                if let limit = context.limitDescription {
                    InfoBanner(type: .warning, message: limit)
                }

                FeatureList(features: context.highlights)
            }
        }
    }
}

#Preview {
    PaywallScreen(
        limitExceeded: false,
        currentFileSize: nil,
        onSubscribe: { plan in
            print("Subscribe to: \(plan)")
        },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
}
