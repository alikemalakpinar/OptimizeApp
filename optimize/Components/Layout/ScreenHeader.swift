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

// MARK: - Navigation Header (with back button and centered title)
struct NavigationHeader: View {
    let title: String
    let onBack: () -> Void
    var trailingButton: AnyView? = nil

    init(
        _ title: String,
        onBack: @escaping () -> Void
    ) {
        self.title = title
        self.onBack = onBack
        self.trailingButton = nil
    }

    init<TrailingButton: View>(
        _ title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: () -> TrailingButton
    ) {
        self.title = title
        self.onBack = onBack
        self.trailingButton = AnyView(trailing())
    }

    var body: some View {
        ZStack {
            // Centered title
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            // Leading back button
            HStack {
                Button(action: {
                    Haptics.selection()
                    onBack()
                }) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.pressable)

                Spacer()

                // Trailing button (invisible placeholder if none)
                if let trailingButton = trailingButton {
                    trailingButton
                } else {
                    Color.clear
                        .frame(width: 60)
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Spacing.md)
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
