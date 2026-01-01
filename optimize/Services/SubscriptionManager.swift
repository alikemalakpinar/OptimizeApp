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

// MARK: - Paywall Context
struct PaywallContext: Equatable {
    let title: String
    let subtitle: String
    let highlights: [String]
    let limitDescription: String?

    static let proRequired = PaywallContext(
        title: "Go Pro to continue",
        subtitle: "Unlock unlimited, ad-free optimization with professional quality.",
        highlights: [
            "No ads, ever",
            "Unlimited conversions & larger files",
            "Priority-grade compression profiles",
            "Works with PDFs, images, videos & docs"
        ],
        limitDescription: nil
    )
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
    private let freeMaxFileSizeMB: Double = 50
    private let freeDailyLimit: Int = 1

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
                highlights: [
                    "Unlimited conversions with Pro",
                    "Priority compression tuned for quality",
                    "Target sizes & custom presets",
                    "All file types supported"
                ],
                limitDescription: "You have used \(status.dailyUsageCount) / \(freeDailyLimit) free conversions today."
            )
        }

        if file.sizeMB > freeMaxFileSizeMB {
            return PaywallContext(
                title: "Large file detected",
                subtitle: "Files over \(Int(freeMaxFileSizeMB)) MB need Pro for reliable compression.",
                highlights: [
                    "Handles files up to 1 GB",
                    "Loss-aware profiles for scans & photos",
                    "Batch-ready pipeline with no ads"
                ],
                limitDescription: "\(file.name) is \(Int(file.sizeMB)) MB"
            )
        }

        if let preset, preset.isProOnly {
            return PaywallContext(
                title: "Custom targets are Pro",
                subtitle: "Dial-in a precise output size and unlock smarter profiles.",
                highlights: [
                    "Target-size slider",
                    "Best quality & mail presets",
                    "Unlimited conversions"
                ],
                limitDescription: nil
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
    private func refreshDailyUsage(lastDate: Date?) {
        guard let lastDate else {
            persistUsage()
            return
        }

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
