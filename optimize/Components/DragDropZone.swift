//
//  DragDropZone.swift
//  optimize
//
//  Drag & Drop support for iPad and macOS Catalyst.
//  Users can drag files onto the app to compress them instantly.
//
//  FEATURES:
//  - Visual drop zone indicator
//  - Multiple file drop support
//  - File type validation
//  - Animated feedback
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Supported File Types

enum SupportedDropType {
    case all
    case pdf
    case images
    case videos

    var allowedTypes: [UTType] {
        switch self {
        case .all:
            return [.pdf, .image, .movie, .video]
        case .pdf:
            return [.pdf]
        case .images:
            return [.image, .jpeg, .png, .heic]
        case .videos:
            return [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        }
    }
}

// MARK: - Drop Zone View

struct DragDropZone<Content: View>: View {
    let supportedTypes: SupportedDropType
    let onDrop: ([URL]) -> Void
    let content: () -> Content

    @State private var isTargeted = false
    @State private var dropFeedback = false

    init(
        supportedTypes: SupportedDropType = .all,
        onDrop: @escaping ([URL]) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.supportedTypes = supportedTypes
        self.onDrop = onDrop
        self.content = content
    }

    var body: some View {
        content()
            .overlay(
                dropOverlay
                    .opacity(isTargeted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
            )
            .onDrop(of: supportedTypes.allowedTypes, isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
    }

    // MARK: - Drop Overlay

    private var dropOverlay: some View {
        ZStack {
            // Background blur
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)

            // Dashed border
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 3,
                        dash: [12, 8]
                    )
                )
                .foregroundColor(.cyan)

            // Content
            VStack(spacing: 16) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(dropFeedback ? 1.2 : 1.0)

                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.cyan)
                        .symbolEffect(.bounce, value: isTargeted)
                }

                Text("Dosyaları Buraya Bırakın")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(supportedTypesText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if isTargeted {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    dropFeedback = true
                }
            }
        }
        .onChange(of: isTargeted) { _, newValue in
            if newValue {
                HapticManager.shared.trigger(.medium)
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    dropFeedback = true
                }
            } else {
                dropFeedback = false
            }
        }
    }

    private var supportedTypesText: String {
        switch supportedTypes {
        case .all:
            return "PDF, Resim, Video dosyaları"
        case .pdf:
            return "Sadece PDF dosyaları"
        case .images:
            return "JPG, PNG, HEIC"
        case .videos:
            return "MP4, MOV"
        }
    }

    // MARK: - Handle Drop

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            for type in supportedTypes.allowedTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, error in
                        defer { group.leave() }

                        if let url = item as? URL {
                            urls.append(url)
                        } else if let data = item as? Data {
                            // Handle data if needed
                            if let url = saveDataToTemp(data: data, type: type) {
                                urls.append(url)
                            }
                        }
                    }
                    break
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                HapticManager.shared.trigger(.success)
                onDrop(urls)
            }
        }
    }

    private func saveDataToTemp(data: Data, type: UTType) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let ext = type.preferredFilenameExtension ?? "tmp"
        let url = tempDir.appendingPathComponent("dropped_\(UUID().uuidString).\(ext)")

        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Compact Drop Zone

struct CompactDropZone: View {
    let supportedTypes: SupportedDropType
    let onDrop: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.title)
                .foregroundColor(isTargeted ? .cyan : .secondary)
                .symbolEffect(.bounce, value: isTargeted)

            Text(isTargeted ? "Bırakın!" : "Sürükleyip bırakın")
                .font(.subheadline)
                .foregroundColor(isTargeted ? .cyan : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isTargeted ? Color.cyan : Color.gray.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isTargeted ? Color.cyan.opacity(0.1) : Color.clear)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .onDrop(of: supportedTypes.allowedTypes, isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            for type in supportedTypes.allowedTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: type.identifier) { item, _ in
                        defer { group.leave() }
                        if let url = item as? URL {
                            urls.append(url)
                        }
                    }
                    break
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                HapticManager.shared.trigger(.success)
                onDrop(urls)
            }
        }
    }
}

// MARK: - Draggable File Card

struct DraggableFileCard: View {
    let file: OrganizedFile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: file.category.icon)
                    .font(.title2)
                    .foregroundColor(categoryColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.compressedName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(file.formattedCompressedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .draggable(file.dragItem)
    }

    private var categoryColor: Color {
        switch file.category {
        case .pdf: return .red
        case .image: return .green
        case .video: return .purple
        case .document: return .blue
        case .other: return .gray
        }
    }
}

// MARK: - Drop Indicator

struct DropIndicator: View {
    @Binding var isActive: Bool

    var body: some View {
        if isActive {
            VStack {
                Spacer()
                HStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .symbolEffect(.bounce, value: isActive)

                        Text("Dosyayı bırakın")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.cyan)
                            .shadow(color: .cyan.opacity(0.5), radius: 10, y: 5)
                    )

                    Spacer()
                }
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        DragDropZone(supportedTypes: .all) { urls in
            print("Dropped: \(urls)")
        } content: {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 300)
                .overlay(Text("Ana İçerik"))
        }

        CompactDropZone(supportedTypes: .pdf) { urls in
            print("Dropped PDFs: \(urls)")
        }
    }
    .padding()
}
