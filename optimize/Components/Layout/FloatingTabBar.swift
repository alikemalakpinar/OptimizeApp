//
//  FloatingTabBar.swift
//  optimize
//
//  Premium floating glassmorphic navigation bar
//  Replaces standard Tab Bar with modern capsule design
//

import SwiftUI

// MARK: - Tab Bar Item
enum FloatingTabItem: Int, CaseIterable {
    case home = 0
    case history = 1
    case settings = 2

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Ana Sayfa"
        case .history: return "Geçmiş"
        case .settings: return "Ayarlar"
        }
    }
}

// MARK: - Floating Tab Bar
/// Premium floating navigation bar with glassmorphic design
/// Features:
/// - Frosted glass effect with .ultraThinMaterial
/// - Capsule shape for modern look
/// - Center action button (elevated) for primary action
/// - Smooth animations on selection
struct FloatingTabBar: View {
    @Binding var selectedTab: FloatingTabItem
    let onAddTap: () -> Void
    var onHistoryTap: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // History Tab
            TabBarButton(
                item: .history,
                isSelected: selectedTab == .history
            ) {
                Haptics.selection()
                onHistoryTap?()
            }

            Spacer()

            // Center Action Button (Elevated)
            CenterActionButton(action: onAddTap)

            Spacer()

            // Settings Tab
            TabBarButton(
                item: .settings,
                isSelected: selectedTab == .settings
            ) {
                Haptics.selection()
                onSettingsTap?()
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.glassBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let item: FloatingTabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.appAccent : Color.secondary.opacity(0.6))
                    .symbolBounce(trigger: isSelected)

                // Small indicator dot for selected state
                Circle()
                    .fill(isSelected ? Color.appAccent : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 60, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
    }
}

// MARK: - Center Action Button
/// Elevated primary action button with gradient
struct CenterActionButton: View {
    let action: () -> Void

    @State private var isPressed = false
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        Button(action: {
            Haptics.impact(style: .medium)
            action()
        }) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.premiumPurple.opacity(glowOpacity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.premiumPurple.opacity(0.4), radius: 12, x: 0, y: 6)

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(CenterButtonStyle())
        .offset(y: -20) // Elevated above the bar
        .onAppear {
            // Subtle breathing glow effect
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowOpacity = 0.5
            }
        }
        .accessibilityLabel("Dosya Seç")
        .accessibilityHint("Yeni dosya seçmek için dokun")
    }
}

// MARK: - Center Button Style
struct CenterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Floating Tab Bar Container
/// Container view that manages tab bar visibility and safe area
struct FloatingTabBarContainer<Content: View>: View {
    @Binding var selectedTab: FloatingTabItem
    let onAddTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            content()
                .safeAreaInset(edge: .bottom) {
                    // Reserve space for tab bar
                    Color.clear
                        .frame(height: 90)
                }

            FloatingTabBar(
                selectedTab: $selectedTab,
                onAddTap: onAddTap
            )
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: FloatingTabItem = .home

        var body: some View {
            FloatingTabBarContainer(
                selectedTab: $selectedTab,
                onAddTap: { print("Add tapped") }
            ) {
                ZStack {
                    Color.appBackground.ignoresSafeArea()

                    VStack {
                        Text("Selected: \(selectedTab.label)")
                            .font(.appLargeTitle)

                        Spacer()
                    }
                    .padding(.top, 100)
                }
            }
        }
    }

    return PreviewWrapper()
}
