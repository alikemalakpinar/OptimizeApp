//
//  AchievementBadge.swift
//  optimize
//
//  Achievement badge UI components for gamification
//  Beautiful 3D-style badges with unlock animations
//

import SwiftUI

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    var size: BadgeSize = .medium
    var showTitle: Bool = true

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: size.spacing) {
            // Badge circle
            ZStack {
                // Outer glow for unlocked
                if isUnlocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [achievement.color.opacity(0.3), .clear],
                                center: .center,
                                startRadius: size.dimension * 0.3,
                                endRadius: size.dimension * 0.7
                            )
                        )
                        .frame(width: size.dimension * 1.3, height: size.dimension * 1.3)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                }

                // Badge background
                Circle()
                    .fill(
                        isUnlocked
                            ? LinearGradient(
                                colors: achievement.rarity.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: size.dimension, height: size.dimension)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isUnlocked
                                    ? achievement.color.opacity(0.5)
                                    : Color.gray.opacity(0.2),
                                lineWidth: size.borderWidth
                            )
                    )
                    .shadow(
                        color: isUnlocked ? achievement.color.opacity(0.3) : .clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )

                // Icon
                Image(systemName: achievement.icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(
                        isUnlocked
                            ? .white
                            : Color.gray.opacity(0.4)
                    )

                // Lock overlay for locked badges
                if !isUnlocked {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: size.dimension, height: size.dimension)

                    Image(systemName: "lock.fill")
                        .font(.system(size: size.iconSize * 0.5))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Title
            if showTitle {
                Text(achievement.title)
                    .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            if isUnlocked {
                withAnimation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Badge Size

enum BadgeSize {
    case small, medium, large

    var dimension: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 60
        case .large: return 80
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 24
        case .large: return 32
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        }
    }

    var spacing: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .small: return 1.5
        case .medium: return 2
        case .large: return 3
        }
    }
}

// MARK: - Achievement Unlock Toast

struct AchievementUnlockToast: View {
    let achievement: Achievement
    @Binding var isPresented: Bool

    @State private var slideIn = false
    @State private var shine = false

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: Spacing.md) {
                // Badge
                AchievementBadge(achievement: achievement, isUnlocked: true, size: .medium, showTitle: false)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yeni Başarı!")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(achievement.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text("+\(achievement.xpPoints) XP")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Rarity badge
                Text(achievement.rarity.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: achievement.rarity.gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .strokeBorder(achievement.color.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: achievement.color.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, Spacing.lg)
            .offset(y: slideIn ? 0 : 150)
            .opacity(slideIn ? 1 : 0)
        }
        .onAppear {
            // Slide in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                slideIn = true
            }

            // Haptic
            Haptics.success()

            // Auto dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    slideIn = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - User Level Card

struct UserLevelCard: View {
    @ObservedObject var achievementManager: AchievementManager

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Level info
            HStack {
                // Level badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.premiumPurple, .premiumBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Text("\(achievementManager.currentLevel.level)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(achievementManager.currentLevel.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("\(achievementManager.totalXP) XP")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Next level info
                if achievementManager.xpToNextLevel > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Sonraki seviye")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)

                        Text("\(achievementManager.xpToNextLevel) XP")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.premiumPurple, .premiumBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * achievementManager.levelProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Achievements Grid

struct AchievementsGrid: View {
    @ObservedObject var achievementManager: AchievementManager

    let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: Spacing.md)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            Text("Başarılar")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Grid
            LazyVGrid(columns: columns, spacing: Spacing.lg) {
                ForEach(achievementManager.allAchievements, id: \.achievement) { item in
                    AchievementBadge(
                        achievement: item.achievement,
                        isUnlocked: item.isUnlocked,
                        size: .medium
                    )
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview("Badge - Unlocked") {
    AchievementBadge(achievement: .saved1GB, isUnlocked: true, size: .large)
        .padding()
}

#Preview("Badge - Locked") {
    AchievementBadge(achievement: .saved10GB, isUnlocked: false, size: .large)
        .padding()
}

#Preview("Toast") {
    ZStack {
        Color.black.opacity(0.3)
        AchievementUnlockToast(achievement: .saved1GB, isPresented: .constant(true))
    }
}

#Preview("Level Card") {
    UserLevelCard(achievementManager: .shared)
        .padding()
}

#Preview("Grid") {
    ScrollView {
        AchievementsGrid(achievementManager: .shared)
            .padding()
    }
}
