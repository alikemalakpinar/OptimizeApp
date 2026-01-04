//
//  FilePreviewCard.swift
//  optimize
//
//  Universal file preview component - supports PDF, Images, Videos, Documents
//  ULTIMATE PREVIEW SYSTEM v2.0
//

import SwiftUI
import UIKit
import PDFKit
import AVFoundation
import QuickLook

// MARK: - Universal File Preview Card

struct FilePreviewCard: View {
    let url: URL
    let pageCount: Int?

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    @State private var currentPreviewPage = 0
    @State private var videoDuration: String?
    @State private var showQuickLook = false

    private let maxPreviewPages = 3

    /// Detect file type from URL
    private var fileType: PreviewFileType {
        PreviewFileType.from(extension: url.pathExtension)
    }

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.sm) {
                // Header with file type indicator
                previewHeader

                // Thumbnail preview area
                ZStack {
                    if isLoading {
                        LoadingThumbnail()
                    } else if let image = thumbnailImage {
                        previewContent(image: image)
                    } else {
                        ErrorThumbnail(fileType: fileType)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.glassBorder, lineWidth: 0.5)
                )
                .onTapGesture {
                    // Full preview with QuickLook
                    showQuickLook = true
                }

                // Quick info badges
                QuickInfoBadges(url: url, pageCount: pageCount, fileType: fileType, videoDuration: videoDuration)
            }
        }
        .onAppear {
            loadPreview()
        }
        .sheet(isPresented: $showQuickLook) {
            QuickLookPreview(url: url)
        }
    }

    // MARK: - Header

    private var previewHeader: some View {
        HStack {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: fileType.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(fileType.color)
                Text("File Preview")
                    .font(.appCaptionMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Page/duration indicator
            if let count = pageCount, count > 1, fileType == .pdf {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                    Text("\(count) pages")
                        .font(.appCaption)
                }
                .foregroundStyle(.tertiary)
            } else if let duration = videoDuration {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text(duration)
                        .font(.appCaption)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Preview Content

    @ViewBuilder
    private func previewContent(image: UIImage) -> some View {
        switch fileType {
        case .pdf:
            ThumbnailView(
                image: image,
                pageCount: pageCount,
                currentPage: currentPreviewPage,
                maxPages: maxPreviewPages,
                onPageChange: { newPage in
                    loadPDFPage(newPage)
                }
            )

        case .image:
            ImagePreviewView(image: image)

        case .video:
            VideoPreviewView(image: image, duration: videoDuration)

        case .document, .unknown:
            DocumentPreviewView(image: image, fileType: fileType)
        }
    }

    // MARK: - Load Preview

    private func loadPreview() {
        isLoading = true

        Task {
            let image: UIImage?

            switch fileType {
            case .pdf:
                image = await renderPDFPage(url: url, pageIndex: 0)
            case .image:
                image = await loadImageThumbnail(url: url)
            case .video:
                let (thumbnail, duration) = await generateVideoThumbnail(url: url)
                image = thumbnail
                await MainActor.run { videoDuration = duration }
            case .document:
                image = await generateDocumentThumbnail(url: url)
            case .unknown:
                image = nil
            }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    thumbnailImage = image
                    isLoading = false
                }
            }
        }
    }

    private func loadPDFPage(_ pageIndex: Int) {
        currentPreviewPage = pageIndex
        isLoading = true

        Task {
            let image = await renderPDFPage(url: url, pageIndex: pageIndex)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    thumbnailImage = image
                    isLoading = false
                }
            }
        }
    }

    // MARK: - PDF Rendering

    private func renderPDFPage(url: URL, pageIndex: Int) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStopAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

                guard let document = PDFDocument(url: url),
                      let page = document.page(at: pageIndex) else {
                    continuation.resume(returning: nil)
                    return
                }

                let bounds = page.bounds(for: .mediaBox)
                let scale = min(400 / bounds.width, 400 / bounds.height, 2.0)
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
                    kCGImageSourceThumbnailMaxPixelSize: 400,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]

                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    // Fallback: Load full image and resize
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        continuation.resume(returning: image.resized(toMaxDimension: 400))
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

    private func generateVideoThumbnail(url: URL) async -> (UIImage?, String?) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStopAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 400, height: 400)

                // Get duration
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                let duration = formatDuration(durationSeconds)

                // Generate thumbnail at 1 second or 10% into video
                let time = CMTime(seconds: min(1.0, durationSeconds * 0.1), preferredTimescale: 600)

                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    continuation.resume(returning: (thumbnail, duration))
                } catch {
                    // Try at start of video
                    do {
                        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                        let thumbnail = UIImage(cgImage: cgImage)
                        continuation.resume(returning: (thumbnail, duration))
                    } catch {
                        continuation.resume(returning: (nil, duration))
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds > 0 else { return "0:00" }

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // MARK: - Document Thumbnail

    private func generateDocumentThumbnail(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let shouldStopAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

                // Try QuickLook thumbnail generation
                let size = CGSize(width: 400, height: 400)
                let request = QLThumbnailGenerator.Request(
                    fileAt: url,
                    size: size,
                    scale: UIScreen.main.scale,
                    representationTypes: .all
                )

                QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, _, error in
                    if let thumbnail = thumbnail {
                        continuation.resume(returning: thumbnail.uiImage)
                    } else {
                        // Fallback: Create text preview for text files
                        if let textPreview = self.createTextPreview(url: url) {
                            continuation.resume(returning: textPreview)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
        }
    }

    private func createTextPreview(url: URL) -> UIImage? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let previewText = String(content.prefix(500))
        let size = CGSize(width: 300, height: 400)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraphStyle
            ]

            let textRect = CGRect(x: 12, y: 12, width: size.width - 24, height: size.height - 24)
            previewText.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Preview File Type

enum PreviewFileType {
    case pdf
    case image
    case video
    case document
    case unknown

    static func from(extension ext: String) -> PreviewFileType {
        switch ext.lowercased() {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif":
            return .image
        case "mp4", "mov", "avi", "mkv", "m4v", "webm", "3gp":
            return .video
        case "txt", "rtf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "json", "xml", "html", "md":
            return .document
        default:
            return .unknown
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .document: return "doc.text.fill"
        case .unknown: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .pdf: return .red
        case .image: return .blue
        case .video: return .purple
        case .document: return .orange
        case .unknown: return .gray
        }
    }
}

// MARK: - Image Preview View

private struct ImagePreviewView: View {
    let image: UIImage

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.1), radius: 4)

            // Tap hint
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                }
            }
        }
    }
}

// MARK: - Video Preview View

private struct VideoPreviewView: View {
    let image: UIImage
    let duration: String?

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.1), radius: 4)

            // Play button overlay
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 4)

            // Duration badge
            if let duration = duration {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                }
            }
        }
    }
}

// MARK: - Document Preview View

private struct DocumentPreviewView: View {
    let image: UIImage
    let fileType: PreviewFileType

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.1), radius: 4)

            // File type indicator
            VStack {
                Spacer()
                HStack {
                    Image(systemName: fileType.icon)
                        .font(.system(size: 10))
                    Text("Tap to preview")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}

// MARK: - UIImage Extension

private extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Thumbnail View
private struct ThumbnailView: View {
    let image: UIImage
    let pageCount: Int?
    let currentPage: Int
    let maxPages: Int
    let onPageChange: (Int) -> Void

    var body: some View {
        ZStack {
            // Thumbnail image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.1), radius: 4)

            // Page navigation arrows (if multiple pages)
            if let count = pageCount, count > 1 {
                HStack {
                    // Previous page button
                    if currentPage > 0 {
                        PageNavButton(direction: .left) {
                            Haptics.selection()
                            onPageChange(currentPage - 1)
                        }
                    }

                    Spacer()

                    // Next page button
                    if currentPage < min(count - 1, maxPages - 1) {
                        PageNavButton(direction: .right) {
                            Haptics.selection()
                            onPageChange(currentPage + 1)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)

                // Page indicator dots
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<min(count, maxPages), id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.appAccent : Color.white.opacity(0.5))
                                .frame(width: 6, height: 6)
                        }
                        if count > maxPages {
                            Text("+\(count - maxPages)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, Spacing.xs)
                }
            }
        }
    }
}

// MARK: - Page Navigation Button
private struct PageNavButton: View {
    enum Direction {
        case left, right

        var icon: String {
            self == .left ? "chevron.left" : "chevron.right"
        }
    }

    let direction: Direction
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 2)
        }
    }
}

// MARK: - Loading Thumbnail
private struct LoadingThumbnail: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Color.appSurface)
            .overlay(
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Loading...")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            )
    }
}

// MARK: - Error Thumbnail
private struct ErrorThumbnail: View {
    var fileType: PreviewFileType = .unknown

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Color.appSurface)
            .overlay(
                VStack(spacing: Spacing.sm) {
                    Image(systemName: fileType.icon)
                        .font(.largeTitle)
                        .foregroundStyle(fileType.color.opacity(0.5))
                    Text("Preview unavailable")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                    Text("Tap to open")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            )
    }
}

// MARK: - Quick Info Badges
private struct QuickInfoBadges: View {
    let url: URL
    let pageCount: Int?
    var fileType: PreviewFileType = .unknown
    var videoDuration: String? = nil

    @State private var fileSize: String = ""

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // File type badge with color
            HStack(spacing: 4) {
                Image(systemName: fileType.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(fileType.color)
                Text(url.pathExtension.uppercased())
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fileType.color.opacity(0.1))
            .clipShape(Capsule())

            // File size badge
            if !fileSize.isEmpty {
                InfoBadgeSmall(icon: "arrow.down.doc", text: fileSize)
            }

            // Video duration badge
            if let duration = videoDuration {
                InfoBadgeSmall(icon: "clock", text: duration)
            }

            Spacer()

            // Verified badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMint)
                Text("Verified")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            loadFileSize()
        }
    }

    private func loadFileSize() {
        let shouldStopAccess = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
}

// MARK: - Small Info Badge
private struct InfoBadgeSmall: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appSurface)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        FilePreviewCard(
            url: URL(fileURLWithPath: "/test.pdf"),
            pageCount: 12
        )
        .padding()
    }
    .appBackgroundLayered()
}
