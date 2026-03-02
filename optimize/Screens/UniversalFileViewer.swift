//
//  UniversalFileViewer.swift
//  optimize
//
//  Full-screen file viewer wrapping QLPreviewController (QuickLook)
//  with a modern SwiftUI overlay for sharing, saving, and metadata display.
//
//  ARCHITECTURE:
//  - UIViewControllerRepresentable wrapping QLPreviewController
//  - Translucent navigation bar with Share/Save actions
//  - Floating GlassCard showing file metadata (size, format, resolution)
//  - Integrates with AppCoordinator for navigation and ResultViewModel for actions
//

import SwiftUI
import QuickLook
import UIKit

// MARK: - Universal File Viewer

struct UniversalFileViewer: View {
    let fileURL: URL
    let fileName: String
    let fileSize: Int64?
    let fileType: FileType

    let onShare: () -> Void
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var showMetadata = true
    @State private var metadataOpacity: Double = 0
    @State private var resolution: String?

    var body: some View {
        ZStack {
            // QuickLook Preview (full screen)
            QuickLookPreview(url: fileURL)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(AppAnimation.standard) {
                        showMetadata.toggle()
                    }
                }

            // Overlay UI
            VStack(spacing: 0) {
                // Translucent Navigation Bar
                fileViewerNavBar
                    .opacity(showMetadata ? 1 : 0)

                Spacer()

                // Floating Metadata Card
                if showMetadata {
                    fileMetadataCard
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Color.black)
        .onAppear {
            loadResolution()
            withAnimation(AppAnimation.standard.delay(0.3)) {
                metadataOpacity = 1
            }
        }
    }

    // MARK: - Translucent Navigation Bar

    private var fileViewerNavBar: some View {
        HStack {
            // Close button
            Button(action: {
                Haptics.selection()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Circle())
            }

            Spacer()

            // File name (centered, truncated)
            Text(fileName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: 200)

            Spacer()

            // Action buttons
            HStack(spacing: Spacing.sm) {
                // Share
                Button(action: {
                    Haptics.impact()
                    onShare()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Circle())
                }

                // Save
                Button(action: {
                    Haptics.impact()
                    onSave()
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - File Metadata Card

    private var fileMetadataCard: some View {
        GlassCard(padding: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Format
                MetadataItem(
                    icon: fileType.icon,
                    label: AppStrings.FileViewer.format,
                    value: fileFormatString
                )

                Divider()
                    .frame(height: 32)

                // Size
                MetadataItem(
                    icon: "internaldrive",
                    label: AppStrings.FileViewer.size,
                    value: formattedSize
                )

                // Resolution (images/videos only)
                if let resolution = resolution {
                    Divider()
                        .frame(height: 32)

                    MetadataItem(
                        icon: "aspectratio",
                        label: AppStrings.FileViewer.resolution,
                        value: resolution
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(metadataOpacity)
    }

    // MARK: - Helpers

    private var fileFormatString: String {
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? fileType.icon : ext
    }

    private var formattedSize: String {
        guard let size = fileSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func loadResolution() {
        guard fileType == .image || fileType == .video else { return }

        Task.detached {
            let res = await Self.getResolution(for: fileURL, type: fileType)
            await MainActor.run {
                resolution = res
            }
        }
    }

    private static func getResolution(for url: URL, type: FileType) async -> String? {
        guard type == .image else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return "\(width) × \(height)"
    }
}

// MARK: - Metadata Item

private struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.dataSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - QuickLook Preview (UIViewControllerRepresentable)

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        // Hide the default navigation bar — we use our own SwiftUI overlay
        controller.navigationItem.rightBarButtonItems = []
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        // MARK: - QLPreviewControllerDataSource

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

// MARK: - Preview

#Preview {
    UniversalFileViewer(
        fileURL: URL(fileURLWithPath: "/tmp/sample.pdf"),
        fileName: "Rapor_2024.pdf",
        fileSize: 15_240_000,
        fileType: .pdf,
        onShare: {},
        onSave: {},
        onDismiss: {}
    )
}
