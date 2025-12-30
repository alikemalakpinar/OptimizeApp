//
//  HomeScreen.swift
//  optimize
//
//  Main home screen with file selection CTA and history
//

import SwiftUI

struct HomeScreen: View {
    @State private var showFilePicker = false
    @State private var showSettings = false
    @State private var ctaPulse = false

    // Sample history for demo
    @State private var recentHistory: [HistoryItem] = [
        HistoryItem(
            id: UUID(),
            fileName: "Rapor_2024.pdf",
            originalSize: 300_000_000,
            compressedSize: 92_000_000,
            savingsPercent: 69,
            processedAt: Date().addingTimeInterval(-120),
            presetUsed: "whatsapp"
        ),
        HistoryItem(
            id: UUID(),
            fileName: "Sunum.pdf",
            originalSize: 150_000_000,
            compressedSize: 45_000_000,
            savingsPercent: 70,
            processedAt: Date().addingTimeInterval(-3600),
            presetUsed: "mail"
        ),
        HistoryItem(
            id: UUID(),
            fileName: "Belge_scan.pdf",
            originalSize: 80_000_000,
            compressedSize: 25_000_000,
            savingsPercent: 69,
            processedAt: Date().addingTimeInterval(-86400),
            presetUsed: "quality"
        )
    ]

    let onSelectFile: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader("Optimize") {
                HeaderIconButton(systemName: "gearshape") {
                    onOpenSettings()
                }
            }

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Main CTA Section
                    VStack(spacing: Spacing.lg) {
                        // CTA Card
                        Button(action: {
                            Haptics.impact()
                            onSelectFile()
                        }) {
                            VStack(spacing: Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(ctaPulse ? 1.1 : 1.0)

                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundStyle(Color.appAccent)
                                }

                                Text("Dosya Seç")
                                    .font(.appTitle)
                                    .foregroundStyle(.primary)

                                Text("PDF, görsel veya döküman seç")
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xl)
                            .glassMaterial()
                        }
                        .buttonStyle(.pressable)

                        // Privacy badges
                        PrivacyBadge()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                    // Recent History Section
                    if !recentHistory.isEmpty {
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
                                ForEach(Array(recentHistory.prefix(3).enumerated()), id: \.element.id) { index, item in
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
        .background(Color.appBackground)
        .onAppear {
            // Single pulse animation on first appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(AppAnimation.bouncy) {
                    ctaPulse = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(AppAnimation.standard) {
                        ctaPulse = false
                    }
                }
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
                        .fill(Color.appAccent.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "doc.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }

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

                        Text(item.timeAgo)
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Savings badge
                Text("-%\(item.savingsPercent)")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.statusSuccess)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.statusSuccess.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(Spacing.sm)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    HomeScreen(
        onSelectFile: {},
        onOpenHistory: {},
        onOpenSettings: {}
    )
}
