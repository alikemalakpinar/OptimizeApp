//
//  StatisticsScreen.swift
//  optimize
//
//  Compression statistics and achievements dashboard
//  Features: Usage graphs, achievements, and analytics
//

import SwiftUI

struct StatisticsScreen: View {
    @StateObject private var statsService = CompressionStatisticsService.shared
    @State private var selectedTimeRange: TimeRange = .week

    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Header
            NavigationHeader("", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title
                    Text("İstatistikler")
                        .font(.displayTitle)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, Spacing.md)

                    // Main Stats Cards
                    MainStatsGrid(stats: statsService.stats)
                        .padding(.horizontal, Spacing.md)

                    // Compression Trend Chart
                    TrendChartCard(
                        title: "Haftalık Tasarruf",
                        data: statsService.getCompressionTrend(days: 7)
                    )
                    .padding(.horizontal, Spacing.md)

                    // File Type Distribution
                    FileTypeDistributionCard(
                        slices: statsService.getFileTypeDistribution()
                    )
                    .padding(.horizontal, Spacing.md)

                    // Streak Card
                    StreakCard(
                        currentStreak: statsService.stats.currentStreak,
                        longestStreak: statsService.stats.longestStreak
                    )
                    .padding(.horizontal, Spacing.md)

                    // Achievements Section
                    AchievementsSection(achievements: statsService.getAchievements())
                        .padding(.horizontal, Spacing.md)

                    // Details Card
                    DetailsCard(stats: statsService.stats)
                        .padding(.horizontal, Spacing.md)
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Time Range

private enum TimeRange: String, CaseIterable {
    case week = "Hafta"
    case month = "Ay"
    case year = "Yıl"
}

// MARK: - Main Stats Grid

private struct MainStatsGrid: View {
    let stats: CompressionStats

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.md) {
            StatCard(
                title: "Toplam Tasarruf",
                value: stats.formattedTotalSaved,
                icon: "arrow.down.circle.fill",
                color: .appMint
            )

            StatCard(
                title: "Dosya Sayısı",
                value: "\(stats.totalFilesCompressed)",
                icon: "doc.on.doc.fill",
                color: .blue
            )

            StatCard(
                title: "Ortalama Oran",
                value: String(format: "%%%.0f", stats.averageCompressionRatio),
                icon: "percent",
                color: .purple
            )

            StatCard(
                title: "İşlenen Veri",
                value: stats.formattedTotalProcessed,
                icon: "externaldrive.fill",
                color: .orange
            )
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)

                    Spacer()
                }

                Text(value)
                    .font(.appTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Trend Chart Card

private struct TrendChartCard: View {
    let title: String
    let data: [TrendPoint]

    private var maxValue: Double {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                if data.isEmpty || maxValue == 0 {
                    // Empty State
                    Text("Henüz veri yok")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                } else {
                    // Bar Chart
                    HStack(alignment: .bottom, spacing: Spacing.xs) {
                        ForEach(data) { point in
                            VStack(spacing: Spacing.xxs) {
                                // Bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.appAccent.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: max(4, CGFloat(point.value / maxValue) * 100))

                                // Day Label
                                Text(point.formattedDate)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 120)
                }
            }
        }
    }
}

// MARK: - File Type Distribution Card

private struct FileTypeDistributionCard: View {
    let slices: [PieSlice]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Dosya Türleri")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                if slices.isEmpty {
                    Text("Henüz veri yok")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: Spacing.lg) {
                        // Simple Pie Representation
                        ZStack {
                            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                                Circle()
                                    .trim(from: startAngle(for: index), to: endAngle(for: index))
                                    .stroke(slice.color, lineWidth: 20)
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(width: 80, height: 80)

                        // Legend
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(slices) { slice in
                                HStack(spacing: Spacing.xs) {
                                    Circle()
                                        .fill(slice.color)
                                        .frame(width: 8, height: 8)

                                    Text(slice.label)
                                        .font(.appCaption)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Text(String(format: "%.0f%%", slice.value * 100))
                                        .font(.appCaptionMedium)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func startAngle(for index: Int) -> CGFloat {
        slices.prefix(index).reduce(0) { $0 + $1.value }
    }

    private func endAngle(for index: Int) -> CGFloat {
        slices.prefix(index + 1).reduce(0) { $0 + $1.value }
    }
}

// MARK: - Streak Card

private struct StreakCard: View {
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        GlassCard {
            HStack {
                // Current Streak
                VStack(spacing: Spacing.xs) {
                    Image(systemName: currentStreak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 32))
                        .foregroundStyle(currentStreak > 0 ? .orange : .secondary)

                    Text("\(currentStreak)")
                        .font(.appTitle)
                        .foregroundStyle(.primary)

                    Text("Günlük Seri")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 60)

                // Longest Streak
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.yellow)

                    Text("\(longestStreak)")
                        .font(.appTitle)
                        .foregroundStyle(.primary)

                    Text("En Uzun Seri")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Achievements Section

private struct AchievementsSection: View {
    let achievements: [StatisticsAchievement]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Başarımlar")
                .font(.appBodyMedium)
                .foregroundStyle(.primary)

            VStack(spacing: Spacing.sm) {
                ForEach(achievements) { achievement in
                    AchievementRow(achievement: achievement)
                }
            }
        }
    }
}

private struct AchievementRow: View {
    let achievement: StatisticsAchievement

    var body: some View {
        GlassCard {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? Color.appMint.opacity(0.2) : Color.appSurface)
                        .frame(width: 44, height: 44)

                    Image(systemName: achievement.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(achievement.isUnlocked ? Color.appMint : .secondary)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.title)
                        .font(.appBodyMedium)
                        .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)

                    Text(achievement.description)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)

                    if !achievement.isUnlocked {
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.appSurface)
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.appAccent)
                                    .frame(width: geo.size.width * achievement.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 4)
                    }
                }

                Spacer()

                if achievement.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appMint)
                }
            }
        }
    }
}

// MARK: - Details Card

private struct DetailsCard: View {
    let stats: CompressionStats

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Detaylar")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                VStack(spacing: Spacing.sm) {
                    StatDetailRow(
                        title: "En İyi Sıkıştırma",
                        value: stats.bestCompressionFile.isEmpty ? "-" : String(format: "%.0f%% (%@)", stats.bestCompressionRatio, stats.bestCompressionFile)
                    )

                    StatDetailRow(
                        title: "Ortalama İşlem Süresi",
                        value: String(format: "%.1f sn", stats.averageProcessingTime)
                    )

                    StatDetailRow(
                        title: "Toplam İşlem Süresi",
                        value: formatDuration(stats.totalCompressionTime)
                    )
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0f sn", seconds)
        } else if seconds < 3600 {
            return String(format: "%.0f dk", seconds / 60)
        } else {
            return String(format: "%.1f sa", seconds / 3600)
        }
    }
}

private struct StatDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.appCaptionMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

#Preview {
    StatisticsScreen {
        print("Back")
    }
}
