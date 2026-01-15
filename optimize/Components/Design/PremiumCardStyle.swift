//
//  PremiumCardStyle.swift
//  optimize
//
//  Premium Card Design System
//
//  DESIGN PHILOSOPHY:
//  - Glass morphism with edge lighting effect
//  - Clear visual distinction between Free and Pro features
//  - Locked items feel "untouchable" with striped pattern
//  - Premium items have subtle glow and premium border
//

import SwiftUI

// MARK: - Premium Card Style Modifier

/// A view modifier that applies premium styling to cards
/// - isPremium: Card represents a premium feature (has glow/border)
/// - isLocked: Feature is locked for current user (striped overlay)
struct PremiumCardStyle: ViewModifier {
    var isPremium: Bool = false
    var isLocked: Bool = false
    var cornerRadius: CGFloat = 20

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass material
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isLocked ? 0.7 : 1)

                    // Locked pattern overlay
                    if isLocked {
                        StripedPattern()
                            .stroke(Color.white.opacity(0.03), lineWidth: 1)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }

                    // Premium gradient tint
                    if isPremium && !isLocked {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.premiumPurple.opacity(0.05),
                                        Color.premiumBlue.opacity(0.03),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .overlay(
                // Edge lighting border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: borderColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPremium ? 1.5 : 1
                    )
            )
            .shadow(
                color: shadowColor,
                radius: isPremium ? 20 : 10,
                x: 0,
                y: isPremium ? 10 : 5
            )
            .opacity(isLocked ? 0.85 : 1.0)
    }

    private var borderColors: [Color] {
        if isLocked {
            return [
                Color.white.opacity(0.1),
                Color.white.opacity(0.05)
            ]
        } else if isPremium {
            return [
                Color.premiumPurple.opacity(0.6),
                Color.premiumBlue.opacity(0.3),
                Color.white.opacity(0.2)
            ]
        } else {
            return [
                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
            ]
        }
    }

    private var shadowColor: Color {
        if isPremium && !isLocked {
            return Color.premiumPurple.opacity(colorScheme == .dark ? 0.2 : 0.15)
        } else {
            return Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1)
        }
    }
}

// MARK: - Striped Pattern for Locked Items

/// Diagonal stripes pattern that overlays locked features
/// Creates a "restricted area" visual cue
struct StripedPattern: Shape {
    var spacing: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let diagonal = rect.width + rect.height

        for x in stride(from: 0, to: diagonal, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x - rect.height, y: rect.height))
        }

        return path
    }
}

// MARK: - View Extension

extension View {
    /// Apply premium card styling
    /// - Parameters:
    ///   - isPremium: Whether this card represents a premium feature
    ///   - isLocked: Whether this feature is locked for the current user
    ///   - cornerRadius: Corner radius for the card
    func premiumStyle(
        isPremium: Bool = false,
        isLocked: Bool = false,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self.modifier(
            PremiumCardStyle(
                isPremium: isPremium,
                isLocked: isLocked,
                cornerRadius: cornerRadius
            )
        )
    }
}

// MARK: - Locked Feature Overlay

/// Overlay view for locked features with lock icon and blur
struct LockedFeatureOverlay: View {
    var message: String = "PRO"
    var onTap: (() -> Void)? = nil

    @State private var isGlowing = false

    var body: some View {
        ZStack {
            // Blur background
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)

            // Lock indicator
            VStack(spacing: Spacing.sm) {
                // Animated lock icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.premiumPurple.opacity(0.3), Color.premiumBlue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.premiumPurple.opacity(isGlowing ? 0.5 : 0.2), radius: isGlowing ? 12 : 6)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.premiumPurple, Color.premiumBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // PRO badge
                Text(message)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        LinearGradient(
                            colors: [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.heavy() // Heavy impact for "blocked" feeling
            onTap?()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

// MARK: - Pro Badge Styles

/// Compact PRO badge for inline use
struct InlineProBadge: View {
    var style: BadgeStyle = .gradient

    enum BadgeStyle {
        case gradient
        case gold
        case subtle
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
                .font(.system(size: 9, weight: .bold))
            Text("PRO")
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(background)
        .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch style {
        case .gradient, .gold:
            return .white
        case .subtle:
            return .premiumPurple
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .gradient:
            LinearGradient(
                colors: [Color.premiumPurple, Color.premiumBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .gold:
            LinearGradient(
                colors: [Color.goldAccent, Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .subtle:
            Color.premiumPurple.opacity(0.15)
        }
    }
}

// MARK: - Premium Feature Card

/// A complete card component for premium features
struct PremiumFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var isLocked: Bool = true
    var onTap: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            if isLocked {
                Haptics.heavy()
            } else {
                Haptics.selection()
            }
            onTap()
        }) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            isLocked
                                ? Color.gray.opacity(0.2)
                                : LinearGradient(
                                    colors: [Color.premiumPurple.opacity(0.2), Color.premiumBlue.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isLocked ? .secondary : Color.premiumPurple)
                }

                // Text
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text(title)
                            .font(.appBodyMedium)
                            .foregroundStyle(isLocked ? .secondary : .primary)

                        if isLocked {
                            InlineProBadge(style: .subtle)
                        }
                    }

                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Lock/Arrow indicator
                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isLocked ? Color.premiumPurple.opacity(0.5) : .tertiary)
            }
            .padding(Spacing.md)
            .premiumStyle(isPremium: !isLocked, isLocked: isLocked, cornerRadius: Radius.lg)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Preview

#Preview("Premium Card Styles") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            // Standard card
            Text("Standard Card")
                .font(.appBodyMedium)
                .padding()
                .frame(maxWidth: .infinity)
                .premiumStyle()

            // Premium unlocked card
            Text("Premium Unlocked")
                .font(.appBodyMedium)
                .padding()
                .frame(maxWidth: .infinity)
                .premiumStyle(isPremium: true)

            // Premium locked card
            Text("Premium Locked")
                .font(.appBodyMedium)
                .padding()
                .frame(maxWidth: .infinity)
                .premiumStyle(isPremium: true, isLocked: true)

            // Feature cards
            PremiumFeatureCard(
                icon: "wand.and.stars",
                title: "AI Smart Compress",
                subtitle: "Intelligent optimization",
                isLocked: true
            ) {
                print("Tapped")
            }

            PremiumFeatureCard(
                icon: "bolt.fill",
                title: "Quick Compress",
                subtitle: "Fast and efficient",
                isLocked: false
            ) {
                print("Tapped")
            }

            // Badge styles
            HStack(spacing: Spacing.md) {
                InlineProBadge(style: .gradient)
                InlineProBadge(style: .gold)
                InlineProBadge(style: .subtle)
            }
        }
        .padding()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
