//
//  PaywallComponents.swift
//  optimize
//
//  Paywall UI components: PlanCard, FeatureRow, RestoreButton
//

import SwiftUI

// MARK: - Plan Card
struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    var badge: String? = nil
    var savings: String? = nil
    var isSelected: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap()
        }) {
            VStack(spacing: Spacing.sm) {
                // Badge if present
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .offset(y: -Spacing.xxs)
                }

                // Title
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                // Price
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(price)
                        .font(.appNumberMedium)
                        .foregroundStyle(.primary)

                    Text("/ \(period)")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                // Savings
                if let savings = savings {
                    Text(savings)
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.statusSuccess)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isSelected ? Color.appAccent.opacity(0.08) : Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        isSelected ? Color.appAccent : Color.clear,
                        lineWidth: 2
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.appAccent)
                        .offset(x: -Spacing.sm, y: Spacing.sm)
                }
            }
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let text: String
    var icon: String = "checkmark.circle.fill"
    var iconColor: Color = .statusSuccess

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)

            Text(text)
                .font(.appBody)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Feature List
struct FeatureList: View {
    let features: [String]

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(features, id: \.self) { feature in
                FeatureRow(text: feature)
            }
        }
    }
}

// MARK: - Restore Button
struct RestoreButton: View {
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                        .scaleEffect(0.8)
                }

                Text("Satın alımı geri yükle")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Footer Links
struct PaywallFooterLinks: View {
    var onPrivacy: () -> Void
    var onTerms: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button("Gizlilik Politikası") {
                onPrivacy()
            }

            Text("•")
                .foregroundStyle(.tertiary)

            Button("Kullanım Koşulları") {
                onTerms()
            }
        }
        .font(.appCaption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Paywall Header
struct PaywallHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Pro badge
            HStack(spacing: Spacing.xs) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                Text("PRO")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            Text(title)
                .font(.appTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Limit Exceeded Banner
struct LimitExceededBanner: View {
    let currentSize: String
    let maxSize: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.statusWarning)

            Text("Ücretsiz limit aşıldı")
                .font(.appBodyMedium)
                .foregroundStyle(.primary)

            Text("Bu dosya \(currentSize). Ücretsiz plan \(maxSize)'a kadar destekler.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.statusWarning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            PaywallHeader(
                title: "Sınırları kaldır",
                subtitle: "Pro ile büyük dosyaları anında optimize et"
            )

            LimitExceededBanner(currentSize: "150 MB", maxSize: "50 MB")

            GlassCard {
                FeatureList(features: [
                    "1 GB'a kadar büyük dosyalar",
                    "Hedef boyut modu",
                    "Batch işlemler",
                    "Öncelikli sıkıştırma"
                ])
            }

            HStack(spacing: Spacing.sm) {
                PlanCard(
                    title: "Aylık",
                    price: "₺49,99",
                    period: "ay",
                    isSelected: false,
                    onTap: {}
                )

                PlanCard(
                    title: "Yıllık",
                    price: "₺249,99",
                    period: "yıl",
                    badge: "En avantajlı",
                    savings: "%58 tasarruf",
                    isSelected: true,
                    onTap: {}
                )
            }

            PrimaryButton(title: "Pro'ya Geç") {}

            RestoreButton {}

            PaywallFooterLinks(
                onPrivacy: {},
                onTerms: {}
            )
        }
        .padding()
    }
}
