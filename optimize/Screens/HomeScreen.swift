//
//  HomeScreen.swift
//  optimize
//
//  Main home screen with breathing CTA and real history
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeScreen: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var ctaPulse = false
    @State private var isDropTargeted = false

    let onSelectFile: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    init(
        coordinator: AppCoordinator,
        onSelectFile: @escaping () -> Void,
        onOpenHistory: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.onSelectFile = onSelectFile
        self.onOpenHistory = onOpenHistory
        self.onOpenSettings = onOpenSettings
    }

    var recentHistory: [HistoryItem] {
        coordinator.historyManager.recentItems(limit: 3)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader(".optimize") {
                HeaderIconButton(systemName: "gearshape") {
                    onOpenSettings()
                }
            }

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Main CTA Section with Breathing Effect
                    VStack(spacing: Spacing.lg) {
                        // CTA Card with drop support
                        BreathingCTACard(
                            isDropTargeted: isDropTargeted,
                            onTap: {
                                Haptics.impact()
                                onSelectFile()
                            }
                        )
                        .accessibilityLabel("PDF dosyası seç")
                        .accessibilityHint("PDF dosyası seçmek için dokunun veya sürükleyip bırakın")
                        .dropDestination(for: URL.self) { urls, _ in
                            if let url = urls.first {
                                Haptics.success()
                                coordinator.handlePickedFile(url)
                                return true
                            }
                            return false
                        } isTargeted: { targeted in
                            withAnimation(AppAnimation.spring) {
                                isDropTargeted = targeted
                            }
                        }

                        // Privacy badges
                        PrivacyBadge()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                    // Recent History Section or Empty State
                    if recentHistory.isEmpty {
                        EmptyHistoryState()
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.xl)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Son İşlemler")
                                    .font(.appSection)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button(action: {
                                    onOpenHistory()
                                }) {
                                    Text("Tümünü Gör")
                                        .font(.appCaptionMedium)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding(.horizontal, Spacing.md)

                            VStack(spacing: Spacing.xs) {
                                ForEach(Array(recentHistory.enumerated()), id: \.element.id) { index, item in
                                    HistoryRow(item: item)
                                        .staggeredAppearance(index: index)
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        }
                    }

                    Spacer(minLength: Spacing.xl)
                }
            }
        }
        .appBackgroundLayered()
    }
}

// MARK: - Breathing CTA Card
struct BreathingCTACard: View {
    let isDropTargeted: Bool
    let onTap: () -> Void

    @State private var breathScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.3

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.md) {
                // Icon with breathing effect
                ZStack {
                    // Outer breathing rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Color.appAccent.opacity(0.15 - Double(index) * 0.04),
                                lineWidth: 1.5
                            )
                            .frame(
                                width: 80 + CGFloat(index) * 20,
                                height: 80 + CGFloat(index) * 20
                            )
                            .scaleEffect(breathScale + CGFloat(index) * 0.02)
                            .opacity(ringOpacity - Double(index) * 0.1)
                    }

                    // Main circle
                    Circle()
                        .fill(Color.appAccent.opacity(Opacity.subtle))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)

                    // Icon
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                        .symbolBounce(trigger: isDropTargeted)
                }

                // Text
                VStack(spacing: Spacing.xxs) {
                    Text(isDropTargeted ? "Dosyayı Bırak" : "Dosya Seç")
                        .font(.appTitle)
                        .foregroundStyle(.primary)

                    Text(isDropTargeted ? "Optimize etmek için bırak" : "Dokun veya dosyayı buraya sürükle")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        isDropTargeted ? Color.appAccent : Color.glassBorder,
                        lineWidth: isDropTargeted ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.pressable)
        .onAppear {
            startBreathingAnimation()
        }
    }

    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            breathScale = 1.08
            ringOpacity = 0.5
        }
    }
}

// MARK: - Empty History State
struct EmptyHistoryState: View {
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Floating illustration
            ZStack {
                // Background glow
                Circle()
                    .fill(Color.appAccent.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)

                // Floating documents illustration
                ZStack {
                    // Back document
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appSurface)
                        .frame(width: 50, height: 65)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                        .rotationEffect(.degrees(-15))
                        .offset(x: -20, y: 10)
                        .offset(y: floatOffset * 0.5)

                    // Middle document
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appSurface)
                        .frame(width: 55, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                        )
                        .rotationEffect(.degrees(5))
                        .offset(x: 15, y: -5)
                        .offset(y: floatOffset * 0.7)

                    // Front document with sparkle
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent.opacity(0.1), Color.appMint.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 75)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.appAccent.opacity(0.4), lineWidth: 1.5)
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.appAccent)
                    }
                    .offset(y: floatOffset)
                }
            }
            .frame(height: 140)

            // Text
            VStack(spacing: Spacing.xs) {
                Text("Depolama Alanın")
                    .font(.appTitle)
                    .foregroundStyle(.primary)

                Text("Ferahlamayı Bekliyor")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appMint)

                Text("İlk dosyanı seç ve sihri başlat")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xxs)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.xl)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                floatOffset = -8
            }
        }
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let item: HistoryItem
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap?()
        }) {
            HStack(spacing: Spacing.sm) {
                // File icon
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.appAccent.opacity(Opacity.subtle))
                        .frame(width: 44, height: 44)

                    Image(systemName: "doc.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                .accessibilityHidden(true)

                // File info
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.fileName)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: Spacing.xs) {
                        Text("\(item.originalSizeFormatted) → \(item.compressedSizeFormatted)")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)

                        Text(item.timeAgo)
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Savings badge with mint color
                Text("-%\(item.savingsPercent)")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.appMint)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.appMint.opacity(Opacity.subtle))
                    .clipShape(Capsule())
                    .accessibilityLabel("Yüzde \(item.savingsPercent) tasarruf")
            }
            .padding(Spacing.sm)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(item.fileName), \(item.originalSizeFormatted) boyutundan \(item.compressedSizeFormatted) boyutuna sıkıştırıldı, yüzde \(item.savingsPercent) tasarruf, \(item.timeAgo)")
        .accessibilityHint("Detayları görmek için dokunun")
    }
}

#Preview {
    HomeScreen(
        coordinator: AppCoordinator(),
        onSelectFile: {},
        onOpenHistory: {},
        onOpenSettings: {}
    )
}
