//
//  FloatingTabBar.swift
//  optimize
//
//  Modern Glass Dock Navigation - iOS 18 Style
//
//  DESIGN PHILOSOPHY:
//  - "Frosted Glass Dock" instead of floating capsule
//  - Professional, not "toy-like"
//  - Apple Human Interface Guidelines compliant
//  - Full-width dock with proper safe area handling
//

import SwiftUI

// MARK: - Tab Bar Item

enum FloatingTabItem: Int, CaseIterable, Identifiable {
    case home = 0
    case tools = 1
    case history = 2
    case settings = 3

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .tools: return "square.grid.2x2"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .tools: return "square.grid.2x2.fill"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .home: return "tab.home"
        case .tools: return "tab.tools"
        case .history: return "tab.history"
        case .settings: return "tab.settings"
        }
    }

    var labelText: String {
        switch self {
        case .home: return "Ana Sayfa"
        case .tools: return "Araçlar"
        case .history: return "Geçmiş"
        case .settings: return "Ayarlar"
        }
    }
}

// MARK: - Modern Glass Dock Tab Bar

/// Premium glass dock navigation following iOS 18 design language
/// Features:
/// - UltraThinMaterial frosted glass effect
/// - Full-width dock (not floating capsule)
/// - Subtle top border
/// - Proper home indicator spacing
/// - iOS 17+ symbol effects
struct FloatingTabBar: View {
    @Binding var selectedTab: FloatingTabItem
    let onAddTap: () -> Void
    var onHistoryTap: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FloatingTabItem.allCases) { tab in
                if tab == .tools {
                    // Center Action Button (Elevated)
                    CenterActionButton(action: onAddTap)
                        .frame(maxWidth: .infinity)
                } else {
                    GlassDockTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: tabNamespace
                    ) {
                        handleTabSelection(tab)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 34) // Home indicator spacing
        .background(
            ZStack {
                // Frosted Glass Effect
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)

                // Subtle top border
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                    Spacer()
                }
                .ignoresSafeArea(edges: .bottom)
            }
        )
    }

    private func handleTabSelection(_ tab: FloatingTabItem) {
        Haptics.selection()

        switch tab {
        case .history:
            onHistoryTap?()
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

// MARK: - Glass Dock Tab Button

struct GlassDockTabButton: View {
    let tab: FloatingTabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon with iOS 17+ effects
                ZStack {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.appMint : Color.white.opacity(0.5))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .symbolBounce(trigger: isSelected)
                }
                .frame(height: 28)

                // Selection indicator dot
                Circle()
                    .fill(isSelected ? Color.appMint : Color.clear)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isSelected ? 1.0 : 0.5)
                    .opacity(isSelected ? 1.0 : 0.0)
            }
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabButtonStyle())
        .accessibilityLabel(tab.label)
    }
}

// MARK: - Tab Button Style

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Center Action Button

/// Elevated primary action button with premium gradient
struct CenterActionButton: View {
    let action: () -> Void

    @State private var glowOpacity: Double = 0.3
    @State private var isPressed = false

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
                                Color.appMint.opacity(glowOpacity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 15,
                            endRadius: 45
                        )
                    )
                    .frame(width: 70, height: 70)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appMint, Color.appTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.appMint.opacity(0.4), radius: 12, x: 0, y: 4)

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .buttonStyle(CenterButtonStyle())
        .offset(y: -16) // Slightly elevated
        .onAppear {
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
    var onHistoryTap: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            content()
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 80)
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

#Preview("Glass Dock Tab Bar") {
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
