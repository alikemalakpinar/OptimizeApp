//
//  SettingsScreen.swift
//  optimize
//
//  Settings screen
//

import SwiftUI

struct SettingsScreen: View {
    // MARK: - Persistent Settings with @AppStorage
    @AppStorage("defaultPresetId") private var defaultPresetId: String = "whatsapp"
    @AppStorage("processOnWifiOnly") private var processOnWifiOnly: Bool = true
    @AppStorage("deleteOriginalAfterProcess") private var deleteOriginalAfterProcess: Bool = false
    @AppStorage("historyRetentionDays") private var historyRetentionDays: Int = 30
    @AppStorage("enableAnalytics") private var enableAnalytics: Bool = true

    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showClearHistoryAlert = false
    @State private var showManageSubscription = false

    @ObservedObject private var historyManager = HistoryManager.shared

    let subscriptionStatus: SubscriptionStatus
    let onUpgrade: () -> Void
    let onBack: () -> Void

    private let presetOptions = ["mail", "whatsapp", "quality"]
    private let retentionOptions = [7, 14, 30, 90]

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader(AppStrings.Settings.title, onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    SettingsSection(title: AppStrings.Settings.membership) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(subscriptionStatus.isPro ? "Pro aktif" : "Ücretsiz plan")
                                        .font(.appBodyMedium)
                                        .foregroundStyle(.primary)
                                    Text(subscriptionStatus.isPro ? "Reklamsız, sınırsız sıkıştırma açık." : "Günlük \(subscriptionStatus.dailyUsageLimit) ücretsiz kullanım, \(subscriptionStatus.remainingUsage) kaldı.")
                                        .font(.appCaption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(subscriptionStatus.isPro ? "PRO" : "FREE")
                                    .font(.appCaptionMedium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xxs)
                                    .background(subscriptionStatus.isPro ? Color.appMint : Color.appAccent)
                                    .clipShape(Capsule())
                            }

                            if !subscriptionStatus.isPro {
                                PrimaryButton(
                                    title: "Pro'ya yükselt",
                                    icon: "crown.fill"
                                ) {
                                    onUpgrade()
                                }
                            } else {
                                InfoBanner(type: .success, message: "Öncelikli, reklamsız sıkıştırma etkin.")

                                // Manage Subscription link
                                Button(action: {
                                    Haptics.selection()
                                    openManageSubscription()
                                }) {
                                    HStack {
                                        Image(systemName: "creditcard")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(AppStrings.Settings.manageSubscription)
                                            .font(.appCaption)
                                    }
                                    .foregroundStyle(Color.appAccent)
                                }
                                .padding(.top, Spacing.xs)
                            }
                        }
                    }

                    // Compression Settings
                    SettingsSection(title: AppStrings.Settings.compression) {
                        VStack(spacing: Spacing.md) {
                            PickerRow(
                                title: AppStrings.Settings.defaultPreset,
                                icon: "slider.horizontal.3",
                                options: presetOptions,
                                optionLabel: { presetName($0) },
                                selection: $defaultPresetId
                            )

                            Divider()

                            ToggleRow(
                                title: AppStrings.Settings.wifiOnly,
                                subtitle: AppStrings.Settings.wifiOnlySubtitle,
                                icon: "wifi",
                                isOn: $processOnWifiOnly
                            )

                            Divider()

                            ToggleRow(
                                title: AppStrings.Settings.deleteOriginal,
                                subtitle: AppStrings.Settings.deleteOriginalSubtitle,
                                icon: "trash",
                                isOn: $deleteOriginalAfterProcess
                            )
                        }
                    }

                    // History Settings
                    SettingsSection(title: AppStrings.Settings.history) {
                        VStack(spacing: Spacing.md) {
                            PickerRow(
                                title: AppStrings.Settings.keepHistory,
                                icon: "clock.arrow.circlepath",
                                options: retentionOptions,
                                optionLabel: { AppStrings.Settings.daysFormat($0) },
                                selection: $historyRetentionDays
                            )

                            Divider()

                            HStack {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(AppStrings.Settings.clearHistory)
                                            .font(.appBody)
                                            .foregroundStyle(.primary)

                                        Text("\(historyManager.items.count) \(AppStrings.Settings.items)")
                                            .font(.appCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button(action: {
                                    Haptics.selection()
                                    showClearHistoryAlert = true
                                }) {
                                    Text(AppStrings.Settings.clear)
                                        .font(.appCaptionMedium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xxs)
                                        .background(Color.red.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                                .disabled(historyManager.items.isEmpty)
                                .opacity(historyManager.items.isEmpty ? 0.5 : 1.0)
                            }
                        }
                    }

                    // Privacy Settings
                    SettingsSection(title: AppStrings.Settings.privacy) {
                        VStack(spacing: Spacing.md) {
                            ToggleRow(
                                title: AppStrings.Settings.anonymousData,
                                subtitle: AppStrings.Settings.anonymousDataSubtitle,
                                icon: "chart.bar",
                                isOn: $enableAnalytics
                            )

                            Divider()

                            SettingsLinkRow(
                                title: AppStrings.Settings.privacyPolicy,
                                icon: "hand.raised"
                            ) {
                                openPrivacyPolicy()
                            }

                            Divider()

                            SettingsLinkRow(
                                title: AppStrings.Settings.termsOfService,
                                icon: "doc.text"
                            ) {
                                openTermsOfService()
                            }
                        }
                    }

                    // Support
                    SettingsSection(title: AppStrings.Settings.support) {
                        VStack(spacing: Spacing.md) {
                            SettingsLinkRow(
                                title: AppStrings.Settings.helpFAQ,
                                icon: "questionmark.circle"
                            ) {
                                openHelp()
                            }

                            Divider()

                            SettingsLinkRow(
                                title: AppStrings.Settings.sendFeedback,
                                icon: "envelope"
                            ) {
                                sendFeedback()
                            }

                            Divider()

                            SettingsLinkRow(
                                title: AppStrings.Settings.rateApp,
                                icon: "star"
                            ) {
                                rateApp()
                            }
                        }
                    }

                    // App Info
                    VStack(spacing: Spacing.xxs) {
                        Text("Optimize v1.0.0")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text(AppStrings.Settings.madeWith)
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }
        }
        .appBackgroundLayered()
        .alert(AppStrings.Settings.clearHistoryTitle, isPresented: $showClearHistoryAlert) {
            Button(AppStrings.Settings.cancel, role: .cancel) { }
            Button(AppStrings.Settings.clearAll, role: .destructive) {
                historyManager.clearAll()
                Haptics.success()
            }
        } message: {
            Text(AppStrings.Settings.clearHistoryMessage(historyManager.items.count))
        }
    }

    // MARK: - Helper Functions
    private func openManageSubscription() {
        // Opens the iOS subscription management page
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacyPolicy() {
        // Replace with your actual Privacy Policy URL
        if let url = URL(string: "https://optimize-app.com/privacy") {
            UIApplication.shared.open(url)
        }
    }

    private func openTermsOfService() {
        // Replace with your actual Terms of Service URL
        if let url = URL(string: "https://optimize-app.com/terms") {
            UIApplication.shared.open(url)
        }
    }

    private func openHelp() {
        // Replace with your actual Help/FAQ URL
        if let url = URL(string: "https://optimize-app.com/help") {
            UIApplication.shared.open(url)
        }
    }

    private func sendFeedback() {
        // Opens Mail app with feedback email including device info
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let email = "support@optimize-app.com"
        let subject = "Optimize App Destek (v\(version).\(build) - \(deviceModel) iOS \(systemVersion))"

        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        // Replace YOUR_APP_ID with actual App Store ID
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private func presetName(_ id: String) -> String {
        switch id {
        case "mail": return "Mail (25 MB)"
        case "whatsapp": return "WhatsApp"
        case "quality": return "Best Quality"
        default: return id
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.appCaptionMedium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            GlassCard {
                content
            }
        }
    }
}

// MARK: - Settings Link Row
struct SettingsLinkRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(title)
                    .font(.appBody)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    SettingsScreen(
        subscriptionStatus: .free,
        onUpgrade: {},
        onBack: {}
    )
}
