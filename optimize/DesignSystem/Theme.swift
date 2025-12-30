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

    // Semantic colors (auto Dark Mode)
    static let appBackground = Color(.systemBackground)
    static let appSurface = Color(.secondarySystemBackground)
    static let appGroupedBackground = Color(.systemGroupedBackground)

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(.tertiaryLabel)

    // Status colors
    static let statusSuccess = Color.green
    static let statusWarning = Color.orange
    static let statusError = Color.red

    // Glass effect colors
    static let glassBackground = Color(.systemBackground).opacity(0.7)
    static let glassBorder = Color.white.opacity(0.2)
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
