//
//  SignatureCanvas.swift
//  optimize
//
//  A canvas component for capturing user signatures
//

import SwiftUI

struct SignatureCanvas: View {
    @Binding var signature: [CGPoint]
    @State private var currentPath: [CGPoint] = []
    let strokeColor: Color
    let strokeWidth: CGFloat
    let backgroundColor: Color

    init(
        signature: Binding<[CGPoint]>,
        strokeColor: Color = .white,
        strokeWidth: CGFloat = 3,
        backgroundColor: Color = Color.appAccent.opacity(0.3)
    ) {
        self._signature = signature
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // Signature line placeholder
                if signature.isEmpty && currentPath.isEmpty {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.bottom, geometry.size.height * 0.25)
                    }
                }

                // Draw signature
                Canvas { context, size in
                    // Draw saved signature
                    if !signature.isEmpty {
                        var path = Path()
                        path.addLines(signature)
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(
                                lineWidth: strokeWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }

                    // Draw current path
                    if !currentPath.isEmpty {
                        var path = Path()
                        path.addLines(currentPath)
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(
                                lineWidth: strokeWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentPath.append(value.location)
                    }
                    .onEnded { _ in
                        signature.append(contentsOf: currentPath)
                        currentPath = []
                    }
            )
        }
    }

    func clear() {
        signature = []
        currentPath = []
    }
}

// MARK: - Signature Canvas with Clear Button
struct SignatureCanvasWithControls: View {
    @Binding var signature: [CGPoint]
    let strokeColor: Color
    let backgroundColor: Color

    init(
        signature: Binding<[CGPoint]>,
        strokeColor: Color = .white,
        backgroundColor: Color = Color.appAccent.opacity(0.3)
    ) {
        self._signature = signature
        self.strokeColor = strokeColor
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            SignatureCanvas(
                signature: $signature,
                strokeColor: strokeColor,
                backgroundColor: backgroundColor
            )

            // Clear button
            if !signature.isEmpty {
                Button(action: {
                    Haptics.selection()
                    withAnimation(AppAnimation.standard) {
                        signature = []
                    }
                }) {
                    Text(AppStrings.Commitment.clear)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.appSurface.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appAccent.ignoresSafeArea()

        SignatureCanvasWithControls(
            signature: .constant([])
        )
        .frame(height: 200)
        .padding()
    }
}
