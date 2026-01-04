//
//  AchievementManager.swift
//  optimize
//
//  Gamification system with achievements, badges, and user levels
//  Increases retention by giving users goals and rewards
//
//  MASTER LEVEL RETENTION:
//  - Achievement badges for milestones
//  - User level progression
//  - Share achievements to social media
//  - Celebration animations on unlock
//

import Foundation
import SwiftUI
import Combine

// MARK: - Achievement Types

enum Achievement: String, CaseIterable, Codable {
    // Compression milestones
    case firstCompression = "first_compression"
    case compressions10 = "compressions_10"
    case compressions50 = "compressions_50"
    case compressions100 = "compressions_100"
    case compressions500 = "compressions_500"

    // Savings milestones
    case saved100MB = "saved_100mb"
    case saved500MB = "saved_500mb"
    case saved1GB = "saved_1gb"
    case saved5GB = "saved_5gb"
    case saved10GB = "saved_10gb"

    // Special achievements
    case batchMaster = "batch_master"         // Compress 10+ files at once
    case nightOwl = "night_owl"               // Compress after midnight
    case earlyBird = "early_bird"             // Compress before 6 AM
    case speedDemon = "speed_demon"           // Compress 5 files in 1 minute
    case perfectionist = "perfectionist"      // Achieve 70%+ compression ratio
    case explorer = "explorer"                // Try all compression presets
    case converter = "converter"              // Convert 10 files

    // MARK: - Properties

    var title: String {
        switch self {
        case .firstCompression: return "İlk Adım"
        case .compressions10: return "Başlangıç"
        case .compressions50: return "Düzenli Kullanıcı"
        case .compressions100: return "Deneyimli"
        case .compressions500: return "Profesyonel"
        case .saved100MB: return "Tasarrufçu"
        case .saved500MB: return "Akıllı Kullanıcı"
        case .saved1GB: return "Veri Mimarı"
        case .saved5GB: return "Space Saver"
        case .saved10GB: return "Space Master"
        case .batchMaster: return "Toplu İşlem Ustası"
        case .nightOwl: return "Gece Kuşu"
        case .earlyBird: return "Erken Kalkan"
        case .speedDemon: return "Hız Şeytanı"
        case .perfectionist: return "Mükemmeliyetçi"
        case .explorer: return "Kaşif"
        case .converter: return "Dönüştürücü"
        }
    }

    var description: String {
        switch self {
        case .firstCompression: return "İlk dosyanı sıkıştırdın!"
        case .compressions10: return "10 dosya sıkıştırdın"
        case .compressions50: return "50 dosya sıkıştırdın"
        case .compressions100: return "100 dosya sıkıştırdın"
        case .compressions500: return "500 dosya sıkıştırdın"
        case .saved100MB: return "100 MB yer kazandın"
        case .saved500MB: return "500 MB yer kazandın"
        case .saved1GB: return "1 GB yer kazandın"
        case .saved5GB: return "5 GB yer kazandın"
        case .saved10GB: return "10 GB yer kazandın"
        case .batchMaster: return "Tek seferde 10+ dosya işledin"
        case .nightOwl: return "Gece yarısından sonra sıkıştırma yaptın"
        case .earlyBird: return "Sabah 6'dan önce sıkıştırma yaptın"
        case .speedDemon: return "1 dakikada 5 dosya sıkıştırdın"
        case .perfectionist: return "%70+ sıkıştırma oranı elde ettin"
        case .explorer: return "Tüm preset'leri denedin"
        case .converter: return "10 dosya dönüştürdün"
        }
    }

    var icon: String {
        switch self {
        case .firstCompression: return "star.fill"
        case .compressions10: return "flame.fill"
        case .compressions50: return "bolt.fill"
        case .compressions100: return "crown.fill"
        case .compressions500: return "trophy.fill"
        case .saved100MB: return "leaf.fill"
        case .saved500MB: return "sparkles"
        case .saved1GB: return "diamond.fill"
        case .saved5GB: return "star.circle.fill"
        case .saved10GB: return "globe.americas.fill"
        case .batchMaster: return "square.stack.3d.up.fill"
        case .nightOwl: return "moon.stars.fill"
        case .earlyBird: return "sunrise.fill"
        case .speedDemon: return "hare.fill"
        case .perfectionist: return "target"
        case .explorer: return "map.fill"
        case .converter: return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .firstCompression: return .yellow
        case .compressions10: return .orange
        case .compressions50: return .red
        case .compressions100: return .purple
        case .compressions500: return .pink
        case .saved100MB: return .green
        case .saved500MB: return .mint
        case .saved1GB: return .cyan
        case .saved5GB: return .blue
        case .saved10GB: return .indigo
        case .batchMaster: return .purple
        case .nightOwl: return .indigo
        case .earlyBird: return .orange
        case .speedDemon: return .red
        case .perfectionist: return .pink
        case .explorer: return .brown
        case .converter: return .teal
        }
    }

    /// XP points awarded for this achievement
    var xpPoints: Int {
        switch self {
        case .firstCompression: return 10
        case .compressions10: return 25
        case .compressions50: return 50
        case .compressions100: return 100
        case .compressions500: return 250
        case .saved100MB: return 25
        case .saved500MB: return 50
        case .saved1GB: return 100
        case .saved5GB: return 200
        case .saved10GB: return 500
        case .batchMaster: return 75
        case .nightOwl: return 30
        case .earlyBird: return 30
        case .speedDemon: return 50
        case .perfectionist: return 75
        case .explorer: return 50
        case .converter: return 50
        }
    }

    /// Rarity tier
    var rarity: AchievementRarity {
        switch self {
        case .firstCompression, .saved100MB:
            return .common
        case .compressions10, .compressions50, .saved500MB, .nightOwl, .earlyBird:
            return .uncommon
        case .compressions100, .saved1GB, .batchMaster, .speedDemon, .explorer, .converter:
            return .rare
        case .compressions500, .saved5GB, .perfectionist:
            return .epic
        case .saved10GB:
            return .legendary
        }
    }
}

// MARK: - Achievement Rarity

enum AchievementRarity: String, Codable {
    case common = "Yaygın"
    case uncommon = "Nadir"
    case rare = "Çok Nadir"
    case epic = "Epik"
    case legendary = "Efsanevi"

    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    var gradient: [Color] {
        switch self {
        case .common: return [.gray, .gray.opacity(0.7)]
        case .uncommon: return [.green, .mint]
        case .rare: return [.blue, .cyan]
        case .epic: return [.purple, .pink]
        case .legendary: return [.orange, .yellow]
        }
    }
}

// MARK: - User Level

struct UserLevel {
    let level: Int
    let title: String
    let minXP: Int
    let maxXP: Int

    var progress: Double {
        guard maxXP > minXP else { return 1.0 }
        return Double(minXP) / Double(maxXP)
    }

    static let levels: [UserLevel] = [
        UserLevel(level: 1, title: "Çırak", minXP: 0, maxXP: 50),
        UserLevel(level: 2, title: "Acemi", minXP: 50, maxXP: 150),
        UserLevel(level: 3, title: "Deneyimli", minXP: 150, maxXP: 300),
        UserLevel(level: 4, title: "Uzman", minXP: 300, maxXP: 500),
        UserLevel(level: 5, title: "Usta", minXP: 500, maxXP: 750),
        UserLevel(level: 6, title: "Büyük Usta", minXP: 750, maxXP: 1000),
        UserLevel(level: 7, title: "Efsane", minXP: 1000, maxXP: 1500),
        UserLevel(level: 8, title: "Space Master", minXP: 1500, maxXP: .max)
    ]

    static func levelFor(xp: Int) -> UserLevel {
        for level in levels.reversed() {
            if xp >= level.minXP {
                return level
            }
        }
        return levels[0]
    }
}

// MARK: - Achievement Manager

@MainActor
final class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    // MARK: - Published State

    @Published private(set) var unlockedAchievements: Set<Achievement> = []
    @Published private(set) var totalXP: Int = 0
    @Published private(set) var currentLevel: UserLevel = UserLevel.levels[0]
    @Published private(set) var newlyUnlocked: Achievement?

    // MARK: - Statistics

    @Published private(set) var totalCompressions: Int = 0
    @Published private(set) var totalBytesSaved: Int64 = 0
    @Published private(set) var totalConversions: Int = 0
    @Published private(set) var usedPresets: Set<String> = []

    // MARK: - Storage Keys

    private let unlockedKey = "achievements.unlocked"
    private let xpKey = "achievements.xp"
    private let statsKey = "achievements.stats"

    // MARK: - Initialization

    private init() {
        loadProgress()
    }

    // MARK: - Progress Tracking

    /// Record a compression and check for new achievements
    func recordCompression(
        bytesSaved: Int64,
        compressionRatio: Double,
        presetId: String,
        batchSize: Int = 1
    ) {
        totalCompressions += 1
        totalBytesSaved += bytesSaved
        usedPresets.insert(presetId)

        // Check compression count achievements
        checkCompressionAchievements()

        // Check savings achievements
        checkSavingsAchievements()

        // Check special achievements
        checkSpecialAchievements(
            compressionRatio: compressionRatio,
            batchSize: batchSize
        )

        saveProgress()
    }

    /// Record a file conversion
    func recordConversion() {
        totalConversions += 1

        if totalConversions >= 10 {
            unlock(.converter)
        }

        saveProgress()
    }

    // MARK: - Achievement Checks

    private func checkCompressionAchievements() {
        if totalCompressions >= 1 { unlock(.firstCompression) }
        if totalCompressions >= 10 { unlock(.compressions10) }
        if totalCompressions >= 50 { unlock(.compressions50) }
        if totalCompressions >= 100 { unlock(.compressions100) }
        if totalCompressions >= 500 { unlock(.compressions500) }
    }

    private func checkSavingsAchievements() {
        let savedMB = totalBytesSaved / 1_048_576
        let savedGB = savedMB / 1024

        if savedMB >= 100 { unlock(.saved100MB) }
        if savedMB >= 500 { unlock(.saved500MB) }
        if savedGB >= 1 { unlock(.saved1GB) }
        if savedGB >= 5 { unlock(.saved5GB) }
        if savedGB >= 10 { unlock(.saved10GB) }
    }

    private func checkSpecialAchievements(compressionRatio: Double, batchSize: Int) {
        // Batch Master
        if batchSize >= 10 {
            unlock(.batchMaster)
        }

        // Perfectionist
        if compressionRatio >= 0.7 {
            unlock(.perfectionist)
        }

        // Explorer (all presets used)
        if usedPresets.count >= 4 {
            unlock(.explorer)
        }

        // Time-based achievements
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 6 {
            if hour >= 0 && hour < 3 {
                unlock(.nightOwl)
            } else {
                unlock(.earlyBird)
            }
        }
    }

    // MARK: - Unlock Achievement

    private func unlock(_ achievement: Achievement) {
        guard !unlockedAchievements.contains(achievement) else { return }

        unlockedAchievements.insert(achievement)
        totalXP += achievement.xpPoints
        currentLevel = UserLevel.levelFor(xp: totalXP)
        newlyUnlocked = achievement

        // Trigger celebration
        Haptics.success()

        // Clear newly unlocked after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.newlyUnlocked == achievement {
                self?.newlyUnlocked = nil
            }
        }

        saveProgress()
    }

    // MARK: - Persistence

    private func loadProgress() {
        let defaults = UserDefaults.standard

        // Load unlocked achievements
        if let data = defaults.data(forKey: unlockedKey),
           let unlocked = try? JSONDecoder().decode(Set<Achievement>.self, from: data) {
            unlockedAchievements = unlocked
        }

        // Load XP
        totalXP = defaults.integer(forKey: xpKey)
        currentLevel = UserLevel.levelFor(xp: totalXP)

        // Load stats
        if let data = defaults.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode(AchievementStats.self, from: data) {
            totalCompressions = stats.compressions
            totalBytesSaved = stats.bytesSaved
            totalConversions = stats.conversions
            usedPresets = stats.presets
        }
    }

    private func saveProgress() {
        let defaults = UserDefaults.standard

        // Save unlocked achievements
        if let data = try? JSONEncoder().encode(unlockedAchievements) {
            defaults.set(data, forKey: unlockedKey)
        }

        // Save XP
        defaults.set(totalXP, forKey: xpKey)

        // Save stats
        let stats = AchievementStats(
            compressions: totalCompressions,
            bytesSaved: totalBytesSaved,
            conversions: totalConversions,
            presets: usedPresets
        )
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: statsKey)
        }
    }

    // MARK: - Public API

    /// Check if achievement is unlocked
    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAchievements.contains(achievement)
    }

    /// Get all achievements with unlock status
    var allAchievements: [(achievement: Achievement, isUnlocked: Bool)] {
        Achievement.allCases.map { ($0, isUnlocked($0)) }
    }

    /// Progress to next level (0.0 - 1.0)
    var levelProgress: Double {
        let level = currentLevel
        let nextLevel = UserLevel.levels.first { $0.minXP > level.minXP }
        guard let next = nextLevel else { return 1.0 }

        let progress = Double(totalXP - level.minXP) / Double(next.minXP - level.minXP)
        return max(0, min(progress, 1))
    }

    /// XP needed for next level
    var xpToNextLevel: Int {
        let nextLevel = UserLevel.levels.first { $0.minXP > currentLevel.minXP }
        return (nextLevel?.minXP ?? currentLevel.minXP) - totalXP
    }
}

// MARK: - Stats Model

private struct AchievementStats: Codable {
    let compressions: Int
    let bytesSaved: Int64
    let conversions: Int
    let presets: Set<String>
}
