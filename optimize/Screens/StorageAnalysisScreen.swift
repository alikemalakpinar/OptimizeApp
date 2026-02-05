//
//  StorageAnalysisScreen.swift
//  optimize
//
//  Photo library storage analysis screen.
//  Shows categorized optimization opportunities (screenshots, large videos, duplicates)
//  and allows batch deletion with system confirmation.
//

import SwiftUI
import Photos

struct StorageAnalysisScreen: View {
    @StateObject private var analyzer = PhotoLibraryAnalyzer()
    let onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            NavigationHeader(AppStrings.Analysis.title, onBack: onBack)
                .padding(.top, Spacing.xs)

            content
        }
        .appBackgroundLayered()
        .task {
            if case .idle = analyzer.state {
                await analyzer.analyze()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch analyzer.state {
        case .idle, .requestingPermission:
            loadingView(text: AppStrings.Analysis.requestingAccess)

        case .analyzing:
            loadingView(text: analyzer.currentStep)

        case .completed(let result):
            if result.categories.isEmpty {
                emptyStateView
            } else {
                resultsView(result)
            }

        case .permissionDenied:
            permissionDeniedView

        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Loading

    private func loadingView(text: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Animated scanning indicator
            ZStack {
                Circle()
                    .stroke(Color.appMint.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: analyzer.progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: analyzer.progress)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.premiumPurple)
            }

            VStack(spacing: Spacing.xs) {
                Text(AppStrings.Analysis.scanning)
                    .font(.appBodyBold)
                    .foregroundStyle(.primary)

                Text(text)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Results

    private func resultsView(_ result: LibraryAnalysisResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Summary card
                summaryCard(result)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                // Category cards
                ForEach(result.categories) { category in
                    CategoryCard(category: category, analyzer: analyzer)
                        .padding(.horizontal, Spacing.md)
                }

                // iCloud comparison tip
                iCloudTipCard
                    .padding(.horizontal, Spacing.md)

                Spacer(minLength: Spacing.xl)
            }
        }
    }

    private func summaryCard(_ result: LibraryAnalysisResult) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(AppStrings.Analysis.foundOptimizable)
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary)

                    Text(result.formattedTotalSize)
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Circular indicator
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appMint.opacity(0.15), Color.appTeal.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.appMint)
                }
            }

            HStack(spacing: Spacing.sm) {
                SummaryPill(
                    value: "\(result.totalAssetCount)",
                    label: AppStrings.Analysis.items,
                    color: .premiumPurple
                )

                SummaryPill(
                    value: "\(result.categories.count)",
                    label: AppStrings.Analysis.categoriesLabel,
                    color: .warmOrange
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.appMint.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, x: 0, y: 4)
    }

    private var iCloudTipCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.premiumBlue)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(AppStrings.Analysis.iCloudTipTitle)
                    .font(.appCaptionMedium)
                    .foregroundStyle(.primary)

                Text(AppStrings.Analysis.iCloudTipBody)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.premiumBlue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.premiumBlue.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appMint.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.appMint)
            }

            VStack(spacing: Spacing.xs) {
                Text(AppStrings.Analysis.allCleanTitle)
                    .font(.appTitle)
                    .foregroundStyle(.primary)

                Text(AppStrings.Analysis.allCleanBody)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.warmOrange.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.warmOrange)
            }

            VStack(spacing: Spacing.xs) {
                Text(AppStrings.Analysis.permissionTitle)
                    .font(.appTitle)
                    .foregroundStyle(.primary)

                Text(AppStrings.Analysis.permissionBody)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(AppStrings.Analysis.openSettings)
                    .font(.appBodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(Color.warmCoral)

            Text(message)
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button(action: {
                Task { await analyzer.analyze() }
            }) {
                Text(AppStrings.Analysis.retry)
                    .font(.appBodyBold)
                    .foregroundStyle(Color.premiumPurple)
            }

            Spacer()
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: MediaCategory
    @ObservedObject var analyzer: PhotoLibraryAnalyzer
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    @State private var isDeleting = false

    private var iconColor: Color {
        switch category.iconColor {
        case "warmOrange": return .warmOrange
        case "premiumPurple": return .premiumPurple
        case "warmCoral": return .warmCoral
        default: return .appMint
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(AppAnimation.spring) {
                    isExpanded.toggle()
                }
                Haptics.selection()
            }) {
                HStack(spacing: Spacing.sm) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: category.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(category.title)
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)

                        Text(category.subtitle)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Size badge
                    Text(category.formattedSize)
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(iconColor)

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(Spacing.md)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, Spacing.md)

                VStack(spacing: Spacing.sm) {
                    // Thumbnail grid (first 6 assets)
                    let previewAssets = Array(category.assets.prefix(6))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3), spacing: Spacing.xs) {
                        ForEach(0..<previewAssets.count, id: \.self) { index in
                            AssetThumbnail(asset: previewAssets[index])
                                .aspectRatio(1, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        }
                    }

                    if category.count > 6 {
                        Text(AppStrings.Analysis.andMore(category.count - 6))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    // Delete button
                    Button(action: {
                        Task {
                            isDeleting = true
                            Haptics.impact()
                            let success = await analyzer.deleteAssets(category.assets)
                            isDeleting = false
                            if success {
                                Haptics.success()
                                // Re-analyze after deletion
                                await analyzer.analyze()
                            }
                        }
                    }) {
                        HStack(spacing: Spacing.xs) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(deleteButtonText)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [iconColor.opacity(0.9), iconColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .disabled(isDeleting)
                }
                .padding(Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, x: 0, y: 4)
    }

    private var deleteButtonText: String {
        switch category.type {
        case .screenshots:
            return AppStrings.Analysis.deleteScreenshots(category.count)
        case .largeVideos:
            return AppStrings.Analysis.deleteVideos(category.count)
        case .duplicates:
            return AppStrings.Analysis.deleteDuplicates(category.count)
        }
    }
}

// MARK: - Asset Thumbnail

private struct AssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                    )
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast

        let size = CGSize(width: 200, height: 200)

        let result: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        await MainActor.run {
            self.image = result
        }
    }
}

// MARK: - Summary Pill

private struct SummaryPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    StorageAnalysisScreen(onBack: {})
}
