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

    var limitExceeded: Bool = false
    var currentFileSize: String? = nil

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with back/close button
            HStack {
                Button(action: {
                    Haptics.selection()
                    onDismiss()
                }) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.appBody)
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.pressable)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // App Icon Header
                    AppIconHeader()

                    if let context {
                        PaywallContextView(context: context)
                            .padding(.horizontal, Spacing.md)
                    }

                    // Title Section
                    VStack(spacing: Spacing.xs) {
                        Text("How Subscription Works")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(selectedPlan == .yearly ?
                             "Yearly $24.99 ($2.08/month)" :
                             "Monthly $4.99")
                            .font(.appBody)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    // Plan Toggle
                    PlanToggle(selectedPlan: $selectedPlan)
                        .padding(.horizontal, Spacing.xl)

                    // Trial Timeline
                    TrialTimeline(selectedPlan: selectedPlan)
                        .padding(.horizontal, Spacing.md)

                    GlassCard {
                        FeatureList(features: [
                            "No ads, clean interface",
                            "PDF, image, video and office files",
                            "Smart target sizes & quality profiles",
                            "Priority compression engine"
                        ])
                    }
                    .padding(.horizontal, Spacing.md)

                    // Limit exceeded banner (if applicable)
                    if limitExceeded, let size = currentFileSize {
                        LimitExceededBanner(
                            currentSize: size,
                            maxSize: "50 MB"
                        )
                        .padding(.horizontal, Spacing.md)
                    }

                    Spacer(minLength: Spacing.lg)
                }
                .padding(.top, Spacing.lg)
            }

            // Bottom CTA Section
            VStack(spacing: Spacing.md) {
                // Main CTA Button
                Button(action: {
                    Haptics.impact(style: .medium)
                    isLoading = true
                    onSubscribe(selectedPlan)
                }) {
                    HStack(spacing: Spacing.xs) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Text("Start Pro")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.pressable)
                .disabled(isLoading)
                .padding(.horizontal, Spacing.md)

                // Restore button
                Button(action: {
                    Haptics.selection()
                    isRestoring = true
                    onRestore()
                }) {
                    HStack(spacing: Spacing.xs) {
                        if isRestoring {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                                .scaleEffect(0.7)
                        }
                        Text("Restore Purchase")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isRestoring)

                // Footer links
                PaywallFooterLinks(
                    onPrivacy: onPrivacy,
                    onTerms: onTerms
                )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(
                Color.appBackground
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
            )
        }
        .appBackgroundLayered()
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
                title: "Yearly",
                subtitle: "58% savings",
                isSelected: selectedPlan == .yearly
            ) {
                withAnimation(AppAnimation.spring) {
                    selectedPlan = .yearly
                }
            }

            // Monthly Option
            PlanToggleOption(
                title: "Monthly",
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
                title: "Today",
                description: "Instant access to all Pro features. Unlimited file size, batch processing and more.",
                isFirst: true,
                isLast: false
            )

            // Step 2: Reminder
            TimelineStep(
                icon: "bell.fill",
                iconColor: .appAccent,
                title: "Anytime",
                description: "Cancel your subscription anytime from App Store settings.",
                isFirst: false,
                isLast: false
            )

            // Step 3: Charge
            TimelineStep(
                icon: "creditcard.fill",
                iconColor: .appAccent,
                title: selectedPlan == .yearly ? "Yearly renewal" : "Monthly renewal",
                description: selectedPlan == .yearly ?
                    "Billed $24.99 annually. Cancel anytime." :
                    "Billed $4.99 monthly. Cancel anytime.",
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

                Text("files optimized")
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
