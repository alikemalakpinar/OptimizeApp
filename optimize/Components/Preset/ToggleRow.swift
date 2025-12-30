//
//  ToggleRow.swift
//  optimize
//
//  Toggle switch row for settings
//

import SwiftUI

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.appBody)
                        .foregroundStyle(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(Color.appAccent)
        .onChange(of: isOn) { _, _ in
            Haptics.selection()
        }
    }
}

// MARK: - Settings Toggle Section
struct ToggleSection: View {
    let title: String?
    let toggles: [ToggleItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let title = title {
                Text(title)
                    .font(.appSection)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, Spacing.md)
            }

            GlassCard {
                VStack(spacing: Spacing.md) {
                    ForEach(Array(toggles.enumerated()), id: \.element.id) { index, toggle in
                        ToggleRow(
                            title: toggle.title,
                            subtitle: toggle.subtitle,
                            icon: toggle.icon,
                            isOn: toggle.binding
                        )

                        if index < toggles.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Toggle Item Model
struct ToggleItem: Identifiable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var binding: Binding<Bool>
}

// MARK: - Picker Row
struct PickerRow<T: Hashable>: View {
    let title: String
    var icon: String? = nil
    let options: [T]
    let optionLabel: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            Text(title)
                .font(.appBody)
                .foregroundStyle(.primary)

            Spacer()

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        Haptics.selection()
                        selection = option
                    }) {
                        HStack {
                            Text(optionLabel(option))
                            if option == selection {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text(optionLabel(selection))
                        .font(.appBody)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var wifiOnly = true
        @State private var deleteAfter = false
        @State private var selectedPreset = "whatsapp"

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    GlassCard {
                        VStack(spacing: Spacing.md) {
                            ToggleRow(
                                title: "Process on Wi-Fi",
                                subtitle: "Don't use mobile data",
                                icon: "wifi",
                                isOn: $wifiOnly
                            )

                            Divider()

                            ToggleRow(
                                title: "Delete after processing",
                                icon: "trash",
                                isOn: $deleteAfter
                            )
                        }
                    }

                    GlassCard {
                        PickerRow(
                            title: "Default preset",
                            icon: "slider.horizontal.3",
                            options: ["mail", "whatsapp", "quality"],
                            optionLabel: { option in
                                switch option {
                                case "mail": return "Mail (25 MB)"
                                case "whatsapp": return "WhatsApp"
                                case "quality": return "Best Quality"
                                default: return option
                                }
                            },
                            selection: $selectedPreset
                        )
                    }
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
