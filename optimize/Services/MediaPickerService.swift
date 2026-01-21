//
//  MediaPickerService.swift
//  optimize
//
//  Modern Photo & Video Selection using PHPickerViewController.
//  EDITOR'S CHOICE QUALITY - iOS 14+ Best Practices.
//
//  WHY PHPicker?
//  - No permission required (iOS handles access transparently)
//  - System-native UI (consistent with Apple apps)
//  - Multi-selection support
//  - Pre-built filtering (images, videos, live photos)
//  - Privacy-first design (only selected items are shared)
//
//  FEATURES:
//  - Single and multiple selection modes
//  - Photo/Video/Mixed filtering
//  - Async/await support
//  - Security-scoped resource handling
//  - SwiftUI integration via UIViewControllerRepresentable
//

import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Media Selection Result

struct MediaSelectionResult: Identifiable {
    let id = UUID()
    let url: URL
    let type: MediaType
    let originalFileName: String
    let fileSize: Int64

    enum MediaType {
        case image
        case video
        case livePhoto
        case unknown

        var icon: String {
            switch self {
            case .image: return "photo"
            case .video: return "video"
            case .livePhoto: return "livephoto"
            case .unknown: return "doc"
            }
        }
    }
}

// MARK: - Media Picker Configuration

struct MediaPickerConfiguration {
    var selectionLimit: Int
    var filter: PHPickerFilter
    var preferredAssetRepresentationMode: PHPickerConfiguration.AssetRepresentationMode

    static let singleImage = MediaPickerConfiguration(
        selectionLimit: 1,
        filter: .images,
        preferredAssetRepresentationMode: .current
    )

    static let singleVideo = MediaPickerConfiguration(
        selectionLimit: 1,
        filter: .videos,
        preferredAssetRepresentationMode: .current
    )

    static let singleAny = MediaPickerConfiguration(
        selectionLimit: 1,
        filter: .any(of: [.images, .videos]),
        preferredAssetRepresentationMode: .current
    )

    static let multipleImages = MediaPickerConfiguration(
        selectionLimit: 0, // 0 = unlimited
        filter: .images,
        preferredAssetRepresentationMode: .current
    )

    static let multipleVideos = MediaPickerConfiguration(
        selectionLimit: 0,
        filter: .videos,
        preferredAssetRepresentationMode: .current
    )

    static let multipleAny = MediaPickerConfiguration(
        selectionLimit: 0,
        filter: .any(of: [.images, .videos]),
        preferredAssetRepresentationMode: .current
    )

    /// Batch processing configuration - limited for free users
    static func batch(limit: Int) -> MediaPickerConfiguration {
        MediaPickerConfiguration(
            selectionLimit: limit,
            filter: .any(of: [.images, .videos]),
            preferredAssetRepresentationMode: .current
        )
    }
}

// MARK: - Media Picker (SwiftUI)

/// Modern photo/video picker using PHPickerViewController
/// - No permission dialogs required
/// - System-native UI
/// - Supports single and multi-selection
struct MediaPicker: UIViewControllerRepresentable {
    let configuration: MediaPickerConfiguration
    let onPick: ([MediaSelectionResult]) -> Void
    let onCancel: () -> Void

    init(
        configuration: MediaPickerConfiguration = .singleAny,
        onPick: @escaping ([MediaSelectionResult]) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.configuration = configuration
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = configuration.selectionLimit
        config.filter = configuration.filter
        config.preferredAssetRepresentationMode = configuration.preferredAssetRepresentationMode

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([MediaSelectionResult]) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping ([MediaSelectionResult]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss picker immediately
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                onCancel()
                return
            }

            // Process results asynchronously
            Task {
                var mediaResults: [MediaSelectionResult] = []

                for result in results {
                    if let mediaResult = await processPickerResult(result) {
                        mediaResults.append(mediaResult)
                    }
                }

                await MainActor.run {
                    if mediaResults.isEmpty {
                        onCancel()
                    } else {
                        onPick(mediaResults)
                    }
                }
            }
        }

        // MARK: - Process Picker Result

        private func processPickerResult(_ result: PHPickerResult) async -> MediaSelectionResult? {
            let itemProvider = result.itemProvider

            // Try video first (higher priority for compression app)
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                return await loadVideo(from: itemProvider)
            }

            // Then try image
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                return await loadImage(from: itemProvider)
            }

            // Live photo (treated as image for compression)
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.livePhoto.identifier) {
                return await loadImage(from: itemProvider)
            }

            return nil
        }

        private func loadVideo(from itemProvider: NSItemProvider) async -> MediaSelectionResult? {
            return await withCheckedContinuation { continuation in
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    guard let sourceURL = url, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }

                    // Copy to temp directory (security-scoped resource)
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(sourceURL.pathExtension)

                    do {
                        try FileManager.default.copyItem(at: sourceURL, to: tempURL)

                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64) ?? 0

                        let result = MediaSelectionResult(
                            url: tempURL,
                            type: .video,
                            originalFileName: sourceURL.lastPathComponent,
                            fileSize: fileSize
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }

        private func loadImage(from itemProvider: NSItemProvider) async -> MediaSelectionResult? {
            return await withCheckedContinuation { continuation in
                // Try to load as file first (preserves original format)
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    guard let sourceURL = url, error == nil else {
                        // Fallback: Load as data
                        itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                            guard let data = data else {
                                continuation.resume(returning: nil)
                                return
                            }

                            // Determine extension from data
                            let ext = self.detectImageFormat(from: data)

                            // Save to temp
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension(ext)

                            do {
                                try data.write(to: tempURL)
                                let result = MediaSelectionResult(
                                    url: tempURL,
                                    type: .image,
                                    originalFileName: "image.\(ext)",
                                    fileSize: Int64(data.count)
                                )
                                continuation.resume(returning: result)
                            } catch {
                                continuation.resume(returning: nil)
                            }
                        }
                        return
                    }

                    // Copy to temp directory
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(sourceURL.pathExtension)

                    do {
                        try FileManager.default.copyItem(at: sourceURL, to: tempURL)

                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64) ?? 0

                        let result = MediaSelectionResult(
                            url: tempURL,
                            type: .image,
                            originalFileName: sourceURL.lastPathComponent,
                            fileSize: fileSize
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }

        private func detectImageFormat(from data: Data) -> String {
            guard data.count >= 12 else { return "jpg" }

            let bytes = [UInt8](data.prefix(12))

            // PNG signature
            if bytes[0...3] == [0x89, 0x50, 0x4E, 0x47] {
                return "png"
            }

            // JPEG signature
            if bytes[0...1] == [0xFF, 0xD8] {
                return "jpg"
            }

            // HEIC/HEIF signature (ftyp box)
            if bytes[4...7] == [0x66, 0x74, 0x79, 0x70] {
                let brandBytes = bytes[8...11]
                if brandBytes == [0x68, 0x65, 0x69, 0x63] || // heic
                   brandBytes == [0x68, 0x65, 0x69, 0x66] || // heif
                   brandBytes == [0x6D, 0x69, 0x66, 0x31] {  // mif1
                    return "heic"
                }
            }

            // WebP signature
            if bytes[0...3] == [0x52, 0x49, 0x46, 0x46] && bytes[8...11] == [0x57, 0x45, 0x42, 0x50] {
                return "webp"
            }

            // GIF signature
            if bytes[0...2] == [0x47, 0x49, 0x46] {
                return "gif"
            }

            return "jpg" // Default
        }
    }
}

// MARK: - Gallery Save Service

/// Save optimized media back to Photo Library
/// Uses PHPhotoLibrary for proper album integration
class GallerySaveService {
    static let shared = GallerySaveService()

    private init() {}

    // MARK: - Save Image

    /// Save image to Photo Library
    /// - Parameters:
    ///   - url: Image file URL
    ///   - albumName: Optional album name (creates if doesn't exist)
    /// - Returns: Success status
    func saveImage(at url: URL, toAlbum albumName: String? = nil) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)

            // Add to album if specified
            if let albumName = albumName,
               let album = self.getOrCreateAlbum(named: albumName) {
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                if let placeholder = request?.placeholderForCreatedAsset {
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                }
            }
        }
    }

    // MARK: - Save Video

    /// Save video to Photo Library
    /// - Parameters:
    ///   - url: Video file URL
    ///   - albumName: Optional album name (creates if doesn't exist)
    /// - Returns: Success status
    func saveVideo(at url: URL, toAlbum albumName: String? = nil) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)

            // Add to album if specified
            if let albumName = albumName,
               let album = self.getOrCreateAlbum(named: albumName) {
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                if let placeholder = request?.placeholderForCreatedAsset {
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                }
            }
        }
    }

    // MARK: - Album Management

    private func getOrCreateAlbum(named name: String) -> PHAssetCollection? {
        // Check if album exists
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let existing = collections.firstObject {
            return existing
        }

        // Create album
        var albumPlaceholder: PHObjectPlaceholder?

        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                albumPlaceholder = createRequest.placeholderForCreatedAssetCollection
            }
        } catch {
            return nil
        }

        guard let placeholder = albumPlaceholder else { return nil }

        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
        return fetchResult.firstObject
    }

    // MARK: - Permission Check

    /// Check if we have permission to save to Photo Library
    /// Note: PHPickerViewController doesn't need permission for READING,
    /// but WRITING requires permission
    func checkWritePermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - SwiftUI Photo Picker Modifier (iOS 16+)

@available(iOS 16.0, *)
extension View {
    /// Presents a native photo picker sheet
    /// - Parameters:
    ///   - isPresented: Binding to control presentation
    ///   - configuration: Picker configuration
    ///   - onPick: Callback with selected media
    func mediaPicker(
        isPresented: Binding<Bool>,
        configuration: MediaPickerConfiguration = .singleAny,
        onPick: @escaping ([MediaSelectionResult]) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            MediaPicker(
                configuration: configuration,
                onPick: { results in
                    isPresented.wrappedValue = false
                    onPick(results)
                },
                onCancel: {
                    isPresented.wrappedValue = false
                }
            )
        }
    }
}
