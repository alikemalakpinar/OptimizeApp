//
//  BeforeAfterSlider.swift
//  optimize
//
//  Interactive before/after comparison slider for visual quality verification
//

import SwiftUI
import PDFKit

// MARK: - Before/After Slider Component
struct BeforeAfterSlider: View {
    let originalURL: URL
    let compressedURL: URL

    @State private var sliderPosition: CGFloat = 0.5
    @State private var originalImage: UIImage?
    @State private var compressedImage: UIImage?
    @State private var isLoading = true
    @State private var isDragging = false

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.sm) {
                // Header
                HStack {
                    Text("Kalite Karsilastirmasi")
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary)
                    Spacer()

                    // Drag hint
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 12))
                        Text("Kaydir")
                            .font(.appCaption)
                    }
                    .foregroundStyle(.tertiary)
                }

                // Comparison View
                if isLoading {
                    LoadingPlaceholder()
                } else if let original = originalImage, let compressed = compressedImage {
                    ComparisonView(
                        originalImage: original,
                        compressedImage: compressed,
                        sliderPosition: $sliderPosition,
                        isDragging: $isDragging
                    )
                } else {
                    ErrorPlaceholder()
                }
            }
        }
        .onAppear {
            loadImages()
        }
    }

    private func loadImages() {
        Task {
            // Load original PDF first page
            originalImage = await renderPDFFirstPage(url: originalURL)
            compressedImage = await renderPDFFirstPage(url: compressedURL)

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        }
    }

    private func renderPDFFirstPage(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Access security-scoped resource if needed
                let shouldStopAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

                guard let document = PDFDocument(url: url),
                      let page = document.page(at: 0) else {
                    continuation.resume(returning: nil)
                    return
                }

                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = min(600 / bounds.width, 600 / bounds.height, 2.0)
                let renderSize = CGSize(
                    width: bounds.width * scale,
                    height: bounds.height * scale
                )

                let renderer = UIGraphicsImageRenderer(size: renderSize)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: renderSize))

                    ctx.cgContext.translateBy(x: 0, y: renderSize.height)
                    ctx.cgContext.scaleBy(x: scale, y: -scale)

                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }

                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Comparison View
private struct ComparisonView: View {
    let originalImage: UIImage
    let compressedImage: UIImage
    @Binding var sliderPosition: CGFloat
    @Binding var isDragging: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                // Bottom Layer (Compressed - After)
                Image(uiImage: compressedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)

                // Top Layer (Original - Before) with mask
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: geo.size.width * sliderPosition)
                            Spacer(minLength: 0)
                        }
                    )

                // Slider Line
                SliderHandle(position: sliderPosition, width: geo.size.width, isDragging: $isDragging)
                    .offset(x: (geo.size.width * sliderPosition) - (geo.size.width / 2))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let newPos = value.location.x / geo.size.width
                                sliderPosition = min(max(newPos, 0.05), 0.95)
                                Haptics.impact(style: .light)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )

                // Labels
                OverlayLabels(sliderPosition: sliderPosition, isDragging: isDragging)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.glassBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Slider Handle
private struct SliderHandle: View {
    let position: CGFloat
    let width: CGFloat
    @Binding var isDragging: Bool

    var body: some View {
        ZStack {
            // Vertical line
            Rectangle()
                .fill(.white)
                .frame(width: 2)
                .shadow(color: .black.opacity(0.3), radius: 4)

            // Handle circle
            Circle()
                .fill(.white)
                .frame(width: isDragging ? 36 : 30, height: isDragging ? 36 : 30)
                .shadow(color: .black.opacity(0.2), radius: 4)
                .overlay(
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: isDragging ? 14 : 12, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                )
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        }
    }
}

// MARK: - Overlay Labels
private struct OverlayLabels: View {
    let sliderPosition: CGFloat
    let isDragging: Bool

    var body: some View {
        VStack {
            HStack {
                // Original label
                Text("Original")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(sliderPosition > 0.15 ? 1 : 0)

                Spacer()

                // Optimized label
                Text("Optimize")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.appMint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(sliderPosition < 0.85 ? 1 : 0)
            }
            .padding(Spacing.xs)

            Spacer()

            // Quality indicator during drag
            if isDragging {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.appMint)
                    Text("Quality preserved")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, Spacing.xs)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
}

// MARK: - Loading Placeholder
private struct LoadingPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Color.appSurface)
            .frame(height: 200)
            .overlay(
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Onizleme hazirlaniyor...")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            )
    }
}

// MARK: - Error Placeholder
private struct ErrorPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Color.appSurface)
            .frame(height: 200)
            .overlay(
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "eye.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Onizleme kullanilamiyor")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            )
    }
}

#Preview {
    VStack {
        BeforeAfterSlider(
            originalURL: URL(fileURLWithPath: "/test.pdf"),
            compressedURL: URL(fileURLWithPath: "/test_compressed.pdf")
        )
        .padding()
    }
    .appBackgroundLayered()
}
