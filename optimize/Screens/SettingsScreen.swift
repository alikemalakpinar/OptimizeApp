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

    let onBack: () -> Void

    private let presetOptions = ["mail", "whatsapp", "quality"]
    private let retentionOptions = [7, 14, 30, 90]

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader("Ayarlar", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Compression Settings
                    SettingsSection(title: "Sıkıştırma") {
                        VStack(spacing: Spacing.md) {
                            PickerRow(
                                title: "Varsayılan preset",
                                icon: "slider.horizontal.3",
                                options: presetOptions,
                                optionLabel: { presetName($0) },
                                selection: $defaultPresetId
                            )

                            Divider()

                            ToggleRow(
                                title: "Wi-Fi ile işle",
                                subtitle: "Mobil veri kullanma",
                                icon: "wifi",
                                isOn: $processOnWifiOnly
                            )

                            Divider()

                            ToggleRow(
                                title: "İşlem sonrası sil",
                                subtitle: "Orijinal dosyayı kaldır",
                                icon: "trash",
                                isOn: $deleteOriginalAfterProcess
                            )
                        }
                    }

                    // History Settings
                    SettingsSection(title: "Geçmiş") {
                        PickerRow(
                            title: "Geçmişi sakla",
                            icon: "clock.arrow.circlepath",
                            options: retentionOptions,
                            optionLabel: { "\($0) gün" },
                            selection: $historyRetentionDays
                        )
                    }

                    // Privacy Settings
                    SettingsSection(title: "Gizlilik") {
                        VStack(spacing: Spacing.md) {
                            ToggleRow(
                                title: "Anonim kullanım verileri",
                                subtitle: "Uygulamayı geliştirmemize yardımcı olun",
                                icon: "chart.bar",
                                isOn: $enableAnalytics
                            )

                            Divider()

                            SettingsLinkRow(
                                title: "Gizlilik Politikası",
                                icon: "hand.raised"
                            ) {
                                showPrivacy = true
                            }

                            Divider()

                            SettingsLinkRow(
                                title: "Kullanım Koşulları",
                                icon: "doc.text"
                            ) {
                                showTerms = true
                            }
                        }
                    }

                    // Support
                    SettingsSection(title: "Destek") {
                        VStack(spacing: Spacing.md) {
                            SettingsLinkRow(
                                title: "Yardım & SSS",
                                icon: "questionmark.circle"
                            ) {
                                // Open help
                            }

                            Divider()

                            SettingsLinkRow(
                                title: "Geri Bildirim Gönder",
                                icon: "envelope"
                            ) {
                                // Open feedback
                            }

                            Divider()

                            SettingsLinkRow(
                                title: "Uygulamayı Değerlendir",
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
        case "quality": return "En İyi Kalite"
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
    SettingsScreen(onBack: {})
}
