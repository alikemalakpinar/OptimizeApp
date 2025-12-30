//
//  InfoBanner.swift
//  optimize
//
//  Info, warning, error banners for contextual messages
//

import SwiftUI

enum BannerType {
    case info
    case warning
    case error
    case success

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .statusWarning
        case .error: return .statusError
        case .success: return .statusSuccess
        }
    }
}

struct InfoBanner: View {
    let type: BannerType
    let message: String
    var dismissable: Bool = false
    var onDismiss: (() -> Void)? = nil

    @State private var isVisible = true

    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(type.color)

                Text(message)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if dismissable {
                    Button(action: {
                        withAnimation(AppAnimation.quick) {
                            isVisible = false
                        }
                        onDismiss?()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(Spacing.sm)
            .background(type.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

// MARK: - Privacy Badge
struct PrivacyBadge: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            PrivacyItem(icon: "link.badge.plus", text: "No links", crossed: true)
            PrivacyItem(icon: "trash", text: "Auto deleted")
            PrivacyItem(icon: "lock.shield", text: "Encrypted")
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color.statusSuccess.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

struct PrivacyItem: View {
    let icon: String
    let text: String
    var crossed: Bool = false

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.statusSuccess)

                if crossed {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.statusSuccess)
                }
            }

            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        InfoBanner(
            type: .info,
            message: "This operation may take a few minutes."
        )

        InfoBanner(
            type: .warning,
            message: "This file may already be optimized.",
            dismissable: true
        )

        InfoBanner(
            type: .error,
            message: "An error occurred while loading the file."
        )

        InfoBanner(
            type: .success,
            message: "File optimized successfully!"
        )

        PrivacyBadge()
    }
    .padding()
}
