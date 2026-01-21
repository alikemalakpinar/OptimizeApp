//
//  Motion.swift
//  optimize
//
//  Motion Design System - Transitions, Microinteractions, matchedGeometry helpers
//
//  DESIGN PRINCIPLES:
//  - Purposeful: Every animation serves a function
//  - Consistent: Same actions have same animations
//  - Responsive: Respects reduceMotion accessibility setting
//  - Performant: Uses efficient animation curves
//

import SwiftUI

// MARK: - Transition Namespace

/// Namespace for matchedGeometryEffect transitions
/// Usage: Add @Namespace private var namespace to your view
/// Then use .matchedGeometryEffect(id: TransitionID.fileCard, in: namespace)
enum TransitionID: String {
    case fileCard = "fileCard"
    case fileIcon = "fileIcon"
    case progressRing = "progressRing"
    case resultCard = "resultCard"
    case savingsValue = "savingsValue"
    case heroTitle = "heroTitle"
    case ctaButton = "ctaButton"
}

// MARK: - Microinteraction Modifiers

/// Bounce effect on tap - creates satisfying feedback
struct BounceOnTapModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Wobble effect for attention - use sparingly
struct WobbleModifier: ViewModifier {
    @State private var isWobbling = false
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWobbling ? 2 : -2))
            .animation(
                .easeInOut(duration: 0.1)
                    .repeatCount(3, autoreverses: true),
                value: isWobbling
            )
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    isWobbling = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isWobbling = false
                    }
                }
            }
    }
}

/// Success checkmark animation
struct SuccessCheckmarkModifier: ViewModifier {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.appMint)
                    .scaleEffect(scale)
                    .opacity(opacity)
            )
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        scale = 1.2
                        opacity = 1
                    }
                    withAnimation(.easeOut(duration: 0.2).delay(0.5)) {
                        scale = 1.0
                    }
                    withAnimation(.easeOut(duration: 0.3).delay(1.0)) {
                        opacity = 0
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds bounce feedback on tap
    func bounceOnTap() -> some View {
        modifier(BounceOnTapModifier())
    }

    /// Adds wobble animation when triggered
    func wobble(trigger: Bool) -> some View {
        modifier(WobbleModifier(trigger: trigger))
    }

    /// Shows success checkmark animation when triggered
    func successCheckmark(trigger: Bool) -> some View {
        modifier(SuccessCheckmarkModifier(trigger: trigger))
    }

    /// Slide in from bottom with fade
    func slideInFromBottom(delay: Double = 0) -> some View {
        self.modifier(SlideInModifier(edge: .bottom, delay: delay))
    }

    /// Slide in from specified edge with fade
    func slideIn(from edge: Edge, delay: Double = 0) -> some View {
        self.modifier(SlideInModifier(edge: edge, delay: delay))
    }

    /// Scale and fade in animation
    func scaleIn(delay: Double = 0) -> some View {
        self.modifier(ScaleInModifier(delay: delay))
    }

    /// Counter animation for numeric values
    func animatedCounter(value: Double, duration: Double = 0.5) -> some View {
        self.modifier(AnimatedCounterModifier(value: value, duration: duration))
    }
}

// MARK: - Slide In Modifier

struct SlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var isVisible = false

    private var offset: CGSize {
        switch edge {
        case .top: return CGSize(width: 0, height: -30)
        case .bottom: return CGSize(width: 0, height: 30)
        case .leading: return CGSize(width: -30, height: 0)
        case .trailing: return CGSize(width: 30, height: 0)
        }
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(isVisible ? .zero : offset)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Scale In Modifier

struct ScaleInModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Animated Counter Modifier

struct AnimatedCounterModifier: ViewModifier {
    let value: Double
    let duration: Double

    @State private var displayValue: Double = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: duration)) {
                    displayValue = newValue
                }
            }
    }
}

// MARK: - Shared Transition Containers

/// Container that provides namespace for matched geometry transitions
/// Wrap screens that transition between each other in this container
struct TransitionContainer<Content: View>: View {
    @Namespace private var namespace
    let content: (Namespace.ID) -> Content

    init(@ViewBuilder content: @escaping (Namespace.ID) -> Content) {
        self.content = content
    }

    var body: some View {
        content(namespace)
    }
}

// MARK: - Progress Animation View

/// Animated progress indicator that can be shared across screens
struct AnimatedProgressView: View {
    let progress: Double
    let namespace: Namespace.ID
    var size: CGFloat = 100

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.appMint.opacity(0.2), lineWidth: size * 0.08)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [Color.appMint, Color.appTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: size * 0.08,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Percentage text
            Text("\(Int(animatedProgress * 100))%")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appMint)
                .contentTransition(.numericText(value: animatedProgress))
        }
        .matchedGeometryEffect(id: TransitionID.progressRing.rawValue, in: namespace)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Celebration Burst Effect

/// Burst of particles for celebration moments
struct CelebrationBurstView: View {
    let trigger: Bool
    var particleCount: Int = 12
    var colors: [Color] = [.appMint, .appTeal, .premiumPurple, .warmOrange]

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var offset: CGSize = .zero
        var scale: CGFloat = 1
        var opacity: Double = 1
        var rotation: Double = 0
        let color: Color
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .offset(particle.offset)
                    .rotationEffect(.degrees(particle.rotation))
            }
        }
        .onChange(of: trigger) { _, newValue in
            if newValue {
                burst()
            }
        }
    }

    private func burst() {
        particles = (0..<particleCount).map { index in
            let angle = (Double(index) / Double(particleCount)) * 2 * .pi
            return Particle(color: colors[index % colors.count])
        }

        for (index, _) in particles.enumerated() {
            let angle = (Double(index) / Double(particleCount)) * 2 * .pi
            let distance: CGFloat = 60 + CGFloat.random(in: 0...40)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                particles[index].offset = CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                )
                particles[index].rotation = Double.random(in: 0...360)
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                particles[index].opacity = 0
                particles[index].scale = 0.3
            }
        }

        // Clear particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            particles = []
        }
    }
}

// MARK: - Preview

#Preview("Motion Effects") {
    VStack(spacing: 40) {
        // Slide in demo
        VStack(spacing: 10) {
            Text("Slide In Effects")
                .font(.headline)

            HStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appMint)
                    .frame(width: 60, height: 60)
                    .slideIn(from: .leading, delay: 0)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.premiumPurple)
                    .frame(width: 60, height: 60)
                    .slideInFromBottom(delay: 0.1)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.warmOrange)
                    .frame(width: 60, height: 60)
                    .scaleIn(delay: 0.2)
            }
        }

        // Bounce demo
        VStack(spacing: 10) {
            Text("Bounce on Tap")
                .font(.headline)

            Button("Tap Me") {
                Haptics.impact()
            }
            .padding()
            .background(Color.appMint)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .bounceOnTap()
        }
    }
    .padding()
}
