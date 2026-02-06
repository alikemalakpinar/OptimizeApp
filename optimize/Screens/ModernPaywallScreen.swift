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

    // Restore State
    @State private var restoreState: RestoreState = .idle
    @State private var showRestoreAlert = false
    @State private var restoreAlertTitle = ""
    @State private var restoreAlertMessage = ""

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

    // MARK: - Restore State
    enum RestoreState: Equatable {
        case idle
        case loading
        case success
        case noSubscription
        case alreadyPremium
        case error
    }

    // MARK: - Localized Strings

    private enum LocalizedStrings {
        static let defaultTitle = "iPhone'unu İlk Günkü Hızına Döndür"
        static let defaultSubtitle = "Fotoğraf, video, rehber ve takvim temizliği. Tek uygulama, sınırsız optimizasyon."
        static let restore = "Geri Yükle"
        static let yearlyPlan = "Yıllık Plan"
        static let weeklyPlan = "Haftalık Plan"
        static let lifetimePlan = "Ömür Boyu"
        static let perYear = "/ yıl"
        static let perWeek = "/ hafta"
        static let oneTime = "tek seferlik"
        static let weeklyFromYearly = "Haftalık %@'ye gelir"
        static let cancelAnytime = "İstediğin zaman iptal et"
        static let mostPopular = "EN POPÜLER"
        static let bestValue = "EN AVANTAJLI"
        static let startTrial = "3 Gün Ücretsiz Dene"
        static let startNow = "Hemen Başla"
        static let autoRenewal = "Yıllık plan 3 gün ücretsiz deneme içerir. Deneme bitmeden ücret alınmaz. Abonelik otomatik yenilenir, Ayarlar'dan iptal edilebilir."
        static let privacy = "Gizlilik"
        static let terms = "Koşullar"

        // Gauge Labels
        static let maximum = "MAKSİMUM"
        static let limited = "SINIRLI"
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
        if let product = subscriptionManager.products.first(where: { $0.id.contains("weekly") }) {
            return product.displayPrice
        }
        return "₺99,99"
    }

    /// Get formatted price for yearly plan from StoreKit
    private var yearlyPrice: String {
        if let product = subscriptionManager.products.first(where: { $0.id.contains("yearly") }) {
            return product.displayPrice
        }
        return "₺599,99"
    }

    /// Get formatted price for lifetime plan from StoreKit
    private var lifetimePrice: String {
        if let product = subscriptionManager.products.first(where: { $0.id.contains("lifetime") }) {
            return product.displayPrice
        }
        return "₺999,99"
    }

    /// Weekly price calculation from yearly
    private var weeklyFromYearly: String {
        if let product = subscriptionManager.products.first(where: { $0.id.contains("yearly") }) {
            let weeklyValue = product.price / 52
            return weeklyValue.formatted(.currency(code: product.priceFormatStyle.currencyCode))
        }
        return "₺11,54"
    }

    /// Savings percentage of yearly vs weekly
    private var yearlySavingsPercent: Int {
        if let weeklyProduct = subscriptionManager.products.first(where: { $0.id.contains("weekly") }),
           let yearlyProduct = subscriptionManager.products.first(where: { $0.id.contains("yearly") }) {
            let weeklyAnnual = weeklyProduct.price * 52
            let savings = (weeklyAnnual - yearlyProduct.price) / weeklyAnnual * 100
            return Int(Double(truncating: savings as NSNumber))
        }
        return 77
    }

    /// CTA button text based on selected plan
    private var ctaText: String {
        if selectedPlan == .yearly {
            return LocalizedStrings.startTrial
        } else {
            return LocalizedStrings.startNow
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompactHeight = geometry.size.height < 700 // iPhone SE, mini
            let gaugeSize = calculateGaugeSize(for: geometry.size)
            let verticalSpacing = isCompactHeight ? 16.0 : 24.0

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

                        Button(action: performRestore) {
                            HStack(spacing: 6) {
                                if restoreState == .loading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.6)
                                }
                                Text(LocalizedStrings.restore)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                        .disabled(restoreState == .loading)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .alert(restoreAlertTitle, isPresented: $showRestoreAlert) {
                        Button(AppStrings.UI.done, role: .cancel) {
                            if restoreState == .success || restoreState == .alreadyPremium {
                                onDismiss()
                            }
                        }
                    } message: {
                        Text(restoreAlertMessage)
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: verticalSpacing) {

                            // 3. HERO: Tactile Gauge (Responsive)
                            VStack(spacing: isCompactHeight ? 12 : 20) {
                                TactileGauge(
                                    value: gaugeValue,
                                    isYearly: selectedPlan == .yearly || selectedPlan == .lifetime,
                                    maxLabel: LocalizedStrings.maximum,
                                    limitedLabel: LocalizedStrings.limited
                                )
                                .frame(width: gaugeSize, height: gaugeSize)

                                VStack(spacing: isCompactHeight ? 6 : 10) {
                                    Text(displayTitle)
                                        .font(.system(size: isCompactHeight ? DisplayScale.subtitle : DisplayScale.title, weight: .bold, design: .serif))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .shadow(color: Brand.primary.opacity(0.3), radius: 20, x: 0, y: 0)

                                    Text(displaySubtitle)
                                        .font(.system(size: isCompactHeight ? DisplayScale.caption : DisplayScale.body, weight: .regular, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 30)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.top, isCompactHeight ? 8 : 16)

                            // 4. FEATURE COMPARISON (Free vs Premium)
                            FeatureComparisonSection()
                                .padding(.horizontal)

                            // 5. PLAN SELECTION - 3 Plans
                            VStack(spacing: isCompactHeight ? 10 : 14) {
                                // YEARLY (recommended, with 3-day trial)
                                PremiumPlanCard(
                                    title: LocalizedStrings.yearlyPlan,
                                    price: yearlyPrice,
                                    period: LocalizedStrings.perYear,
                                    subtitle: "3 gün ücretsiz dene • " + String(format: LocalizedStrings.weeklyFromYearly, weeklyFromYearly),
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
                                    isSelected: selectedPlan == .weekly,
                                    action: {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            selectedPlan = .weekly
                                            gaugeValue = 0.45
                                        }
                                    }
                                )

                                // LIFETIME
                                PremiumPlanCard(
                                    title: LocalizedStrings.lifetimePlan,
                                    price: lifetimePrice,
                                    period: LocalizedStrings.oneTime,
                                    subtitle: "Bir kez öde, sonsuza kadar kullan",
                                    badge: LocalizedStrings.bestValue,
                                    isSelected: selectedPlan == .lifetime,
                                    action: {
                                        Haptics.impact(style: .medium)
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            selectedPlan = .lifetime
                                            gaugeValue = 1.0
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal)

                            // ANCHOR PRICING: Show savings comparison
                            if selectedPlan == .yearly {
                                AnchorPricingBanner(
                                    weeklyPrice: weeklyPrice,
                                    weeklyFromYearly: weeklyFromYearly
                                )
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // Legal footer
                            Text(LocalizedStrings.autoRenewal)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                        }
                    }
                }

                // 6. STICKY CTA (Bottom Bar)
                VStack {
                    Spacer()

                    VStack(spacing: isCompactHeight ? 10 : 14) {
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
                                    Text(ctaText)
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

                        // Footer Links
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

    // MARK: - Restore Purchase Handler

    /// Performs restore with comprehensive user feedback
    private func performRestore() {
        guard restoreState != .loading else { return }

        restoreState = .loading
        Haptics.selection()

        Task {
            // Check if already premium first
            if subscriptionManager.status.isPro {
                await MainActor.run {
                    restoreState = .alreadyPremium
                    restoreAlertTitle = "🎉 Zaten Premium!"
                    restoreAlertMessage = "Premium üyeliğiniz aktif durumda. Tüm özelliklere erişebilirsiniz."
                    showRestoreAlert = true
                    Haptics.success()
                }
                return
            }

            // Attempt restore
            await subscriptionManager.restore()

            // Check result after restore
            await MainActor.run {
                if subscriptionManager.status.isPro {
                    restoreState = .success
                    restoreAlertTitle = "🎉 Başarılı!"
                    restoreAlertMessage = "Premium üyeliğiniz geri yüklendi! Artık tüm özelliklere sınırsız erişebilirsiniz."
                    Haptics.success()
                    SoundManager.shared.playPremiumUnlockSound()
                } else {
                    restoreState = .noSubscription
                    restoreAlertTitle = "ℹ️ Bilgi"
                    restoreAlertMessage = "Bu Apple ID ile ilişkili aktif bir abonelik bulunamadı.\n\nDaha önce satın aldıysanız:\n• Aynı Apple ID ile giriş yaptığınızdan emin olun\n• App Store'da oturum açık olduğunu kontrol edin"
                    Haptics.warning()
                }
                showRestoreAlert = true
            }
        }
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

// MARK: - Feature Comparison Section

/// Free vs Premium feature comparison with checkmarks
private struct FeatureComparisonSection: View {
    private let features: [(name: String, freeValue: String?, proValue: String)] = [
        ("Analiz & Tarama", "Sınırsız", "Sınırsız"),
        ("Fotoğraf Sıkıştırma", "3/gün", "Sınırsız"),
        ("Video Sıkıştırma", nil, "Sınırsız"),
        ("Toplu İşlem", nil, "Sınırsız"),
        ("Tek Tıkla Temizle", nil, "Tümü"),
        ("Akıllı Seçim (AI)", nil, "Aktif"),
        ("Özel Uygulama İkonları", nil, "6 İkon"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Özellikler")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("Ücretsiz")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 60)
                Text("Premium")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.appMint)
                    .frame(width: 70)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.1))

            // Feature rows
            ForEach(features, id: \.name) { feature in
                HStack {
                    Text(feature.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()

                    // Free column
                    Group {
                        if let freeVal = feature.freeValue {
                            Text(freeVal)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                    .frame(width: 60)

                    // Pro column
                    Text(feature.proValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appMint)
                        .frame(width: 70)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                if feature.name != features.last?.name {
                    Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 14)
                }
            }
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - App Icon Preview Section

/// Shows locked custom app icons to create desire for Premium
/// Tap on any icon to see a "preview" bounce animation
private struct AppIconPreviewSection: View {
    @State private var previewingIcon: String?

    private let icons: [(name: String, icon: String, color: Color)] = [
        ("Dark", "moon.fill", .white),
        ("Gold", "crown.fill", .proGold),
        ("Mint", "leaf.fill", .appMint),
        ("Retro", "camera.filters", .warmOrange),
        ("Neon", "bolt.fill", .premiumPurple),
        ("Minimal", "circle.fill", .white)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(localized: "Özel Uygulama İkonları", comment: "Paywall: Custom icons title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.proGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.proGold.opacity(0.15))
                .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(icons, id: \.name) { item in
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [item.color.opacity(0.3), item.color.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(item.color.opacity(0.3), lineWidth: 1)
                                    )

                                Image(systemName: item.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(item.color)

                                // Lock overlay
                                if previewingIcon != item.name {
                                    ZStack {
                                        Color.black.opacity(0.4)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .frame(width: 56, height: 56)
                                }
                            }
                            .scaleEffect(previewingIcon == item.name ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: previewingIcon)
                            .onTapGesture {
                                Haptics.impact(style: .light)
                                withAnimation {
                                    previewingIcon = item.name
                                }
                                // Auto-dismiss preview
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        previewingIcon = nil
                                    }
                                }
                            }

                            Text(item.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Anchor Pricing Banner

/// Shows weekly price comparison between plans to highlight yearly savings
/// This "anchor pricing" technique makes the yearly plan feel like a bargain
private struct AnchorPricingBanner: View {
    let weeklyPrice: String
    let weeklyFromYearly: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.proGold)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(weeklyPrice)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .strikethrough(true, color: .white.opacity(0.6))
                        .foregroundColor(.white.opacity(0.5))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))

                    Text(weeklyFromYearly)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appMint)

                    Text(String(localized: "/ hafta", comment: "Paywall: per week"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                Text(String(localized: "Yıllık plan ile haftalık %75+ tasarruf", comment: "Paywall: Yearly savings breakdown"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.proGold.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Free Trial Toggle (Removed - trial is built into yearly plan)

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
