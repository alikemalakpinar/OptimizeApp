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

    let subscriptionStatus: SubscriptionStatus
    let onUpgrade: () -> Void
    let onBack: () -> Void

    private let presetOptions = ["mail", "whatsapp", "quality"]
    private let retentionOptions = [7, 14, 30, 90]

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader("Settings", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    SettingsSection(title: "Membership") {
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
                            }
                        }
                    }

                    // Compression Settings
                    SettingsSection(title: "Compression") {
                        VStack(spacing: Spacing.md) {
                            PickerRow(
                                title: "Default preset",
                                icon: "slider.horizontal.3",
                                options: presetOptions,
                                optionLabel: { presetName($0) },
                                selection: $defaultPresetId
                            )

                            Divider()

                            ToggleRow(
                                title: "Process on Wi-Fi",
                                subtitle: "Don't use mobile data",
                                icon: "wifi",
                                isOn: $processOnWifiOnly
                            )

                            Divider()

                            ToggleRow(
                                title: "Delete after processing",
                                subtitle: "Remove original file",
                                icon: "trash",
                                isOn: $deleteOriginalAfterProcess
                            )
                        }
                    }

                    // History Settings
                    SettingsSection(title: "History") {
                        PickerRow(
                            title: "Keep history",
                            icon: "clock.arrow.circlepath",
                            options: retentionOptions,
                            optionLabel: { "\($0) days" },
                            selection: $historyRetentionDays
                        )
                    }

                    // Privacy Settings
                    SettingsSection(title: "Privacy") {
                        VStack(spacing: Spacing.md) {
                            ToggleRow(
                                title: "Anonymous usage data",
                                subtitle: "Help us improve the app",
                                icon: "chart.bar",
                                isOn: $enableAnalytics
                            )

                            Divider()

                            SettingsLinkRow(
                                title: "Privacy Policy",
                                icon: "hand.raised"
                            ) {
                                showPrivacy = true
                            }

                            Divider()

                            SettingsLinkRow(
                                title: "Terms of Service",
                                icon: "doc.text"
                            ) {
                                showTerms = true
                            }
                        }
                    }

                    // Support
                    SettingsSection(title: "Support") {
                        VStack(spacing: Spacing.md) {
                            SettingsLinkRow(
                                title: "Help & FAQ",
                                icon: "questionmark.circle"
                            ) {
                                // Open help
                            }

                            Divider()

                            SettingsLinkRow(
                                title: "Send Feedback",
                                icon: "envelope"
                            ) {
                                // Open feedback
                            }

                            Divider()

                            SettingsLinkRow(
                                title: "Rate the App",
                                icon: "star"
                            ) {
                                // Open App Store review
                            }
                        }
                    }

                    // App Info
                    VStack(spacing: Spacing.xxs) {
                        Text("Optimize v1.0.0")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text("Made with ❤️ in Istanbul")
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
