//
//  SettingsScreen.swift
//  optimize
//
//  Premium Settings Design with Apple-style Inset Grouped List
//  Includes Commitment Signature Card for psychological retention
//

import SwiftUI

struct SettingsScreen: View {
    // MARK: - Persistent Settings with @AppStorage
    @AppStorage("defaultPresetId") private var defaultPresetId: String = "whatsapp"
    @AppStorage("processOnWifiOnly") private var processOnWifiOnly: Bool = true
    @AppStorage("deleteOriginalAfterProcess") private var deleteOriginalAfterProcess: Bool = false
    @AppStorage("historyRetentionDays") private var historyRetentionDays: Int = 30
    @AppStorage("enableAnalytics") private var enableAnalytics: Bool = true

    @State private var showClearHistoryAlert = false
    @State private var signatureImage: UIImage?

    @ObservedObject private var historyManager = HistoryManager.shared

    let subscriptionStatus: SubscriptionStatus
    let onUpgrade: () -> Void
    let onBack: () -> Void

    private let presetOptions = ["mail", "whatsapp", "quality"]
    private let retentionOptions = [7, 14, 30, 90]

    // MARK: - URL Constants
    // TODO: Update these URLs before App Store submission
    private let privacyURL = URL(string: "https://optimize-app.com/privacy")!
    private let termsURL = URL(string: "https://optimize-app.com/terms")!
    private let helpURL = URL(string: "https://optimize-app.com/help")!
    private let supportEmail = "support@optimize-app.com"
    // TODO: Replace YOUR_APP_ID with actual App Store ID
    private let rateURL = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review")!

    var body: some View {
        List {
                // MARK: - Commitment Signature Card (Motivation)
                if signatureImage != nil {
                    Section {
                        CommitmentSignatureCard(signatureImage: signatureImage)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: - Premium Banner Section
                Section {
                    PremiumBannerRow(
                        isPro: subscriptionStatus.isPro,
                        onUpgrade: onUpgrade
                    )
                }
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))

                // MARK: - Compression Settings
                Section {
                    // Default Quality Picker
                    Picker(selection: $defaultPresetId) {
                        Text("WhatsApp").tag("whatsapp")
                        Text("Mail (25 MB)").tag("mail")
                        Text(AppStrings.Presets.quality).tag("quality")
                    } label: {
                        Label(AppStrings.Settings.defaultPreset, systemImage: "slider.horizontal.3")
                    }
                    .pickerStyle(.menu)

                    // Delete Original Toggle
                    Toggle(isOn: $deleteOriginalAfterProcess) {
                        Label(AppStrings.Settings.deleteOriginal, systemImage: "trash")
                    }
                    .tint(Color.appMint)

                    // Wi-Fi Only Toggle
                    Toggle(isOn: $processOnWifiOnly) {
                        Label(AppStrings.Settings.wifiOnly, systemImage: "wifi")
                    }
                    .tint(Color.appMint)
                } header: {
                    Text(AppStrings.Settings.compression)
                }

                // MARK: - History Settings
                Section {
                    // History Retention Picker
                    Picker(selection: $historyRetentionDays) {
                        ForEach(retentionOptions, id: \.self) { days in
                            Text(AppStrings.Settings.daysFormat(days)).tag(days)
                        }
                    } label: {
                        Label(AppStrings.Settings.keepHistory, systemImage: "clock.arrow.circlepath")
                    }
                    .pickerStyle(.menu)

                    // Clear History Button
                    Button(role: .destructive) {
                        showClearHistoryAlert = true
                    } label: {
                        HStack {
                            Label(AppStrings.Settings.clearHistory, systemImage: "trash")
                            Spacer()
                            Text("\(historyManager.items.count) \(AppStrings.Settings.items)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(historyManager.items.isEmpty)
                } header: {
                    Text(AppStrings.Settings.history)
                }

                // MARK: - Privacy Settings
                Section {
                    // Analytics Toggle
                    Toggle(isOn: $enableAnalytics) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(AppStrings.Settings.anonymousData, systemImage: "chart.bar")
                            Text(AppStrings.Settings.anonymousDataSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Color.appMint)
                } header: {
                    Text(AppStrings.Settings.privacy)
                }

                // MARK: - Support Section
                Section {
                    // Rate App
                    Link(destination: rateURL) {
                        Label(AppStrings.Settings.rateApp, systemImage: "star.fill")
                            .foregroundStyle(.primary)
                    }

                    // Send Feedback
                    Button {
                        sendFeedback()
                    } label: {
                        Label(AppStrings.Settings.sendFeedback, systemImage: "envelope.fill")
                            .foregroundStyle(.primary)
                    }

                    // Help & FAQ
                    Link(destination: helpURL) {
                        Label(AppStrings.Settings.helpFAQ, systemImage: "questionmark.circle.fill")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text(AppStrings.Settings.support)
                }

                // MARK: - Legal Section
                Section {
                    Link(destination: privacyURL) {
                        Label(AppStrings.Settings.privacyPolicy, systemImage: "hand.raised.fill")
                            .foregroundStyle(.primary)
                    }

                    Link(destination: termsURL) {
                        Label(AppStrings.Settings.termsOfService, systemImage: "doc.text.fill")
                            .foregroundStyle(.primary)
                    }

                    if subscriptionStatus.isPro {
                        Button {
                            openManageSubscription()
                        } label: {
                            Label(AppStrings.Settings.manageSubscription, systemImage: "creditcard.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text(AppStrings.Settings.legal)
                }

                // MARK: - App Info Footer
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Optimize v\(appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(AppStrings.Settings.madeWith)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
        .listStyle(.insetGrouped)
        .navigationTitle(AppStrings.Settings.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Haptics.selection()
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Geri")
                    }
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
        .alert(AppStrings.Settings.clearHistoryTitle, isPresented: $showClearHistoryAlert) {
            Button(AppStrings.Settings.cancel, role: .cancel) { }
            Button(AppStrings.Settings.clearAll, role: .destructive) {
                historyManager.clearAll()
                Haptics.success()
            }
        } message: {
            Text(AppStrings.Settings.clearHistoryMessage(historyManager.items.count))
        }
        .onAppear {
            loadSignatureImage()
        }
    }

    // MARK: - Load Signature Image
    private func loadSignatureImage() {
        if let data = UserDefaults.standard.data(forKey: "user_commitment_signature"),
           let image = UIImage(data: data) {
            signatureImage = image
        }
    }

    // MARK: - Helper Properties
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Helper Functions
    private func openManageSubscription() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func sendFeedback() {
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let subject = "Optimize App Destek (v\(appVersion) - \(deviceModel) iOS \(systemVersion))"

        if let url = URL(string: "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Premium Banner Row
struct PremiumBannerRow: View {
    let isPro: Bool
    let onUpgrade: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if !isPro {
            // Upgrade Banner
            Button(action: onUpgrade) {
                HStack(spacing: Spacing.md) {
                    // Crown Icon with premium gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.premiumPurple, Color.premiumBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppStrings.Home.upgradeToPro)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Sınırsız sıkıştırma & Reklamsız")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.premiumPurple)
                }
                .padding(.vertical, 6)
            }
        } else {
            // Pro Active Banner
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.appMint.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.appMint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium Üyesiniz")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Tüm özellikler aktif")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("PRO")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color.appMint, Color.appTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Preview
#Preview("Free User") {
    SettingsScreen(
        subscriptionStatus: .free,
        onUpgrade: {},
        onBack: {}
    )
}

#Preview("Pro User") {
    SettingsScreen(
        subscriptionStatus: .pro,
        onUpgrade: {},
        onBack: {}
    )
}

// MARK: - Commitment Signature Card
/// Shows the user's onboarding signature as a "contract" reminder
/// Psychology: Commitment & Consistency principle - users who sign are more likely to stay
struct CommitmentSignatureCard: View {
    let signatureImage: UIImage?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "seal.fill")
                    .foregroundStyle(Color.goldAccent)
                    .font(.system(size: 16))

                Text("KENDİNE VERDİĞİN SÖZ")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Signature Display
            if let image = signatureImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .colorMultiply(colorScheme == .dark ? .white : .primary)
                    .opacity(colorScheme == .dark ? 0.9 : 1.0)
            }

            // Commitment Text
            Text("Dosyalarımı her zaman optimize edeceğime ve dijital kirlilik yaratmayacağıma söz veriyorum.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(colorScheme == .dark
                    ? Color(.systemGray6)
                    : Color.signatureCardBG
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.goldAccent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
