//
//  ScreenHeader.swift
//  optimize
//
//  Screen header with title, subtitle, and trailing action
//

import SwiftUI

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingButton: AnyView? = nil

    init(
        _ title: String,
        subtitle: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingButton = nil
    }

    init<TrailingButton: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> TrailingButton
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingButton = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.appTitle)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let trailingButton = trailingButton {
                trailingButton
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Header Button Styles
struct HeaderIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

struct HeaderCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ScreenHeader("Optimize")

        ScreenHeader("Analiz", subtitle: "Dosya detayları")

        ScreenHeader("Ayarlar") {
            HeaderIconButton(systemName: "gearshape") {}
        }

        ScreenHeader("Modal Ekran") {
            HeaderCloseButton {}
        }
    }
}
