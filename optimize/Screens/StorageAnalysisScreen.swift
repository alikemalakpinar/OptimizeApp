//
//  StorageAnalysisScreen.swift
//  optimize
//
//  Photo library storage analysis screen.
//  Shows categorized optimization opportunities (screenshots, large videos, duplicates)
//  and allows batch deletion with system confirmation.
//
//  UI/UX DESIGN:
//  - Scanning State: Canvas particle animation + live AI log view + haptic ticks
//  - Results State: Bento Box asymmetric grid layout with glassmorphic cards
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

    // MARK: - Scanning View (Particle Animation + Live Log)

    private var scanningView: some View {
        VStack(spacing: 0) {
            // Particle animation area
            ZStack {
                // Canvas-based particle effect
                ParticleScanCanvas(progress: analyzer.progress, isActive: analyzer.state == .analyzing)
                    .frame(height: 220)

                // Center progress ring with glow
                VStack(spacing: 8) {
                    ZStack {
                        // Breathing glow
                        Circle()
                            .fill(Color.premiumBlue.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .blur(radius: scanPhase > 0 ? 20 : 10)

                        // Background track
                        Circle()
                            .stroke(Color(.tertiarySystemFill), lineWidth: 6)
                            .frame(width: 80, height: 80)

                        // Progress arc
                        Circle()
                            .trim(from: 0, to: analyzer.progress)
                            .stroke(
                                LinearGradient(
                                    colors: [.premiumBlue, .appMint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: analyzer.progress)

                        // Percentage
                        Text("\(Int(analyzer.progress * 100))%")
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                    }

                    Text(analyzer.currentStep)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    scanPhase = 1
                }
            }

            // Live AI log view
            LiveLogView(lines: analyzer.logLines)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
        }
    }

    // MARK: - Results View (Bento Box Layout)

    private func resultsView(_ result: LibraryAnalysisResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                // Bento Box Grid
                bentoBanner(result)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                // Category bento grid
                bentoCategoryGrid(result)
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

    // MARK: - Bento Banner (Large hero card)

    private func bentoBanner(_ result: LibraryAnalysisResult) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(AppStrings.Analysis.foundOptimizable)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(result.formattedTotalSize)
                        .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appMint.opacity(0.2), Color.appTeal.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.appMint)
                }
            }

            // Mini stat pills
            HStack(spacing: Spacing.sm) {
                BentoStatPill(
                    value: "\(result.totalAssetCount)",
                    label: AppStrings.Analysis.items,
                    color: .premiumPurple
                )

                BentoStatPill(
                    value: "\(result.categories.count)",
                    label: AppStrings.Analysis.categoriesLabel,
                    color: .warmOrange
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(Color.appMint.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Bento Category Grid (Asymmetric)

    private func bentoCategoryGrid(_ result: LibraryAnalysisResult) -> some View {
        let cats = result.categories
        return VStack(spacing: Spacing.sm) {
            // Row 1: If 2+ categories, first one large + second small. Otherwise single full-width.
            if cats.count >= 2 {
                HStack(spacing: Spacing.sm) {
                    BentoCategoryCard(category: cats[0], analyzer: analyzer, style: .large)
                    BentoCategoryCard(category: cats[1], analyzer: analyzer, style: .small)
                }
            } else if cats.count == 1 {
                BentoCategoryCard(category: cats[0], analyzer: analyzer, style: .fullWidth)
            }

            // Row 2+: Remaining categories in pairs
            let remaining = Array(cats.dropFirst(2))
            ForEach(Array(stride(from: 0, to: remaining.count, by: 2)), id: \.self) { i in
                HStack(spacing: Spacing.sm) {
                    BentoCategoryCard(category: remaining[i], analyzer: analyzer, style: .half)
                    if i + 1 < remaining.count {
                        BentoCategoryCard(category: remaining[i + 1], analyzer: analyzer, style: .half)
                    } else {
                        // Placeholder for visual balance
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
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

// MARK: - Canvas Particle Animation

private struct ParticleScanCanvas: View {
    let progress: Double
    let isActive: Bool

    @State private var particles: [Particle] = []
    @State private var time: Double = 0

    struct Particle: Identifiable {
        let id = UUID()
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        var size: Double
        var opacity: Double
        var hue: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x * size.width - particle.size / 2,
                        y: particle.y * size.height - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    let color = Color(hue: particle.hue, saturation: 0.6, brightness: 0.9)
                    context.opacity = particle.opacity
                    context.fill(Circle().path(in: rect), with: .color(color))
                }
            }
            .onChange(of: timeline.date) { _, _ in
                updateParticles()
            }
        }
        .onAppear {
            // Spawn initial particles
            for _ in 0..<40 {
                particles.append(randomParticle())
            }
        }
    }

    private func updateParticles() {
        guard isActive else { return }
        time += 0.016

        // Haptic tick every ~0.5 seconds during active scan
        if Int(time * 2) != Int((time - 0.016) * 2) {
            Haptics.soft()
        }

        for i in particles.indices {
            // Move particles toward center as progress increases (organizing chaos)
            let centerX = 0.5
            let centerY = 0.5
            let pullStrength = progress * 0.02

            particles[i].x += particles[i].vx + (centerX - particles[i].x) * pullStrength
            particles[i].y += particles[i].vy + (centerY - particles[i].y) * pullStrength

            // Add slight oscillation
            particles[i].x += sin(time * 2 + Double(i)) * 0.001
            particles[i].y += cos(time * 2 + Double(i)) * 0.001

            // Wrap around
            if particles[i].x < 0 { particles[i].x = 1 }
            if particles[i].x > 1 { particles[i].x = 0 }
            if particles[i].y < 0 { particles[i].y = 1 }
            if particles[i].y > 1 { particles[i].y = 0 }

            // Fade opacity based on progress (more organized = more opaque)
            particles[i].opacity = 0.3 + progress * 0.5
            particles[i].size = 3 + progress * 4
        }
    }

    private func randomParticle() -> Particle {
        Particle(
            x: Double.random(in: 0...1),
            y: Double.random(in: 0...1),
            vx: Double.random(in: -0.002...0.002),
            vy: Double.random(in: -0.002...0.002),
            size: Double.random(in: 2...5),
            opacity: Double.random(in: 0.2...0.5),
            hue: Double.random(in: 0.5...0.7) // Blue-cyan range
        )
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
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .id(index)
                    }
                }
                .padding(Spacing.sm)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(Color.cardBorder.opacity(0.5), lineWidth: 1)
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

// MARK: - Bento Category Card

private struct BentoCategoryCard: View {
    let category: MediaCategory
    @ObservedObject var analyzer: PhotoLibraryAnalyzer
    let style: BentoStyle

    @Environment(\.colorScheme) private var colorScheme
    @State private var isDeleting = false

    enum BentoStyle {
        case large      // 2/3 width, tall
        case small      // 1/3 width, tall
        case half       // 1/2 width
        case fullWidth  // full width
    }

    private var iconColor: Color {
        switch category.iconColor {
        case "warmOrange": return .warmOrange
        case "premiumPurple": return .premiumPurple
        case "warmCoral": return .warmCoral
        default: return .appMint
        }
    }

    private var isCompact: Bool {
        style == .small
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? Spacing.xs : Spacing.sm) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)

                Image(systemName: category.icon)
                    .font(.system(size: isCompact ? 16 : 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Title
            Text(category.title)
                .font(.system(size: isCompact ? 13 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Count
            Text("\(category.count)")
                .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(iconColor)

            // Size
            Text(category.formattedSize)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

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
                    }

                    if !isCompact {
                        Text("Temizle")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }
            .disabled(isDeleting)
        }
        .padding(isCompact ? Spacing.sm : Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: style == .large || style == .small ? 200 : nil)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Bento Stat Pill

private struct BentoStatPill: View {
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
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
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
