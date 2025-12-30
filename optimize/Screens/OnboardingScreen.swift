//
//  OnboardingScreen.swift
//  optimize
//
//  Onboarding flow with 3 pages
//

import SwiftUI

struct OnboardingScreen: View {
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "doc.zipper",
            title: "PDF'leri Küçült",
            subtitle: "300 MB'lık dosyaları saniyeler içinde sıkıştır"
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Gizlilik Öncelikli",
            subtitle: "Dosyalarınız paylaşılmaz, işlem sonrası otomatik silinir"
        ),
        OnboardingPage(
            icon: "bolt.fill",
            title: "Hızlı & Kolay",
            subtitle: "Tek dokunuşla optimize et, anında paylaş"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Pages
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom section
            VStack(spacing: Spacing.lg) {
                // Page indicators
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.appAccent : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(AppAnimation.standard, value: currentPage)
                    }
                }

                // Continue button
                PrimaryButton(
                    title: currentPage == pages.count - 1 ? "Başla" : "Devam"
                ) {
                    if currentPage < pages.count - 1 {
                        withAnimation(AppAnimation.standard) {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xl)
        }
        .appBackgroundLayered()
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.1))
                    .frame(width: 160, height: 160)

                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            // Text
            VStack(spacing: Spacing.sm) {
                Text(page.title)
                    .font(.appLargeTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            .opacity(iconOpacity)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(AppAnimation.spring.delay(0.1)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }
}

#Preview {
    OnboardingScreen {
        print("Onboarding complete")
    }
}
