//
//  FloatingTabBar.swift
//  optimize
//
//  Minimal Floating Dock - Premium App Design
//
//  DESIGN PHILOSOPHY:
//  - Minimalist: Only 2 tabs (Home, Settings) + Center FAB
//  - Premium feel: Floating capsule, not full-width dock
//  - Focus on primary action: Compress files
//  - Clean, uncluttered navigation
//

import SwiftUI

// MARK: - Tab Bar Item (Simplified)

enum FloatingTabItem: Int, CaseIterable, Identifiable {
    case home = 0
    case settings = 1

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .home: return "tab.home"
        case .settings: return "tab.settings"
        }
    }

    var labelText: String {
        switch self {
        case .home: return "Ana Sayfa"
        case .settings: return "Ayarlar"
        }
    }
}

// MARK: - Premium Floating Dock

/// Minimal floating dock with 2 tabs and center FAB
/// Design inspired by premium apps like Arc, Things, Paper
struct FloatingTabBar: View {
    @Binding var selectedTab: FloatingTabItem
    let onAddTap: () -> Void
    var onHistoryTap: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            // Left Tab - Home
            MinimalTabButton(
                tab: .home,
                isSelected: selectedTab == .home,
                namespace: tabNamespace
            ) {
                handleTabSelection(.home)
            }
            .frame(width: 56)

            Spacer()

            // Center FAB - Primary Action
            PremiumFAB(action: onAddTap)

            Spacer()

            // Right Tab - Settings
            MinimalTabButton(
                tab: .settings,
                isSelected: selectedTab == .settings,
                namespace: tabNamespace
            ) {
                handleTabSelection(.settings)
            }
            .frame(width: 56)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, 34) // Safe area for home indicator
    }

    private func handleTabSelection(_ tab: FloatingTabItem) {
        Haptics.selection()

        switch tab {
        case .settings:
            onSettingsTap?()
        default:
            break
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedTab = tab
        }
    }
}

// MARK: - Minimal Tab Button

struct MinimalTabButton: View {
    let tab: FloatingTabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Selection indicator
                if isSelected {
                    Circle()
                        .fill(Color.appMint.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .matchedGeometryEffect(id: "tab_indicator", in: namespace)
                }

                // Icon
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.appMint : Color.primary.opacity(0.5))
                    .symbolBounce(trigger: isSelected)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(TabButtonStyle())
        .accessibilityLabel(tab.label)
    }
}

// MARK: - Tab Button Style

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Premium Floating Action Button

/// Elevated primary action button with premium gradient and glow
struct PremiumFAB: View {
    let action: () -> Void

    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.4
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            Haptics.impact(style: .medium)
            action()
        }) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.premiumPurple.opacity(glowIntensity * 0.5),
                                Color.premiumBlue.opacity(glowIntensity * 0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)

                // Main button with premium gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        // Inner highlight
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.premiumPurple.opacity(0.5), radius: 16, x: 0, y: 8)

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
                }
        )
        .onAppear {
            // Subtle breathing glow
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.7
            }
        }
        .accessibilityLabel("Dosya Seç")
        .accessibilityHint("Yeni dosya seçmek için dokun")
    }
}

// MARK: - Center Action Button (Legacy - Kept for compatibility)

/// Elevated primary action button with premium gradient
struct CenterActionButton: View {
    let action: () -> Void

    var body: some View {
        PremiumFAB(action: action)
    }
}

// MARK: - Floating Tab Bar Container

/// Container view that manages tab bar visibility and safe area
struct FloatingTabBarContainer<Content: View>: View {
    @Binding var selectedTab: FloatingTabItem
    let onAddTap: () -> Void
    var onHistoryTap: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            content()
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 100)
                }

            FloatingTabBar(
                selectedTab: $selectedTab,
                onAddTap: onAddTap,
                onHistoryTap: onHistoryTap,
                onSettingsTap: onSettingsTap
            )
        }
    }
}

// MARK: - Preview

#Preview("Premium Floating Dock") {
    struct PreviewWrapper: View {
        @State private var selectedTab: FloatingTabItem = .home

        var body: some View {
            FloatingTabBarContainer(
                selectedTab: $selectedTab,
                onAddTap: { print("Add tapped") }
            ) {
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack {
                        Text("Selected: \(selectedTab.labelText)")
                            .font(.title)
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.top, 100)
                }
            }
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
