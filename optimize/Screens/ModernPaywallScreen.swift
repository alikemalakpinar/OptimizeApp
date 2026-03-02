//
//  ModernPaywallScreen.swift
//  optimize
//
//  High-Converting Immersive Paywall (Blinkist/Calm aesthetic)
//
//  DESIGN:
//  - Background: MeshGradient (iOS 18) or cinematic aurora fallback
//  - Social Proof: Auto-scrolling review marquee + trust badges
//  - Pricing: Glassmorphic cards with Annual as hero
//  - CTA: Breathing "Start Free Trial" button with haptic feedback
//  - Feature comparison: Free vs Premium grid
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

    // Post-Purchase Celebration
    @State private var showPurchaseCelebration = false

    // Countdown Timer
    @State private var trialCountdownText: String = ""
    @State private var countdownTimer: Timer?

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
    @State private var breatheScale: CGFloat = 1.0

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

    private enum L {
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
        static let startTrial = "7 Gün Ücretsiz Başla"
        static let startNow = "Hemen Başla"
        static let autoRenewal = "Yıllık plan 3 gün ücretsiz deneme içerir. Deneme bitmeden ücret alınmaz. Abonelik otomatik yenilenir, Ayarlar'dan iptal edilebilir."
        static let privacy = "Gizlilik"
        static let terms = "Koşullar"
        static let trustedBy = "100.000+ kullanıcı tarafından tercih edildi"
    }

    // MARK: - Computed Properties

    private var displayTitle: String { context?.title ?? L.defaultTitle }
    private var displaySubtitle: String { context?.subtitle ?? L.defaultSubtitle }

    private var weeklyPrice: String {
        subscriptionManager.products.first(where: { $0.id.contains("weekly") })?.displayPrice ?? "₺99,99"
    }

    private var yearlyPrice: String {
        subscriptionManager.products.first(where: { $0.id.contains("yearly") })?.displayPrice ?? "₺599,99"
    }

    private var lifetimePrice: String {
        subscriptionManager.products.first(where: { $0.id.contains("lifetime") })?.displayPrice ?? "₺999,99"
    }

    private var weeklyFromYearly: String {
        if let product = subscriptionManager.products.first(where: { $0.id.contains("yearly") }) {
            let weeklyValue = product.price / 52
            return weeklyValue.formatted(.currency(code: product.priceFormatStyle.currencyCode))
        }
        return "₺11,54"
    }

    private var ctaText: String {
        selectedPlan == .yearly ? L.startTrial : L.startNow
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 700

            ZStack {
                // LAYER 1: Immersive Background
                PaywallBackground(isAnimating: $isAnimating)

                VStack(spacing: 0) {
                    // TOP BAR: Close + Restore
                    topBar

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: isCompact ? 16 : 24) {
                            // HERO SECTION
                            heroSection(isCompact: isCompact)

                            // SOCIAL PROOF: Marquee + Trust
                            ReviewMarquee()
                                .padding(.vertical, 4)

                            PaywallTrustRow()
                                .padding(.horizontal)

                            // TRIAL COUNTDOWN (urgency driver)
                            if !trialCountdownText.isEmpty && !subscriptionManager.status.isPro {
                                TrialCountdownBanner(countdownText: trialCountdownText)
                                    .padding(.horizontal)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            // FEATURE COMPARISON
                            FeatureComparisonSection()
                                .padding(.horizontal)

                            // PRICING CARDS (Glassmorphic)
                            pricingCards(isCompact: isCompact)
                                .padding(.horizontal)

                            // ANCHOR PRICING
                            if selectedPlan == .yearly {
                                AnchorPricingBanner(weeklyPrice: weeklyPrice, weeklyFromYearly: weeklyFromYearly)
                                    .padding(.horizontal)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // LEGAL
                            Text(L.autoRenewal)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                        }
                    }
                }

                // STICKY CTA
                stickyCTA(isCompact: isCompact)

                // POST-PURCHASE CELEBRATION OVERLAY
                if showPurchaseCelebration {
                    PurchaseCelebrationOverlay {
                        withAnimation { showPurchaseCelebration = false }
                        onDismiss()
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
        }
        .onAppear {
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showCloseButton = true }
            }
            startBreathing()
            startCountdownTimer()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
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
                    Text(L.restore)
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
    }

    // MARK: - Hero Section

    private func heroSection(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 12 : 20) {
            // Premium crown icon
            ZStack {
                Circle()
                    .fill(Color.appMint.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.proGold, .appMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: isCompact ? 6 : 10) {
                Text(displayTitle)
                    .font(.system(size: isCompact ? 22 : 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.appMint.opacity(0.3), radius: 20)

                Text(displaySubtitle)
                    .font(.system(size: isCompact ? 14 : 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineSpacing(4)
            }
        }
        .padding(.top, isCompact ? 8 : 16)
    }

    // MARK: - Pricing Cards (Glassmorphic)

    private func pricingCards(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 10 : 14) {
            // YEARLY (Hero card - highlighted with shimmer + glow)
            GlassmorphicPlanCard(
                title: L.yearlyPlan,
                price: yearlyPrice,
                period: L.perYear,
                subtitle: "3 gün ücretsiz dene • " + String(format: L.weeklyFromYearly, weeklyFromYearly),
                badge: L.mostPopular,
                badgeColor: .proGold,
                isSelected: selectedPlan == .yearly,
                isHero: true
            ) {
                Haptics.impact(style: .medium)
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { selectedPlan = .yearly }
            }
            .shimmer(isActive: selectedPlan == .yearly)
            .shadow(color: selectedPlan == .yearly ? Color.appMint.opacity(0.3) : .clear, radius: 12, x: 0, y: 4)

            // WEEKLY
            GlassmorphicPlanCard(
                title: L.weeklyPlan,
                price: weeklyPrice,
                period: L.perWeek,
                subtitle: L.cancelAnytime,
                badge: nil,
                badgeColor: .clear,
                isSelected: selectedPlan == .weekly,
                isHero: false
            ) {
                Haptics.selection()
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { selectedPlan = .weekly }
            }

            // LIFETIME
            GlassmorphicPlanCard(
                title: L.lifetimePlan,
                price: lifetimePrice,
                period: L.oneTime,
                subtitle: "Bir kez öde, sonsuza kadar kullan",
                badge: L.bestValue,
                badgeColor: .appMint,
                isSelected: selectedPlan == .lifetime,
                isHero: false
            ) {
                Haptics.impact(style: .medium)
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { selectedPlan = .lifetime }
            }
        }
    }

    // MARK: - Sticky CTA

    private func stickyCTA(isCompact: Bool) -> some View {
        VStack {
            Spacer()

            VStack(spacing: isCompact ? 10 : 14) {
                // Breathing CTA button
                Button(action: {
                    Haptics.success()
                    isLoading = true
                    handleSubscribe()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.8)
                        } else {
                            Text(ctaText)
                                .font(.system(size: isCompact ? 15 : 17, weight: .bold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 50 : 58)
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
                    .scaleEffect(isLoading ? 0.98 : breatheScale)
                }
                .disabled(isLoading)

                // Footer links
                HStack(spacing: 20) {
                    Button(action: onPrivacy) { Text(L.privacy) }
                    Text("•")
                    Button(action: onTerms) { Text(L.terms) }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal)
            .padding(.bottom, isCompact ? 16 : 20)
            .padding(.top, isCompact ? 16 : 20)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.9), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Breathing Animation

    private func startBreathing() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.03
        }
    }

    // MARK: - Trial Countdown Timer

    private func startCountdownTimer() {
        updateCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            updateCountdown()
        }
    }

    private static let trialStartKey = "paywall.trial.start.date"

    private func updateCountdown() {
        // Initialize trial start date on first paywall view
        let defaults = UserDefaults.standard
        let trialStart: Date
        if let stored = defaults.object(forKey: Self.trialStartKey) as? Date {
            trialStart = stored
        } else {
            trialStart = Date()
            defaults.set(trialStart, forKey: Self.trialStartKey)
        }

        let trialDays: Double = 7
        let trialEnd = trialStart.addingTimeInterval(trialDays * 86400)
        let remaining = trialEnd.timeIntervalSince(Date())

        if remaining > 0 {
            let days = Int(remaining / 86400)
            let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
            if days > 0 {
                trialCountdownText = "\(days) gün \(hours) saat"
            } else if hours > 0 {
                trialCountdownText = "\(hours) saat"
            } else {
                let minutes = Int(remaining / 60)
                trialCountdownText = "\(minutes) dakika"
            }
        } else {
            trialCountdownText = ""
        }
    }

    // MARK: - Subscribe Handler (with celebration)

    private func handleSubscribe() {
        Task {
            do {
                try await subscriptionManager.purchase(plan: selectedPlan)
                await MainActor.run {
                    isLoading = false
                    triggerPurchaseCelebration()
                }
            } catch SubscriptionError.userCancelled {
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Fall back to coordinator-managed purchase flow for error handling
                    onSubscribe(selectedPlan)
                }
            }
        }
    }

    // MARK: - Post-Purchase Celebration

    private func triggerPurchaseCelebration() {
        Haptics.premiumUnlock()
        SoundManager.shared.playSubscriptionActivatedSound()
        withAnimation(.spring(duration: 0.5)) {
            showPurchaseCelebration = true
        }
    }

    // MARK: - Restore Handler

    private func performRestore() {
        guard restoreState != .loading else { return }
        restoreState = .loading
        Haptics.selection()

        Task {
            if subscriptionManager.status.isPro {
                await MainActor.run {
                    restoreState = .alreadyPremium
                    restoreAlertTitle = "Zaten Premium!"
                    restoreAlertMessage = "Premium üyeliğiniz aktif durumda. Tüm özelliklere erişebilirsiniz."
                    showRestoreAlert = true
                    Haptics.success()
                }
                return
            }

            await subscriptionManager.restore()

            await MainActor.run {
                if subscriptionManager.status.isPro {
                    restoreState = .success
                    restoreAlertTitle = "Başarılı!"
                    restoreAlertMessage = "Premium üyeliğiniz geri yüklendi! Artık tüm özelliklere sınırsız erişebilirsiniz."
                    Haptics.success()
                    SoundManager.shared.playPremiumUnlockSound()
                } else {
                    restoreState = .noSubscription
                    restoreAlertTitle = "Bilgi"
                    restoreAlertMessage = "Bu Apple ID ile ilişkili aktif bir abonelik bulunamadı.\n\nDaha önce satın aldıysanız:\n• Aynı Apple ID ile giriş yaptığınızdan emin olun\n• App Store'da oturum açık olduğunu kontrol edin"
                    Haptics.warning()
                }
                showRestoreAlert = true
            }
        }
    }
}

// MARK: - Paywall Background (MeshGradient iOS 18 / Aurora Fallback)

private struct PaywallBackground: View {
    @Binding var isAnimating: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if #available(iOS 18.0, *) {
                meshView
            } else {
                auroraView
            }

            // Grain overlay
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .blendMode(.overlay)
                .overlay(
                    GeometryReader { geo in
                        Color.white.opacity(0.05).mask(
                            NoiseTexture()
                                .frame(width: geo.size.width, height: geo.size.height)
                        )
                    }
                )
                .ignoresSafeArea()
        }
    }

    @available(iOS 18.0, *)
    private var meshView: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5),
                .init(isAnimating ? 0.6 : 0.4, isAnimating ? 0.4 : 0.6),
                .init(1, 0.5),
                .init(0, 1), .init(0.5, 1), .init(1, 1)
            ],
            colors: [
                .black, Color(red: 0.0, green: 0.08, blue: 0.15), .black,
                Color(red: 0.05, green: 0.0, blue: 0.15),
                Color(red: 0.0, green: 0.15, blue: 0.2),
                Color(red: 0.1, green: 0.0, blue: 0.2),
                .black, Color(red: 0.0, green: 0.05, blue: 0.1), .black
            ]
        )
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: isAnimating)
        .ignoresSafeArea()
    }

    private var auroraView: some View {
        GeometryReader { proxy in
            Circle()
                .fill(Color.appMint.opacity(0.2))
                .frame(width: 350, height: 350)
                .blur(radius: 90)
                .offset(x: isAnimating ? -50 : 100, y: -100)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: isAnimating)

            Circle()
                .fill(Color.premiumPurple.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: proxy.size.width - 100, y: 150)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: isAnimating)

            Circle()
                .fill(Color.premiumBlue.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: isAnimating ? proxy.size.width * 0.2 : proxy.size.width * 0.6, y: proxy.size.height * 0.5)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: isAnimating)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Noise Texture

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

// MARK: - Review Marquee (Auto-Scrolling Social Proof with Avatars)

private struct ReviewMarquee: View {
    @State private var offset: CGFloat = 0

    private let reviews: [(text: String, name: String, initials: String, color: Color)] = [
        ("1.5 GB dosyayı 200 MB'a düşürdü!", "Mehmet Y.", "MY", .blue),
        ("WhatsApp videolarım artık 10 saniyede gidiyor", "Elif K.", "EK", .purple),
        ("En iyi sıkıştırma uygulaması, 5 yıldız!", "Ahmet B.", "AB", .green),
        ("iCloud'u yükseltmeme gerek kalmadı", "Zeynep A.", "ZA", .orange),
        ("PDF'lerim artık e-postaya sığıyor", "Can D.", "CD", .pink),
    ]

    var body: some View {
        GeometryReader { geometry in
            let cardWidth: CGFloat = 260
            let totalWidth = CGFloat(reviews.count) * (cardWidth + 12)

            HStack(spacing: 12) {
                // Double the reviews for seamless loop
                ForEach(0..<reviews.count * 2, id: \.self) { i in
                    let review = reviews[i % reviews.count]
                    reviewCard(text: review.text, name: review.name, initials: review.initials, avatarColor: review.color, width: cardWidth)
                }
            }
            .offset(x: offset)
            .onAppear {
                // Start continuous scroll
                offset = 0
                withAnimation(.linear(duration: Double(reviews.count) * 4).repeatForever(autoreverses: false)) {
                    offset = -totalWidth
                }
            }
        }
        .frame(height: 80)
        .clipped()
    }

    private func reviewCard(text: String, name: String, initials: String, avatarColor: Color, width: CGFloat) -> some View {
        HStack(spacing: 10) {
            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor, avatarColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Text(initials)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.proGold)
                    }
                }

                Text("\"\(text)\"")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)

                Text("— \(name)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: width, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Paywall Trust Badge Row

private struct PaywallTrustRow: View {
    var body: some View {
        HStack(spacing: 16) {
            trustBadge(icon: "checkmark.shield.fill", text: "Apple Onaylı")
            trustBadge(icon: "person.3.fill", text: "100K+ Kullanıcı")
            trustBadge(icon: "lock.fill", text: "Güvenli Ödeme")
        }
    }

    private func trustBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.4))
    }
}

// MARK: - Glassmorphic Plan Card

private struct GlassmorphicPlanCard: View {
    let title: String
    let price: String
    let period: String
    let subtitle: String
    let badge: String?
    let badgeColor: Color
    let isSelected: Bool
    let isHero: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Radio
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

                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor)
                                .cornerRadius(4)
                                .shimmer(isActive: isHero && isSelected)
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
            .background {
                ZStack {
                    if isHero && isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    }
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected
                                ? Color.appMint.opacity(0.1)
                                : Color.white.opacity(0.03)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.appMint, Color.appMint.opacity(0.3)]
                                : [Color.white.opacity(0.1), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Comparison

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

            ForEach(features, id: \.name) { feature in
                HStack {
                    Text(feature.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()

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

// MARK: - Anchor Pricing Banner

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

                    Text("/ hafta")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                Text("Yıllık plan ile haftalık %75+ tasarruf")
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

// MARK: - Trial Countdown Banner (Urgency Driver)

private struct TrialCountdownBanner: View {
    let countdownText: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.warmOrange)
                .scaleEffect(pulse ? 1.1 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ücretsiz deneme süresi")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Text("\(countdownText) kaldı")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.warmOrange)
            }

            Spacer()

            Text("Şimdi Başla")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.warmOrange)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.warmOrange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.warmOrange.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Post-Purchase Celebration Overlay

private struct PurchaseCelebrationOverlay: View {
    let onComplete: () -> Void
    @State private var showContent = false
    @State private var showConfetti = false
    @State private var crownScale: CGFloat = 0.3

    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Crown icon with scale animation
                ZStack {
                    // Glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.proGold.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: CGFloat(100 + i * 30), height: CGFloat(100 + i * 30))
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .opacity(showContent ? 1 : 0)
                            .animation(.spring(duration: 0.8).delay(Double(i) * 0.1), value: showContent)
                    }

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.proGold, Color.appMint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.proGold.opacity(0.5), radius: 20)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
                .scaleEffect(crownScale)

                VStack(spacing: 8) {
                    Text("Hoş Geldin, Pro!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Tüm premium özellikler artık senin")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                Spacer()

                // Confetti burst
                if showConfetti {
                    CelebrationBurstView(trigger: showConfetti)
                }

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.4)) {
                crownScale = 1.0
            }
            withAnimation(.spring(duration: 0.6).delay(0.3)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
            }
            // Auto-dismiss after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onComplete()
            }
        }
    }
}

// MARK: - Previews

#Preview("Default") {
    ModernPaywallScreen(
        subscriptionManager: SubscriptionManager.shared,
        context: nil,
        onSubscribe: { _ in },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
}
