//
//  ModernPaywallScreen.swift
//  optimize
//
//  Holographic Optimizer HUD - Premium Paywall v3.0
//  Interactive gauge + Bento grid features + Gamification design
//

import SwiftUI

struct ModernPaywallScreen: View {
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var isAnimating = false
    @State private var showCloseButton = false
    @Environment(\.colorScheme) private var colorScheme

    // Efficiency Gauge Animation
    @State private var gaugeValue: CGFloat = 0.4

    // StoreKit prices
    @ObservedObject var subscriptionManager: SubscriptionManager

    // Feature-specific paywall context
    var context: PaywallContext?

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    // MARK: - Computed Properties

    private var displayTitle: String {
        context?.title ?? "Sisteminizi Ozgürlestirin"
    }

    private var displaySubtitle: String {
        context?.subtitle ?? "OptimizeApp Premium ile sikistirma limitlerini kaldirin ve %100 verime ulasin."
    }

    private var displayIcon: String {
        context?.icon ?? "bolt.horizontal.circle.fill"
    }

    /// Get formatted price for weekly plan from StoreKit
    private var weeklyPrice: String {
        if let product = subscriptionManager.products.first(where: { $0.id.contains("monthly") }) {
            return product.displayPrice
        }
        return "--"
    }

    /// Get formatted price for yearly plan from StoreKit
    private var yearlyPrice: String {
        if let product = subscriptionManager.products.first(where: { $0.id.contains("yearly") }) {
            return product.displayPrice
        }
        return "--"
    }

    /// Weekly price calculation from yearly
    private var weeklyFromYearly: String {
        if let product = subscriptionManager.products.first(where: { $0.id.contains("yearly") }) {
            let weeklyValue = product.price / 52
            return weeklyValue.formatted(.currency(code: product.priceFormatStyle.currencyCode ?? "TRY"))
        }
        return "--"
    }

    var body: some View {
        ZStack {
            // 1. Background: Deep black with Aurora blobs
            HolographicBackground(isAnimating: $isAnimating)

            VStack(spacing: 0) {
                // 2. Top Bar: Close & Restore
                HStack {
                    Button(action: {
                        Haptics.selection()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .opacity(showCloseButton ? 1 : 0)
                    .disabled(!showCloseButton)

                    Spacer()

                    Button(action: {
                        Haptics.selection()
                        onRestore()
                    }) {
                        Text("Geri Yükle")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {

                        // 3. HERO: Interactive Efficiency Meter
                        VStack(spacing: 20) {
                            EfficiencyGauge(
                                gaugeValue: gaugeValue,
                                selectedPlan: selectedPlan
                            )

                            VStack(spacing: 8) {
                                Text(displayTitle)
                                    .font(.displayTitle)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text(displaySubtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 20)

                        // 4. BENTO GRID FEATURES
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                HUDFeatureBox(
                                    icon: "bolt.fill",
                                    title: "Sinirsiz Hiz",
                                    desc: "4x daha hizli islem",
                                    color: .yellow
                                )
                                HUDFeatureBox(
                                    icon: "lock.shield.fill",
                                    title: "Güvenli Kasa",
                                    desc: "Tam sifreleme",
                                    color: .premiumBlue
                                )
                            }
                            HStack(spacing: 12) {
                                HUDFeatureBox(
                                    icon: "photo.stack",
                                    title: "Toplu Islem",
                                    desc: "Ayni anda 100+ dosya",
                                    color: .premiumPurple
                                )
                                HUDFeatureBox(
                                    icon: "crown.fill",
                                    title: "Pro Destek",
                                    desc: "7/24 Öncelik",
                                    color: .appMint
                                )
                            }
                        }
                        .padding(.horizontal)

                        // 5. PLAN SELECTOR
                        VStack(spacing: 12) {
                            // YEARLY PLAN (Recommended)
                            HUDPlanCard(
                                planType: .yearly,
                                isSelected: selectedPlan == .yearly,
                                price: "\(yearlyPrice) / yil",
                                subtitle: "Haftalik \(weeklyFromYearly)'ye gelir",
                                badge: "EN IYI TEKLIF"
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedPlan = .yearly
                                    gaugeValue = 1.0
                                }
                                Haptics.selection()
                            }

                            // WEEKLY PLAN
                            HUDPlanCard(
                                planType: .monthly,
                                isSelected: selectedPlan == .monthly,
                                price: "\(weeklyPrice) / hafta",
                                subtitle: "Istedigin zaman iptal et",
                                badge: nil
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedPlan = .monthly
                                    gaugeValue = 0.5
                                }
                                Haptics.selection()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        // Legal text
                        Text("Abonelik otomatik olarak yenilenir. Istediginiz zaman ayarlardan iptal edebilirsiniz.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                    }
                }

                // 6. STICKY BOTTOM CTA
                VStack(spacing: 12) {
                    Button(action: {
                        Haptics.impact(style: .medium)
                        isLoading = true
                        onSubscribe(selectedPlan)
                    }) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else {
                                Text(selectedPlan == .yearly ? "Tam Gücü Etkinlestir" : "Haftalik Basla")
                                    .font(.headline.weight(.bold))
                                Image(systemName: "arrow.right")
                                    .font(.headline.weight(.bold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.appMint)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.appMint.opacity(0.5), radius: 20, x: 0, y: 5)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)

                    // Footer Links
                    HStack(spacing: Spacing.md) {
                        Button(action: onPrivacy) {
                            Text("Gizlilik")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                            .font(.system(size: 10))

                        Button(action: onTerms) {
                            Text("Kosullar")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.bottom, 10)
                }
                .padding(.top, 20)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            isAnimating = true

            // Animate gauge to full on appear (show potential)
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3)) {
                gaugeValue = 1.0
            }

            // Delayed close button for better conversion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showCloseButton = true
                }
            }
        }
    }
}

// MARK: - Holographic Background

private struct HolographicBackground: View {
    @Binding var isAnimating: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                // Mint Aurora blob
                Circle()
                    .fill(Color.appMint.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(
                        x: isAnimating ? -50 : 50,
                        y: -100
                    )
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // Purple/Blue Aurora blob
                Circle()
                    .fill(Color.premiumPurple.opacity(0.25))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(
                        x: proxy.size.width - 150,
                        y: isAnimating ? 80 : 120
                    )
                    .animation(
                        .easeInOut(duration: 5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // Accent blob
                Circle()
                    .fill(Color.premiumBlue.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(
                        x: isAnimating ? proxy.size.width * 0.3 : proxy.size.width * 0.5,
                        y: proxy.size.height * 0.6
                    )
                    .animation(
                        .easeInOut(duration: 6).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Efficiency Gauge (Interactive Meter)

private struct EfficiencyGauge: View {
    let gaugeValue: CGFloat
    let selectedPlan: SubscriptionPlan

    var body: some View {
        ZStack {
            // Outer ring (background)
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 20)
                .frame(width: 160, height: 160)

            // Fill ring (animated)
            Circle()
                .trim(from: 0, to: gaugeValue)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.premiumPurple, Color.appMint]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.appMint.opacity(0.5), radius: 20, x: 0, y: 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: gaugeValue)

            // Inner content
            VStack(spacing: 4) {
                Text("\(Int(gaugeValue * 100))%")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: gaugeValue * 100))
                    .animation(.spring(response: 0.4), value: gaugeValue)

                Text(selectedPlan == .yearly ? "MAX POWER" : "LIMITED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(selectedPlan == .yearly ? Color.appMint : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            selectedPlan == .yearly
                                ? Color.appMint.opacity(0.2)
                                : Color.white.opacity(0.1)
                        )
                    )
            }
        }
    }
}

// MARK: - Bento Feature Box

private struct HUDFeatureBox: View {
    let icon: String
    let title: String
    let desc: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.glassSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - HUD Plan Card

private struct HUDPlanCard: View {
    let planType: SubscriptionPlan
    let isSelected: Bool
    let price: String
    let subtitle: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.appMint : Color.white.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.appMint)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(planType == .yearly ? "Yillik (Pro)" : "Haftalik")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(price)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? Color.appMint : .white)

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.proGold)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.appMint.opacity(0.1) : Color.glassSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.appMint : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Preview

#Preview("Default") {
    ModernPaywallScreen(
        subscriptionManager: SubscriptionManager.shared,
        context: nil,
        onSubscribe: { plan in print("Subscribe: \(plan)") },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
}

#Preview("Batch Processing") {
    ModernPaywallScreen(
        subscriptionManager: SubscriptionManager.shared,
        context: .batchProcessing,
        onSubscribe: { plan in print("Subscribe: \(plan)") },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
}

#Preview("Dark Mode") {
    ModernPaywallScreen(
        subscriptionManager: SubscriptionManager.shared,
        context: .advancedPresets,
        onSubscribe: { plan in print("Subscribe: \(plan)") },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
    .preferredColorScheme(.dark)
}
