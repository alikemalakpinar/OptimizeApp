//
//  HistoryScreen.swift
//  optimize
//
//  History list screen
//

import SwiftUI

struct HistoryScreen: View {
    @State private var history: [HistoryItem] = [
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
            fileName: "Sunum_Q4.pdf",
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
        ),
        HistoryItem(
            id: UUID(),
            fileName: "Fatura_2024.pdf",
            originalSize: 50_000_000,
            compressedSize: 15_000_000,
            savingsPercent: 70,
            processedAt: Date().addingTimeInterval(-172800),
            presetUsed: "mail"
        ),
        HistoryItem(
            id: UUID(),
            fileName: "Sözleşme.pdf",
            originalSize: 25_000_000,
            compressedSize: 8_000_000,
            savingsPercent: 68,
            processedAt: Date().addingTimeInterval(-259200),
            presetUsed: "whatsapp"
        )
    ]

    @State private var selectedItem: HistoryItem?
    @State private var showDetail = false

    let onBack: () -> Void

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

                Text("Geçmiş")
                    .font(.appSection)
                    .foregroundStyle(.primary)

                Spacer()

                // Clear all button
                if !history.isEmpty {
                    Button(action: {
                        Haptics.warning()
                        withAnimation(AppAnimation.standard) {
                            history.removeAll()
                        }
                    }) {
                        Text("Temizle")
                            .font(.appCaption)
                            .foregroundStyle(Color.statusError)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            if history.isEmpty {
                // Empty state
                VStack(spacing: Spacing.md) {
                    Spacer()

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.secondary)

                    Text("Henüz işlem yok")
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)

                    Text("Optimize ettiğiniz dosyalar burada görünecek")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                // History list
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, item in
                            HistoryRow(item: item) {
                                selectedItem = item
                                showDetail = true
                            }
                            .staggeredAppearance(index: index)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                }
            }
        }
        .appBackgroundLayered()
        .sheet(isPresented: $showDetail) {
            if let item = selectedItem {
                HistoryDetailSheet(item: item) {
                    showDetail = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - History Detail Sheet
struct HistoryDetailSheet: View {
    let item: HistoryItem
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            HStack {
                Text("Detaylar")
                    .font(.appSection)
                    .foregroundStyle(.primary)

                Spacer()

                HeaderCloseButton {
                    onDismiss()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            // File info
            GlassCard {
                VStack(spacing: Spacing.md) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.appAccent)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(item.fileName)
                                .font(.appBodyMedium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(item.timeAgo)
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Divider()

                    KeyValueRow(key: "Orijinal boyut", value: item.originalSizeFormatted)
                    KeyValueRow(key: "Sıkıştırılmış boyut", value: item.compressedSizeFormatted, valueColor: .statusSuccess)
                    KeyValueRow(key: "Tasarruf", value: "%\(item.savingsPercent)", valueColor: .statusSuccess)
                    KeyValueRow(key: "Kullanılan preset", value: presetName(item.presetUsed))
                }
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            // Actions
            VStack(spacing: Spacing.sm) {
                SecondaryButton(title: "Tekrar Sıkıştır", icon: "arrow.counterclockwise") {
                    // Re-compress action
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .background(Color.appBackground)
    }

    private func presetName(_ id: String) -> String {
        switch id {
        case "mail": return "Mail (25 MB)"
        case "whatsapp": return "WhatsApp"
        case "quality": return "En İyi Kalite"
        case "custom": return "Özel"
        default: return id
        }
    }
}

#Preview {
    HistoryScreen(onBack: {})
}
