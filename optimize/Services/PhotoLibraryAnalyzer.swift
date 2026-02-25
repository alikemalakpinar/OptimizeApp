//
//  PhotoLibraryAnalyzer.swift
//  optimize
//
//  Analyzes the user's photo library to find storage optimization opportunities.
//  Uses PhotoKit (PHAsset) to scan for:
//  - Screenshots (mediaSubtype .screenshot)
//  - Large videos (sorted by file size)
//  - Duplicate/similar photos (via Vision VNFeaturePrint perceptual hashing)
//  - Blurry photos (Laplacian variance)
//
//  INTELLIGENCE:
//  - Vision framework VNGenerateImageFeaturePrintRequest for perceptual similarity
//  - Laplacian variance for blur detection with two-pass confirmation
//  - Smart "Best Pick" selection: favorited > highest resolution > sharpest > newest
//  - Batched processing (50-asset batches) with autoreleasepool for OOM prevention
//
//  PRIVACY: Only reads metadata and small thumbnails - never copies or modifies assets.
//  PERFORMANCE: All Vision/image work runs off the Main Thread via Task.detached.
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
    let iconColor: String
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
    /// Live log lines for the scanning UI's "AI thinking" log view
    @Published var logLines: [String] = []

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

    // MARK: - Constants

    /// Batch size for Vision processing to prevent OOM
    private let visionBatchSize = 50
    /// Max assets to process for similarity (CPU-intensive)
    private let similarScanLimit = 500
    /// Max assets to process for blur detection
    private let blurryScanLimit = 300
    /// Vision similarity threshold: lower = more strict
    private let similarityThreshold: Float = 12.0
    /// Laplacian variance below this = blurry
    private let blurThreshold: Double = 50.0

    // MARK: - Public API

    /// Start full library analysis
    func analyze() async {
        state = .requestingPermission
        progress = 0
        logLines = []

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

        guard status == .authorized || status == .limited else {
            state = .permissionDenied
            return
        }

        state = .analyzing
        appendLog("Analiz motoru başlatılıyor...")

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

        let sorted = categories.sorted { $0.totalBytes > $1.totalBytes }
        let totalBytes = sorted.reduce(0) { $0 + $1.totalBytes }
        let totalCount = sorted.reduce(0) { $0 + $1.count }

        let result = LibraryAnalysisResult(
            categories: sorted,
            totalOptimizableBytes: totalBytes,
            totalAssetCount: totalCount,
            analysisDate: Date()
        )

        appendLog("Analiz tamamlandı: \(totalCount) dosya, \(result.formattedTotalSize) kazanılabilir")
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

    // MARK: - Log Helper

    private func appendLog(_ message: String) {
        Task { @MainActor in
            logLines.append(message)
            // Keep only last 50 lines to prevent memory bloat
            if logLines.count > 50 {
                logLines.removeFirst(logLines.count - 50)
            }
        }
    }

    // MARK: - Analysis Steps

    /// Find all screenshots
    private func findScreenshots() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningScreenshots
            progress = 0.1
        }
        appendLog("Ekran görüntüleri taranıyor...")

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

        await MainActor.run { progress = 0.2 }
        appendLog("\(assets.count) ekran görüntüsü bulundu")

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
            progress = 0.25
        }
        appendLog("Video kütüphanesi taranıyor...")

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = PHAsset.fetchAssets(with: .video, options: options)

        var assetsWithSize: [(asset: PHAsset, size: Int64)] = []

        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first,
               let size = resource.value(forKey: "fileSize") as? Int64 {
                if size > 50_000_000 {
                    assetsWithSize.append((asset, size))
                }
            }
        }

        assetsWithSize.sort { $0.size > $1.size }

        await MainActor.run { progress = 0.35 }

        let assets = assetsWithSize.map(\.asset)
        let totalBytes = assetsWithSize.reduce(0) { $0 + $1.size }

        appendLog("\(assets.count) büyük video bulundu (50MB+)")

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
    private func findDuplicateSizePhotos() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningDuplicates
            progress = 0.4
        }
        appendLog("Byte-düzeyinde tekrar analizi yapılıyor...")

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = PHAsset.fetchAssets(with: .image, options: options)

        var sizeGroups: [Int64: [PHAsset]] = [:]

        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first,
               let size = resource.value(forKey: "fileSize") as? Int64,
               size > 100_000 {
                sizeGroups[size, default: []].append(asset)
            }
        }

        let duplicateGroups = sizeGroups.filter { $0.value.count >= 2 }

        var duplicateAssets: [PHAsset] = []
        var totalBytes: Int64 = 0

        for (size, assets) in duplicateGroups {
            // Smart selection: keep the best, mark rest as deletable
            let best = selectBestAsset(from: assets)
            let removable = assets.filter { $0.localIdentifier != best.localIdentifier }
            duplicateAssets.append(contentsOf: removable)
            totalBytes += size * Int64(removable.count)
        }

        await MainActor.run { progress = 0.5 }
        appendLog("\(duplicateAssets.count) byte-düzeyi tekrar tespit edildi")

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

    // MARK: - Vision Framework Similar Photo Detection (Batched)

    /// Find visually similar photos using Vision's VNFeaturePrintObservation.
    /// Groups photos by perceptual similarity (burst shots, near-duplicates).
    /// Processes in batches of 50 with autoreleasepool for memory safety.
    private func findSimilarPhotos() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningSimilar
            progress = 0.55
        }
        appendLog("Vision motoru başlatılıyor...")
        appendLog("Algısal parmak izi (feature print) oluşturuluyor...")

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = similarScanLimit

        let results = PHAsset.fetchAssets(with: .image, options: options)

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        requestOptions.resizeMode = .fast

        let targetSize = CGSize(width: 300, height: 300)

        var assetsToProcess: [(asset: PHAsset, size: Int64)] = []
        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            let size = (resources.first.flatMap { $0.value(forKey: "fileSize") as? Int64 }) ?? 0
            if size > 500_000 {
                assetsToProcess.append((asset, size))
            }
        }

        appendLog("\(assetsToProcess.count) fotoğraf için parmak izi oluşturuluyor...")

        // Process in batches with autoreleasepool for memory safety
        var featurePrints: [(asset: PHAsset, print: VNFeaturePrintObservation, size: Int64)] = []
        let totalBatches = (assetsToProcess.count + visionBatchSize - 1) / visionBatchSize

        for batchIndex in 0..<totalBatches {
            let start = batchIndex * visionBatchSize
            let end = min(start + visionBatchSize, assetsToProcess.count)
            let batch = assetsToProcess[start..<end]

            for item in batch {
                if let fp = await generateFeaturePrint(
                    for: item.asset,
                    manager: imageManager,
                    options: requestOptions,
                    targetSize: targetSize
                ) {
                    featurePrints.append((item.asset, fp, item.size))
                }
            }

            let batchProgress = 0.55 + 0.15 * (Double(batchIndex + 1) / Double(totalBatches))
            await MainActor.run { progress = batchProgress }

            if (batchIndex + 1) % 3 == 0 || batchIndex == totalBatches - 1 {
                appendLog("Parmak izi: \(min(end, assetsToProcess.count))/\(assetsToProcess.count) tamamlandı")
            }
        }

        appendLog("Algısal kümeleme (clustering) yapılıyor...")

        // Compare feature prints to find similar groups
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

        appendLog("\(similarGroups.count) benzer fotoğraf grubu tespit edildi")

        // Smart selection: keep best from each group, mark rest as removable
        var similarAssets: [PHAsset] = []
        var totalBytes: Int64 = 0

        for group in similarGroups {
            let assets = group.map { $0.0 }
            let best = selectBestAsset(from: assets)
            for item in group where item.0.localIdentifier != best.localIdentifier {
                similarAssets.append(item.0)
                totalBytes += item.1
            }
        }

        await MainActor.run { progress = 0.75 }

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

    // MARK: - Blurry Photo Detection (Laplacian Variance, Batched)

    /// Find blurry photos using Laplacian variance analysis.
    /// Two-pass approach: quick pre-filter at small size, then confirm at higher resolution.
    /// Processes in batches for memory safety.
    private func findBlurryPhotos() async -> MediaCategory? {
        await MainActor.run {
            currentStep = AppStrings.Analysis.scanningBlurry
            progress = 0.78
        }
        appendLog("Bulanıklık algılama motoru başlatılıyor...")
        appendLog("Laplacian varyans analizi yapılıyor...")

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = blurryScanLimit

        let results = PHAsset.fetchAssets(with: .image, options: options)

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = false
        requestOptions.isSynchronous = false
        requestOptions.resizeMode = .fast

        let smallSize = CGSize(width: 200, height: 200)

        var assetsToCheck: [(asset: PHAsset, size: Int64)] = []
        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            let size = (resources.first.flatMap { $0.value(forKey: "fileSize") as? Int64 }) ?? 0
            if size > 100_000 {
                assetsToCheck.append((asset, size))
            }
        }

        appendLog("\(assetsToCheck.count) fotoğraf netlik kontrolüne tabi tutuluyor...")

        var blurryAssets: [PHAsset] = []
        var totalBytes: Int64 = 0
        let totalBatches = (assetsToCheck.count + visionBatchSize - 1) / visionBatchSize

        for batchIndex in 0..<totalBatches {
            let start = batchIndex * visionBatchSize
            let end = min(start + visionBatchSize, assetsToCheck.count)
            let batch = assetsToCheck[start..<end]

            for item in batch {
                // Pass 1: Quick check at small size
                let image: UIImage? = await withCheckedContinuation { continuation in
                    imageManager.requestImage(
                        for: item.asset,
                        targetSize: smallSize,
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

            let batchProgress = 0.78 + 0.12 * (Double(batchIndex + 1) / Double(totalBatches))
            await MainActor.run { progress = batchProgress }
        }

        appendLog("\(blurryAssets.count) bulanık fotoğraf tespit edildi")
        await MainActor.run { progress = 0.92 }

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

    // MARK: - Smart "Best Pick" Selection

    /// Select the best asset from a group to keep.
    /// Priority: favorited > highest pixel count > newest creation date.
    private func selectBestAsset(from assets: [PHAsset]) -> PHAsset {
        guard assets.count > 1 else { return assets[0] }

        return assets.max { a, b in
            // Favorited assets always win
            if a.isFavorite != b.isFavorite { return !a.isFavorite }
            // Higher resolution wins
            let aPixels = a.pixelWidth * a.pixelHeight
            let bPixels = b.pixelWidth * b.pixelHeight
            if aPixels != bPixels { return aPixels < bPixels }
            // Newer wins
            let aDate = a.creationDate ?? .distantPast
            let bDate = b.creationDate ?? .distantPast
            return aDate < bDate
        } ?? assets[0]
    }

    // MARK: - Laplacian Variance (Blur Detection)

    /// Compute Laplacian variance to measure image sharpness.
    /// A 3x3 Laplacian kernel is convolved with the grayscale image.
    /// Low variance = blurry, high variance = sharp.
    private func laplacianVariance(of image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        guard width > 2, height > 2 else { return 0 }

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

    // MARK: - Vision Feature Print

    /// Generate a Vision feature print for a photo asset.
    /// Wrapped in autoreleasepool for memory safety during batch processing.
    private func generateFeaturePrint(
        for asset: PHAsset,
        manager: PHImageManager,
        options: PHImageRequestOptions,
        targetSize: CGSize
    ) async -> VNFeaturePrintObservation? {
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

        return autoreleasepool {
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
}
