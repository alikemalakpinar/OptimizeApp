//
//  BeforeAfterSlider.swift
//  optimize
//
//  Interactive before/after comparison slider for visual quality verification
//  UNIVERSAL FILE SUPPORT v2.0 - PDF, Images, Videos
//

import SwiftUI
import UIKit
import PDFKit
import AVFoundation

// MARK: - Before/After Slider Component
struct BeforeAfterSlider: View {
    let originalURL: URL
    let compressedURL: URL

    @State private var sliderPosition: CGFloat = 0.5
    @State private var originalImage: UIImage?
    @State private var compressedImage: UIImage?
    @State private var isLoading = true
    @State private var isDragging = false

    /// Detect file type from URL
    private var fileType: ComparisonFileType {
        ComparisonFileType.from(extension: originalURL.pathExtension)
    }

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.sm) {
                // Header with file type indicator
                HStack {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: fileType.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(fileType.color)
                        Text(AppStrings.ResultScreen.qualityComparison)
                            .font(.appCaptionMedium)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    // Interaction hint - Drag or hold
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 12))
                        Text(AppStrings.ResultScreen.dragOrHold)
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
            // Load based on file type
            switch fileType {
            case .pdf:
                originalImage = await renderPDFFirstPage(url: originalURL)
                compressedImage = await renderPDFFirstPage(url: compressedURL)
            case .image:
                originalImage = await loadImageThumbnail(url: originalURL)
                compressedImage = await loadImageThumbnail(url: compressedURL)
            case .video:
                originalImage = await generateVideoThumbnail(url: originalURL)
                compressedImage = await generateVideoThumbnail(url: compressedURL)
            case .other:
                // For other types, try generic thumbnail
                originalImage = await loadGenericThumbnail(url: originalURL)
                compressedImage = await loadGenericThumbnail(url: compressedURL)
            }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        }
    }

    // MARK: - PDF Rendering

    private func renderPDFFirstPage(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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

    // MARK: - Image Loading

    private func loadImageThumbnail(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStopAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

                // Use ImageIO for efficient thumbnail generation
                let options: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: 600,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]

                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    // Fallback: Load full image
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        continuation.resume(returning: image.resizedForComparison(maxDimension: 600))
                    } else {
                        continuation.resume(returning: nil)
                    }
                    return
                }

                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }

    // MARK: - Video Thumbnail

    private func generateVideoThumbnail(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStopAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 600, height: 600)

                // Get frame at 1 second or 10% into video
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                let time = CMTime(seconds: min(1.0, durationSeconds * 0.1), preferredTimescale: 600)

                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } catch {
                    // Try at start
                    do {
                        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    // MARK: - Generic Thumbnail

    private func loadGenericThumbnail(url: URL) async -> UIImage? {
        // Try QuickLook first, then fall back to icon
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStopAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

                // Create a placeholder with file icon
                let size = CGSize(width: 300, height: 300)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { ctx in
                    UIColor.systemGray6.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))

                    // Draw file icon
                    let icon = UIImage(systemName: "doc.fill")?.withTintColor(.systemGray)
                    let iconSize: CGFloat = 80
                    let iconRect = CGRect(
                        x: (size.width - iconSize) / 2,
                        y: (size.height - iconSize) / 2 - 20,
                        width: iconSize,
                        height: iconSize
                    )
                    icon?.draw(in: iconRect)

                    // Draw filename
                    let filename = url.lastPathComponent
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                        .foregroundColor: UIColor.darkGray,
                        .paragraphStyle: paragraphStyle
                    ]
                    let textRect = CGRect(x: 20, y: size.height - 60, width: size.width - 40, height: 40)
                    filename.draw(in: textRect, withAttributes: attrs)
                }

                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Comparison File Type

private enum ComparisonFileType {
    case pdf
    case image
    case video
    case other

    static func from(extension ext: String) -> ComparisonFileType {
        switch ext.lowercased() {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif":
            return .image
        case "mp4", "mov", "avi", "mkv", "m4v", "webm", "3gp":
            return .video
        default:
            return .other
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .other: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .pdf: return .red
        case .image: return .blue
        case .video: return .purple
        case .other: return .gray
        }
    }
}

// MARK: - UIImage Extension

private extension UIImage {
    func resizedForComparison(maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Comparison View
/// Interactive comparison with two modes:
/// 1. SLIDER MODE: Drag left/right to compare
/// 2. PRESS-TO-COMPARE: Long press to see original (Instagram style)
private struct ComparisonView: View {
    let originalImage: UIImage
    let compressedImage: UIImage
    @Binding var sliderPosition: CGFloat
    @Binding var isDragging: Bool

    /// Press-to-compare state (Instagram style)
    @State private var isShowingOriginal = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                // Bottom Layer (Compressed - After)
                Image(uiImage: compressedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(isShowingOriginal ? 0 : 1)

                // Top Layer (Original - Before)
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(isShowingOriginal ? 1 : 0)
                    .mask(
                        Group {
                            if isShowingOriginal {
                                Rectangle() // Full visibility when pressing
                            } else {
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .frame(width: geo.size.width * sliderPosition)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    )

                // Slider Line (hidden during press-to-compare)
                if !isShowingOriginal {
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
                }

                // Labels with press-to-compare indicator
                OverlayLabels(
                    sliderPosition: sliderPosition,
                    isDragging: isDragging,
                    isShowingOriginal: isShowingOriginal
                )
            }
            // PRESS-TO-COMPARE: Long press to see original
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isShowingOriginal = pressing
                }
                if pressing {
                    Haptics.impact(style: .medium)
                }
            }, perform: { })
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
    var isShowingOriginal: Bool = false

    var body: some View {
        VStack {
            HStack {
                // Original label
                Text(AppStrings.ResultScreen.before)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(isShowingOriginal || sliderPosition > 0.15 ? 1 : 0)

                Spacer()

                // Optimized label
                Text(AppStrings.ResultScreen.after)
                    .font(.caption2.bold())
                    .foregroundStyle(Color.appMint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(!isShowingOriginal && sliderPosition < 0.85 ? 1 : 0)
            }
            .padding(Spacing.xs)

            Spacer()

            // Press-to-compare hint OR quality indicator
            if isShowingOriginal {
                // Showing original indicator
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundStyle(.white)
                    Text(AppStrings.ResultScreen.before)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(.bottom, Spacing.xs)
                .transition(.scale.combined(with: .opacity))
            } else if isDragging {
                // Quality indicator during drag
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.appMint)
                    Text(AppStrings.QualityBadge.title)
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
        .animation(.easeInOut(duration: 0.15), value: isShowingOriginal)
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
