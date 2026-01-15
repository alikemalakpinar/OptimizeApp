//
//  ModernPaywallScreen.swift
//  optimize
//
//  Cinematic HUD v4.0 - Premium Paywall
//  Noise texture + Tactile gauge + Gradient borders
//
//  UPDATED: Full localization support + Responsive design for all screen sizes
//

import SwiftUI

struct ModernPaywallScreen: View {
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var isAnimating = false
    @State private var showCloseButton = false
    @Environment(\.colorScheme) private var colorScheme

    // StoreKit prices
    @ObservedObject var subscriptionManager: SubscriptionManager

    // Context
    var context: PaywallContext?

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    // Animation State
    @State private var gaugeValue: CGFloat = 0.0

    // MARK: - Localized Strings

    private enum LocalizedStrings {
        static let defaultTitle = String(localized: "paywall.title.free_system", defaultValue: "Sisteminizi Özgürleştirin")
        static let defaultSubtitle = String(localized: "paywall.subtitle.remove_limits", defaultValue: "OptimizeApp Premium ile sınırları kaldırın.")
        static let restore = String(localized: "paywall.button.restore", defaultValue: "Geri Yükle")
        static let yearlyPlan = String(localized: "paywall.plan.yearly", defaultValue: "Yıllık Plan")
        static let weeklyPlan = String(localized: "paywall.plan.weekly", defaultValue: "Haftalık Plan")
        static let perYear = String(localized: "paywall.period.year", defaultValue: "/ yıl")
        static let perWeek = String(localized: "paywall.period.week", defaultValue: "/ hafta")
        static let weeklyFromYearly = String(localized: "paywall.subtitle.weekly_from_yearly", defaultValue: "Haftalık %@'ye gelir")
        static let cancelAnytime = String(localized: "paywall.subtitle.cancel_anytime", defaultValue: "İstediğin zaman iptal et")
        static let mostPopular = String(localized: "paywall.badge.most_popular", defaultValue: "EN POPÜLER")
        static let startFullPower = String(localized: "paywall.button.start_full_power", defaultValue: "Tam Gücü Başlat")
        static let startTrial = String(localized: "paywall.button.start_trial", defaultValue: "Denemeye Başla")
        static let autoRenewal = String(localized: "paywall.legal.auto_renewal", defaultValue: "Abonelik otomatik yenilenir. Ayarlardan iptal edilebilir.")
        static let privacy = String(localized: "paywall.link.privacy", defaultValue: "Gizlilik")
        static let terms = String(localized: "paywall.link.terms", defaultValue: "Koşullar")

        // Features
        static let unlimitedSpeed = String(localized: "paywall.feature.unlimited_speed", defaultValue: "Sınırsız Hız")
        static let secureVault = String(localized: "paywall.feature.secure_vault", defaultValue: "Güvenli Kasa")
        static let batchProcessing = String(localized: "paywall.feature.batch_processing", defaultValue: "Toplu İşlem")
        static let proSupport = String(localized: "paywall.feature.pro_support", defaultValue: "Pro Destek")

        // Gauge Labels
        static let maximum = String(localized: "paywall.gauge.maximum", defaultValue: "MAXIMUM")
        static let limited = String(localized: "paywall.gauge.limited", defaultValue: "LIMITED")
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        context?.title ?? LocalizedStrings.defaultTitle
    }

    private var displaySubtitle: String {
        context?.subtitle ?? LocalizedStrings.defaultSubtitle
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
        GeometryReader { geometry in
            let isCompactHeight = geometry.size.height < 700 // iPhone SE, mini
            let gaugeSize = calculateGaugeSize(for: geometry.size)
            let verticalSpacing = isCompactHeight ? 20.0 : 32.0

            ZStack {
                // 1. LAYER: Cinematic Background (Noise + Aurora)
                CinematicBackground(isAnimating: $isAnimating)

                VStack(spacing: 0) {
                    // 2. TOP BAR
                    HStack {
                        Button(action: {
                            Haptics.selection()
                            onDismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(8)
                                .background(Color.white.opacity(0.1), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .opacity(showCloseButton ? 1 : 0)
                        .disabled(!showCloseButton)

                        Spacer()

                        Button(action: {
                            Haptics.selection()
                            onRestore()
                        }) {
                            Text(LocalizedStrings.restore)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: verticalSpacing) {

                            // 3. HERO: Tactile Gauge (Responsive)
                            VStack(spacing: isCompactHeight ? 16 : 24) {
                                TactileGauge(
                                    value: gaugeValue,
                                    isYearly: selectedPlan == .yearly,
                                    maxLabel: LocalizedStrings.maximum,
                                    limitedLabel: LocalizedStrings.limited
                                )
                                .frame(width: gaugeSize, height: gaugeSize)

                                VStack(spacing: isCompactHeight ? 8 : 12) {
                                    Text(displayTitle)
                                        .font(.system(size: isCompactHeight ? 24 : 28, weight: .bold, design: .default))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .shadow(color: Color.appMint.opacity(0.3), radius: 20, x: 0, y: 0)

                                    Text(displaySubtitle)
                                        .font(.system(size: isCompactHeight ? 13 : 15, weight: .regular, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 30)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.top, isCompactHeight ? 10 : 20)

                            // 4. BENTO GRID FEATURES (Compact) - Localized
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    TechFeatureBox(icon: "bolt.fill", title: LocalizedStrings.unlimitedSpeed, color: .yellow)
                                    TechFeatureBox(icon: "lock.shield.fill", title: LocalizedStrings.secureVault, color: .premiumBlue)
                                }
                                HStack(spacing: 12) {
                                    TechFeatureBox(icon: "photo.stack", title: LocalizedStrings.batchProcessing, color: .premiumPurple)
                                    TechFeatureBox(icon: "crown.fill", title: LocalizedStrings.proSupport, color: .appMint)
                                }
                            }
                            .padding(.horizontal)

                            // 5. PLAN SELECTION - Localized
                            VStack(spacing: isCompactHeight ? 12 : 16) {
                                // YEARLY
                                PremiumPlanCard(
                                    title: LocalizedStrings.yearlyPlan,
                                    price: yearlyPrice,
                                    period: LocalizedStrings.perYear,
                                    subtitle: String(format: LocalizedStrings.weeklyFromYearly, weeklyFromYearly),
                                    badge: LocalizedStrings.mostPopular,
                                    isSelected: selectedPlan == .yearly,
                                    action: {
                                        Haptics.impact(style: .medium)
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            selectedPlan = .yearly
                                            gaugeValue = 1.0
                                        }
                                    }
                                )

                                // WEEKLY
                                PremiumPlanCard(
                                    title: LocalizedStrings.weeklyPlan,
                                    price: weeklyPrice,
                                    period: LocalizedStrings.perWeek,
                                    subtitle: LocalizedStrings.cancelAnytime,
                                    badge: nil,
                                    isSelected: selectedPlan == .monthly,
                                    action: {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            selectedPlan = .monthly
                                            gaugeValue = 0.45
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal)

                            // Legal - Localized
                            Text(LocalizedStrings.autoRenewal)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 100)
                        }
                    }
                }

                // 6. STICKY CTA (Bottom Bar) - Localized
                VStack {
                    Spacer()

                    VStack(spacing: isCompactHeight ? 12 : 16) {
                        Button(action: {
                            Haptics.success()
                            isLoading = true
                            onSubscribe(selectedPlan)
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(selectedPlan == .yearly ? LocalizedStrings.startFullPower : LocalizedStrings.startTrial)
                                        .font(.system(size: isCompactHeight ? 15 : 17, weight: .bold, design: .rounded))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: isCompactHeight ? 13 : 15, weight: .bold))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: isCompactHeight ? 50 : 58)
                            .background(
                                ZStack {
                                    Color.appMint
                                    // Inner highlight gradient
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.appMint.opacity(0.5), radius: 20, x: 0, y: 5)
                            .scaleEffect(isLoading ? 0.98 : 1)
                        }
                        .disabled(isLoading)

                        // Footer Links - Localized
                        HStack(spacing: 20) {
                            Button(action: onPrivacy) {
                                Text(LocalizedStrings.privacy)
                            }
                            Text("•")
                            Button(action: onTerms) {
                                Text(LocalizedStrings.terms)
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, isCompactHeight ? 16 : 20)
                    .padding(.top, isCompactHeight ? 16 : 20)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0), .black.opacity(0.9), .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .onAppear {
            isAnimating = true
            // Opening animation - show full potential
            withAnimation(.spring(response: 1.2, dampingFraction: 0.6).delay(0.2)) {
                gaugeValue = 1.0
            }

            // Delayed close button for better conversion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showCloseButton = true }
            }
        }
    }

    // MARK: - Responsive Helpers

    /// Calculate optimal gauge size based on screen dimensions
    /// Ensures gauge fits well on iPhone SE (667pt) through iPhone Pro Max (932pt)
    private func calculateGaugeSize(for size: CGSize) -> CGFloat {
        let screenHeight = size.height
        let screenWidth = size.width

        // Base size on screen height percentage (25% of height)
        let heightBasedSize = screenHeight * 0.25

        // Also limit by width (50% of width max)
        let widthBasedSize = screenWidth * 0.5

        // Use the smaller value, but clamp between 140-220
        return min(max(min(heightBasedSize, widthBasedSize), 140), 220)
    }
}

// MARK: - 🎨 Cinematic Background (Noise + Aurora)

private struct CinematicBackground: View {
    @Binding var isAnimating: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Aurora Blobs
            GeometryReader { proxy in
                // Primary Mint Light
                Circle()
                    .fill(Color.appMint.opacity(0.2))
                    .frame(width: 350, height: 350)
                    .blur(radius: 90)
                    .offset(x: isAnimating ? -50 : 100, y: -100)
                    .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: isAnimating)

                // Secondary Purple Light
                Circle()
                    .fill(Color.premiumPurple.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: proxy.size.width - 100, y: 150)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: isAnimating)

                // Tertiary Blue Accent
                Circle()
                    .fill(Color.premiumBlue.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: isAnimating ? proxy.size.width * 0.2 : proxy.size.width * 0.6, y: proxy.size.height * 0.5)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: isAnimating)
            }
            .ignoresSafeArea()

            // 🌟 GRAIN OVERLAY - Premium texture feel
            // This visual noise makes digital gradients look 'analog' and expensive
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .blendMode(.overlay)
                .overlay(
                    GeometryReader { geo in
                        Color.white
                            .opacity(0.05)
                            .mask(
                                NoiseTexture()
                                    .frame(width: geo.size.width, height: geo.size.height)
                            )
                    }
                )
                .ignoresSafeArea()
        }
    }
}

// Noise Texture Generator
private struct NoiseTexture: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            for _ in 0..<Int(size.width * size.height / 20) {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                context.opacity = Double.random(in: 0...0.5)
                context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white))
            }
        }
    }
}

// MARK: - 🏎️ Tactile Gauge (Instrument Panel Style) - Responsive & Localized

private struct TactileGauge: View {
    var value: CGFloat // 0.0 to 1.0
    var isYearly: Bool
    var maxLabel: String = "MAXIMUM"
    var limitedLabel: String = "LIMITED"

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringLineWidth = size * 0.12 // 12% of gauge size
            let tickOffset = size * 0.425 // Tick marks position
            let percentFontSize = size * 0.23 // Percentage font size
            let labelFontSize = max(8, size * 0.05) // Label font size (min 8pt)

            ZStack {
                // Background Ring
                Circle()
                    .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))

                // Tick Marks - Gives instrument panel feel
                ForEach(0..<40, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 5 == 0 ? 0.3 : 0.1))
                        .frame(width: 2, height: i % 5 == 0 ? size * 0.06 : size * 0.03)
                        .offset(y: -tickOffset)
                        .rotationEffect(.degrees(Double(i) / 40 * 360))
                }

                // Fill Arc (Gradient)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.appMint.opacity(0.1),
                                Color.appMint,
                                Color.white
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.appMint.opacity(0.6), radius: size * 0.075, x: 0, y: 0) // Neon Glow
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: value)

                // Center Info
                VStack(spacing: 2) {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: percentFontSize, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(value: value * 100))
                        .animation(.spring(response: 0.4), value: value)

                    Text(isYearly ? maxLabel : limitedLabel)
                        .font(.system(size: labelFontSize, weight: .bold))
                        .tracking(2)
                        .foregroundColor(isYearly ? .black : .white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isYearly ? Color.appMint : Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// MARK: - 📱 Tech Feature Box (Clean & Compact)

private struct TechFeatureBox: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - 💎 Premium Plan Card (Glassy + Gradient Borders)

private struct PremiumPlanCard: View {
    let title: String
    let price: String
    let period: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Radio Button (Animated)
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appMint : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.appMint)
                            .frame(width: 12, height: 12)
                            .transition(.scale)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.proGold)
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text(price)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? Color.appMint : .white)

                    Text(period)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.appMint.opacity(0.1) : Color.white.opacity(0.03))
            )
            .overlay(
                // Gradient Border - Light reflection effect
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.appMint, Color.appMint.opacity(0.3)]
                                : [Color.white.opacity(0.1), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
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
