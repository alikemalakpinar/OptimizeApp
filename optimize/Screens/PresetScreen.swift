//
//  PresetScreen.swift
//  optimize
//
//  Preset selection screen
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
            // Header with back button
            HStack {
                Button(action: {
                    Haptics.selection()
                    onBack()
                }) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Geri")
                            .font(.appBody)
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.pressable)

                Spacer()

                Text("Hedef")
                    .font(.appSection)
                    .foregroundStyle(.primary)

                Spacer()

                // Placeholder for alignment
                Color.clear
                    .frame(width: 60)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Preset Grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Spacing.sm),
                            GridItem(.flexible(), spacing: Spacing.sm)
                        ],
                        spacing: Spacing.sm
                    ) {
                        ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                            PresetCard(
                                title: preset.name,
                                subtitle: preset.description,
                                icon: preset.icon,
                                isSelected: selectedPresetId == preset.id,
                                isProLocked: preset.isProOnly
                            ) {
                                if preset.isProOnly {
                                    onShowPaywall()
                                } else {
                                    withAnimation(AppAnimation.spring) {
                                        selectedPresetId = preset.id
                                    }
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

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
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
        .background(Color.appBackground)
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
