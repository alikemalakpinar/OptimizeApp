//
//  HistoryScreen.swift
//  optimize
//
//  Premium Bento Grid Design - Gallery-style history view
//  Features: Matched Geometry Effect for hero transitions
//

import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var selectedItem: HistoryItem?
    @State private var showDetail = false
    @State private var showClearConfirmation = false

    // Matched Geometry Namespace for hero transitions
    @Namespace private var heroAnimation

    let onBack: () -> Void

    // Bento Grid Layout (2 Columns)
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            // Main Content
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

                            // BENTO GRID with Matched Geometry
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(Array(historyManager.items.enumerated()), id: \.element.id) { index, item in
                                    BentoHistoryCard(
                                        item: item,
                                        namespace: heroAnimation,
                                        isSource: selectedItem?.id != item.id
                                    ) {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            selectedItem = item
                                            showDetail = true
                                        }
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
            .opacity(showDetail ? 0.3 : 1)

            // Hero Detail Overlay
            if showDetail, let item = selectedItem {
                HeroDetailView(
                    item: item,
                    namespace: heroAnimation,
                    onDismiss: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showDetail = false
                        }
                        // Clear selection after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            selectedItem = nil
                        }
                    }
                )
                .transition(.opacity)
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

// MARK: - Bento History Card with Matched Geometry
struct BentoHistoryCard: View {
    let item: HistoryItem
    var namespace: Namespace.ID? = nil
    var isSource: Bool = true
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            cardContent
                .padding(Spacing.md)
                .frame(height: 180)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .matchedGeometryEffectIfAvailable(
                            id: "card-bg-\(item.id)",
                            in: namespace,
                            isSource: isSource
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(
                    color: colorScheme == .dark ? .clear : Color.black.opacity(0.05),
                    radius: 10, x: 0, y: 5
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) { isPressed = false }
                }
        )
    }

    private var cardContent: some View {
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
                    .matchedGeometryEffectIfAvailable(
                        id: "icon-\(item.id)",
                        in: namespace,
                        isSource: isSource
                    )

                Spacer()

                // Savings Badge
                Text("-\(item.savingsPercent)%")
                    .font(.uiCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.appMint)
                    .clipShape(Capsule())
                    .matchedGeometryEffectIfAvailable(
                        id: "badge-\(item.id)",
                        in: namespace,
                        isSource: isSource
                    )
            }

            Spacer()

            // Bottom: File Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.uiBodyBold)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .matchedGeometryEffectIfAvailable(
                        id: "title-\(item.id)",
                        in: namespace,
                        isSource: isSource
                    )

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
    }
}

// MARK: - Matched Geometry Helper Extension
extension View {
    @ViewBuilder
    func matchedGeometryEffectIfAvailable(id: String, in namespace: Namespace.ID?, isSource: Bool) -> some View {
        if let namespace = namespace {
            self.matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            self
        }
    }
}

// MARK: - Hero Detail View (Expanded Card)
struct HeroDetailView: View {
    let item: HistoryItem
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Expanded Card
            VStack(spacing: 0) {
                // Card Content
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Header with close button
                    HStack {
                        // File Icon (matched)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 56, height: 56)
                            .background(Color.appAccent.opacity(0.1))
                            .clipShape(Circle())
                            .matchedGeometryEffect(id: "icon-\(item.id)", in: namespace, isSource: false)

                        Spacer()

                        // Close button
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Title (matched)
                    Text(item.fileName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .matchedGeometryEffect(id: "title-\(item.id)", in: namespace, isSource: false)

                    // Savings Badge (matched)
                    HStack {
                        Text("-\(item.savingsPercent)%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.appMint)
                            .clipShape(Capsule())
                            .matchedGeometryEffect(id: "badge-\(item.id)", in: namespace, isSource: false)

                        Text("tasarruf sağlandı")
                            .font(.appBody)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Details
                    VStack(spacing: Spacing.md) {
                        DetailRow(icon: "doc.fill", label: "Orijinal Boyut", value: item.originalSizeFormatted, valueColor: .secondary)
                        DetailRow(icon: "doc.badge.arrow.up", label: "Sıkıştırılmış", value: item.compressedSizeFormatted, valueColor: .appMint)
                        DetailRow(icon: "clock", label: "İşlem Zamanı", value: item.timeAgo, valueColor: .secondary)
                        DetailRow(icon: "slider.horizontal.3", label: "Kullanılan Ayar", value: presetName(item.presetUsed), valueColor: .appAccent)
                    }

                    Spacer()
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.systemBackground))
                        .matchedGeometryEffect(id: "card-bg-\(item.id)", in: namespace, isSource: false)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 20)
            }
            .padding(.horizontal, Spacing.lg)
        }
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

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.appBody)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.appBodyMedium)
                .foregroundStyle(valueColor)
        }
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

// NOTE: HistoryDetailSheet replaced by HeroDetailView with Matched Geometry Effect

#Preview {
    HistoryScreen(
        historyManager: HistoryManager.shared,
        onBack: {}
    )
}
