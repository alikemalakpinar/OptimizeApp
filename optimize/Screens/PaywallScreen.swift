//
//  PaywallScreen.swift
//  optimize
//
//  Subscription paywall modal
//

import SwiftUI

struct PaywallScreen: View {
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var isRestoring = false

    var limitExceeded: Bool = false
    var currentFileSize: String? = nil

    let onSubscribe: (SubscriptionPlan) -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPrivacy: () -> Void
    let onTerms: () -> Void

    private let features = [
        "1 GB'a kadar büyük dosyalar",
        "Hedef boyut modu",
        "Batch işlemler",
        "Öncelikli sıkıştırma",
        "Reklamsız deneyim"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                HeaderCloseButton {
                    onDismiss()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Header
                    PaywallHeader(
                        title: "Sınırları kaldır",
                        subtitle: "Pro ile büyük dosyaları anında optimize et"
                    )

                    // Limit exceeded banner (if applicable)
                    if limitExceeded, let size = currentFileSize {
                        LimitExceededBanner(
                            currentSize: size,
                            maxSize: "50 MB"
                        )
                    }

                    // Features
                    GlassCard {
                        FeatureList(features: features)
                    }

                    // Plan cards
                    HStack(spacing: Spacing.sm) {
                        PlanCard(
                            title: "Aylık",
                            price: "₺49,99",
                            period: "ay",
                            isSelected: selectedPlan == .monthly
                        ) {
                            withAnimation(AppAnimation.spring) {
                                selectedPlan = .monthly
                            }
                        }

                        PlanCard(
                            title: "Yıllık",
                            price: "₺249,99",
                            period: "yıl",
                            badge: "En avantajlı",
                            savings: "%58 tasarruf",
                            isSelected: selectedPlan == .yearly
                        ) {
                            withAnimation(AppAnimation.spring) {
                                selectedPlan = .yearly
                            }
                        }
                    }

                    // Subscription info
                    Text("Abonelik otomatik olarak yenilenir. İstediğiniz zaman iptal edebilirsiniz.")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }

            // Bottom section
            VStack(spacing: Spacing.md) {
                PrimaryButton(
                    title: "Pro'ya Geç",
                    isLoading: isLoading
                ) {
                    isLoading = true
                    onSubscribe(selectedPlan)
                }

                RestoreButton(isLoading: isRestoring) {
                    isRestoring = true
                    onRestore()
                }

                PaywallFooterLinks(
                    onPrivacy: onPrivacy,
                    onTerms: onTerms
                )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
    }
}

#Preview {
    PaywallScreen(
        limitExceeded: true,
        currentFileSize: "150 MB",
        onSubscribe: { plan in
            print("Subscribe to: \(plan)")
        },
        onRestore: {},
        onDismiss: {},
        onPrivacy: {},
        onTerms: {}
    )
}
