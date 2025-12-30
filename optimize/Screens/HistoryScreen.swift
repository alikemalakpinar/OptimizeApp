//
//  HistoryScreen.swift
//  optimize
//
//  History list screen with persistent data
//

import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var selectedItem: HistoryItem?
    @State private var showDetail = false
    @State private var showClearConfirmation = false

    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader("Geçmiş", onBack: onBack) {
                if !historyManager.items.isEmpty {
                    Button(action: {
                        Haptics.warning()
                        showClearConfirmation = true
                    }) {
                        Text("Temizle")
                            .font(.appCaption)
                            .foregroundStyle(Color.statusError)
                    }
                } else {
                    Color.clear.frame(width: 60)
                }
            }

            if historyManager.items.isEmpty {
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
                        ForEach(Array(historyManager.items.enumerated()), id: \.element.id) { index, item in
                            HistoryRow(item: item) {
                                selectedItem = item
                                showDetail = true
                            }
                            .staggeredAppearance(index: index)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        historyManager.removeItem(item)
                                    }
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
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
        .alert("Geçmişi Temizle", isPresented: $showClearConfirmation) {
            Button("İptal", role: .cancel) {}
            Button("Temizle", role: .destructive) {
                withAnimation {
                    historyManager.clearAll()
                }
            }
        } message: {
            Text("Tüm geçmiş silinecek. Bu işlem geri alınamaz.")
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
    HistoryScreen(
        historyManager: HistoryManager.shared,
        onBack: {}
    )
}
