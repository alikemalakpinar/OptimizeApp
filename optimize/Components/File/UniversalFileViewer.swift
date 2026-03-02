//
//  UniversalFileViewer.swift
//  optimize
//
//  Full-screen file viewer with QuickLook preview and share/save actions.
//  Presented as a fullScreenCover from the root coordinator.
//

import SwiftUI
import QuickLook

struct UniversalFileViewer: View {
    let fileURL: URL
    let fileName: String
    let fileSize: Int64
    let fileType: String
    let onShare: () -> Void
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var showShareSheet = false
    @State private var showFileSaver = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // File Info Header
                fileInfoHeader
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)

                // QuickLook Preview (main content)
                QuickLookPreview(url: fileURL)
                    .ignoresSafeArea(edges: .bottom)

                // Bottom Action Bar
                actionBar
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(.ultraThinMaterial)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(fileName)
                        .font(.appBodyMedium)
                        .lineLimit(1)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                FileViewerShareSheet(items: [fileURL])
            }
            .sheet(isPresented: $showFileSaver) {
                FileViewerExporter(url: fileURL) { success in
                    showFileSaver = false
                    if success {
                        Haptics.success()
                    }
                }
            }
        }
    }

    // MARK: - File Info Header

    private var fileInfoHeader: some View {
        HStack(spacing: Spacing.md) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text(fileType.uppercased())
                        .font(.appCaption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Spacing.sm) {
            // Share Button
            Button(action: {
                Haptics.impact()
                showShareSheet = true
                onShare()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                    Text(AppStrings.UI.share)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [Color.appMint, Color.appTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }

            // Save Button
            Button(action: {
                Haptics.impact()
                showFileSaver = true
                onSave()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                    Text(AppStrings.UI.save)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.appAccent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
        }
    }

    // MARK: - Icon Helpers

    private var iconName: String {
        switch fileType.lowercased() {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "bmp": return "photo.fill"
        case "mp4", "mov", "m4v", "avi", "mkv": return "film.fill"
        case "gif": return "photo.on.rectangle.angled"
        case "doc", "docx", "txt", "rtf": return "doc.text.fill"
        case "ppt", "pptx", "key": return "rectangle.stack.fill"
        case "xls", "xlsx", "csv", "numbers": return "tablecells.fill"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch fileType.lowercased() {
        case "pdf": return .red
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "bmp": return .blue
        case "mp4", "mov", "m4v", "avi", "mkv": return .purple
        case "gif": return .orange
        case "doc", "docx", "txt", "rtf": return .indigo
        case "ppt", "pptx", "key": return .orange
        case "xls", "xlsx", "csv", "numbers": return .green
        default: return .gray
        }
    }
}

// MARK: - File Viewer Share Sheet

private struct FileViewerShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.permittedArrowDirections = []
            if let sourceView = controller.view {
                popover.sourceView = sourceView
                popover.sourceRect = CGRect(
                    x: sourceView.bounds.midX,
                    y: sourceView.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - File Viewer Exporter

private struct FileViewerExporter: UIViewControllerRepresentable {
    let url: URL
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: (Bool) -> Void

        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete(true)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete(false)
        }
    }
}
