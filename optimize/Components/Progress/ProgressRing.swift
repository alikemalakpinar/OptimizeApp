//
//  ProgressRing.swift
//  optimize
//
//  Circular progress indicator with optional percentage
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    var lineWidth: CGFloat = 8
    var size: CGFloat = 80
    var showPercentage: Bool = true
    var accentColor: Color = .appAccent

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    accentColor.opacity(0.15),
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            // Percentage text
            if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.appNumberSmall)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(AppAnimation.slow) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(AppAnimation.standard) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Indeterminate Progress Ring
struct IndeterminateProgressRing: View {
    var lineWidth: CGFloat = 4
    var size: CGFloat = 60
    var accentColor: Color = .appAccent

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    accentColor.opacity(0.15),
                    lineWidth: lineWidth
                )

            // Animated arc
            Circle()
                .trim(from: 0.0, to: 0.3)
                .stroke(
                    accentColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(
                Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Processing Indicator
struct ProcessingIndicator: View {
    let message: String
    var submessage: String? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            IndeterminateProgressRing()

            VStack(spacing: Spacing.xxs) {
                Text(message)
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                if let submessage = submessage {
                    Text(submessage)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        HStack(spacing: Spacing.xl) {
            ProgressRing(progress: 0.25)
            ProgressRing(progress: 0.5)
            ProgressRing(progress: 0.75)
        }

        ProgressRing(progress: 0.69, size: 120, showPercentage: true)

        IndeterminateProgressRing()

        ProcessingIndicator(
            message: "Optimize ediliyor",
            submessage: "Bu işlem birkaç dakika sürebilir"
        )
    }
    .padding()
}
