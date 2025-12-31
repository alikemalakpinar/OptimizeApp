//
//  SubscriptionManager.swift
//  optimize
//
//  Central place for handling free/pro logic, usage limits and paywall context
//

import Combine
import Foundation

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
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // Published status for UI
    @Published private(set) var status: SubscriptionStatus

    // Storage keys
    private let planKey = "subscription.plan"
    private let dailyCountKey = "subscription.daily.count"
    private let lastUsageDateKey = "subscription.daily.date"

    // Free-plan limits
    private let freeMaxFileSizeMB: Double = 50
    private let freeDailyLimit: Int = 1

    private init() {
        let storedPlan = UserDefaults.standard.string(forKey: planKey)
        let plan = SubscriptionPlan(rawValue: storedPlan ?? "") ?? .free
        let dailyCount = UserDefaults.standard.integer(forKey: dailyCountKey)
        let lastDate = UserDefaults.standard.object(forKey: lastUsageDateKey) as? Date

        status = SubscriptionStatus(
            plan: plan,
            isActive: plan != .free,
            expiresAt: nil,
            dailyUsageCount: dailyCount,
            dailyUsageLimit: plan == .free ? freeDailyLimit : .max
        )

        refreshDailyUsage(lastDate: lastDate)
    }

    // MARK: - Public API
    func paywallContext(for file: FileInfo, preset: CompressionPreset? = nil) -> PaywallContext? {
        refreshDailyUsage(lastDate: UserDefaults.standard.object(forKey: lastUsageDateKey) as? Date)

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
                limitDescription: "\(file.name) is \(String(format: \"%.0f\", file.sizeMB)) MB"
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

    func startPro(plan: SubscriptionPlan) {
        status = SubscriptionStatus(
            plan: plan,
            isActive: true,
            expiresAt: nil,
            dailyUsageCount: 0,
            dailyUsageLimit: .max
        )
        UserDefaults.standard.set(plan.rawValue, forKey: planKey)
        UserDefaults.standard.set(0, forKey: dailyCountKey)
    }

    func restore() {
        // In a real app, call StoreKit restore. Here we mirror a success path.
        startPro(plan: .yearly)
    }

    func resetToFree() {
        status = SubscriptionStatus.free
        UserDefaults.standard.set(SubscriptionPlan.free.rawValue, forKey: planKey)
        persistUsage()
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

    private func persistUsage() {
        UserDefaults.standard.set(status.dailyUsageCount, forKey: dailyCountKey)
        UserDefaults.standard.set(Date(), forKey: lastUsageDateKey)
    }
}
