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
            NavigationHeader("History", onBack: onBack) {
                if !historyManager.items.isEmpty {
                    Button(action: {
                        Haptics.warning()
                        showClearConfirmation = true
                    }) {
                        Text("Clear")
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

                    Text("No activity yet")
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)

                    Text("Your optimized files will appear here")
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
                                    Label("Delete", systemImage: "trash")
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
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                withAnimation {
                    historyManager.clearAll()
                }
            }
        } message: {
            Text("All history will be deleted. This action cannot be undone.")
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
                Text("Details")
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

                    KeyValueRow(key: "Original size", value: item.originalSizeFormatted)
                    KeyValueRow(key: "Compressed size", value: item.compressedSizeFormatted, valueColor: .statusSuccess)
                    KeyValueRow(key: "Savings", value: "\(item.savingsPercent)%", valueColor: .statusSuccess)
                    KeyValueRow(key: "Preset used", value: presetName(item.presetUsed))
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
        case "quality": return "Best Quality"
        case "custom": return "Custom"
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
