//
//  SavingsMeter.swift
//  optimize
//
//  Visual meter showing estimated savings (Low/Medium/High)
//

import SwiftUI

enum SavingsLevel: String, CaseIterable {
    case low = "Düşük"
    case medium = "Orta"
    case high = "Yüksek"

    var color: Color {
        switch self {
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }

    var fillPercent: Double {
        switch self {
        case .low: return 0.33
        case .medium: return 0.66
        case .high: return 1.0
        }
    }
}

struct SavingsMeter: View {
    let level: SavingsLevel
    let label: String
    @State private var animatedProgress: Double = 0

    init(level: SavingsLevel, label: String = "Tahmini kazanç") {
        self.level = level
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label)
                    .font(.appBody)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(level.rawValue)
                    .font(.appBodyMedium)
                    .foregroundStyle(level.color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appSurface)
                        .frame(height: 8)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level.color)
                        .frame(width: geometry.size.width * animatedProgress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(AppAnimation.slow.delay(0.2)) {
                animatedProgress = level.fillPercent
            }
        }
    }
}

// MARK: - Estimated Size Savings
struct EstimatedSavings: View {
    let originalSize: String
    let estimatedSize: String
    let savingsPercent: Int

    @State private var showEstimate = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Mevcut")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                    Text(originalSize)
                        .font(.appNumberSmall)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("Tahmini")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                    Text(estimatedSize)
                        .font(.appNumberSmall)
                        .foregroundStyle(Color.statusSuccess)
                        .opacity(showEstimate ? 1 : 0)
                        .offset(x: showEstimate ? 0 : 10)
                }
            }

            // Savings badge
            HStack {
                Spacer()
                Text("~%\(savingsPercent) tasarruf")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.statusSuccess)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.statusSuccess.opacity(0.1))
                    .clipShape(Capsule())
                    .opacity(showEstimate ? 1 : 0)
                    .scaleEffect(showEstimate ? 1 : 0.8)
                Spacer()
            }
        }
        .onAppear {
            withAnimation(AppAnimation.spring.delay(0.3)) {
                showEstimate = true
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        GlassCard {
            VStack(spacing: Spacing.md) {
                SavingsMeter(level: .low)
                SavingsMeter(level: .medium)
                SavingsMeter(level: .high)
            }
        }

        GlassCard {
            EstimatedSavings(
                originalSize: "300 MB",
                estimatedSize: "92 MB",
                savingsPercent: 69
            )
        }
    }
    .padding()
}
