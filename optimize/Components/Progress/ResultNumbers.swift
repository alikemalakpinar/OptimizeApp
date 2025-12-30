//
//  ResultNumbers.swift
//  optimize
//
//  Animated result display showing before/after sizes
//

import SwiftUI

struct ResultNumbers: View {
    let fromSizeMB: Double
    let toSizeMB: Double
    let percentSaved: Int

    @State private var animatedFromSize: Double = 0
    @State private var animatedToSize: Double = 0
    @State private var animatedPercent: Int = 0
    @State private var showResult = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Size comparison
            HStack(spacing: Spacing.md) {
                // Original size
                VStack(spacing: Spacing.xxs) {
                    Text(formatSize(animatedFromSize))
                        .font(.appNumber)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())

                    Text("Orijinal")
                        .font(.appCaption)
                        .foregroundStyle(.tertiary)
                }

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(showResult ? 1 : 0)
                    .scaleEffect(showResult ? 1 : 0.5)

                // Optimized size
                VStack(spacing: Spacing.xxs) {
                    Text(formatSize(animatedToSize))
                        .font(.appNumber)
                        .foregroundStyle(Color.statusSuccess)
                        .contentTransition(.numericText())

                    Text("Optimize")
                        .font(.appCaption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Savings badge
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))

                Text("%\(animatedPercent) tasarruf")
                    .font(.appBodyMedium)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Color.statusSuccess)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.statusSuccess.opacity(0.1))
            .clipShape(Capsule())
            .opacity(showResult ? 1 : 0)
            .scaleEffect(showResult ? 1 : 0.8)
        }
        .onAppear {
            animateResults()
        }
    }

    private func animateResults() {
        // Animate from size
        withAnimation(.easeOut(duration: 0.8)) {
            animatedFromSize = fromSizeMB
        }

        // Show arrow and start to size animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(AppAnimation.spring) {
                showResult = true
            }

            withAnimation(.easeOut(duration: 0.8)) {
                animatedToSize = toSizeMB
            }
        }

        // Animate percentage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            animateCounter(to: percentSaved)
        }
    }

    private func animateCounter(to value: Int) {
        let duration: Double = 0.8
        let steps = 30
        let stepDuration = duration / Double(steps)
        let increment = Double(value) / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                withAnimation(.linear(duration: stepDuration)) {
                    animatedPercent = min(Int(increment * Double(step)), value)
                }
            }
        }
    }

    private func formatSize(_ sizeMB: Double) -> String {
        if sizeMB >= 1000 {
            return String(format: "%.1f GB", sizeMB / 1000)
        } else {
            return String(format: "%.0f MB", sizeMB)
        }
    }
}

// MARK: - Success Header
struct SuccessHeader: View {
    let title: String

    @State private var showCheck = false
    @State private var checkScale: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.statusSuccess.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(showCheck ? 1 : 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.statusSuccess)
                    .scaleEffect(checkScale)
            }

            Text(title)
                .font(.appTitle)
                .foregroundStyle(.primary)
                .opacity(showCheck ? 1 : 0)
        }
        .onAppear {
            withAnimation(AppAnimation.bouncy.delay(0.1)) {
                showCheck = true
            }

            withAnimation(AppAnimation.bouncy.delay(0.2)) {
                checkScale = 1
            }

            Haptics.success()
        }
    }
}

// MARK: - Output File Info
struct OutputFileInfo: View {
    let fileName: String
    var onTap: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.appAccent)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Sıkıştırılan dosya")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)

                    Text(fileName)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .onTapGesture {
            if let onTap = onTap {
                Haptics.selection()
                onTap()
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        SuccessHeader(title: "Hazır!")

        ResultNumbers(
            fromSizeMB: 300,
            toSizeMB: 92,
            percentSaved: 69
        )

        OutputFileInfo(fileName: "Rapor_2024_optimized.pdf")
    }
    .padding()
}
