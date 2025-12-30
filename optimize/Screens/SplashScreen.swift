//
//  SplashScreen.swift
//  optimize
//
//  Splash screen with animated logo
//

import SwiftUI

struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.92
    @State private var logoOpacity: Double = 0
    @State private var isAnimationComplete = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            AppBackground()

            // Logo
            VStack(spacing: Spacing.md) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.appAccent.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    // Icon container
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "doc.zipper")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Text("Optimize")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            // Logo animation
            withAnimation(.easeOut(duration: 0.6)) {
                logoOpacity = 1
                logoScale = 1.0
            }

            // Complete after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashScreen {
        print("Splash complete")
    }
}
