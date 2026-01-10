//
//  SubscriptionManager.swift
//  optimize
//
//  Central place for handling free/pro logic, usage limits and paywall context
//  UPDATED: StoreKit 2 integration for real In-App Purchases
//
//  SECURITY ENHANCEMENT:
//  - Real-time entitlement verification for critical operations
//  - Critical counters (dailyUsageCount, firstInstallDate) stored in Keychain
//  - Keychain data persists across app reinstalls (prevents limit reset exploits)
//  - Verifies subscription status with StoreKit before premium features
//

import Combine
import Foundation
import StoreKit
import Security

// MARK: - Subscription Manager Protocol (Dependency Injection)

/// Protocol for subscription management - enables testability and mocking
@MainActor
protocol SubscriptionManagerProtocol: AnyObject {
    var status: SubscriptionStatus { get }
    var products: [Product] { get }

    func paywallContext(for file: FileInfo, preset: CompressionPreset?) -> PaywallContext?
    func recordSuccessfulCompression()
    func purchase(plan: SubscriptionPlan) async throws
    func restore() async

    /// SECURITY: Verify entitlement in real-time before critical operations
    func verifyEntitlementForCriticalOperation() async -> Bool
}

// MARK: - Paywall Context (Master Level - Feature-Specific Upsells)

/// Context for paywall presentation - customized per feature
/// Each context is designed to highlight the specific value proposition
struct PaywallContext: Equatable {
    let title: String
    let subtitle: String
    let icon: String  // SF Symbol name for hero section
    let highlights: [String]
    let limitDescription: String?
    let ctaText: String  // Call-to-action button text

    // MARK: - Default Context

    static let proRequired = PaywallContext(
        title: "Premium'a Geç",
        subtitle: "Sınırsız, reklamsız optimizasyon ile profesyonel kaliteyi aç.",
        icon: "crown.fill",
        highlights: [
            "Reklamsız deneyim",
            "Sınırsız dönüştürme",
            "Profesyonel sıkıştırma",
            "PDF, görsel, video desteği"
        ],
        limitDescription: nil,
        ctaText: "7 Gün Ücretsiz Başla"
    )

    // MARK: - Feature-Specific Contexts

    /// Batch Processing - Time-saving focus
    static let batchProcessing = PaywallContext(
        title: "Zamandan Tasarruf Et",
        subtitle: "Tek tek uğraşma! Sınırsız dosyayı aynı anda küçült.",
        icon: "square.stack.3d.up.fill",
        highlights: [
            "Toplu Dosya İşleme",
            "4x Paralel İşlem Gücü",
            "Sırada Bekleme Yok",
            "Arka Planda Çalışma"
        ],
        limitDescription: "Ücretsiz sürümde en fazla 2 dosya işleyebilirsiniz.",
        ctaText: "Toplu İşlemi Aç"
    )

    /// File Conversion - Format freedom focus
    static let converter = PaywallContext(
        title: "Format Özgürlüğü",
        subtitle: "PDF, Word, Görsel... İstediğin dosyayı istediğin formata çevir.",
        icon: "arrow.triangle.2.circlepath.circle.fill",
        highlights: [
            "Tüm Formatlar Açık",
            "PDF ↔ Görsel Dönüşümü",
            "Video Sıkıştırma & GIF",
            "Kalite Kaybı Yok"
        ],
        limitDescription: nil,
        ctaText: "Dönüştürmeyi Aç"
    )

    /// Advanced Presets - Quality control focus
    static let advancedPresets = PaywallContext(
        title: "Profesyonel Kontrol",
        subtitle: "Maksimum sıkıştırma, yüksek kalite veya özel ayarlar - sen seç.",
        icon: "slider.horizontal.3",
        highlights: [
            "Maksimum Sıkıştırma Modu",
            "Yüksek Kalite Modu",
            "Özel DPI Ayarı",
            "Vektör Koruma"
        ],
        limitDescription: "Ücretsiz sürümde sadece 'Dengeli' mod kullanılabilir.",
        ctaText: "Gelişmiş Ayarları Aç"
    )

    /// Customization - Personalization focus
    static let customization = PaywallContext(
        title: "Kişiselleştir",
        subtitle: "Uygulamayı kendin yap. Özel ikonlar ve temalar seni bekliyor.",
        icon: "paintpalette.fill",
        highlights: [
            "6 Özel Uygulama İkonu",
            "Karanlık Mod İkonu",
            "Altın Premium İkonu",
            "Retro Klasik İkon"
        ],
        limitDescription: nil,
        ctaText: "İkonları Aç"
    )

    /// Background Processing - Productivity focus
    static let backgroundProcessing = PaywallContext(
        title: "Çoklu Görev Ustası",
        subtitle: "Uygulamayı kapat, işlem devam etsin. Bildirimi bekle.",
        icon: "arrow.down.circle.fill",
        highlights: [
            "Arka Plan İşleme",
            "Uygulama Kapalıyken Çalışır",
            "Bildirimle Sonuç Alma",
            "Kesintisiz Çalışma"
        ],
        limitDescription: "Ücretsiz sürümde uygulama açık kalmalıdır.",
        ctaText: "Arka Planı Aç"
    )

    /// Daily limit reached
    static func dailyLimitReached(used: Int, limit: Int) -> PaywallContext {
        PaywallContext(
            title: "Günlük Limit Doldu",
            subtitle: "Bugün \(used)/\(limit) hakkını kullandın. Premium ile sınırsız devam et.",
            icon: "clock.badge.exclamationmark.fill",
            highlights: [
                "Sınırsız Günlük Kullanım",
                "Büyük Dosya Desteği (500MB+)",
                "Öncelikli İşlem Kuyruğu",
                "7/24 Premium Destek"
            ],
            limitDescription: "Yarın saat 00:00'da \(limit) hak yenilenir.",
            ctaText: "Sınırı Kaldır"
        )
    }

    /// File too large for free tier
    static func fileTooLarge(sizeMB: Double, limitMB: Double) -> PaywallContext {
        PaywallContext(
            title: "Dosya Çok Büyük",
            subtitle: String(format: "%.0f MB'lık dosya, %.0f MB limitini aşıyor.", sizeMB, limitMB),
            icon: "doc.badge.arrow.up.fill",
            highlights: [
                "500MB'a Kadar Dosya Desteği",
                "4K Video Sıkıştırma",
                "Çok Sayfalı PDF İşleme",
                "Yüksek Çözünürlük Koruma"
            ],
            limitDescription: String(format: "Ücretsiz limit: %.0f MB", limitMB),
            ctaText: "Büyük Dosyaları Aç"
        )
    }
}

// MARK: - Subscription Manager
@MainActor
final class SubscriptionManager: ObservableObject, SubscriptionManagerProtocol {
    static let shared = SubscriptionManager()

    // MARK: - Real-time Verification Cache
    /// Last verification timestamp to avoid excessive StoreKit calls
    private var lastVerificationTime: Date?
    private var lastVerificationResult: Bool = false
    private let verificationCacheDuration: TimeInterval = 60 // 1 minute cache

    // Published status for UI
    @Published private(set) var status: SubscriptionStatus
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String?

    // StoreKit Product IDs - Update these with your App Store Connect IDs
    private let productIds = [
        "com.optimize.pro.monthly",
        "com.optimize.pro.yearly"
    ]

    // Storage keys
    private let planKey = "subscription.plan"

    // SECURITY: These keys are stored in Keychain (not UserDefaults)
    // Keychain persists across reinstalls, preventing limit reset exploits
    private let dailyCountKey = "secure.subscription.daily.count"
    private let lastUsageDateKey = "secure.subscription.daily.date"
    private let firstInstallDateKey = "secure.subscription.first.install"

    // Free-plan limits
    // PRODUCT FIX: Increased from 1 to 3 - Give users a chance to test the app
    // With only 1 free usage, churn is guaranteed. 3 uses allows:
    // - Testing with different file types
    // - Recovery from accidental file selection
    // - Building trust before paywall conversion
    //
    // PRODUCT FIX: Increased file size limit from 50MB to 100MB
    // Modern iPhone photos create PDFs that easily exceed 50MB
    // Users couldn't even "test" the app before hitting the wall
    // 100MB covers most real-world use cases while still incentivizing Pro
    private let freeMaxFileSizeMB: Double = 100
    private let freeDailyLimit: Int = 3

    // SECURITY: Secure storage for critical counters
    private let secureStorage: SecureStorageProtocol

    // Transaction listener task
    private var transactionListener: Task<Void, Error>?

    private init(secureStorage: SecureStorageProtocol = KeychainStorage.shared) {
        self.secureStorage = secureStorage

        // SECURITY: Migrate existing UserDefaults data to Keychain (one-time)
        Self.migrateToSecureStorage(secureStorage: secureStorage)

        let storedPlan = UserDefaults.standard.string(forKey: planKey)
        let plan = SubscriptionPlan(rawValue: storedPlan ?? "") ?? .free

        // SECURITY: Read daily count from Keychain (persists across reinstalls)
        let dailyCount = secureStorage.getInt(forKey: dailyCountKey) ?? 0
        let lastDate = secureStorage.getDate(forKey: lastUsageDateKey)

        // Record first install date if not already set
        if !secureStorage.contains(key: firstInstallDateKey) {
            secureStorage.set(Date(), forKey: firstInstallDateKey)
        }

        status = SubscriptionStatus(
            plan: plan,
            isActive: plan != .free,
            expiresAt: nil,
            dailyUsageCount: dailyCount,
            dailyUsageLimit: plan == .free ? freeDailyLimit : .max
        )

        refreshDailyUsage(lastDate: lastDate)

        // Start listening for transactions
        transactionListener = listenForTransactions()

        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Migration from UserDefaults to Keychain

    /// One-time migration of sensitive data from UserDefaults to Keychain
    private static func migrateToSecureStorage(secureStorage: SecureStorageProtocol) {
        let defaults = UserDefaults.standard

        // Migrate daily count
        let oldDailyKey = "subscription.daily.count"
        if let oldCount = defaults.object(forKey: oldDailyKey) as? Int {
            secureStorage.set(oldCount, forKey: "secure.subscription.daily.count")
            defaults.removeObject(forKey: oldDailyKey)
        }

        // Migrate last usage date
        let oldDateKey = "subscription.daily.date"
        if let oldDate = defaults.object(forKey: oldDateKey) as? Date {
            secureStorage.set(oldDate, forKey: "secure.subscription.daily.date")
            defaults.removeObject(forKey: oldDateKey)
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - StoreKit 2 Methods

    /// Load products from App Store
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price } // Sort by price (monthly first)
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    /// Purchase a subscription
    func purchase(plan: SubscriptionPlan) async throws {
        let productId = plan == .yearly ? "com.optimize.pro.yearly" : "com.optimize.pro.monthly"

        guard let product = products.first(where: { $0.id == productId }) else {
            // Fallback: Try to fetch product directly
            guard let product = try await Product.products(for: [productId]).first else {
                purchaseError = "Product not found"
                throw SubscriptionError.productNotFound
            }
            try await performPurchase(product: product)
            return
        }

        try await performPurchase(product: product)
    }

    private func performPurchase(product: Product) async throws {
        purchaseError = nil

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()

        case .userCancelled:
            throw SubscriptionError.userCancelled

        case .pending:
            purchaseError = "Purchase pending approval"
            throw SubscriptionError.pending

        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    /// Restore purchases
    /// Note: In StoreKit 2, checking Transaction.currentEntitlements is sufficient
    /// AppStore.sync() forces password entry which creates poor UX
    func restore() async {
        do {
            // Simply check current entitlements - no need for AppStore.sync()
            // which forces password entry and creates poor user experience
            await updateSubscriptionStatus()

            // If still no subscription found, show appropriate message
            if !status.isPro {
                purchaseError = "No active subscription found. Please ensure you're signed in with the correct Apple ID."
            }
        } catch {
            purchaseError = "Failed to restore: \(error.localizedDescription)"
        }
    }

    /// Check current subscription status from StoreKit
    func updateSubscriptionStatus() async {
        var foundActiveSubscription = false
        var activePlan: SubscriptionPlan = .free
        var expirationDate: Date?

        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Check if this is one of our subscription products
                if productIds.contains(transaction.productID) {
                    // Check if subscription is still valid
                    if transaction.revocationDate == nil {
                        foundActiveSubscription = true
                        expirationDate = transaction.expirationDate

                        // Determine plan type
                        if transaction.productID.contains("yearly") {
                            activePlan = .yearly
                        } else {
                            activePlan = .monthly
                        }
                    }
                }
            }
        }

        // Update status
        if foundActiveSubscription {
            status = SubscriptionStatus(
                plan: activePlan,
                isActive: true,
                expiresAt: expirationDate,
                dailyUsageCount: 0,
                dailyUsageLimit: .max
            )
            UserDefaults.standard.set(activePlan.rawValue, forKey: planKey)
        } else {
            // Check if we had a cached plan that's no longer valid
            // SECURITY FIX: Use secureStorage instead of UserDefaults for daily count
            // This ensures consistency with persistUsage() and prevents limit bypass
            let dailyCount = secureStorage.getInt(forKey: dailyCountKey) ?? 0
            status = SubscriptionStatus(
                plan: .free,
                isActive: false,
                expiresAt: nil,
                dailyUsageCount: dailyCount,
                dailyUsageLimit: freeDailyLimit
            )
            UserDefaults.standard.set(SubscriptionPlan.free.rawValue, forKey: planKey)
        }
    }

    /// Listen for transaction updates (purchases made on other devices, subscription renewals, etc.)
    ///
    /// CONCURRENCY: Uses Task.detached to create an independent listener that:
    /// - Survives parent task cancellation (intentional for app lifecycle)
    /// - Runs continuously in background
    /// - Properly dispatches UI updates to MainActor
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                // Check if self still exists (app might be terminating)
                guard self != nil else { break }

                if case .verified(let transaction) = result {
                    await transaction.finish()
                    // Properly dispatch UI updates to MainActor
                    await MainActor.run {
                        Task { [weak self] in
                            await self?.updateSubscriptionStatus()
                        }
                    }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Public API
    func paywallContext(for file: FileInfo, preset: CompressionPreset? = nil) -> PaywallContext? {
        // SECURITY: Read last usage date from Keychain
        refreshDailyUsage(lastDate: secureStorage.getDate(forKey: lastUsageDateKey))

        guard !status.isPro else { return nil }

        if status.dailyUsageCount >= freeDailyLimit {
            return PaywallContext(
                title: "Daily limit reached",
                subtitle: "Free plan includes \(freeDailyLimit) optimization per day.",
                icon: "clock.badge.exclamationmark.fill",
                highlights: [
                    "Unlimited conversions with Pro",
                    "Priority compression tuned for quality",
                    "Target sizes & custom presets",
                    "All file types supported"
                ],
                limitDescription: "You have used \(status.dailyUsageCount) / \(freeDailyLimit) free conversions today.",
                ctaText: "Sınırı Kaldır"
            )
        }

        if file.sizeMB > freeMaxFileSizeMB {
            return PaywallContext(
                title: "Large file detected",
                subtitle: "Files over \(Int(freeMaxFileSizeMB)) MB need Pro for reliable compression.",
                icon: "doc.badge.arrow.up.fill",
                highlights: [
                    "Handles files up to 1 GB",
                    "Loss-aware profiles for scans & photos",
                    "Batch-ready pipeline with no ads"
                ],
                limitDescription: "\(file.name) is \(Int(file.sizeMB)) MB",
                ctaText: "Büyük Dosyaları Aç"
            )
        }

        if let preset, preset.isProOnly {
            return PaywallContext(
                title: "Custom targets are Pro",
                subtitle: "Dial-in a precise output size and unlock smarter profiles.",
                icon: "slider.horizontal.3",
                highlights: [
                    "Target-size slider",
                    "Best quality & mail presets",
                    "Unlimited conversions"
                ],
                limitDescription: nil,
                ctaText: "Gelişmiş Ayarları Aç"
            )
        }

        return nil
    }

    func recordSuccessfulCompression() {
        if status.plan == .free {
            status = SubscriptionStatus(
                plan: status.plan,
                isActive: true,
                expiresAt: status.expiresAt,
                dailyUsageCount: status.dailyUsageCount + 1,
                dailyUsageLimit: freeDailyLimit
            )
            persistUsage()
        }
    }

    /// Start Pro - for legacy compatibility and testing
    /// In production, use purchase(plan:) instead
    func startPro(plan: SubscriptionPlan) {
        status = SubscriptionStatus(
            plan: plan,
            isActive: true,
            expiresAt: nil,
            dailyUsageCount: 0,
            dailyUsageLimit: .max
        )
        UserDefaults.standard.set(plan.rawValue, forKey: planKey)
        // SECURITY FIX: Use secureStorage instead of UserDefaults for daily count
        secureStorage.set(0, forKey: dailyCountKey)
    }

    /// Synchronous restore wrapper for UI
    func restoreSync() {
        Task {
            await restore()
        }
    }

    func resetToFree() {
        status = SubscriptionStatus.free
        UserDefaults.standard.set(SubscriptionPlan.free.rawValue, forKey: planKey)
        persistUsage()
    }

    // MARK: - Real-time Entitlement Verification (Security Critical)

    /// Verifies subscription status in real-time before critical operations
    /// This prevents bypass attacks via UserDefaults manipulation
    ///
    /// SECURITY: Always call this before:
    /// - Starting compression of large files
    /// - Using Pro-only presets
    /// - Any premium feature access
    ///
    /// Uses a short cache (60 seconds) to balance security with performance
    func verifyEntitlementForCriticalOperation() async -> Bool {
        // Check cache first to avoid excessive StoreKit calls
        if let lastTime = lastVerificationTime,
           Date().timeIntervalSince(lastTime) < verificationCacheDuration {
            return lastVerificationResult
        }

        // Real-time verification with StoreKit
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIds.contains(transaction.productID) {
                    if transaction.revocationDate == nil {
                        hasActiveSubscription = true
                        break
                    }
                }
            }
        }

        // Update cache
        lastVerificationTime = Date()
        lastVerificationResult = hasActiveSubscription

        // Sync UI state if there's a mismatch (e.g., subscription expired)
        if hasActiveSubscription != status.isPro {
            await updateSubscriptionStatus()
        }

        return hasActiveSubscription
    }

    /// Checks if user can perform a specific operation with real-time verification
    /// Returns true if user is Pro OR has remaining free usage
    func canPerformOperation(file: FileInfo, preset: CompressionPreset?) async -> Bool {
        // Free users: check daily limit
        if !status.isPro {
            // SECURITY: Read last usage date from Keychain
            refreshDailyUsage(lastDate: secureStorage.getDate(forKey: lastUsageDateKey))

            // Check file size limit for free users
            if file.sizeMB > freeMaxFileSizeMB {
                return false
            }

            // Check Pro-only preset
            if let preset, preset.isProOnly {
                return false
            }

            // Check daily limit
            return status.dailyUsageCount < freeDailyLimit
        }

        // Pro users: verify subscription is still active
        return await verifyEntitlementForCriticalOperation()
    }

    // MARK: - Helpers

    /// Refreshes daily usage count with TIME MANIPULATION PROTECTION
    ///
    /// SECURITY: Detects and handles "time travel" exploits where users
    /// change their device clock to reset daily limits. If the last usage
    /// date is in the future, we know the user set their clock back.
    ///
    /// Protection strategies:
    /// 1. If lastDate > now: User manipulated clock backward - DON'T reset limits
    /// 2. If lastDate is today: Normal usage - keep current count
    /// 3. If lastDate is in the past (yesterday or earlier): Reset count for new day
    private func refreshDailyUsage(lastDate: Date?) {
        guard let lastDate else {
            persistUsage()
            return
        }

        let now = Date()

        // SECURITY: Time manipulation detection
        // If last usage date is in the future, user set clock back after using the app
        // This is a clear sign of manipulation - DO NOT reset the limit
        if lastDate > now {
            // Time travel detected! User manipulated their clock.
            // Keep the existing usage count - don't reward cheating
            // Optionally: Could add analytics tracking here for monitoring
            return
        }

        // Normal flow: Reset count if it's a new day
        if !Calendar.current.isDateInToday(lastDate) {
            status = SubscriptionStatus(
                plan: status.plan,
                isActive: status.isActive,
                expiresAt: status.expiresAt,
                dailyUsageCount: 0,
                dailyUsageLimit: status.plan == .free ? freeDailyLimit : .max
            )
            persistUsage()
        }
    }

    /// SECURITY: Persist usage data to Keychain (not UserDefaults)
    /// Keychain data survives app reinstalls, preventing limit bypass
    private func persistUsage() {
        secureStorage.set(status.dailyUsageCount, forKey: dailyCountKey)
        secureStorage.set(Date(), forKey: lastUsageDateKey)
    }
}

// MARK: - Subscription Error
enum SubscriptionError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case userCancelled
    case pending
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found. Please try again later."
        case .purchaseFailed:
            return "Purchase failed. Please check your payment method."
        case .userCancelled:
            return "Purchase was cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .verificationFailed:
            return "Could not verify purchase. Please contact support."
        case .unknown:
            return "An unknown error occurred. Please try again."
        }
    }
}

// MARK: - Feature Entitlements (Master Level Architecture)

/// Centralized feature access control
/// This eliminates scattered "if isPremium" checks throughout the codebase
/// and provides a single source of truth for feature gating
extension SubscriptionManager {

    // MARK: - Feature Flags

    /// Can perform batch (multi-file) processing?
    /// Free: No (or max 2 files)
    /// Pro: Unlimited
    var canPerformBatchProcessing: Bool {
        status.isPro
    }

    /// Can perform file format conversion?
    /// Free: No
    /// Pro: All formats (PDF ↔ Image, Video → GIF, etc.)
    var canPerformFileConversion: Bool {
        status.isPro
    }

    /// Maximum concurrent operations allowed
    /// Free: 1 (sequential only)
    /// Pro: 4 (parallel processing)
    var maxConcurrentOperations: Int {
        status.isPro ? 4 : 1
    }

    /// Maximum files in batch queue
    /// Free: 2 files (teaser)
    /// Pro: Unlimited
    var maxBatchQueueSize: Int {
        status.isPro ? .max : 2
    }

    /// Can use advanced compression presets?
    /// Free: Only "Balanced" preset
    /// Pro: All presets (Maximum, High Quality, Custom)
    var canUseAdvancedPresets: Bool {
        status.isPro
    }

    /// Can change app icon?
    /// Free: No
    /// Pro: Yes (Dark, Gold, Retro icons)
    var canChangeAppIcon: Bool {
        status.isPro
    }

    /// Can process files in background?
    /// Free: No (app must stay open)
    /// Pro: Yes (continues when minimized)
    var canProcessInBackground: Bool {
        status.isPro
    }

    // MARK: - Feature Check with Paywall Trigger

    /// Check if a feature is available, optionally triggering paywall
    /// Returns true if feature is available, false if blocked
    @discardableResult
    func checkFeatureAccess(_ feature: PremiumFeature, triggerPaywall: Bool = true) -> Bool {
        let hasAccess: Bool

        switch feature {
        case .batchProcessing:
            hasAccess = canPerformBatchProcessing
        case .fileConversion:
            hasAccess = canPerformFileConversion
        case .advancedPresets:
            hasAccess = canUseAdvancedPresets
        case .customAppIcon:
            hasAccess = canChangeAppIcon
        case .backgroundProcessing:
            hasAccess = canProcessInBackground
        case .unlimitedUsage:
            hasAccess = status.isPro
        }

        if !hasAccess && triggerPaywall {
            // Post notification to trigger paywall with appropriate context
            NotificationCenter.default.post(
                name: .showPaywallForFeature,
                object: nil,
                userInfo: ["feature": feature]
            )
        }

        return hasAccess
    }
}

// MARK: - Premium Features Enum

/// All premium features that can be gated
enum PremiumFeature: String, CaseIterable {
    case batchProcessing = "batch_processing"
    case fileConversion = "file_conversion"
    case advancedPresets = "advanced_presets"
    case customAppIcon = "custom_app_icon"
    case backgroundProcessing = "background_processing"
    case unlimitedUsage = "unlimited_usage"

    /// Paywall context for this feature
    var paywallContext: PaywallContext {
        switch self {
        case .batchProcessing:
            return .batchProcessing
        case .fileConversion:
            return .converter
        case .advancedPresets:
            return .advancedPresets
        case .customAppIcon:
            return .customization
        case .backgroundProcessing:
            return .backgroundProcessing
        case .unlimitedUsage:
            return .proRequired
        }
    }

    /// Localized title for feature
    var title: String {
        switch self {
        case .batchProcessing:
            return String(localized: "Toplu İşlem", comment: "Batch processing feature")
        case .fileConversion:
            return String(localized: "Format Dönüştürme", comment: "File conversion feature")
        case .advancedPresets:
            return String(localized: "Gelişmiş Ayarlar", comment: "Advanced presets feature")
        case .customAppIcon:
            return String(localized: "Özel İkonlar", comment: "Custom app icon feature")
        case .backgroundProcessing:
            return String(localized: "Arka Plan İşleme", comment: "Background processing feature")
        case .unlimitedUsage:
            return String(localized: "Sınırsız Kullanım", comment: "Unlimited usage feature")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a premium feature is accessed without subscription
    /// UserInfo contains "feature": PremiumFeature
    static let showPaywallForFeature = Notification.Name("showPaywallForFeature")
}
