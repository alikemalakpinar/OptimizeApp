//
//  PresetCard.swift
//  optimize
//
//  Preset selection card with Pro lock state
//

import SwiftUI

struct PresetCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var isSelected: Bool = false
    var isProLocked: Bool = false
    let onTap: () -> Void

    @State private var isShaking = false

    var body: some View {
        Button(action: {
            if isProLocked {
                // Shake animation for locked preset
                withAnimation(Animation.spring(response: 0.2, dampingFraction: 0.2)) {
                    isShaking = true
                }
                Haptics.warning()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isShaking = false
                }
            } else {
                Haptics.selection()
            }
            onTap()
        }) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Icon and Pro badge row
                HStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.appSurface)
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }

                    Spacer()

                    if isProLocked {
                        ProLockPill()
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.appAccent)
                    }
                }

                // Title and subtitle
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.appBodyMedium)
                        .foregroundStyle(isProLocked ? .secondary : .primary)

                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isSelected ? Color.appAccent.opacity(0.08) : Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        isSelected ? Color.appAccent : Color.clear,
                        lineWidth: 2
                    )
            )
            .opacity(isProLocked ? 0.7 : 1.0)
        }
        .buttonStyle(.pressable)
        .offset(x: isShaking ? -5 : 0)
    }
}

// MARK: - Pro Lock Pill
struct ProLockPill: View {
    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text("PRO")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
    }
}

// MARK: - Preset Grid
struct PresetGrid: View {
    let presets: [PresetItem]
    @Binding var selectedId: String?

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.sm),
                GridItem(.flexible(), spacing: Spacing.sm)
            ],
            spacing: Spacing.sm
        ) {
            ForEach(presets) { preset in
                PresetCard(
                    title: preset.title,
                    subtitle: preset.subtitle,
                    icon: preset.icon,
                    isSelected: selectedId == preset.id,
                    isProLocked: preset.isProLocked
                ) {
                    if !preset.isProLocked {
                        withAnimation(AppAnimation.spring) {
                            selectedId = preset.id
                        }
                    } else {
                        // Trigger paywall
                    }
                }
                .staggeredAppearance(index: presets.firstIndex(where: { $0.id == preset.id }) ?? 0)
            }
        }
    }
}

// MARK: - Preset Item Model
struct PresetItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    var isProLocked: Bool = false
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            PresetCard(
                title: "Mail (25 MB)",
                subtitle: "E-posta eklerine uygun",
                icon: "envelope.fill",
                isSelected: true,
                onTap: {}
            )

            PresetCard(
                title: "WhatsApp",
                subtitle: "Hızlı paylaşım için optimize",
                icon: "message.fill",
                onTap: {}
            )

            PresetCard(
                title: "Özel Boyut",
                subtitle: "Hedef boyut belirle",
                icon: "slider.horizontal.3",
                isProLocked: true,
                onTap: {}
            )

            ProLockPill()
        }
        .padding()
    }
}
