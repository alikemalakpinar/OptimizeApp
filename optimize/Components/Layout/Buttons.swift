//
//  Buttons.swift
//  optimize
//
//  Primary, Secondary, and Text button components
//

import SwiftUI

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard !isLoading && !isDisabled else { return }
            Haptics.impact(style: .light)
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.appBodyMedium)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(isDisabled ? Color.appAccent.opacity(0.5) : Color.appAccent)
            )
        }
        .buttonStyle(.pressable)
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text(title)
                        .font(.appBodyMedium)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(Color.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .disabled(isLoading)
    }
}

// MARK: - Text Button
struct TextButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.xxs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.appBodyMedium)
            }
            .foregroundStyle(Color.appAccent)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Icon Badge
struct IconBadge: View {
    let icon: String
    let text: String
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(.appCaption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Action Sheet Buttons
struct ActionSheetButtons: View {
    let primaryTitle: String
    let primaryIcon: String
    let primaryAction: () -> Void

    let secondaryTitle: String
    let secondaryIcon: String
    let secondaryAction: () -> Void

    var tertiaryTitle: String? = nil
    var tertiaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: primaryTitle, icon: primaryIcon, action: primaryAction)

            SecondaryButton(title: secondaryTitle, icon: secondaryIcon, action: secondaryAction)

            if let tertiaryTitle = tertiaryTitle, let tertiaryAction = tertiaryAction {
                TextButton(title: tertiaryTitle, action: tertiaryAction)
                    .padding(.top, Spacing.xs)
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton(title: "Dosya Seç", icon: "doc.badge.plus") {}

        PrimaryButton(title: "Yükleniyor", isLoading: true) {}

        PrimaryButton(title: "Devre Dışı", isDisabled: true) {}

        SecondaryButton(title: "Dosyalara Kaydet", icon: "square.and.arrow.down") {}

        TextButton(title: "Yeni dosya seç", icon: "arrow.counterclockwise") {}

        HStack {
            IconBadge(icon: "link.badge.plus", text: "Link yok", color: .green)
            IconBadge(icon: "trash", text: "Otomatik silinir", color: .orange)
        }
    }
    .padding()
}
