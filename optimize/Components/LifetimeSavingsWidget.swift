//
//  LifetimeSavingsWidget.swift
//  optimize
//
//  Premium Dashboard Widget — Gamified Progress Tracker
//
//  DESIGN:
//  - Circular progress gauge (Apple Watch ring style) with gradient fill
//  - "Total Space Saved: 42 GB" hero typography
//  - Relatable metric: "Equivalent to 12,000 new photos"
//  - Liquid fill animation on first appearance
//  - Milestone celebrations with sound + haptics
//
//  PSYCHOLOGY:
//  - "You've saved 3.4 GB" → Sunk cost / investment feeling
//  - Animated counter → Satisfying dopamine hit
//  - Photo equivalent → Tangible value understanding
//  - Ring progress → Gamified "fill it up" motivation
//

import SwiftUI

// MARK: - Lifetime Savings Widget (Dashboard Style)

struct LifetimeSavingsWidget: View {
    let totalBytesSaved: Int64
    let totalFilesCompressed: Int
    let averageSavingsPercentage: Int

    @State private var animatedValue: Double = 0
    @State private var hasAnimated = false
    @State private var ringProgress: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    /// Ring progress based on milestone targets (10 GB = full ring)
    private var targetProgress: CGFloat {
        let gbSaved = Double(totalBytesSaved) / 1_000_000_000
        return min(CGFloat(gbSaved / 10.0), 1.0)  // 10 GB = 100%
    }

    /// How many photos this savings is equivalent to (~3 MB per photo)
    private var photoEquivalent: Int {
        max(1, Int(Double(totalBytesSaved) / 3_000_000))
    }

    /// Next milestone to reach
    private var nextMilestone: SavingsMilestone? {
        SavingsMilestone.allCases.first { totalBytesSaved < $0.threshold }
    }

    /// Progress toward next milestone (0.0 - 1.0)
    private var milestoneProgress: CGFloat {
        guard let next = nextMilestone else { return 1.0 }
        let prevThreshold = SavingsMilestone.allCases
            .last(where: { $0.threshold <= totalBytesSaved })?.threshold ?? 0
        let range = next.threshold - prevThreshold
        guard range > 0 else { return 0 }
        return CGFloat(totalBytesSaved - prevThreshold) / CGFloat(range)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(alignment: .top) {
                // Left: Text content
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Header
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.appMint)
                            .font(.system(size: 14))

                        Text("Toplam Tasarruf")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    // Hero number
                    Text(formatBytes(Int64(animatedValue)))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.appMint, .appTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .contentTransition(.numericText())

                    // Photo equivalent
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                        Text("\(photoEquivalent.formatted()) fotoğrafa eşdeğer")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.appMint.opacity(0.7))
                }

                Spacer()

                // Right: Circular gauge
                SavingsRingGauge(
                    progress: ringProgress,
                    percentage: averageSavingsPercentage,
                    size: 90
                )
            }

            // Stats row
            HStack(spacing: 0) {
                statItem(
                    value: "\(totalFilesCompressed)",
                    label: "dosya",
                    icon: "doc.fill"
                )

                Divider()
                    .frame(height: 28)

                statItem(
                    value: "~%\(averageSavingsPercentage)",
                    label: "ortalama",
                    icon: "percent"
                )

                Divider()
                    .frame(height: 28)

                // Milestone progress
                if let next = nextMilestone {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(formatBytes(next.threshold))
                                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.tertiarySystemFill))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.appMint)
                                    .frame(width: geo.size.width * milestoneProgress)
                            }
                        }
                        .frame(height: 4)
                        .frame(maxWidth: 60)

                        Text("hedef")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    statItem(
                        value: "MAX",
                        label: "seviye",
                        icon: "crown.fill"
                    )
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.appMint.opacity(0.3), Color.appMint.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.appMint.opacity(colorScheme == .dark ? 0.08 : 0.06), radius: 16, x: 0, y: 4)
        .onAppear {
            if !hasAnimated {
                // Animate counter
                withAnimation(.easeOut(duration: 1.5)) {
                    animatedValue = Double(totalBytesSaved)
                }
                // Animate ring
                withAnimation(.spring(duration: 1.2, bounce: 0.3).delay(0.3)) {
                    ringProgress = targetProgress
                }
                hasAnimated = true
            }
        }
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Savings Ring Gauge

private struct SavingsRingGauge: View {
    let progress: CGFloat
    let percentage: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: size * 0.1)

            // Fill arc with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .appMint.opacity(0.3),
                            .appMint,
                            .appTeal
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.appMint.opacity(0.4), radius: size * 0.06)

            // Center label
            VStack(spacing: 0) {
                Text("~%\(percentage)")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)

                Text("ort.")
                    .font(.system(size: size * 0.11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Compact Version (For smaller spaces)

struct CompactSavingsIndicator: View {
    let totalBytesSaved: Int64

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .foregroundColor(.appMint)
                .font(.system(size: 12))

            Text("\(formatBytes(totalBytesSaved)) tasarruf")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appMint.opacity(0.1))
        .cornerRadius(100)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Milestone Celebrations

struct MilestoneCelebration: View {
    let milestone: SavingsMilestone
    let onDismiss: () -> Void

    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                // Animated rings
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(milestone.color.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                            .frame(width: 100 + CGFloat(i) * 30, height: 100 + CGFloat(i) * 30)
                            .scaleEffect(showConfetti ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                                value: showConfetti
                            )
                    }

                    Text(milestone.emoji)
                        .font(.system(size: 60))
                }

                Text(milestone.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(milestone.message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button(action: onDismiss) {
                    Text("Harika!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(milestone.color)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(28)
            .padding(.horizontal, 24)
            .scaleEffect(scale)
            .opacity(opacity)

            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            showConfetti = true
            Haptics.dramaticSuccess()
            SoundManager.shared.playAchievementSound()
        }
    }
}

// MARK: - Savings Milestones

enum SavingsMilestone: CaseIterable {
    case first100MB
    case first500MB
    case first1GB
    case first5GB
    case first10GB

    var threshold: Int64 {
        switch self {
        case .first100MB: return 100_000_000
        case .first500MB: return 500_000_000
        case .first1GB: return 1_000_000_000
        case .first5GB: return 5_000_000_000
        case .first10GB: return 10_000_000_000
        }
    }

    var title: String {
        switch self {
        case .first100MB: return "İlk 100 MB!"
        case .first500MB: return "500 MB Başarıldı!"
        case .first1GB: return "1 GB Efsanesi!"
        case .first5GB: return "5 GB Ustası!"
        case .first10GB: return "10 GB Şampiyonu!"
        }
    }

    var message: String {
        switch self {
        case .first100MB: return "Harika bir başlangıç! Depolama alanın şimdiden nefes aldı."
        case .first500MB: return "Yarım Gigabyte! Bu ciddi bir başarı, böyle devam!"
        case .first1GB: return "1 Gigabyte kazandın! Sen gerçek bir optimizasyon uzmanısın."
        case .first5GB: return "5 GB tasarruf! Bu kadar veriyi kurtaran çok az kişi var."
        case .first10GB: return "Efsane! 10 GB tasarruf yaptın. Sen bir şampiyonsun!"
        }
    }

    var emoji: String {
        switch self {
        case .first100MB: return "🎉"
        case .first500MB: return "🚀"
        case .first1GB: return "⭐"
        case .first5GB: return "🏆"
        case .first10GB: return "👑"
        }
    }

    var color: Color {
        switch self {
        case .first100MB: return .blue
        case .first500MB: return .purple
        case .first1GB: return .orange
        case .first5GB: return .pink
        case .first10GB: return .yellow
        }
    }

    static func checkNewMilestone(previousTotal: Int64, newTotal: Int64) -> SavingsMilestone? {
        for milestone in allCases {
            if previousTotal < milestone.threshold && newTotal >= milestone.threshold {
                return milestone
            }
        }
        return nil
    }
}

// MARK: - Preview

#Preview("Lifetime Savings Widget") {
    VStack(spacing: 20) {
        LifetimeSavingsWidget(
            totalBytesSaved: 3_456_789_012,
            totalFilesCompressed: 127,
            averageSavingsPercentage: 58
        )
        .padding()

        CompactSavingsIndicator(totalBytesSaved: 1_234_567_890)
    }
}

#Preview("Milestone Celebration") {
    MilestoneCelebration(milestone: .first1GB) {
        print("Dismissed")
    }
}
