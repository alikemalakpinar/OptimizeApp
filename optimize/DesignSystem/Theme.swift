//
//  Theme.swift
//  optimize
//
//  Design System - Apple 2025 Design (Content-first + Glassy surfaces)
//
//  BRAND SYSTEM:
//  - Primary: Electric Mint (#33C7A6) - Energy, optimization, success
//  - Secondary: Premium Purple (#8F44FC) - Pro features, premium feel
//  - Accent: Deep Blue (#4078FF) - Links, interactive elements
//
//  TYPOGRAPHY PHILOSOPHY:
//  - Display (Serif): Editorial headlines, paywall titles
//  - UI (Rounded): Buttons, labels, body text - friendly & modern
//  - Data (Mono): File sizes, percentages - engineering precision
//

import SwiftUI
import UIKit

// MARK: - Brand System

/// OptimizeApp Brand Identity
/// Use these semantic colors for consistent brand expression
enum Brand {
    /// Primary brand color - Electric Mint
    /// Use for: Success states, primary CTAs, completed actions
    static let primary = Color.appMint

    /// Secondary brand color - Premium Purple
    /// Use for: Pro features, upgrades, premium indicators
    static let secondary = Color.premiumPurple

    /// Accent color - Deep Blue
    /// Use for: Links, interactive elements, selection states
    static let accent = Color.premiumBlue

    /// Primary gradient for CTAs
    static let primaryGradient = LinearGradient(
        colors: [Color.appMint, Color.appTeal],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Premium gradient for Pro features
    static let premiumGradient = LinearGradient(
        colors: [Color.premiumPurple, Color.premiumBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Success gradient for completion states
    static let successGradient = LinearGradient(
        colors: [Color.successGradientStart, Color.successGradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Semantic Spacing

/// Semantic spacing aliases for consistent layouts
enum SemanticSpacing {
    /// Standard card internal padding (16pt)
    static let cardPadding: CGFloat = Spacing.md

    /// Spacing between cards in a list (12pt)
    static let cardGap: CGFloat = Spacing.sm

    /// Section spacing in scrollable content (24pt)
    static let sectionGap: CGFloat = Spacing.lg

    /// Screen edge padding (16pt)
    static let screenPadding: CGFloat = Spacing.md

    /// Spacing between icon and text (8pt)
    static let iconTextGap: CGFloat = Spacing.xs

    /// Spacing between stacked text lines (4pt)
    static let textStackGap: CGFloat = Spacing.xxs

    /// Bottom safe area for floating buttons (32pt)
    static let floatingBottomPadding: CGFloat = Spacing.xl
}

// MARK: - Display Scale

/// Opinionated display text sizes for visual hierarchy
/// Use for screen titles and hero content
enum DisplayScale {
    /// Hero titles on paywall/success screens (34pt)
    static let hero: CGFloat = 34

    /// Major section headers (28pt)
    static let title: CGFloat = 28

    /// Secondary headers (22pt)
    static let subtitle: CGFloat = 22

    /// Subsection headers (17pt)
    static let heading: CGFloat = 17

    /// Body text (15pt)
    static let body: CGFloat = 15

    /// Caption and metadata (12pt)
    static let caption: CGFloat = 12

    /// Micro text for badges (10pt)
    static let micro: CGFloat = 10
}

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

    // Premium UI Colors - Harmonized Palette
    static let premiumPurple = Color(red: 0.56, green: 0.27, blue: 0.98) // #8F44FC
    static let premiumBlue = Color(red: 0.25, green: 0.47, blue: 1.0) // #4078FF
    static let premiumIndigo = Color(red: 0.35, green: 0.34, blue: 0.84) // #5957D6
    static let premiumCyan = Color(red: 0.2, green: 0.68, blue: 0.9) // #33ADE5

    // Warm accent for CTAs
    static let warmOrange = Color(red: 1.0, green: 0.58, blue: 0.0) // #FF9500
    static let warmCoral = Color(red: 1.0, green: 0.38, blue: 0.42) // #FF616B

    // Warm palette - Liquid Glass era
    static let warmWhite = Color(red: 0.973, green: 0.965, blue: 0.953) // #F8F6F3
    static let warmSurface = Color(red: 0.965, green: 0.957, blue: 0.945) // Slightly deeper warm
    static let mutedSapphire = Color(red: 0.25, green: 0.42, blue: 0.72) // Trust, tech feel

    // Semantic colors (auto Dark Mode) — Warm-tinted
    static let appBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.systemBackground
            : UIColor(red: 0.973, green: 0.965, blue: 0.953, alpha: 1.0)
    })
    static let appSurface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.secondarySystemBackground
            : UIColor(red: 0.961, green: 0.953, blue: 0.941, alpha: 1.0)
    })
    static let appGroupedBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.systemGroupedBackground
            : UIColor(red: 0.949, green: 0.941, blue: 0.929, alpha: 1.0)
    })

    // Bento Grid Design System
    static let bentoBackground = Color(.secondarySystemBackground)
    static let cardBorder = Color.primary.opacity(0.05)

    // Dynamic signatureCardBG - Safe for both Light and Dark Mode
    // Uses UIColor dynamic provider instead of Asset (more reliable)
    static let signatureCardBG = Color(uiColor: UIColor { trait in
        // Dark Mode: Koyu gri (System Grouped Background)
        if trait.userInterfaceStyle == .dark {
            return UIColor.secondarySystemGroupedBackground
        }
        // Light Mode: Hafif krem/kağıt rengi
        return UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)
    })

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(.tertiaryLabel)

    // Status colors (Semantic)
    static let statusSuccess = Color(red: 0.2, green: 0.78, blue: 0.65) // Mint green
    static let statusWarning = Color.orange
    static let statusError = Color.red

    // Semantic aliases — use these for new code
    static let colorSuccess = statusSuccess
    static let colorWarning = statusWarning
    static let colorError = statusError
    static let colorPremium = premiumPurple
    static let colorAccent = appMint

    // Glass effect colors - System-aware for better visibility
    static let glassBackground = Color(.systemBackground).opacity(0.7)
    static let glassBorder = Color.primary.opacity(0.1) // Works in both light and dark mode

    // Liquid Glass specular highlight
    static let glassSpecular = Color.white.opacity(0.25)
    static let glassTint = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.3) // Tinted dark glass
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5) // Warm light glass
    })

    // Holographic HUD Paywall colors
    static let glassSurface = Color.white.opacity(0.1)
    static let proGold = Color(red: 1.0, green: 0.85, blue: 0.35) // Premium feel
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

// MARK: - Typography System (Pro Tool Design)
///
/// DESIGN PHILOSOPHY:
/// - Headings: New York (Serif) - Editöryal, premium his
/// - Body: SF Pro Rounded - Arkadaş canlısı, modern
/// - Data/Numbers: SF Mono - Teknik, mühendislik hissi
/// - Sizes: Consistent scale for visual hierarchy
///
extension Font {
    // MARK: - Display Styles (Serif - Premium Headlines)
    /// For paywall titles, major headlines - "Apple Design Award" feel
    static let displayTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let displaySubtitle = Font.system(.title2, design: .serif).weight(.medium)
    static let displayHeadline = Font.system(.title3, design: .serif).weight(.semibold)

    // MARK: - UI Styles (Rounded - Friendly & Modern)
    /// For buttons, labels, interactive elements
    static let uiLarge = Font.system(.title, design: .rounded).weight(.bold)
    static let uiBody = Font.system(.body, design: .rounded)
    static let uiBodyBold = Font.system(.body, design: .rounded).weight(.semibold)
    static let uiCaption = Font.system(.caption, design: .rounded)
    static let uiCaptionBold = Font.system(.caption, design: .rounded).weight(.bold)

    // MARK: - Data Styles (Monospaced - Engineering Dashboard)
    /// For file sizes, percentages, GB/MB values
    static let dataValue = Font.system(.headline, design: .monospaced).weight(.medium)
    static let dataLarge = Font.system(.title, design: .monospaced).weight(.bold)
    static let dataSmall = Font.system(.caption, design: .monospaced)

    // MARK: - Heading Styles (Serif - New York)
    /// Large headlines with editorial feel
    static let appHeadlineSerif = Font.system(.title, design: .serif).weight(.semibold)
    static let appLargeTitleSerif = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let appSubheadlineSerif = Font.system(.title3, design: .serif).weight(.medium)

    // MARK: - Title styles (Rounded for friendliness)
    static let appTitle = Font.system(.title2, design: .rounded).weight(.semibold)
    static let appLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let appTitleSmall = Font.system(.title3, design: .rounded).weight(.semibold)

    // MARK: - Section header
    static let appSection = Font.system(.headline, design: .rounded)
    static let appSectionSerif = Font.system(.headline, design: .serif).weight(.semibold)

    // MARK: - Body (Rounded for approachability)
    static let appBody = Font.system(.body, design: .rounded)
    static let appBodyMedium = Font.system(.body, design: .rounded).weight(.medium)
    static let appBodyBold = Font.system(.body, design: .rounded).weight(.bold)

    // MARK: - Caption
    static let appCaption = Font.system(.caption, design: .rounded)
    static let appCaptionMedium = Font.system(.caption, design: .rounded).weight(.medium)
    static let appCaptionBold = Font.system(.caption, design: .rounded).weight(.bold)

    // MARK: - Technical Data (Monospaced)
    /// File sizes, percentages, technical values
    /// Monospaced creates "engineering dashboard" feel
    static let appDataLarge = Font.system(.largeTitle, design: .monospaced).monospacedDigit()
    static let appDataMedium = Font.system(.title, design: .monospaced).monospacedDigit()
    static let appDataSmall = Font.system(.title3, design: .monospaced).monospacedDigit()
    static let appDataCaption = Font.system(.caption, design: .monospaced).monospacedDigit()

    // MARK: - Numbers (Rounded + Monospaced - Best of both)
    /// For counters, savings percentages - friendly but aligned
    static let appNumber = Font.system(.largeTitle, design: .rounded).monospacedDigit()
    static let appNumberMedium = Font.system(.title, design: .rounded).monospacedDigit()
    static let appNumberSmall = Font.system(.title3, design: .rounded).monospacedDigit()

    // MARK: - Special Purpose
    /// For file names, paths, technical info
    static let appMono = Font.system(.body, design: .monospaced)
    static let appMonoSmall = Font.system(.caption, design: .monospaced)

    /// For premium/pro badges
    static let appBadge = Font.system(.caption2, design: .rounded).weight(.bold)
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

    // MARK: - Premium Easing Curves (Custom Springs)

    /// Premium ease-out: fast start, gentle stop — feels snappy & expensive
    /// Use for: card reveals, bottom sheet open, navigation push
    static let premiumEaseOut = Animation.spring(response: 0.35, dampingFraction: 0.85)

    /// Dramatic reveal: slow start, explosive finish — builds anticipation
    /// Use for: result screen reveal, savings counter final value, achievement unlock
    static let dramaticReveal = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.1)

    /// Gentle bounce: soft spring for paywall, modals — inviting, not aggressive
    static let gentleBounce = Animation.spring(response: 0.55, dampingFraction: 0.72)

    /// Micro interaction: ultra-fast for toggles, checkmarks, small state changes
    static let micro = Animation.spring(response: 0.2, dampingFraction: 0.9)

    /// Celebration: bouncy spring for confetti, badges, achievement popups
    static let celebration = Animation.spring(response: 0.45, dampingFraction: 0.55)

    // MARK: - Motion Narrative Presets
    // Each screen transition tells a visual "story"

    /// "File entering" — Home → Analyze: content slides in with slight scale
    static let fileEntering = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// "Options opening" — Analyze → Preset: elements fan out from center
    static let optionsOpening = Animation.spring(response: 0.35, dampingFraction: 0.75)

    /// "Processing" — Preset → Progress: pulsing momentum
    static let processing = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)

    /// "Victory" — Progress → Result: explosive celebration
    static let victory = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.2)

    // Pressed scale
    static let pressedScale: CGFloat = 0.98

    // Stagger delay for list items
    static let staggerDelay: Double = 0.05
}

// MARK: - Motion Narrative View Modifiers

/// Slide-in from bottom with scale — "file entering" feel
struct FileEnteringTransition: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: isActive ? 0 : 40)
            .scaleEffect(isActive ? 1.0 : 0.95)
            .opacity(isActive ? 1.0 : 0.0)
    }
}

/// Fan-out from center — "options opening" feel
struct OptionsRevealTransition: ViewModifier {
    let isActive: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .offset(y: isActive ? 0 : 20)
            .scaleEffect(isActive ? 1.0 : 0.9)
            .opacity(isActive ? 1.0 : 0.0)
            .animation(
                AppAnimation.optionsOpening.delay(Double(index) * 0.06),
                value: isActive
            )
    }
}

/// Explosive scale-up — "victory" feel
struct VictoryRevealTransition: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.0 : 0.5)
            .opacity(isActive ? 1.0 : 0.0)
    }
}

extension View {
    func fileEntering(_ isActive: Bool) -> some View {
        modifier(FileEnteringTransition(isActive: isActive))
            .animation(AppAnimation.fileEntering, value: isActive)
    }

    func optionsReveal(_ isActive: Bool, index: Int = 0) -> some View {
        modifier(OptionsRevealTransition(isActive: isActive, index: index))
    }

    func victoryReveal(_ isActive: Bool) -> some View {
        modifier(VictoryRevealTransition(isActive: isActive))
            .animation(AppAnimation.victory, value: isActive)
    }
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

// MARK: - Glass Material Modifier (Legacy — use liquidGlass for new code)
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

// MARK: - Liquid Glass Modifier (iOS 26-ready Design Language)

/// Enhanced glass effect with specular highlights, tinted blur, and edge lighting.
/// Uses native `.glassEffect()` on iOS 26+; approximates on iOS 18.
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.lg
    var tint: Color? = nil
    var prominent: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(0) // ensure view identity
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(specularHighlight)
                .overlay(edgeBorder)
        }
    }

    // Tinted glass blur material
    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            // Base blur
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            // Color tint overlay
            if let tint = tint {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.15 : 0.08))
            } else if colorScheme == .dark {
                // Default tinted dark glass
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.3))
            }
        }
    }

    // Top-left specular highlight (light refraction effect)
    private var specularHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(prominent ? 0.25 : 0.15), location: 0),
                        .init(color: Color.white.opacity(0.05), location: 0.35),
                        .init(color: Color.clear, location: 0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .allowsHitTesting(false)
    }

    // Edge lighting border
    private var edgeBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
            .allowsHitTesting(false)
    }
}

/// Capsule variant of Liquid Glass (for tab bars, pills, chips)
struct LiquidGlassCapsuleModifier: ViewModifier {
    var tint: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(0)
                .glassEffect(.regular.interactive(), in: .capsule)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, x: 0, y: 10)
        } else {
            content
                .background(
                    ZStack {
                        Capsule()
                            .fill(.ultraThinMaterial)
                        if colorScheme == .dark {
                            Capsule()
                                .fill(Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.3))
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, x: 0, y: 10)
        }
    }
}

extension View {
    func glassMaterial(cornerRadius: CGFloat = Radius.lg) -> some View {
        modifier(GlassMaterialModifier(cornerRadius: cornerRadius))
    }

    /// Liquid Glass effect — the primary glass modifier for all new UI.
    /// Uses tinted blur + specular highlight + edge lighting.
    func liquidGlass(
        cornerRadius: CGFloat = Radius.lg,
        tint: Color? = nil,
        prominent: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            prominent: prominent
        ))
    }

    /// Liquid Glass capsule variant for tab bars, pills, etc.
    func liquidGlassCapsule(tint: Color? = nil) -> some View {
        modifier(LiquidGlassCapsuleModifier(tint: tint))
    }

    // Layered gradient background used across main screens
    func appBackgroundLayered() -> some View {
        background(AppBackground())
    }
}

// MARK: - Device Performance Detection

/// Utility to detect device capabilities and optimize UI accordingly
enum DevicePerformance {
    /// Check if device is in Low Power Mode
    static var isLowPowerModeEnabled: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// Check if device has limited RAM (<4GB)
    static var isLowMemoryDevice: Bool {
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        return memoryGB < 4.0
    }

    /// Check if animations should be reduced
    static var shouldReduceAnimations: Bool {
        // Check accessibility setting
        if UIAccessibility.isReduceMotionEnabled {
            return true
        }
        // Check low power mode
        if isLowPowerModeEnabled {
            return true
        }
        // Check device capability
        if isLowMemoryDevice {
            return true
        }
        return false
    }

    /// Check if blur effects should be simplified
    static var shouldReduceBlur: Bool {
        // Reduce blur on low power or low memory devices
        return isLowPowerModeEnabled || isLowMemoryDevice
    }

    /// Get recommended animation duration multiplier
    static var animationSpeedMultiplier: Double {
        shouldReduceAnimations ? 0.5 : 1.0
    }
}

// MARK: - Gradient Background (Animated) - Performance Optimized

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rotationAngle: Double = 0
    var animated: Bool = true

    /// Whether to use reduced effects for performance
    private var useReducedEffects: Bool {
        DevicePerformance.shouldReduceAnimations
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.appAccent.opacity(0.28),
                Color.appBackground
            ]
        }

        // Warm-tinted light mode gradient
        return [
            Color.appAccent.opacity(0.12),
            Color.warmWhite
        ]
    }

    var body: some View {
        ZStack {
            // Base gradient - always rendered
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // PERFORMANCE: Skip animated overlays on low-end devices
            if !useReducedEffects {
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
        }
        .ignoresSafeArea()
        .onAppear {
            // PERFORMANCE: Only animate if device supports it and animation is requested
            if animated && !useReducedEffects {
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

// MARK: - Performance-Aware Blur Modifier

struct PerformanceAwareBlurModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        if DevicePerformance.shouldReduceBlur {
            // Simplified background for low-end devices
            content
                .background(Color.black.opacity(0.3))
        } else {
            // Full blur effect for capable devices
            content
                .blur(radius: radius)
        }
    }
}

extension View {
    /// Applies blur effect with automatic performance optimization
    /// Falls back to simple opacity overlay on low-end devices
    func performanceAwareBlur(radius: CGFloat) -> some View {
        modifier(PerformanceAwareBlurModifier(radius: radius))
    }
}

// MARK: - Stagger Animation Modifier
struct StaggeredAppearance: ViewModifier {
    let index: Int
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 20)
            .onAppear {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(AppAnimation.standard.delay(Double(index) * AppAnimation.staggerDelay)) {
                        isVisible = true
                    }
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

// NOTE: ConfettiView is defined in CelebrationView.swift

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
import AudioToolbox

/// Master-level Sound Manager with compression-specific audio feedback
/// Creates satisfying audio experiences for every interaction
class SoundManager {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    /// User preference for sounds — stored in UserDefaults
    var isSoundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "app.sounds.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "app.sounds.enabled") }
    }

    private init() {}

    // MARK: - Success & Completion Sounds

    /// Main success sound - compression complete
    func playSuccessSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1407) // Payment success sound
    }

    /// Achievement unlocked celebration
    func playAchievementSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1025) // Fanfare-like sound
    }

    /// Level up celebration
    func playLevelUpSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1026) // Ascending tone
    }

    // MARK: - Compression Flow Sounds

    /// Compression started - building anticipation
    func playCompressionStartSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1117) // Subtle start indicator
    }

    /// Progress tick during compression (use sparingly)
    func playProgressTick() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1104) // Light tick
    }

    /// File added to queue
    func playFileAddedSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1001) // Photo shutter-like
    }

    /// Single file compression complete
    func playFileCompleteSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1001) // Satisfying pop
    }

    /// Batch processing complete
    func playBatchCompleteSound() {
        guard isSoundEnabled else { return }
        // Double success sound for batch
        AudioServicesPlaySystemSound(1407)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AudioServicesPlaySystemSound(1407)
        }
    }

    // MARK: - UI Interaction Sounds

    /// Button tap feedback
    func playTapSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1104) // Keyboard tap
    }

    /// Toggle switch sound
    func playToggleSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1156) // Toggle sound
    }

    /// Navigation/swipe sound
    func playSwipeSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1105) // Swipe indicator
    }

    /// Selection changed in picker
    func playPickerSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1161) // Picker tick
    }

    // MARK: - Notification Sounds

    func playNotificationSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1315) // Subtle notification
    }

    /// New file received (from share sheet, etc.)
    func playFileReceivedSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1003) // Mail received-like
    }

    // MARK: - Warning & Error Sounds

    /// Warning sound - approaching limit
    func playWarningSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1053) // Subtle warning
    }

    /// Error sound - operation failed
    func playErrorSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1053) // Error indicator
    }

    /// Limit reached (daily limit, etc.)
    func playLimitReachedSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1107) // Lock/denied sound
    }

    // MARK: - Premium Sounds

    /// Premium feature unlock
    func playPremiumUnlockSound() {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(1025) // Unlock fanfare
    }

    /// Subscription activated
    func playSubscriptionActivatedSound() {
        guard isSoundEnabled else { return }
        // Celebratory sequence
        AudioServicesPlaySystemSound(1407)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AudioServicesPlaySystemSound(1025)
        }
    }
}

// MARK: - Enhanced Haptics

extension Haptics {
    /// Light tap for subtle interactions
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium tap for standard interactions
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy tap for important actions
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Rigid tap for firm feedback
    static func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    /// Soft tap for gentle feedback
    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// Sequential haptics for progress indication
    static func progressTick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.5)
    }

    /// Dramatic impact for major completions
    static func dramaticSuccess() {
        // Triple haptic sequence
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred(intensity: 0.8)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        }
    }

    /// Building tension haptic pattern
    static func buildingTension(completion: @escaping () -> Void) {
        let generator = UIImpactFeedbackGenerator(style: .light)

        // Accelerating taps
        let delays: [Double] = [0, 0.15, 0.27, 0.36, 0.42, 0.46, 0.49]

        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let intensity = CGFloat(index + 1) / CGFloat(delays.count)
                generator.impactOccurred(intensity: intensity)

                if index == delays.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        completion()
                    }
                }
            }
        }
    }

    /// Achievement unlock haptic pattern
    static func achievementUnlock() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }

    // MARK: - Premium/Lock Haptics

    /// Locked feature denied - "hitting a wall" feeling
    /// Use when user taps on a locked/pro feature
    static func lockedDenied() {
        // Heavy impact like hitting a closed door
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred(intensity: 1.0)

        // Follow-up rigid tap for "bounce back" feeling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            rigid.impactOccurred(intensity: 0.7)
        }
    }

    /// Premium unlock celebration - triumphant feeling
    /// Use when user successfully subscribes
    static func premiumUnlock() {
        let notification = UINotificationFeedbackGenerator()

        // Build up
        let light = UIImpactFeedbackGenerator(style: .light)
        light.impactOccurred(intensity: 0.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            light.impactOccurred(intensity: 0.7)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Climax - success notification
            notification.notificationOccurred(.success)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Celebration follow-up
            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.impactOccurred()
        }
    }

    /// Paywall appearance - attention grab
    /// Use when paywall sheet appears
    static func paywallAppear() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.6)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.impactOccurred(intensity: 0.4)
        }
    }

    /// Limit reached warning - urgency feeling
    /// Use when user hits daily/usage limits
    static func limitReached() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            notification.notificationOccurred(.warning)
        }
    }

    /// Button press for primary actions
    /// Use for main CTA buttons
    static func primaryAction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.8)
    }

    /// Subtle confirmation for secondary actions
    static func secondaryAction() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.6)
    }

    // MARK: - Compression Flow Haptics

    /// Compression progress milestone — fires at 25%, 50%, 75%, 100%
    /// Creates momentum feeling during long operations
    static func compressionProgress(percent: Int) {
        let intensity = CGFloat(percent) / 100.0
        let style: UIImpactFeedbackGenerator.FeedbackStyle = percent >= 75 ? .medium : .light
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: max(0.4, intensity))
    }

    /// Warning alert — double tap for attention
    static func warningAlert() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.impactOccurred(intensity: 0.8)
        }
    }

    /// File selection — satisfying pick sound
    static func fileSelected() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.6)
        SoundManager.shared.playFileAddedSound()
    }

    /// Tab switch — minimal
    static func tabSwitch() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.3)
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
