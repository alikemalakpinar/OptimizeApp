//
//  PresetScreen.swift
//  optimize
//
//  Preset selection screen with quality preview simulation
//

import SwiftUI

struct PresetScreen: View {
    @State private var selectedPresetId: String? = "whatsapp"
    @State private var wifiOnly = true
    @State private var deleteAfterProcess = false
    @State private var showPaywall = false

    let presets: [CompressionPreset]
    let onCompress: (CompressionPreset) -> Void
    let onBack: () -> Void
    let onShowPaywall: () -> Void

    init(
        presets: [CompressionPreset] = CompressionPreset.defaultPresets,
        onCompress: @escaping (CompressionPreset) -> Void,
        onBack: @escaping () -> Void,
        onShowPaywall: @escaping () -> Void
    ) {
        self.presets = presets
        self.onCompress = onCompress
        self.onBack = onBack
        self.onShowPaywall = onShowPaywall
    }

    var selectedPreset: CompressionPreset? {
        presets.first { $0.id == selectedPresetId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader("Hedef", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    // Quality Preview Card
                    QualityPreviewCard(selectedPresetId: selectedPresetId)

                    // Preset Grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Spacing.sm),
                            GridItem(.flexible(), spacing: Spacing.sm)
                        ],
                        spacing: Spacing.sm
                    ) {
                        ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                            EnhancedPresetCard(
                                preset: preset,
                                isSelected: selectedPresetId == preset.id
                            ) {
                                if preset.isProOnly {
                                    onShowPaywall()
                                } else {
                                    withAnimation(AppAnimation.spring) {
                                        selectedPresetId = preset.id
                                    }
                                    Haptics.selection()
                                }
                            }
                            .staggeredAppearance(index: index)
                        }
                    }

                    // Settings section
                    GlassCard {
                        VStack(spacing: Spacing.md) {
                            ToggleRow(
                                title: "Wi-Fi ile işle",
                                subtitle: "Mobil veri kullanma",
                                icon: "wifi",
                                isOn: $wifiOnly
                            )

                            Divider()

                            ToggleRow(
                                title: "İşlem sonrası sil",
                                subtitle: "Orijinal dosyayı kaldır",
                                icon: "trash",
                                isOn: $deleteAfterProcess
                            )
                        }
                    }

                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }

            // Bottom CTA
            VStack(spacing: Spacing.sm) {
                PrimaryButton(
                    title: "Sıkıştır",
                    icon: "bolt.fill",
                    isDisabled: selectedPreset == nil
                ) {
                    if let preset = selectedPreset {
                        Haptics.impact()
                        onCompress(preset)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.appBackground)
        }
        .appBackgroundLayered()
    }
}

// MARK: - Quality Preview Card
struct QualityPreviewCard: View {
    let selectedPresetId: String?

    private var blurAmount: CGFloat {
        switch selectedPresetId {
        case "mail": return 2.0
        case "whatsapp": return 1.0
        case "quality": return 0.0
        case "custom": return 0.5
        default: return 0.0
        }
    }

    private var qualityLabel: String {
        switch selectedPresetId {
        case "mail": return "Orta Kalite"
        case "whatsapp": return "İyi Kalite"
        case "quality": return "En İyi Kalite"
        case "custom": return "Özel Ayar"
        default: return "Önizleme"
        }
    }

    private var qualityColor: Color {
        switch selectedPresetId {
        case "mail": return .statusWarning
        case "whatsapp": return .appMint
        case "quality": return .appAccent
        case "custom": return .purple
        default: return .secondary
        }
    }

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                HStack {
                    Text("Kalite Önizlemesi")
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(qualityLabel)
                        .font(.appCaptionMedium)
                        .foregroundStyle(qualityColor)
                }

                // Preview image simulation
                ZStack {
                    // Sample "image" with varying blur
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                        .overlay(
                            // Fake content
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: 30, height: 30)

                                    VStack(alignment: .leading, spacing: 3) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 80, height: 8)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.4))
                                            .frame(width: 50, height: 6)
                                    }
                                }

                                Spacer()

                                HStack(spacing: 4) {
                                    ForEach(0..<4, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 40, height: 30)
                                    }
                                }
                            }
                            .padding(Spacing.sm)
                        )
                        .blur(radius: blurAmount)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                    // Quality indicator overlay
                    if blurAmount > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Sıkıştırılmış")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedPresetId)
            }
        }
    }
}

// MARK: - Enhanced Preset Card with Flip Effect for Pro
struct EnhancedPresetCard: View {
    let preset: CompressionPreset
    var isSelected: Bool = false
    let onTap: () -> Void

    @State private var isFlipped = false
    @State private var isShaking = false

    // Custom icon colors for platforms
    private var iconColor: Color {
        switch preset.id {
        case "whatsapp": return Color(red: 0.15, green: 0.68, blue: 0.38) // WhatsApp green
        case "mail": return .blue
        case "quality": return .appAccent
        case "custom": return .purple
        default: return .appAccent
        }
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // Front of card
                frontContent
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )

                // Back of card (Pro info)
                if preset.isProOnly {
                    backContent
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(isFlipped ? 0 : -180),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        }
        .buttonStyle(.pressable)
        .offset(x: isShaking ? -5 : 0)
    }

    private var frontContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Icon and Pro badge row
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? iconColor : Color.appSurface)
                        .frame(width: 44, height: 44)

                    Image(systemName: preset.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : iconColor)
                }

                Spacer()

                if preset.isProOnly {
                    ProBadge()
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(iconColor)
                }
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(preset.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(preset.isProOnly ? .secondary : .primary)

                Text(preset.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(isSelected ? iconColor.opacity(0.08) : Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    isSelected ? iconColor : Color.clear,
                    lineWidth: 2
                )
        )
        .opacity(preset.isProOnly ? 0.85 : 1.0)
    }

    private var backContent: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.goldAccent, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Pro Özellik")
                .font(.appBodyMedium)
                .foregroundStyle(.primary)

            Text("Kilidi açmak için dokun")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.proGradientStart.opacity(0.1), Color.proGradientEnd.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.proGradientStart, .proGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private func handleTap() {
        if preset.isProOnly {
            // Flip animation for locked preset
            withAnimation {
                isFlipped.toggle()
            }
            Haptics.warning()

            // Auto-flip back and trigger paywall
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isFlipped = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onTap()
                }
            }
        } else {
            onTap()
        }
    }
}

// MARK: - Pro Badge (Crown style)
struct ProBadge: View {
    @State private var isGlowing = false

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "crown.fill")
                .font(.system(size: 10, weight: .bold))
            Text("PRO")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(
            LinearGradient(
                colors: [.goldAccent, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: Color.goldAccent.opacity(isGlowing ? 0.6 : 0.2), radius: isGlowing ? 8 : 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

#Preview {
    PresetScreen(
        onCompress: { preset in
            print("Selected: \(preset.name)")
        },
        onBack: {},
        onShowPaywall: {}
    )
}
