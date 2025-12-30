//
//  SplashScreen.swift
//  optimize
//
//  Splash screen with animated logo and dynamic status messages
//

import SwiftUI

struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.92
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var statusIndex = 0
    @State private var isAnimationComplete = false

    let onComplete: () -> Void

    // Technical status messages for "engineering marvel" feel
    private let statusMessages = [
        "Initializing Neural Engine...",
        "Image Processing Cores Active...",
        "Loading Compression Algorithms...",
        "Ready."
    ]

    var body: some View {
        ZStack {
            // Background
            AppBackground(animated: false)

            // Content
            VStack(spacing: Spacing.md) {
                Spacer()

                // Logo with breathing effect
                ZStack {
                    // Outer glow rings (breathing effect)
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.appAccent.opacity(0.05 - Double(index) * 0.015))
                            .frame(width: 120 + CGFloat(index) * 30, height: 120 + CGFloat(index) * 30)
                            .blur(radius: CGFloat(index) * 8 + 10)
                    }

                    // App Icon
                    Image("AppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                Text(".optimize")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .opacity(logoOpacity)

                Spacer()

                // Dynamic status message
                VStack(spacing: Spacing.xs) {
                    // Status indicator
                    HStack(spacing: Spacing.xs) {
                        if statusIndex < statusMessages.count - 1 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.appMint)
                                .font(.system(size: 16))
                        }

                        Text(statusMessages[min(statusIndex, statusMessages.count - 1)])
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .opacity(textOpacity)
                    .animation(.easeInOut(duration: 0.3), value: statusIndex)
                }
                .frame(height: 40)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Phase 1: Logo appears
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale = 1.0
        }

        // Phase 2: Status text appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.3)) {
                textOpacity = 1
            }
        }

        // Phase 3: Cycle through status messages
        let messageInterval: Double = 0.5
        for (index, _) in statusMessages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(index) * messageInterval) {
                withAnimation {
                    statusIndex = index
                }

                // Play subtle haptic on status change
                if index < statusMessages.count - 1 {
                    Haptics.selection()
                } else {
                    Haptics.success()
                    isAnimationComplete = true
                }
            }
        }

        // Complete after all animations
        let totalDuration = 0.6 + Double(statusMessages.count) * messageInterval + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            onComplete()
        }
    }
}

#Preview {
    SplashScreen {
        print("Splash complete")
    }
}
