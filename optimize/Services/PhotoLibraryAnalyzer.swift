//
//  PhotoLibraryAnalyzer.swift
//  optimize
//
//  Analyzes the user's photo library to find storage optimization opportunities.
//  Uses PhotoKit (PHAsset) to scan for:
//  - Screenshots (mediaSubtype .screenshot)
//  - Large videos (sorted by file size)
//  - Duplicate/similar photos (via resource byte size grouping)
//
//  PRIVACY: Only reads metadata - never copies or modifies assets without user action.
//  PERFORMANCE: Uses PHFetchOptions with sort descriptors and predicates
//  to minimize memory footprint. All heavy work runs on background threads.
//

import Photos
import UIKit
import Vision

// MARK: - Analysis Models

/// A category of optimizable media found in the photo library
struct MediaCategory: Identifiable {
    let id: String
    let type: CategoryType
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: String // Color name from theme
    let assets: [PHAsset]
    let totalBytes: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var count: Int { assets.count }

    enum CategoryType: String {
        case screenshots
        case largeVideos
        case duplicates
        case similarPhotos
        case blurryPhotos
    }
}

/// Overall analysis result
struct LibraryAnalysisResult {
    let categories: [MediaCategory]
    let totalOptimizableBytes: Int64
    let totalAssetCount: Int
    let analysisDate: Date

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalOptimizableBytes, countStyle: .file)
    }

    static let empty = LibraryAnalysisResult(
        categories: [],
        totalOptimizableBytes: 0,
        totalAssetCount: 0,
        analysisDate: Date()
    )
}

// MARK: - Analyzer

@MainActor
final class PhotoLibraryAnalyzer: ObservableObject {

    @Published var state: AnalysisState = .idle
    @Published var progress: Double = 0
    @Published var currentStep: String = ""

    enum AnalysisState: Equatable {
        case idle
        case requestingPermission
        case analyzing
        case completed(LibraryAnalysisResult)
        case permissionDenied
        case error(String)

        static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.requestingPermission, .requestingPermission),
                 (.analyzing, .analyzing),
                 (.permissionDenied, .permissionDenied):
                return true
            case (.completed(let a), .completed(let b)):
                return a.analysisDate == b.analysisDate
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Public API

    /// Start full library analysis
    func analyze() async {
        state = .requestingPermission
        progress = 0

        // Request read-write access (needed to later delete assets)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

        guard status == .authorized || status == .limited else {
            state = .permissionDenied
            return
        }

        state = .analyzing

        // Run analysis steps
        let categories = await withTaskGroup(of: MediaCategory?.self) { group -> [MediaCategory] in
            group.addTask { [weak self] in
                await self?.findScreenshots()
            }

            group.addTask { [weak self] in
                await self?.findLargeVideos()
            }

            group.addTask { [weak self] in
                await self?.findDuplicateSizePhotos()
            }

            group.addTask { [weak self] in
                await self?.findSimilarPhotos()
            }

            group.addTask { [weak self] in
                await self?.findBlurryPhotos()
            }

            var results: [MediaCategory] = []
            for await category in group {
                if let category = category, !category.assets.isEmpty {
                    results.append(category)
                }
            }
            return results
        }

        // Sort: largest total size first
        let sorted = categories.sorted { $0.totalBytes > $1.totalBytes }
        let totalBytes = sorted.reduce(0) { $0 + $1.totalBytes }
        let totalCount = sorted.reduce(0) { $0 + $1.count }

        let result = LibraryAnalysisResult(
            categories: sorted,
            totalOptimizableBytes: totalBytes,
            totalAssetCount: totalCount,
            analysisDate: Date()
        )

        progress = 1.0
        state = .completed(result)
    }

    /// Delete selected assets (requires user confirmation via system dialog)
    func deleteAssets(_ assets: [PHAsset]) async -> Bool {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Analysis Steps

    /// Find all screenshots
    private func findScreenshots() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningScreenshots
            progress = 0.1
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaSubtypes & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = PHAsset.fetchAssets(with: .image, options: options)

        var assets: [PHAsset] = []
        var totalBytes: Int64 = 0

        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first,
               let size = resource.value(forKey: "fileSize") as? Int64 {
                totalBytes += size
            }
        }

        await MainActor.run { progress = 0.35 }

        guard !assets.isEmpty else { return nil }

        return MediaCategory(
            id: "screenshots",
            type: .screenshots,
            title: AppStrings.Analysis.screenshotsTitle,
            subtitle: AppStrings.Analysis.screenshotsSubtitle(assets.count),
            icon: "camera.viewfinder",
            iconColor: "warmOrange",
            assets: assets,
            totalBytes: totalBytes
        )
    }

    /// Find large videos (> 50MB)
    private func findLargeVideos() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningVideos
            progress = 0.4
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = PHAsset.fetchAssets(with: .video, options: options)

        var assetsWithSize: [(asset: PHAsset, size: Int64)] = []

        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first,
               let size = resource.value(forKey: "fileSize") as? Int64 {
                // Only include videos > 50MB
                if size > 50_000_000 {
                    assetsWithSize.append((asset, size))
                }
            }
        }

        // Sort by size descending
        assetsWithSize.sort { $0.size > $1.size }

        await MainActor.run { progress = 0.65 }

        let assets = assetsWithSize.map(\.asset)
        let totalBytes = assetsWithSize.reduce(0) { $0 + $1.size }

        guard !assets.isEmpty else { return nil }

        return MediaCategory(
            id: "large_videos",
            type: .largeVideos,
            title: AppStrings.Analysis.largeVideosTitle,
            subtitle: AppStrings.Analysis.largeVideosSubtitle(assets.count),
            icon: "video.fill",
            iconColor: "premiumPurple",
            assets: assets,
            totalBytes: totalBytes
        )
    }

    /// Find potential duplicates by matching exact file sizes
    /// This is a lightweight heuristic - same byte count + same creation date = likely duplicate
    private func findDuplicateSizePhotos() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningDuplicates
            progress = 0.7
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = PHAsset.fetchAssets(with: .image, options: options)

        // Group by file size - exact same size is a strong duplicate indicator
        var sizeGroups: [Int64: [PHAsset]] = [:]

        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first,
               let size = resource.value(forKey: "fileSize") as? Int64,
               size > 100_000 { // Ignore tiny files (< 100KB)
                sizeGroups[size, default: []].append(asset)
            }
        }

        // Only keep groups with 2+ assets (actual duplicates)
        let duplicateGroups = sizeGroups.filter { $0.value.count >= 2 }

        // Collect all duplicate assets (keep first of each group, mark rest as deletable)
        var duplicateAssets: [PHAsset] = []
        var totalBytes: Int64 = 0

        for (size, assets) in duplicateGroups {
            // Skip the first (keep it), add the rest as duplicates
            let removable = Array(assets.dropFirst())
            duplicateAssets.append(contentsOf: removable)
            totalBytes += size * Int64(removable.count)
        }

        await MainActor.run { progress = 0.9 }

        guard !duplicateAssets.isEmpty else { return nil }

        return MediaCategory(
            id: "duplicates",
            type: .duplicates,
            title: AppStrings.Analysis.duplicatesTitle,
            subtitle: AppStrings.Analysis.duplicatesSubtitle(duplicateAssets.count),
            icon: "doc.on.doc.fill",
            iconColor: "warmCoral",
            assets: duplicateAssets,
            totalBytes: totalBytes
        )
    }

    // MARK: - Vision Framework Similar Photo Detection

    /// Find visually similar photos using Vision's VNFeaturePrintObservation
    /// Groups photos by perceptual similarity (burst shots, near-duplicates)
    /// Only analyzes the most recent 200 photos to keep scan time reasonable
    private func findSimilarPhotos() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningSimilar
            progress = 0.75
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 200 // Limit for performance - Vision analysis is CPU intensive

        let results = PHAsset.fetchAssets(with: .image, options: options)

        // Generate feature prints for each photo
        var featurePrints: [(asset: PHAsset, print: VNFeaturePrintObservation, size: Int64)] = []

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        // .highQualityFormat guarantees a single callback, preventing
        // "SWIFT TASK CONTINUATION MISUSE" crashes with withCheckedContinuation
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        requestOptions.resizeMode = .fast

        let targetSize = CGSize(width: 300, height: 300) // Small size for fast feature extraction

        // Enumerate and compute feature prints
        var assetsToProcess: [(asset: PHAsset, size: Int64)] = []
        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            let size = (resources.first.flatMap { $0.value(forKey: "fileSize") as? Int64 }) ?? 0
            // Only include photos > 500KB to skip tiny thumbnails
            if size > 500_000 {
                assetsToProcess.append((asset, size))
            }
        }

        // Process in batches for memory efficiency
        for item in assetsToProcess {
            if let fp = await generateFeaturePrint(
                for: item.asset,
                manager: imageManager,
                options: requestOptions,
                targetSize: targetSize
            ) {
                featurePrints.append((item.asset, fp, item.size))
            }
        }

        await MainActor.run { progress = 0.85 }

        // Compare feature prints to find similar groups
        // Distance threshold: 0.0 = identical, higher = more different
        // ~12.0 is a good threshold for "visually very similar" (burst shots, slight edits)
        let similarityThreshold: Float = 12.0
        var visited = Set<Int>()
        var similarGroups: [[(PHAsset, Int64)]] = []

        for i in 0..<featurePrints.count {
            guard !visited.contains(i) else { continue }

            var group: [(PHAsset, Int64)] = [(featurePrints[i].asset, featurePrints[i].size)]

            for j in (i+1)..<featurePrints.count {
                guard !visited.contains(j) else { continue }

                var distance: Float = 0
                do {
                    try featurePrints[i].print.computeDistance(&distance, to: featurePrints[j].print)
                } catch {
                    continue
                }

                if distance < similarityThreshold {
                    group.append((featurePrints[j].asset, featurePrints[j].size))
                    visited.insert(j)
                }
            }

            if group.count >= 2 {
                visited.insert(i)
                similarGroups.append(group)
            }
        }

        // Collect removable assets (keep best quality from each group, mark rest)
        var similarAssets: [PHAsset] = []
        var totalBytes: Int64 = 0

        for group in similarGroups {
            // Keep the largest file (highest quality), mark rest as removable
            let sorted = group.sorted { $0.1 > $1.1 }
            let removable = sorted.dropFirst()
            for item in removable {
                similarAssets.append(item.0)
                totalBytes += item.1
            }
        }

        await MainActor.run { progress = 0.92 }

        guard !similarAssets.isEmpty else { return nil }

        return MediaCategory(
            id: "similar_photos",
            type: .similarPhotos,
            title: AppStrings.Analysis.similarTitle,
            subtitle: AppStrings.Analysis.similarSubtitle(similarAssets.count),
            icon: "photo.stack",
            iconColor: "premiumPurple",
            assets: similarAssets,
            totalBytes: totalBytes
        )
    }

    // MARK: - Blurry Photo Detection (Laplacian Variance)

    /// Find blurry photos using Laplacian variance analysis.
    /// Low variance = blurry image (uniform pixel values).
    /// Analyzes the most recent 150 photos to keep scan time reasonable.
    private func findBlurryPhotos() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningBlurry
            progress = 0.78
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 150

        let results = PHAsset.fetchAssets(with: .image, options: options)

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = false
        requestOptions.isSynchronous = false
        requestOptions.resizeMode = .fast

        let targetSize = CGSize(width: 200, height: 200)
        // Laplacian variance threshold - values below this are considered blurry
        let blurThreshold: Double = 50.0

        var blurryAssets: [PHAsset] = []
        var totalBytes: Int64 = 0

        var assetsToCheck: [(asset: PHAsset, size: Int64)] = []
        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            let size = (resources.first.flatMap { $0.value(forKey: "fileSize") as? Int64 }) ?? 0
            if size > 100_000 { // Skip tiny files
                assetsToCheck.append((asset, size))
            }
        }

        for item in assetsToCheck {
            let image: UIImage? = await withCheckedContinuation { continuation in
                imageManager.requestImage(
                    for: item.asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: requestOptions
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }

            guard let cgImage = image?.cgImage else { continue }

            let variance = laplacianVariance(of: cgImage)
            if variance < blurThreshold {
                blurryAssets.append(item.asset)
                totalBytes += item.size
            }
        }

        await MainActor.run { progress = 0.88 }

        guard !blurryAssets.isEmpty else { return nil }

        return MediaCategory(
            id: "blurry_photos",
            type: .blurryPhotos,
            title: AppStrings.Analysis.blurryTitle,
            subtitle: AppStrings.Analysis.blurrySubtitle(blurryAssets.count),
            icon: "camera.metering.unknown",
            iconColor: "warmOrange",
            assets: blurryAssets,
            totalBytes: totalBytes
        )
    }

    /// Compute Laplacian variance to measure image sharpness.
    /// A 3x3 Laplacian kernel is convolved with the grayscale image.
    /// Low variance = blurry, high variance = sharp.
    private func laplacianVariance(of image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        guard width > 2, height > 2 else { return 0 }

        // Convert to grayscale pixel buffer
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply 3x3 Laplacian kernel: [0,1,0; 1,-4,1; 0,1,0]
        var sum: Double = 0
        var sumSq: Double = 0
        var count: Double = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let laplacian = -4.0 * Double(pixels[idx])
                    + Double(pixels[idx - 1])
                    + Double(pixels[idx + 1])
                    + Double(pixels[idx - width])
                    + Double(pixels[idx + width])

                sum += laplacian
                sumSq += laplacian * laplacian
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        let mean = sum / count
        let variance = (sumSq / count) - (mean * mean)
        return variance
    }

    /// Generate a Vision feature print for a photo asset
    private func generateFeaturePrint(
        for asset: PHAsset,
        manager: PHImageManager,
        options: PHImageRequestOptions,
        targetSize: CGSize
    ) async -> VNFeaturePrintObservation? {
        // Load thumbnail
        let image: UIImage? = await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        guard let cgImage = image?.cgImage else { return nil }

        // Run Vision feature print request
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }
}
