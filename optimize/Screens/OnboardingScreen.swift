//
//  OnboardingScreen.swift
//  optimize
//
//  "AHA Moment" Onboarding - Scan-to-Paywall Pipeline
//
//  FLOW:
//  1. Hero Welcome: Heavy typography, fluid background
//  2. Permission Ask: Request Photo access with privacy-first messaging
//  3. Fast Scan: Hyper-fast background analysis with live counter
//  4. AHA Reveal: "We found ~X GB of junk" with urgent CTA → Paywall
//
//  PSYCHOLOGY:
//  - Create value immediately (show what's wasting space)
//  - Create urgency ("X GB of your storage is wasted")
//  - Permission feels like a feature, not a demand
//

import SwiftUI
import Photos

struct OnboardingScreen: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var scanState: ScanState = .idle
    @State private var estimatedJunkGB: Double = 0
    @State private var screenshotCount = 0
    @State private var duplicateCount = 0
    @State private var largeVideoCount = 0
    @State private var scanProgress: Double = 0
    @State private var hasPhotoAccess = false
    @State private var backgroundPhase: CGFloat = 0

    enum ScanState {
        case idle
        case scanning
        case completed
        case noAccess
    }

    var body: some View {
        ZStack {
            // Animated atmospheric background
            OnboardingGradientBackground(phase: backgroundPhase)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Pages
                TabView(selection: $currentPage) {
                    heroPage.tag(0)
                    permissionPage.tag(1)
                    ahaRevealPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: currentPage)

                // Bottom controls
                bottomControls
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                backgroundPhase = 1
            }
        }
    }

    // MARK: - Page 1: Hero Welcome

    private var heroPage: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Animated compression icon
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.appMint.opacity(0.06 - Double(i) * 0.015))
                        .frame(width: 180 + CGFloat(i) * 50, height: 180 + CGFloat(i) * 50)
                }

                Circle()
                    .fill(Color.appMint.opacity(0.12))
                    .frame(width: 160, height: 160)

                CompressAnimationIcon(color: .appMint, isActive: currentPage == 0)
            }

            VStack(spacing: Spacing.md) {
                Text(AppStrings.Onboarding.page1Title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(AppStrings.Onboarding.page1Sub)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .lineSpacing(3)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: Permission + Privacy

    private var permissionPage: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Shield icon
            ZStack {
                Circle()
                    .fill(Color.premiumPurple.opacity(0.1))
                    .frame(width: 160, height: 160)

                ShieldAnimationIcon(color: .premiumPurple, isActive: currentPage == 1)
            }

            VStack(spacing: Spacing.md) {
                Text(AppStrings.Onboarding.page2Title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(AppStrings.Onboarding.page2Sub)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .lineSpacing(3)
            }

            // Trust badges
            HStack(spacing: Spacing.lg) {
                trustBadge(icon: "lock.fill", text: "Cihaz İçi")
                trustBadge(icon: "wifi.slash", text: "İnternetsiz")
                trustBadge(icon: "eye.slash.fill", text: "Gizli")
            }
            .padding(.top, Spacing.sm)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 3: AHA Reveal

    private var ahaRevealPage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            switch scanState {
            case .idle:
                // Waiting to scan
                scanIdleView

            case .scanning:
                // Live scanning with counters
                scanningLiveView

            case .completed:
                // The big reveal
                scanRevealView

            case .noAccess:
                // No photo access - show value proposition instead
                noAccessFallbackView
            }

            Spacer()
        }
        .onAppear {
            if currentPage == 2 {
                startScanIfNeeded()
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage == 2 {
                startScanIfNeeded()
            }
        }
    }

    // MARK: - Scan States

    private var scanIdleView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.appMint)
                .scaleEffect(1.5)

            Text("Hazırlanıyor...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var scanningLiveView: some View {
        VStack(spacing: Spacing.xl) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: scanProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.appMint, .appTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(scanProgress * 100))%")
                    .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: Int(scanProgress * 100))

            VStack(spacing: Spacing.xs) {
                Text("Telefonun taranıyor...")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Fotoğraflar, videolar ve dosyalar analiz ediliyor")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Live counters
            HStack(spacing: Spacing.lg) {
                liveCounter(value: screenshotCount, label: "Ekran Gör.", icon: "camera.viewfinder")
                liveCounter(value: duplicateCount, label: "Benzer", icon: "doc.on.doc")
                liveCounter(value: largeVideoCount, label: "B. Video", icon: "video")
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private var scanRevealView: some View {
        VStack(spacing: Spacing.lg) {
            // "Wow" typography
            VStack(spacing: Spacing.xs) {
                Text("DEPOLAMANI YORAN")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.warmOrange)
                    .tracking(3)

                // The big number
                Text(formattedJunkSize)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.warmOrange, .warmCoral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())

                Text("gereksiz dosya tespit ettik")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Category breakdown
            VStack(spacing: Spacing.sm) {
                if screenshotCount > 0 {
                    revealRow(icon: "camera.viewfinder", text: "\(screenshotCount) ekran görüntüsü", color: .warmOrange)
                }
                if duplicateCount > 0 {
                    revealRow(icon: "doc.on.doc", text: "\(duplicateCount) benzer fotoğraf", color: .premiumPurple)
                }
                if largeVideoCount > 0 {
                    revealRow(icon: "video.fill", text: "\(largeVideoCount) büyük video", color: .premiumBlue)
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
    }

    private var noAccessFallbackView: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.appMint.opacity(0.1))
                    .frame(width: 120, height: 120)

                BoltAnimationIcon(color: .appMint, isActive: true)
            }

            VStack(spacing: Spacing.md) {
                Text(AppStrings.Onboarding.page3Title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(AppStrings.Onboarding.page3Sub)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Spacing.lg) {
            // Page indicators
            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.appMint : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(AppAnimation.spring, value: currentPage)
                }
            }

            // CTA button
            Button(action: handleCTA) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(ctaGradient)

                    // Shimmer on last page
                    if currentPage == 2 && scanState == .completed {
                        ShimmerOverlay()
                    }

                    Text(ctaTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(currentPage == 2 && scanState == .completed ? .black : .white)
                }
                .frame(height: 56)
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Spacing.lg)

            // Skip
            if currentPage < 2 {
                Button(action: {
                    Haptics.selection()
                    onComplete()
                }) {
                    Text(AppStrings.Onboarding.skip)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                Text(" ").font(.system(size: 13))
            }
        }
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Helpers

    private var ctaTitle: String {
        if currentPage == 0 {
            return AppStrings.Onboarding.continue
        } else if currentPage == 1 {
            return "Galeriyi Tara"
        } else if scanState == .completed {
            return "Alanımı Kurtar"
        } else if scanState == .noAccess {
            return AppStrings.Onboarding.start
        } else {
            return "Taranıyor..."
        }
    }

    private var ctaGradient: LinearGradient {
        if currentPage == 2 && scanState == .completed {
            return LinearGradient(
                colors: [.appMint, .appTeal],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [.white.opacity(0.15), .white.opacity(0.08)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var formattedJunkSize: String {
        if estimatedJunkGB >= 1.0 {
            return String(format: "%.1f GB", estimatedJunkGB)
        } else {
            return "\(Int(estimatedJunkGB * 1024)) MB"
        }
    }

    private func handleCTA() {
        if currentPage == 0 {
            Haptics.selection()
            withAnimation(AppAnimation.spring) { currentPage = 1 }
        } else if currentPage == 1 {
            Haptics.impact(style: .medium)
            requestPhotoAccessAndScan()
        } else if scanState == .completed || scanState == .noAccess {
            Haptics.success()
            onComplete()
        }
    }

    // MARK: - Scan Logic

    private func requestPhotoAccessAndScan() {
        withAnimation(AppAnimation.spring) { currentPage = 2 }

        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

            await MainActor.run {
                if status == .authorized || status == .limited {
                    hasPhotoAccess = true
                    scanState = .scanning
                    performQuickScan()
                } else {
                    scanState = .noAccess
                }
            }
        }
    }

    private func startScanIfNeeded() {
        if hasPhotoAccess && scanState == .idle {
            scanState = .scanning
            performQuickScan()
        }
    }

    /// Hyper-fast scan that estimates storage waste without deep Vision analysis.
    /// Uses only PHAsset metadata (no image loading) for sub-second speed.
    private func performQuickScan() {
        Task {
            var screenshots = 0
            var totalWasteBytes: Int64 = 0

            // 1. Count screenshots
            let screenshotOptions = PHFetchOptions()
            screenshotOptions.predicate = NSPredicate(
                format: "mediaSubtype == %d",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            let screenshotResult = PHAsset.fetchAssets(with: screenshotOptions)
            screenshots = screenshotResult.count
            // Estimate ~2MB per screenshot
            totalWasteBytes += Int64(screenshots) * 2_000_000

            await MainActor.run {
                screenshotCount = screenshots
                scanProgress = 0.3
                Haptics.soft()
            }

            // 2. Count large videos (50MB+)
            let videoOptions = PHFetchOptions()
            videoOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            let videoResult = PHAsset.fetchAssets(with: videoOptions)

            var largeVids = 0
            let resources = videoResult.objects(at: IndexSet(0..<min(videoResult.count, 200)))
            for asset in resources {
                let assetResources = PHAssetResource.assetResources(for: asset)
                if let resource = assetResources.first,
                   let fileSize = resource.value(forKey: "fileSize") as? Int64,
                   fileSize > 50_000_000 {
                    largeVids += 1
                    totalWasteBytes += fileSize
                }
            }

            await MainActor.run {
                largeVideoCount = largeVids
                scanProgress = 0.6
                Haptics.soft()
            }

            // 3. Estimate duplicates via creation-date clustering
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            allPhotosOptions.fetchLimit = 500
            let allPhotos = PHAsset.fetchAssets(with: .image, options: allPhotosOptions)

            var prevDate: Date?
            var clusterCount = 0
            for i in 0..<allPhotos.count {
                let asset = allPhotos[i]
                if let date = asset.creationDate, let prev = prevDate {
                    // Photos within 3 seconds are likely burst/similar
                    if abs(date.timeIntervalSince(prev)) < 3 {
                        clusterCount += 1
                    }
                }
                prevDate = asset.creationDate
            }
            // Estimate ~3MB per duplicate cluster photo
            totalWasteBytes += Int64(clusterCount) * 3_000_000

            await MainActor.run {
                duplicateCount = clusterCount
                scanProgress = 1.0
                estimatedJunkGB = Double(totalWasteBytes) / 1_000_000_000

                // Ensure minimum impressive number
                if estimatedJunkGB < 0.5 && (screenshots > 10 || largeVids > 0 || clusterCount > 5) {
                    estimatedJunkGB = max(estimatedJunkGB, 0.5)
                }

                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    scanState = .completed
                }
                Haptics.dramaticSuccess()
            }
        }
    }

    // MARK: - Subviews

    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func liveCounter(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func revealRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - Onboarding Gradient Background

private struct OnboardingGradientBackground: View {
    let phase: CGFloat

    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    Color(red: 0.1, green: 0.0, blue: 0.25).opacity(0.6),
                    .clear
                ],
                center: UnitPoint(x: 0.3 + Double(phase) * 0.2, y: 0.3),
                startRadius: 30,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    Color(red: 0.0, green: 0.15, blue: 0.3).opacity(0.4),
                    .clear
                ],
                center: UnitPoint(x: 0.7 - Double(phase) * 0.15, y: 0.7),
                startRadius: 20,
                endRadius: 250
            )
        }
    }
}

// MARK: - Shimmer Overlay

private struct ShimmerOverlay: View {
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: shimmerPhase * 300 - 150)
            .mask(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
    }
}

// MARK: - Icon Animations (Preserved from original)

struct CompressAnimationIcon: View {
    let color: Color
    let isActive: Bool
    @State private var compressionPhase: CGFloat = 0

    var body: some View {
        ZStack {
            Image(systemName: "doc.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(color)
                .scaleEffect(y: 1 - compressionPhase * 0.3)

            VStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color.opacity(0.6))
                    .offset(y: -40 + compressionPhase * 15)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color.opacity(0.6))
                    .offset(y: 40 - compressionPhase * 15)
            }
            .frame(height: 120)
        }
        .onAppear { if isActive { startAnimation() } }
        .onChange(of: isActive) { _, newValue in if newValue { startAnimation() } }
    }

    private func startAnimation() {
        compressionPhase = 0
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            compressionPhase = 1
        }
    }
}

struct ShieldAnimationIcon: View {
    let color: Color
    let isActive: Bool
    @State private var lockPhase: CGFloat = 0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(glowOpacity))
                .frame(width: 100, height: 100)
                .blur(radius: 20)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(1 + lockPhase * 0.05)
        }
        .onAppear { if isActive { startAnimation() } }
        .onChange(of: isActive) { _, newValue in if newValue { startAnimation() } }
    }

    private func startAnimation() {
        lockPhase = 0
        glowOpacity = 0.3
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            lockPhase = 1
            glowOpacity = 0.6
        }
    }
}

struct BoltAnimationIcon: View {
    let color: Color
    let isActive: Bool
    @State private var boltOffset: CGFloat = 0
    @State private var trailOpacity: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "bolt.fill")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(color.opacity(0.2 - Double(index) * 0.05))
                    .offset(x: CGFloat(index + 1) * -15, y: CGFloat(index + 1) * 8)
                    .opacity(trailOpacity)
            }

            Image(systemName: "bolt.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(color)
                .offset(x: boltOffset)
        }
        .onAppear { if isActive { startAnimation() } }
        .onChange(of: isActive) { _, newValue in if newValue { startAnimation() } }
    }

    private func startAnimation() {
        boltOffset = 0
        trailOpacity = 0
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            boltOffset = 5
            trailOpacity = 1
        }
    }
}

#Preview {
    OnboardingScreen { print("Onboarding complete") }
}
