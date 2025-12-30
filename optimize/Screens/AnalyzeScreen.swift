//
//  AnalyzeScreen.swift
//  optimize
//
//  File analysis screen with real analysis results
//

import SwiftUI

struct AnalyzeScreen: View {
    let file: FileInfo
    let analysisResult: AnalysisResult?

    let onContinue: () -> Void
    let onBack: () -> Void
    let onReplace: () -> Void

    @State private var isAnalyzing = true
    @State private var statusIndex = 0
    @State private var showResults = false

    // User-friendly analysis messages
    private let analysisMessages = [
        "Görseller taranıyor...",
        "Metin alanları inceleniyor...",
        "Gereksiz veriler tespit ediliyor...",
        "En iyi sıkıştırma stratejisi belirleniyor...",
        "Dosya haritası çıkarılıyor..."
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader("Analiz", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    // File Card
                    FileCard(
                        name: file.name,
                        sizeText: file.sizeFormatted,
                        typeIcon: file.fileType.icon,
                        subtitle: file.pageCount != nil ? "\(file.pageCount!) sayfa" : nil,
                        onReplace: onReplace
                    )

                    // Analysis Animation or Results
                    if isAnalyzing || analysisResult == nil {
                        AnalysisScanView(
                            statusMessages: analysisMessages,
                            currentIndex: statusIndex
                        )
                        .transition(.opacity)
                    } else if let result = analysisResult {
                        // Analysis Results Card
                        AnalysisResultCard(result: result)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))

                        // Warning if already optimized
                        if result.isAlreadyOptimized {
                            InfoBanner(
                                type: .warning,
                                message: "Bu dosya zaten optimize edilmiş olabilir. Beklenen kazanç düşük olabilir.",
                                dismissable: true
                            )
                        }
                    }

                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }

            // Bottom CTA
            VStack(spacing: Spacing.sm) {
                PrimaryButton(
                    title: isAnalyzing ? "Analiz Ediliyor..." : "Devam",
                    icon: isAnalyzing ? nil : "arrow.right",
                    isLoading: isAnalyzing,
                    isDisabled: isAnalyzing || analysisResult == nil
                ) {
                    onContinue()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.appBackground)
        }
        .appBackgroundLayered()
        .onAppear {
            startAnalysisAnimation()
        }
        .onChange(of: analysisResult) { _, newValue in
            if newValue != nil {
                completeAnalysis()
            }
        }
    }

    private func startAnalysisAnimation() {
        // Cycle through status messages
        let messageInterval: Double = 0.6
        for (index, _) in analysisMessages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * messageInterval) {
                withAnimation {
                    statusIndex = index
                }
                Haptics.selection()
            }
        }

        // Check if we already have results
        if analysisResult != nil {
            let totalDuration = Double(analysisMessages.count) * messageInterval
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
                completeAnalysis()
            }
        }
    }

    private func completeAnalysis() {
        withAnimation(AppAnimation.spring) {
            isAnalyzing = false
            showResults = true
        }
        Haptics.success()
    }
}

// MARK: - Analysis Scan View
struct AnalysisScanView: View {
    let statusMessages: [String]
    let currentIndex: Int

    @State private var scanPosition: CGFloat = 0

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.lg) {
                // Document with scan line
                ZStack {
                    // Document background
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color.appSurface)
                        .frame(width: 120, height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                        )

                    // Fake content lines
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<6, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: CGFloat.random(in: 60...90), height: 6)
                        }
                    }
                    .padding()

                    // Scan line overlay
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color.clear)
                        .frame(width: 120, height: 160)
                        .overlay(
                            GeometryReader { geometry in
                                // Scan line
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, Color.appMint.opacity(0.5), Color.appMint, Color.appMint.opacity(0.5), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 3)
                                    .blur(radius: 1)
                                    .offset(y: scanPosition * (geometry.size.height - 3))

                                // Scan glow
                                Rectangle()
                                    .fill(Color.appMint.opacity(0.1))
                                    .frame(height: 40)
                                    .blur(radius: 10)
                                    .offset(y: scanPosition * (geometry.size.height - 40))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }

                // Status text with typing effect
                VStack(spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appMint))
                            .scaleEffect(0.8)

                        Text(statusMessages[min(currentIndex, statusMessages.count - 1)])
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .animation(.easeInOut(duration: 0.2), value: currentIndex)
                    }

                    // Progress dots
                    HStack(spacing: Spacing.xxs) {
                        ForEach(0..<statusMessages.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentIndex ? Color.appMint : Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                scanPosition = 1
            }
        }
    }
}

// MARK: - Analysis Result Card
struct AnalysisResultCard: View {
    let result: AnalysisResult

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                // Section header
                HStack {
                    Text("Analiz Sonuçları")
                        .font(.appSection)
                        .foregroundStyle(.primary)
                    Spacer()

                    // Checkmark badge
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appMint)
                        .font(.system(size: 20))
                }

                Divider()

                // Key-value rows
                KeyValueRow(
                    key: "Sayfa",
                    value: "\(result.pageCount)",
                    icon: "doc.text"
                )

                KeyValueRow(
                    key: "Görsel sayısı",
                    value: "\(result.imageCount)",
                    icon: "photo"
                )

                // Image Density Gauge
                ImageDensityGauge(density: result.imageDensity)

                if let dpi = result.originalDPI {
                    KeyValueRow(
                        key: "Orijinal DPI",
                        value: "\(dpi)",
                        icon: "viewfinder"
                    )
                }

                Divider()

                // Savings potential with visual
                SavingsPotentialView(level: result.estimatedSavings)
            }
        }
    }
}

// MARK: - Image Density Gauge
struct ImageDensityGauge: View {
    let density: AnalysisResult.ImageDensity

    private var gaugeValue: Double {
        switch density {
        case .low: return 0.25
        case .medium: return 0.55
        case .high: return 0.85
        }
    }

    private var gaugeColor: Color {
        switch density {
        case .low: return .appMint
        case .medium: return .statusWarning
        case .high: return .statusError
        }
    }

    private var needleRotation: Double {
        // Convert 0-1 to -45 to 45 degrees
        return (gaugeValue - 0.5) * 90
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            Image(systemName: "photo.stack")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appAccent)
                .frame(width: 24)

            Text("Görsel yoğunluğu")
                .font(.appBody)
                .foregroundStyle(.secondary)

            Spacer()

            // Mini gauge
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(90))

                // Colored arc
                Circle()
                    .trim(from: 0.25, to: 0.25 + gaugeValue * 0.5)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(90))

                // Needle
                Rectangle()
                    .fill(gaugeColor)
                    .frame(width: 2, height: 12)
                    .offset(y: -6)
                    .rotationEffect(.degrees(needleRotation))
            }

            Text(density.rawValue)
                .font(.appCaptionMedium)
                .foregroundStyle(gaugeColor)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(gaugeColor.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Savings Potential View
struct SavingsPotentialView: View {
    let level: SavingsLevel

    private var percentage: Int {
        switch level {
        case .low: return 25
        case .medium: return 50
        case .high: return 70
        }
    }

    private var barWidth: CGFloat {
        switch level {
        case .low: return 0.3
        case .medium: return 0.55
        case .high: return 0.8
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Tahmini Tasarruf")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                Spacer()

                Text("~%\(percentage)")
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appMint)
            }

            // Visual bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 12)

                    // Filled portion (waste data)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.statusError.opacity(0.7), Color.statusWarning.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * barWidth, height: 12)
                }
            }
            .frame(height: 12)

            // Legend
            HStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xxs) {
                    Circle()
                        .fill(Color.statusError.opacity(0.7))
                        .frame(width: 8, height: 8)
                    Text("Optimize edilebilir")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: Spacing.xxs) {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 8, height: 8)
                    Text("Korunacak veri")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    AnalyzeScreen(
        file: FileInfo(
            name: "Rapor_2024.pdf",
            url: URL(fileURLWithPath: "/test.pdf"),
            size: 300_000_000,
            pageCount: 84,
            fileType: .pdf
        ),
        analysisResult: AnalysisResult(
            pageCount: 84,
            imageCount: 42,
            imageDensity: .high,
            estimatedSavings: .high,
            isAlreadyOptimized: false,
            originalDPI: 300
        ),
        onContinue: {},
        onBack: {},
        onReplace: {}
    )
}
