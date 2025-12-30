//
//  SettingsScreen.swift
//  optimize
//
//  Settings screen
//

import SwiftUI

struct SettingsScreen: View {
    @State private var settings = AppSettings()
    @State private var showPrivacy = false
    @State private var showTerms = false

    let onBack: () -> Void

    private let presetOptions = ["mail", "whatsapp", "quality"]
    private let retentionOptions = [7, 14, 30, 90]

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: {
                    Haptics.selection()
                    onBack()
                }) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Geri")
                            .font(.appBody)
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.pressable)

                Spacer()

                Text("Ayarlar")
                    .font(.appSection)
                    .foregroundStyle(.primary)

                Spacer()

                // Placeholder for alignment
                Color.clear
                    .frame(width: 60)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Compression Settings
                    SettingsSection(title: "Sıkıştırma") {
                        VStack(spacing: Spacing.md) {
                            PickerRow(
                                title: "Varsayılan preset",
                                icon: "slider.horizontal.3",
                                options: presetOptions,
                                optionLabel: { presetName($0) },
                                selection: $settings.defaultPresetId
                            )

                            Divider()

                            ToggleRow(
                                title: "Wi-Fi ile işle",
                                subtitle: "Mobil veri kullanma",
                                icon: "wifi",
                                isOn: $settings.processOnWifiOnly
                            )

                            Divider()

                            ToggleRow(
                                title: "İşlem sonrası sil",
                                subtitle: "Orijinal dosyayı kaldır",
                                icon: "trash",
                                isOn: $settings.deleteOriginalAfterProcess
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
                            selection: $settings.historyRetentionDays
                        )
                    }

                    // Privacy Settings
                    SettingsSection(title: "Gizlilik") {
                        VStack(spacing: Spacing.md) {
                            ToggleRow(
                                title: "Anonim kullanım verileri",
                                subtitle: "Uygulamayı geliştirmemize yardımcı olun",
                                icon: "chart.bar",
                                isOn: $settings.enableAnalytics
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
                .padding(.top, Spacing.md)
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
