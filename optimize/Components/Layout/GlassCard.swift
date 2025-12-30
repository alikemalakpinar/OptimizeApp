//
//  GlassCard.swift
//  optimize
//
//  Glass material container component
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.md

    init(padding: CGFloat = Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassMaterial()
    }
}

// MARK: - Solid Card Variant
struct SolidCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.md
    var backgroundColor: Color = Color.appSurface

    init(
        padding: CGFloat = Spacing.md,
        backgroundColor: Color = Color.appSurface,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Glass Card")
                    .font(.appSection)
                Text("This is a glass material card with blur effect")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        SolidCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Solid Card")
                    .font(.appSection)
                Text("This is a solid background card")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
}
