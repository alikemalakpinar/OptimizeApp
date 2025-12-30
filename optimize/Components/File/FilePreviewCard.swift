//
//  FilePreviewCard.swift
//  optimize
//
//  PDF preview thumbnail component for file verification before compression
//

import SwiftUI
import PDFKit

struct FilePreviewCard: View {
    let url: URL
    let pageCount: Int?

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    @State private var currentPreviewPage = 0

    private let maxPreviewPages = 3

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.sm) {
                // Header
                HStack {
                    Text("File Preview")
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Page indicator
                    if let count = pageCount, count > 1 {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                            Text("\(count) pages")
                                .font(.appCaption)
                        }
                        .foregroundStyle(.tertiary)
                    }
                }

                // Thumbnail preview area
                ZStack {
                    if isLoading {
                        LoadingThumbnail()
                    } else if let image = thumbnailImage {
                        ThumbnailView(
                            image: image,
                            pageCount: pageCount,
                            currentPage: currentPreviewPage,
                            maxPages: maxPreviewPages,
                            onPageChange: { newPage in
                                loadPage(newPage)
                            }
                        )
                    } else {
                        ErrorThumbnail()
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.glassBorder, lineWidth: 0.5)
                )

                // Quick info badges
                QuickInfoBadges(url: url, pageCount: pageCount)
            }
        }
        .onAppear {
            loadPage(0)
        }
    }

    private func loadPage(_ pageIndex: Int) {
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
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Color.appSurface)
            .overlay(
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "doc.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Preview unavailable")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            )
    }
}

// MARK: - Quick Info Badges
private struct QuickInfoBadges: View {
    let url: URL
    let pageCount: Int?

    @State private var fileSize: String = ""

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // File type badge
            InfoBadgeSmall(icon: "doc.fill", text: url.pathExtension.uppercased())

            // File size badge
            if !fileSize.isEmpty {
                InfoBadgeSmall(icon: "arrow.down.doc", text: fileSize)
            }

            Spacer()

            // Verified badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMint)
                Text("File verified")
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
