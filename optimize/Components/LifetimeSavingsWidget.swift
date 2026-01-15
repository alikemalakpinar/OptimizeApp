//
//  LifetimeSavingsWidget.swift
//  optimize
//
//  Gamification widget showing total lifetime savings.
//  Uses "Sunk Cost" psychology to increase retention.
//
//  PSYCHOLOGY:
//  - "You've saved 3.4 GB" → User feels investment
//  - Animated counter → Satisfying dopamine hit
//  - Milestone celebrations → Achievement motivation
//

import SwiftUI

// MARK: - Lifetime Savings Widget

struct LifetimeSavingsWidget: View {
    let totalBytesSaved: Int64
    let totalFilesCompressed: Int
    let averageSavingsPercentage: Int

    @State private var animatedValue: Double = 0
    @State private var hasAnimated = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.appMint)
                    .font(.system(size: 14))

                Text("Toplam Tasarruf")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                // Info button
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            // Main counter with animation
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatBytes(Int64(animatedValue)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.appMint)
                    .contentTransition(.numericText())

                Text("kazanıldı")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Stats row
            HStack(spacing: 24) {
                StatItem(
                    value: "\(totalFilesCompressed)",
                    label: "dosya",
                    icon: "doc.fill"
                )

                StatItem(
                    value: "~%\(averageSavingsPercentage)",
                    label: "ortalama",
                    icon: "percent"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.appMint.opacity(0.3), Color.appMint.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            if !hasAnimated {
                withAnimation(.easeOut(duration: 1.5)) {
                    animatedValue = Double(totalBytesSaved)
                }
                hasAnimated = true
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
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
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Celebration card
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    // Glow rings
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

                    // Main icon
                    Text(milestone.emoji)
                        .font(.system(size: 60))
                }

                // Title
                Text(milestone.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                // Message
                Text(milestone.message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Dismiss button
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

            // Confetti
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

    /// Check if a new milestone was reached
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
