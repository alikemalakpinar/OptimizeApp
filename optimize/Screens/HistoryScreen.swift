//
//  HistoryScreen.swift
//  optimize
//
//  Premium Bento Grid Design - Gallery-style history view
//

import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var selectedItem: HistoryItem?
    @State private var showDetail = false
    @State private var showClearConfirmation = false

    let onBack: () -> Void

    // Bento Grid Layout (2 Columns)
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader("", onBack: onBack) {
                if !historyManager.items.isEmpty {
                    Button(action: {
                        Haptics.warning()
                        showClearConfirmation = true
                    }) {
                        Text("Temizle")
                            .font(.uiCaption)
                            .foregroundStyle(Color.statusError)
                    }
                } else {
                    Color.clear.frame(width: 60)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Serif Title - Editorial Feel
                    Text("Geçmiş İşlemler")
                        .font(.displayTitle)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, Spacing.md)

                    if historyManager.items.isEmpty {
                        // Empty State
                        EmptyHistoryState()
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.xxl)
                    } else {
                        // Stats Summary Card
                        HistoryStatsCard(items: historyManager.items)
                            .padding(.horizontal, Spacing.md)

                        // BENTO GRID
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(historyManager.items.enumerated()), id: \.element.id) { index, item in
                                BentoHistoryCard(item: item) {
                                    Haptics.selection()
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
                    }
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(Color(.systemGroupedBackground))
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

// MARK: - Bento History Card
struct BentoHistoryCard: View {
    let item: HistoryItem
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Top: Icon & Savings Badge
                HStack {
                    // File Icon
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 40, height: 40)
                        .background(Color.appAccent.opacity(0.1))
                        .clipShape(Circle())

                    Spacer()

                    // Savings Badge
                    Text("-\(item.savingsPercent)%")
                        .font(.uiCaptionBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.appMint)
                        .clipShape(Capsule())
                }

                Spacer()

                // Bottom: File Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.uiBodyBold)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Text(item.originalSizeFormatted)
                            .strikethrough()
                            .foregroundStyle(.secondary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        Text(item.compressedSizeFormatted)
                            .foregroundStyle(Color.appMint)
                            .fontWeight(.medium)
                    }
                    .font(.dataSmall)

                    // Time ago
                    Text(item.timeAgo)
                        .font(.uiCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Spacing.md)
            .frame(height: 180)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.05),
                radius: 10, x: 0, y: 5
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Stats Card
struct HistoryStatsCard: View {
    let items: [HistoryItem]

    private var totalSaved: Int64 {
        items.reduce(0) { $0 + ($1.originalSize - $1.compressedSize) }
    }

    private var averageSavings: Int {
        guard !items.isEmpty else { return 0 }
        let total = items.reduce(0) { $0 + $1.savingsPercent }
        return total / items.count
    }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Total Files
            StatItem(
                icon: "doc.on.doc.fill",
                value: "\(items.count)",
                label: "Dosya",
                color: .appAccent
            )

            Divider()
                .frame(height: 40)

            // Total Saved
            StatItem(
                icon: "arrow.down.circle.fill",
                value: formatBytes(totalSaved),
                label: "Tasarruf",
                color: .appMint
            )

            Divider()
                .frame(height: 40)

            // Average Savings
            StatItem(
                icon: "percent",
                value: "\(averageSavings)%",
                label: "Ortalama",
                color: .appTeal
            )
        }
        .padding(Spacing.md)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text(value)
                .font(.dataValue)
                .foregroundStyle(.primary)

            Text(label)
                .font(.uiCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty History State
struct EmptyHistoryState: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))

            Text("Henüz işlem yok")
                .font(.displayHeadline)
                .foregroundStyle(.primary)

            Text("Optimize ettiğiniz dosyalar\nburada görünecek")
                .font(.uiBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xl)
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
                    .font(.displayHeadline)
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
                                .font(.uiBodyBold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(item.timeAgo)
                                .font(.uiCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Savings Badge
                        Text("-\(item.savingsPercent)%")
                            .font(.uiCaptionBold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.appMint)
                            .clipShape(Capsule())
                    }

                    Divider()

                    KeyValueRow(key: "Orijinal boyut", value: item.originalSizeFormatted)
                    KeyValueRow(key: "Sıkıştırılmış", value: item.compressedSizeFormatted, valueColor: .statusSuccess)
                    KeyValueRow(key: "Tasarruf", value: "\(item.savingsPercent)%", valueColor: .statusSuccess)
                    KeyValueRow(key: "Kullanılan ayar", value: presetName(item.presetUsed))
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
