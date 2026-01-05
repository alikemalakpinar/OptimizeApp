//
//  StorageHealthCard.swift
//  optimize
//
//  Storage Health visualization - shows device storage status
//  and potential savings to motivate user action
//
//  MASTER LEVEL UX:
//  - Psychological trigger: "Your phone is X% full"
//  - Potential gain visualization: "Save Y GB with OptimizeApp"
//  - Breathing animation for urgency
//  - Color transitions from danger (red) to safe (green)
//

import SwiftUI

// MARK: - Storage Health Card

struct StorageHealthCard: View {
    @StateObject private var storageManager = StorageHealthManager.shared

    @State private var animateRing = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var showDetails = false

    var body: some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showDetails.toggle()
            }
        }) {
            VStack(spacing: Spacing.md) {
                // Main content
                HStack(spacing: Spacing.lg) {
                    // Circular progress ring
                    storageRing
                        .frame(width: 70, height: 70)

                    // Text content
                    VStack(alignment: .leading, spacing: 4) {
                        // Title
                        Text(storageManager.statusTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        // Subtitle
                        Text(storageManager.statusSubtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        // Potential savings (if available)
                        if storageManager.potentialSavingsMB > 100 {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                Text("~\(storageManager.formattedPotentialSavings) kazanılabilir")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color.appMint)
                            .padding(.top, 2)
                        }
                    }

                    Spacer()

                    // Chevron indicator
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                // Expandable details
                if showDetails {
                    StorageDetailsView(storageManager: storageManager)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .strokeBorder(
                                storageManager.usagePercentage > 0.9
                                    ? Color.red.opacity(0.3)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            storageManager.refresh()
            startAnimations()
        }
    }

    // MARK: - Storage Ring

    private var storageRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: animateRing ? storageManager.usagePercentage : 0)
                .stroke(
                    AngularGradient(
                        colors: storageManager.ringColors,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: animateRing)

            // Center content
            VStack(spacing: 0) {
                Text("\(Int(storageManager.usagePercentage * 100))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(storageManager.statusColor)
                Text("%")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .scaleEffect(breathingScale)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Ring fill animation
        withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
            animateRing = true
        }

        // Breathing animation for critical storage
        if storageManager.usagePercentage > 0.85 {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                breathingScale = 1.05
            }
        }
    }
}

// MARK: - Storage Details View

private struct StorageDetailsView: View {
    @ObservedObject var storageManager: StorageHealthManager

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Divider()
                .padding(.vertical, Spacing.xs)

            // Storage breakdown bars
            VStack(spacing: Spacing.sm) {
                StorageBarRow(
                    label: "Kullanılan",
                    value: storageManager.formattedUsedSpace,
                    ratio: storageManager.usagePercentage,
                    color: storageManager.statusColor
                )

                StorageBarRow(
                    label: "Kullanılabilir",
                    value: storageManager.formattedFreeSpace,
                    ratio: 1 - storageManager.usagePercentage,
                    color: .appMint
                )
            }

            // Action hint
            if storageManager.potentialSavingsMB > 100 {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Dosyalarınızı sıkıştırarak yer açın")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Storage Bar Row

private struct StorageBarRow: View {
    let label: String
    let value: String
    let ratio: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(max(0, min(ratio, 1))))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Storage Health Manager

@MainActor
final class StorageHealthManager: ObservableObject {
    static let shared = StorageHealthManager()

    @Published private(set) var totalSpace: Int64 = 0
    @Published private(set) var freeSpace: Int64 = 0
    @Published private(set) var usedSpace: Int64 = 0
    @Published private(set) var potentialSavingsMB: Double = 0

    private init() {
        refresh()
    }

    // MARK: - Computed Properties

    var usagePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }

    var statusColor: Color {
        switch usagePercentage {
        case 0..<0.7: return .appMint
        case 0.7..<0.85: return .warmOrange
        case 0.85..<0.95: return .orange
        default: return .red
        }
    }

    var ringColors: [Color] {
        switch usagePercentage {
        case 0..<0.7: return [.appMint, .appTeal]
        case 0.7..<0.85: return [.yellow, .orange]
        case 0.85..<0.95: return [.orange, .red]
        default: return [.red, .pink]
        }
    }

    var statusTitle: String {
        switch usagePercentage {
        case 0..<0.7: return "Depolama Durumu: İyi"
        case 0.7..<0.85: return "Depolama Dolmaya Başladı"
        case 0.85..<0.95: return "Depolama Neredeyse Dolu"
        default: return "Depolama Kritik Seviyede!"
        }
    }

    var statusSubtitle: String {
        let freeGB = Double(freeSpace) / 1_073_741_824
        if freeGB < 1 {
            let freeMB = Double(freeSpace) / 1_048_576
            return String(format: "%.0f MB boş alan kaldı", freeMB)
        }
        return String(format: "%.1f GB boş alan mevcut", freeGB)
    }

    var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }

    var formattedUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }

    var formattedFreeSpace: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }

    var formattedPotentialSavings: String {
        if potentialSavingsMB >= 1000 {
            return String(format: "%.1f GB", potentialSavingsMB / 1000)
        }
        return String(format: "%.0f MB", potentialSavingsMB)
    }

    // MARK: - Refresh

    func refresh() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            totalSpace = (attrs[.systemSize] as? Int64) ?? 0
            freeSpace = (attrs[.systemFreeSize] as? Int64) ?? 0
            usedSpace = totalSpace - freeSpace
        }

        // Estimate potential savings (based on history or typical compression ratios)
        estimatePotentialSavings()
    }

    private func estimatePotentialSavings() {
        // Get total savings from history
        let historySavings = HistoryManager.shared.totalBytesSaved

        // If user has history, use actual data
        if historySavings > 0 {
            // Estimate there might be 3x more files to compress
            potentialSavingsMB = Double(historySavings) * 3 / 1_048_576
        } else {
            // Default estimate: 5% of used space could be saved
            potentialSavingsMB = Double(usedSpace) * 0.05 / 1_048_576
        }

        // Cap at reasonable amount
        potentialSavingsMB = min(potentialSavingsMB, 10_000) // Max 10GB
    }
}

// MARK: - Compact Storage Indicator

/// Smaller version for navigation bar or inline use
struct CompactStorageIndicator: View {
    @StateObject private var storageManager = StorageHealthManager.shared

    var body: some View {
        HStack(spacing: 6) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 20, height: 20)

                Circle()
                    .trim(from: 0, to: storageManager.usagePercentage)
                    .stroke(storageManager.statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
            }

            Text("\(Int(storageManager.usagePercentage * 100))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(storageManager.statusColor)
        }
    }
}

// MARK: - Preview

#Preview("Normal Storage") {
    VStack {
        StorageHealthCard()
            .padding()
        Spacer()
    }
    .background(Color(.systemBackground))
}

#Preview("Compact") {
    CompactStorageIndicator()
        .padding()
}
