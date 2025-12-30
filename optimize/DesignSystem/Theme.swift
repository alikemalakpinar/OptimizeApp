//
//  Theme.swift
//  optimize
//
//  Design System - Apple 2025 Design (Content-first + Glassy surfaces)
//

import SwiftUI

// MARK: - Color Tokens
extension Color {
    // Primary accent - Premium blue
    static let appAccent = Color("AccentColor")

    // Secondary accent - Mint/Electric Teal (Success & Completion)
    static let appMint = Color(red: 0.2, green: 0.78, blue: 0.65) // #33C7A6
    static let appTeal = Color(red: 0.0, green: 0.8, blue: 0.82) // #00CCD1

    // Gradient accent for success states
    static let successGradientStart = Color(red: 0.2, green: 0.78, blue: 0.65)
    static let successGradientEnd = Color(red: 0.0, green: 0.8, blue: 0.82)

    // Pro/Premium gradient colors
    static let proGradientStart = Color.purple
    static let proGradientEnd = Color.blue
    static let goldAccent = Color(red: 1.0, green: 0.84, blue: 0.0) // Gold for premium

    // Semantic colors (auto Dark Mode)
    static let appBackground = Color(.systemBackground)
    static let appSurface = Color(.secondarySystemBackground)
    static let appGroupedBackground = Color(.systemGroupedBackground)

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(.tertiaryLabel)

    // Status colors
    static let statusSuccess = Color(red: 0.2, green: 0.78, blue: 0.65) // Mint green
    static let statusWarning = Color.orange
    static let statusError = Color.red

    // Glass effect colors - System-aware for better visibility
    static let glassBackground = Color(.systemBackground).opacity(0.7)
    static let glassBorder = Color.primary.opacity(0.1) // Works in both light and dark mode
}

// MARK: - Spacing System
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radius System
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16  // Card radius
    static let xl: CGFloat = 20  // Large CTA radius
    static let full: CGFloat = 100
}

// MARK: - Opacity Scale
enum Opacity {
    static let disabled: Double = 0.4
    static let subtle: Double = 0.1
    static let light: Double = 0.2
    static let medium: Double = 0.5
    static let high: Double = 0.8
    static let full: Double = 1.0
}

// MARK: - Typography
extension Font {
    // Title styles
    static let appTitle = Font.title2.weight(.semibold)
    static let appLargeTitle = Font.largeTitle.weight(.bold)

    // Section header
    static let appSection = Font.headline

    // Body
    static let appBody = Font.body
    static let appBodyMedium = Font.body.weight(.medium)

    // Caption
    static let appCaption = Font.caption
    static let appCaptionMedium = Font.caption.weight(.medium)

    // Numbers - Rounded monospaced
    static let appNumber = Font.system(.largeTitle, design: .rounded).monospacedDigit()
    static let appNumberMedium = Font.system(.title, design: .rounded).monospacedDigit()
    static let appNumberSmall = Font.system(.title3, design: .rounded).monospacedDigit()
}

// MARK: - Animation Constants
enum AppAnimation {
    // Standard transitions
    static let standard = Animation.easeInOut(duration: 0.25)
    static let quick = Animation.easeInOut(duration: 0.15)
    static let slow = Animation.easeInOut(duration: 0.4)

    // Spring animations
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.75)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    // Pressed scale
    static let pressedScale: CGFloat = 0.98

    // Stagger delay for list items
    static let staggerDelay: Double = 0.05
}

// MARK: - Shadow System
enum AppShadow {
    static let light = Color.black.opacity(0.06)
    static let medium = Color.black.opacity(0.1)

    static func cardShadow() -> some View {
        EmptyView()
            .shadow(color: light, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Haptic Feedback
enum Haptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - View Modifiers
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppAnimation.pressedScale : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle {
        PressableButtonStyle()
    }
}

// MARK: - Glass Material Modifier
struct GlassMaterialModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.lg

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.glassBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func glassMaterial(cornerRadius: CGFloat = Radius.lg) -> some View {
        modifier(GlassMaterialModifier(cornerRadius: cornerRadius))
    }

    // Layered gradient background used across main screens
    func appBackgroundLayered() -> some View {
        background(AppBackground())
    }
}

// MARK: - Gradient Background (Animated)
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rotationAngle: Double = 0
    var animated: Bool = true

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.appAccent.opacity(0.28),
                Color.appBackground
            ]
        }

        return [
            Color.appAccent.opacity(0.16),
            Color.appBackground
        ]
    }

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Slowly rotating radial gradient overlay
            RadialGradient(
                colors: [
                    Color.appAccent.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    Color.appMint.opacity(colorScheme == .dark ? 0.06 : 0.04),
                    .clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .rotationEffect(.degrees(rotationAngle))
            .scaleEffect(1.2)

            // Secondary highlight
            RadialGradient(
                colors: [Color.white.opacity(colorScheme == .dark ? 0.04 : 0.08), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .onAppear {
            if animated {
                withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
        }
    }
}

// Static version for performance-sensitive screens
struct AppBackgroundStatic: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppBackground(animated: false)
    }
}

// MARK: - Stagger Animation Modifier
struct StaggeredAppearance: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(AppAnimation.standard.delay(Double(index) * AppAnimation.staggerDelay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }
}

// MARK: - Shimmer Effect Modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var isActive: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.4),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: -geometry.size.width * 0.3 + (geometry.size.width * 1.6) * phase)
                        .mask(content)
                    }
                }
            )
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
    }
}

extension View {
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Breathing Circle Animation
struct BreathingCircle: View {
    let color: Color
    var size: CGFloat = 80
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.3

    var body: some View {
        ZStack {
            // Outer breathing ring
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .frame(width: size * 1.3, height: size * 1.3)
                .scaleEffect(scale)
                .opacity(opacity)

            // Middle ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 1.5)
                .frame(width: size * 1.15, height: size * 1.15)
                .scaleEffect(1 + (scale - 1) * 0.5)

            // Inner solid circle
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                scale = 1.15
                opacity = 0.6
            }
        }
    }
}

// MARK: - Scan Line Animation
struct ScanLineView: View {
    let color: Color
    var height: CGFloat = 3
    @State private var position: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Glow effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, color.opacity(0.3), color, color.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: height + 6)
                    .blur(radius: 4)

                // Main scan line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, color, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: height)
            }
            .offset(y: position * (geometry.size.height - height))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    position = 1
                }
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var isAnimating = false

    private let colors: [Color] = [
        .appMint, .appTeal, .appAccent, .purple, .pink, .yellow, .orange
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece, isAnimating: isAnimating)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 3.0)) {
                        isAnimating = true
                    }
                }
            }
        }
    }

    private func generateConfetti(in size: CGSize) {
        confettiPieces = (0..<50).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                targetY: size.height + 50,
                rotation: Double.random(in: 0...360),
                targetRotation: Double.random(in: 720...1440),
                scale: CGFloat.random(in: 0.5...1.0),
                color: colors.randomElement() ?? .appMint,
                shape: ConfettiShape.allCases.randomElement() ?? .circle,
                delay: Double.random(in: 0...0.5),
                horizontalDrift: CGFloat.random(in: -50...50)
            )
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let targetY: CGFloat
    let rotation: Double
    let targetRotation: Double
    let scale: CGFloat
    let color: Color
    let shape: ConfettiShape
    let delay: Double
    let horizontalDrift: CGFloat
}

enum ConfettiShape: CaseIterable {
    case circle, rectangle, triangle
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let isAnimating: Bool

    var body: some View {
        Group {
            switch piece.shape {
            case .circle:
                Circle()
                    .fill(piece.color)
                    .frame(width: 8 * piece.scale, height: 8 * piece.scale)
            case .rectangle:
                Rectangle()
                    .fill(piece.color)
                    .frame(width: 10 * piece.scale, height: 6 * piece.scale)
            case .triangle:
                Triangle()
                    .fill(piece.color)
                    .frame(width: 10 * piece.scale, height: 10 * piece.scale)
            }
        }
        .position(
            x: piece.x + (isAnimating ? piece.horizontalDrift : 0),
            y: isAnimating ? piece.targetY : piece.y
        )
        .rotationEffect(.degrees(isAnimating ? piece.targetRotation : piece.rotation))
        .opacity(isAnimating ? 0 : 1)
        .animation(
            .easeOut(duration: 3.0).delay(piece.delay),
            value: isAnimating
        )
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Glow Effect Modifier
struct GlowModifier: ViewModifier {
    let color: Color
    var radius: CGFloat = 10
    var isAnimated: Bool = true
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isGlowing ? 0.8 : 0.4), radius: radius)
            .shadow(color: color.opacity(isGlowing ? 0.4 : 0.2), radius: radius * 2)
            .onAppear {
                if isAnimated {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isGlowing = true
                    }
                }
            }
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 10, animated: Bool = true) -> some View {
        modifier(GlowModifier(color: color, radius: radius, isAnimated: animated))
    }
}

// MARK: - Pulse Effect Modifier
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulse() -> some View {
        modifier(PulseModifier())
    }
}

// MARK: - Typing Text Animation
struct TypingText: View {
    let texts: [String]
    var typingSpeed: Double = 0.05
    var pauseDuration: Double = 1.5

    @State private var currentTextIndex = 0
    @State private var displayedText = ""
    @State private var isTyping = true

    var body: some View {
        Text(displayedText)
            .onAppear {
                startTypingAnimation()
            }
    }

    private func startTypingAnimation() {
        guard !texts.isEmpty else { return }

        let currentText = texts[currentTextIndex]

        if isTyping {
            // Typing phase
            if displayedText.count < currentText.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + typingSpeed) {
                    displayedText = String(currentText.prefix(displayedText.count + 1))
                    startTypingAnimation()
                }
            } else {
                // Pause before next text
                DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                    isTyping = false
                    startTypingAnimation()
                }
            }
        } else {
            // Move to next text
            displayedText = ""
            currentTextIndex = (currentTextIndex + 1) % texts.count
            isTyping = true
            startTypingAnimation()
        }
    }
}

// MARK: - Sound Manager
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func playSuccessSound() {
        // System sound for completion
        AudioServicesPlaySystemSound(1407) // Payment success sound
    }

    func playNotificationSound() {
        AudioServicesPlaySystemSound(1315) // Subtle notification
    }
}

// MARK: - Symbol Effect Extensions (iOS 17+)
extension View {
    @ViewBuilder
    func symbolBounce(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func symbolPulse(isActive: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.pulse, isActive: isActive)
        } else {
            self
        }
    }
}
