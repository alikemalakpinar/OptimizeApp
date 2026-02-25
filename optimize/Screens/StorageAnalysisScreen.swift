//
//  StorageAnalysisScreen.swift
//  optimize
//
//  Photo library storage analysis screen.
//  Shows categorized optimization opportunities (screenshots, large videos, duplicates)
//  and allows batch deletion with system confirmation.
//
//  UI/UX DESIGN (Apple Premium Redesign):
//  - Scanning State: Full-screen MeshGradient (iOS 18) with frosted glass pill + live log
//  - Results State: Horizontal Storage Bar + edge-to-edge minimal list rows
//  - Premium haptic patterns synced with UI transitions
//

import SwiftUI
import Photos
import UIKit

struct StorageAnalysisScreen: View {
    @StateObject private var analyzer = PhotoLibraryAnalyzer()
    @StateObject private var contactsAnalyzer = ContactsAnalyzer()
    @StateObject private var calendarAnalyzer = CalendarAnalyzer()
    let onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Scanning animation state
    @State private var scanPhase: CGFloat = 0
    @State private var scanComplete = false

    // Clipboard state
    @State private var clipboardMessage: String?

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
        .task {
            if case .idle = contactsAnalyzer.state {
                await contactsAnalyzer.analyze()
            }
        }
        .task {
            if case .idle = calendarAnalyzer.state {
                await calendarAnalyzer.analyze()
            }
        }
        .onChange(of: analyzer.state) { _, newState in
            if case .completed = newState {
                scanComplete = true
                Haptics.dramaticSuccess()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch analyzer.state {
        case .idle, .requestingPermission:
            scanningView

        case .analyzing:
            scanningView

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

    // MARK: - Scanning View (MeshGradient + Glass Pill + Live Log)

    private var scanningView: some View {
        ZStack {
            // Full-screen animated gradient background
            NeuralGradientBackground(phase: scanPhase)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Spacer()

                // Frosted glass pill with scanning file names
                ScanningPillView(
                    currentStep: analyzer.currentStep,
                    progress: analyzer.progress,
                    isActive: analyzer.state == .analyzing
                )

                // Progress percentage
                Text("\(Int(analyzer.progress * 100))%")
                    .font(.system(size: 48, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4, bounce: 0.2), value: Int(analyzer.progress * 100))

                Spacer()

                // Live AI log view
                LiveLogView(lines: analyzer.logLines)
                    .frame(maxHeight: 180)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                scanPhase = 1
            }
        }
    }

    // MARK: - Results View (Storage Bar + Minimal List)

    private func resultsView(_ result: LibraryAnalysisResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Hero banner with total savings
                resultsBanner(result)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                // Horizontal storage bar
                StorageBar(categories: result.categories, totalBytes: result.totalOptimizableBytes)
                    .padding(.horizontal, Spacing.md)

                // Media category list (edge-to-edge iOS 18 style)
                sectionHeader(
                    title: AppStrings.Analysis.sectionMedia,
                    icon: "photo.stack.fill",
                    color: .premiumPurple
                )
                .padding(.horizontal, Spacing.md)

                VStack(spacing: 0) {
                    ForEach(Array(result.categories.enumerated()), id: \.element.id) { index, category in
                        CategoryRow(category: category, analyzer: analyzer)

                        if index < result.categories.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
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
                .padding(.horizontal, Spacing.md)

                // System section header
                sectionHeader(
                    title: AppStrings.Analysis.sectionSystem,
                    icon: "gearshape.2.fill",
                    color: .appMint
                )
                .padding(.horizontal, Spacing.md)

                // Contacts results
                if case .completed(let contactResult) = contactsAnalyzer.state,
                   contactResult.totalIssueCount > 0 {
                    ContactCleanupCard(
                        result: contactResult,
                        analyzer: contactsAnalyzer
                    )
                    .padding(.horizontal, Spacing.md)
                }

                // Calendar results
                if case .completed(let calendarResult) = calendarAnalyzer.state,
                   calendarResult.totalIssueCount > 0 {
                    CalendarCleanupCard(
                        result: calendarResult,
                        analyzer: calendarAnalyzer
                    )
                    .padding(.horizontal, Spacing.md)
                }

                // Clipboard cleanup
                clipboardCleanupCard
                    .padding(.horizontal, Spacing.md)

                // iCloud tip
                iCloudTipCard
                    .padding(.horizontal, Spacing.md)

                Spacer(minLength: Spacing.xl)
            }
        }
    }

    // MARK: - Results Banner

    private func resultsBanner(_ result: LibraryAnalysisResult) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(AppStrings.Analysis.foundOptimizable)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(result.formattedTotalSize)
                        .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.appMint, .appTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .contentTransition(.numericText())
                }

                Spacer()

                // Stats column
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    HStack(spacing: 4) {
                        Text("\(result.totalAssetCount)")
                            .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                        Text(AppStrings.Analysis.items)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text("\(result.categories.count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                        Text(AppStrings.Analysis.categoriesLabel)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(Color.appMint.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.appMint.opacity(0.1), radius: 20, x: 0, y: 8)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Clipboard Card

    private var clipboardCleanupCard: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.premiumBlue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.premiumBlue)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(AppStrings.Analysis.clipboardTitle)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)
                    Text(AppStrings.Analysis.clipboardBody)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button(action: {
                Haptics.impact()
                if UIPasteboard.general.hasStrings || UIPasteboard.general.hasImages || UIPasteboard.general.hasURLs {
                    UIPasteboard.general.items = []
                    clipboardMessage = AppStrings.Analysis.clipboardCleared
                    Haptics.success()
                } else {
                    clipboardMessage = AppStrings.Analysis.clipboardEmpty
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    clipboardMessage = nil
                }
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: clipboardMessage != nil ? "checkmark" : "trash")
                        .font(.system(size: 14, weight: .semibold))
                    Text(clipboardMessage ?? AppStrings.Analysis.clipboardClear)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [Color.premiumBlue.opacity(0.9), Color.premiumBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
        }
        .padding(Spacing.md)
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

// MARK: - Neural Gradient Background (MeshGradient iOS 18 / Fallback)

private struct NeuralGradientBackground: View {
    let phase: CGFloat

    var body: some View {
        if #available(iOS 18.0, *) {
            meshGradientView
        } else {
            fallbackGradientView
        }
    }

    @available(iOS 18.0, *)
    private var meshGradientView: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                // Top row
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                // Middle row (shifts with phase for breathing effect)
                .init(0, 0.5),
                .init(Float(0.5 + sin(phase * .pi) * 0.1), Float(0.5 + cos(phase * .pi) * 0.1)),
                .init(1, 0.5),
                // Bottom row
                .init(0, 1), .init(0.5, 1), .init(1, 1)
            ],
            colors: [
                .black, Color(red: 0.05, green: 0.0, blue: 0.15), .black,
                Color(red: 0.0, green: 0.05, blue: 0.2),
                Color(red: 0.15, green: 0.0, blue: 0.35),
                Color(red: 0.0, green: 0.1, blue: 0.25),
                .black, Color(red: 0.05, green: 0.05, blue: 0.15), .black
            ]
        )
        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: phase)
    }

    private var fallbackGradientView: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.0, blue: 0.15),
                    .black,
                    Color(red: 0.0, green: 0.05, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Breathing purple orb
            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.0, blue: 0.45).opacity(0.6),
                    .clear
                ],
                center: UnitPoint(x: 0.3 + Double(phase) * 0.2, y: 0.4),
                startRadius: 30,
                endRadius: 250
            )
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: phase)

            // Breathing blue orb
            RadialGradient(
                colors: [
                    Color(red: 0.0, green: 0.1, blue: 0.4).opacity(0.4),
                    .clear
                ],
                center: UnitPoint(x: 0.7 - Double(phase) * 0.15, y: 0.6),
                startRadius: 20,
                endRadius: 200
            )
            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: phase)
        }
    }
}

// MARK: - Scanning Pill View (Frosted Glass with Rapid File Names)

private struct ScanningPillView: View {
    let currentStep: String
    let progress: Double
    let isActive: Bool

    @State private var displayIndex = 0
    @State private var time: Double = 0

    // Rapid file name rotation to simulate deep system scan
    private let scanPaths = [
        "DCIM/IMG_4829.HEIC",
        "Screenshots/Screen_2024.png",
        "Videos/MOV_1847.mp4",
        "Downloads/Report.pdf",
        "WhatsApp/IMG-2024.jpg",
        "Camera/IMG_5012.HEIC",
        "Bursts/burst_001.HEIC",
        "Selfies/photo_093.HEIC",
        "Live Photos/live_041.HEIC",
        "Panoramas/pano_007.HEIC"
    ]

    var body: some View {
        VStack(spacing: Spacing.xs) {
            // Main scanning pill
            HStack(spacing: Spacing.sm) {
                // Pulsing indicator dot
                Circle()
                    .fill(Color.appMint)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isActive ? 1.2 : 0.8)
                    .opacity(isActive ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isActive)

                // Rapidly flashing file path
                Text(isActive ? scanPaths[displayIndex % scanPaths.count] : currentStep)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: displayIndex)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )

            // Current step label below
            Text(currentStep)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .onAppear {
            startRapidRotation()
        }
    }

    private func startRapidRotation() {
        guard isActive else { return }
        // Rotate file names every 150ms for rapid scanning feel
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            if !isActive {
                timer.invalidate()
                return
            }
            displayIndex += 1

            // Haptic tick every ~0.5s
            if displayIndex % 3 == 0 {
                Haptics.soft()
            }
        }
    }
}

// MARK: - Horizontal Storage Bar (iOS Settings Style)

private struct StorageBar: View {
    let categories: [MediaCategory]
    let totalBytes: Int64

    private let categoryColors: [MediaCategory.CategoryType: Color] = [
        .screenshots: .warmOrange,
        .largeVideos: .premiumPurple,
        .duplicates: .premiumBlue,
        .similarPhotos: .appMint,
        .blurryPhotos: .warmCoral
    ]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // The bar itself
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(categories) { category in
                        let fraction = totalBytes > 0
                            ? CGFloat(category.totalBytes) / CGFloat(totalBytes)
                            : 0

                        RoundedRectangle(cornerRadius: 4)
                            .fill(categoryColors[category.type] ?? .gray)
                            .frame(width: max(4, geometry.size.width * fraction))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.tertiarySystemFill))
            )

            // Legend below the bar
            HStack(spacing: Spacing.md) {
                ForEach(categories) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(categoryColors[category.type] ?? .gray)
                            .frame(width: 8, height: 8)
                        Text(category.title)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Category Row (Minimal iOS 18 List Style)

private struct CategoryRow: View {
    let category: MediaCategory
    @ObservedObject var analyzer: PhotoLibraryAnalyzer
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

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("\(category.count) \(AppStrings.Analysis.items) · \(category.formattedSize)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Delete button
            Button(action: {
                guard SubscriptionManager.shared.canOneTapClean else {
                    Haptics.warning()
                    NotificationCenter.default.post(
                        name: .showPaywallForFeature,
                        object: nil,
                        userInfo: ["feature": PremiumFeature.oneTapClean]
                    )
                    return
                }
                Task {
                    isDeleting = true
                    Haptics.impact()
                    let success = await analyzer.deleteAssets(category.assets)
                    isDeleting = false
                    if success {
                        Haptics.success()
                        await analyzer.analyze()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else {
                        if !SubscriptionManager.shared.canOneTapClean {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                        }
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Temizle")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(iconColor)
                .clipShape(Capsule())
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Live Log View (Algorithmic Transparency)

private struct LiveLogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 6) {
                            Text(">")
                                .foregroundStyle(Color.appMint.opacity(0.6))
                            Text(line)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .id(index)
                    }
                }
                .padding(Spacing.sm)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .onChange(of: lines.count) { _, _ in
                if let last = lines.indices.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Contact Cleanup Card

private struct ContactCleanupCard: View {
    let result: ContactAnalysisResult
    @ObservedObject var analyzer: ContactsAnalyzer
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    @State private var isDeleting = false
    @State private var deletedCount = 0

    private var allItems: [ContactCleanupItem] {
        result.duplicates + result.namelessContacts + result.noInfoContacts
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(AppAnimation.spring) { isExpanded.toggle() }
                Haptics.selection()
            }) {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Color.appTeal.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.appTeal)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Rehber Temizliği")
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)
                        Text("\(result.totalIssueCount) sorunlu kişi bulundu")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(result.totalIssueCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.appTeal)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(Spacing.md)

            if isExpanded {
                Divider().padding(.horizontal, Spacing.md)

                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        if !result.duplicates.isEmpty {
                            contactPill("Tekrar: \(result.duplicates.count)", color: .warmOrange)
                        }
                        if !result.namelessContacts.isEmpty {
                            contactPill("İsimsiz: \(result.namelessContacts.count)", color: .premiumPurple)
                        }
                        if !result.noInfoContacts.isEmpty {
                            contactPill("Boş: \(result.noInfoContacts.count)", color: .warmCoral)
                        }
                    }

                    ForEach(allItems.prefix(5)) { item in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(item.displayName)
                                    .font(.appCaptionMedium)
                                    .foregroundStyle(.primary)
                                Text(item.detail)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    if allItems.count > 5 {
                        Text(AppStrings.Analysis.andMore(allItems.count - 5))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {
                        guard SubscriptionManager.shared.canOneTapClean else {
                            Haptics.warning()
                            NotificationCenter.default.post(
                                name: .showPaywallForFeature,
                                object: nil,
                                userInfo: ["feature": PremiumFeature.oneTapClean]
                            )
                            return
                        }
                        isDeleting = true
                        Haptics.impact()
                        var count = 0
                        for item in allItems {
                            if analyzer.deleteContact(item.contact) {
                                count += 1
                            }
                        }
                        deletedCount = count
                        isDeleting = false
                        if count > 0 {
                            Haptics.success()
                            Task { await analyzer.analyze() }
                        }
                    }) {
                        HStack(spacing: Spacing.xs) {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                if !SubscriptionManager.shared.canOneTapClean {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(AppStrings.Analysis.deleteContacts(allItems.count))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [Color.appTeal.opacity(0.9), Color.appTeal],
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

    private func contactPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Calendar Cleanup Card

private struct CalendarCleanupCard: View {
    let result: CalendarAnalysisResult
    @ObservedObject var analyzer: CalendarAnalyzer
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(AppAnimation.spring) { isExpanded.toggle() }
                Haptics.selection()
            }) {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Color.warmCoral.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.warmCoral)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Takvim Temizliği")
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)
                        Text("\(result.totalIssueCount) temizlenebilir öğe")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(result.totalIssueCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.warmCoral)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(Spacing.md)

            if isExpanded {
                Divider().padding(.horizontal, Spacing.md)

                VStack(spacing: Spacing.sm) {
                    if !result.oldEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(AppStrings.Analysis.calendarOldSubtitle(result.oldEvents.count))
                                .font(.appCaptionMedium)
                                .foregroundStyle(.secondary)

                            ForEach(result.oldEvents.prefix(5)) { item in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 14))
                                    VStack(alignment: .leading) {
                                        Text(item.title)
                                            .font(.appCaptionMedium)
                                            .lineLimit(1)
                                        Text(item.detail)
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }

                            if result.oldEvents.count > 5 {
                                Text(AppStrings.Analysis.andMore(result.oldEvents.count - 5))
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                            }

                            Button(action: {
                                guard SubscriptionManager.shared.canOneTapClean else {
                                    Haptics.warning()
                                    NotificationCenter.default.post(
                                        name: .showPaywallForFeature,
                                        object: nil,
                                        userInfo: ["feature": PremiumFeature.oneTapClean]
                                    )
                                    return
                                }
                                isDeleting = true
                                Haptics.impact()
                                let count = analyzer.deleteEvents(result.oldEvents)
                                isDeleting = false
                                if count > 0 {
                                    Haptics.success()
                                    Task { await analyzer.analyze() }
                                }
                            }) {
                                HStack(spacing: Spacing.xs) {
                                    if isDeleting {
                                        ProgressView().tint(.white)
                                    } else {
                                        if !SubscriptionManager.shared.canOneTapClean {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    Text(AppStrings.Analysis.deleteEvents(result.oldEvents.count))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color.warmCoral.opacity(0.9), Color.warmCoral],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            }
                            .disabled(isDeleting)
                        }
                    }

                    if !result.spamCalendars.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(AppStrings.Analysis.calendarSpamSubtitle(result.spamCalendars.count))
                                .font(.appCaptionMedium)
                                .foregroundStyle(.secondary)

                            ForEach(result.spamCalendars) { item in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.warmOrange)
                                        .font(.system(size: 14))
                                    Text(item.title)
                                        .font(.appCaptionMedium)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: {
                                        guard SubscriptionManager.shared.canOneTapClean else {
                                            Haptics.warning()
                                            NotificationCenter.default.post(
                                                name: .showPaywallForFeature,
                                                object: nil,
                                                userInfo: ["feature": PremiumFeature.oneTapClean]
                                            )
                                            return
                                        }
                                        Haptics.impact()
                                        if analyzer.removeCalendar(item) {
                                            Haptics.success()
                                            Task { await analyzer.analyze() }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            if !SubscriptionManager.shared.canOneTapClean {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            Text("Kaldır")
                                        }
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, Spacing.sm)
                                            .padding(.vertical, Spacing.xxs)
                                            .background(Color.warmCoral)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
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
}

// MARK: - Preview

#Preview {
    StorageAnalysisScreen(onBack: {})
}
