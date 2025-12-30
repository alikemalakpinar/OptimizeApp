//
//  PaywallScreen.swift
//  optimize
//
//  Subscription paywall with glowing badges and social proof
//

import SwiftUI

struct PaywallScreen: View {
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

    private let features = [
        "1 GB'a kadar büyük dosyalar",
        "Hedef boyut modu",
        "Batch işlemler",
        "Öncelikli sıkıştırma",
        "Reklamsız deneyim"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                HeaderCloseButton {
                    onDismiss()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Enhanced Header with animation
                    EnhancedPaywallHeader(
                        title: "Sınırları Kaldır",
                        subtitle: "Pro ile büyük dosyaları anında optimize et"
                    )

                    // Limit exceeded banner (if applicable)
                    if limitExceeded, let size = currentFileSize {
                        LimitExceededBanner(
                            currentSize: size,
                            maxSize: "50 MB"
                        )
                    }

                    // Features with checkmarks
                    GlassCard {
                        FeatureList(features: features)
                    }

                    // Plan cards with glowing best value
                    HStack(spacing: Spacing.sm) {
                        EnhancedPlanCard(
                            title: "Aylık",
                            price: "₺49,99",
                            period: "ay",
                            monthlyEquivalent: nil,
                            isSelected: selectedPlan == .monthly,
                            isBestValue: false
                        ) {
                            withAnimation(AppAnimation.spring) {
                                selectedPlan = .monthly
                            }
                        }

                        EnhancedPlanCard(
                            title: "Yıllık",
                            price: "₺249,99",
                            period: "yıl",
                            monthlyEquivalent: "₺20,83 / ay",
                            badge: "En Avantajlı",
                            savings: "%58 tasarruf",
                            isSelected: selectedPlan == .yearly,
                            isBestValue: true
                        ) {
                            withAnimation(AppAnimation.spring) {
                                selectedPlan = .yearly
                            }
                        }
                    }

                    // Subscription info
                    Text("Abonelik otomatik olarak yenilenir. İstediğiniz zaman iptal edebilirsiniz.")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)

                    // Social proof
                    SocialProofBanner()

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }

            // Bottom section
            VStack(spacing: Spacing.md) {
                PrimaryButton(
                    title: "Pro'ya Geç",
                    isLoading: isLoading
                ) {
                    isLoading = true
                    onSubscribe(selectedPlan)
                }

                RestoreButton(isLoading: isRestoring) {
                    isRestoring = true
                    onRestore()
                }

                PaywallFooterLinks(
                    onPrivacy: onPrivacy,
                    onTerms: onTerms
                )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.appBackground)
        }
        .appBackgroundLayered()
    }
}

// MARK: - Enhanced Paywall Header
struct EnhancedPaywallHeader: View {
    let title: String
    var subtitle: String? = nil

    @State private var crownScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Animated Pro badge with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.goldAccent.opacity(glowOpacity))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)

                // Crown icon
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                    Text("PRO")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [.goldAccent, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(crownScale)
            }

            Text(title)
                .font(.appTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                crownScale = 1.08
                glowOpacity = 0.6
            }
        }
    }
}

// MARK: - Enhanced Plan Card with Glow
struct EnhancedPlanCard: View {
    let title: String
    let price: String
    let period: String
    var monthlyEquivalent: String? = nil
    var badge: String? = nil
    var savings: String? = nil
    var isSelected: Bool = false
    var isBestValue: Bool = false
    let onTap: () -> Void

    @State private var glowIntensity: Double = 0.3

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap()
        }) {
            VStack(spacing: Spacing.sm) {
                // Badge if present
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            LinearGradient(
                                colors: [.goldAccent, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.goldAccent.opacity(glowIntensity), radius: 8)
                        .offset(y: -Spacing.xxs)
                }

                // Title
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                // Price
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(price)
                        .font(.appNumberMedium)
                        .foregroundStyle(.primary)

                    Text("/ \(period)")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                // Monthly equivalent
                if let monthly = monthlyEquivalent {
                    Text(monthly)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                // Savings
                if let savings = savings {
                    Text(savings)
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.appMint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isSelected ? Color.appAccent.opacity(0.08) : Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        isSelected ? (isBestValue ? Color.goldAccent : Color.appAccent) : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isBestValue && isSelected ? Color.goldAccent.opacity(glowIntensity) : .clear,
                radius: 12
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isBestValue ? Color.goldAccent : Color.appAccent)
                        .offset(x: -Spacing.sm, y: Spacing.sm)
                }
            }
        }
        .buttonStyle(.pressable)
        .onAppear {
            if isBestValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.6
                }
            }
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

                Text("dosya optimize edildi")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.appSurface)
        .clipShape(Capsule())
        .onAppear {
            // Animate counter
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

#Preview {
    PaywallScreen(
        limitExceeded: true,
        currentFileSize: "150 MB",
        onSubscribe: { plan in
            print("Subscribe to: \(plan)")
        },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
}
