//
//  AnalyzeScreen.swift
//  optimize
//
//  File analysis screen showing file details and estimated savings
//

import SwiftUI

struct AnalyzeScreen: View {
    let file: FileInfo
    let analysisResult: AnalysisResult?

    let onContinue: () -> Void
    let onBack: () -> Void
    let onReplace: () -> Void

    @State private var showSkeleton = true

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: {
                    Haptics.selection()
                    onBack()
                }) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Geri")
                            .font(.appBody)
                    }
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.pressable)

                Spacer()

                Text("Analiz")
                    .font(.appSection)
                    .foregroundStyle(.primary)

                Spacer()

                // Placeholder for alignment
                Color.clear
                    .frame(width: 60)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // File Card
                    FileCard(
                        name: file.name,
                        sizeText: file.sizeFormatted,
                        typeIcon: file.fileType.icon,
                        subtitle: file.pageCount != nil ? "\(file.pageCount!) sayfa" : nil,
                        onReplace: onReplace
                    )

                    // Analysis Results
                    if let result = analysisResult {
                        GlassCard {
                            VStack(spacing: Spacing.md) {
                                // Section header
                                HStack {
                                    Text("Analiz Sonuçları")
                                        .font(.appSection)
                                        .foregroundStyle(.primary)
                                    Spacer()
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

                                KeyValueRow(
                                    key: "Görsel yoğunluğu",
                                    value: result.imageDensity.rawValue,
                                    valueColor: densityColor(result.imageDensity),
                                    icon: "photo.stack"
                                )

                                if let dpi = result.originalDPI {
                                    KeyValueRow(
                                        key: "Orijinal DPI",
                                        value: "\(dpi)",
                                        icon: "viewfinder"
                                    )
                                }

                                Divider()

                                // Savings meter
                                SavingsMeter(level: result.estimatedSavings)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                        // Warning if already optimized
                        if result.isAlreadyOptimized {
                            InfoBanner(
                                type: .warning,
                                message: "Bu dosya zaten optimize edilmiş olabilir. Beklenen kazanç düşük olabilir.",
                                dismissable: true
                            )
                        }
                    } else if showSkeleton {
                        // Skeleton loading state
                        AnalysisSkeletonView()
                    }

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }

            // Bottom CTA
            VStack(spacing: Spacing.sm) {
                PrimaryButton(
                    title: "Devam",
                    icon: "arrow.right",
                    isDisabled: analysisResult == nil
                ) {
                    onContinue()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .onAppear {
            // Simulate analysis loading
            if analysisResult != nil {
                withAnimation(AppAnimation.standard.delay(0.3)) {
                    showSkeleton = false
                }
            }
        }
    }

    private func densityColor(_ density: AnalysisResult.ImageDensity) -> Color {
        switch density {
        case .low: return .statusSuccess
        case .medium: return .statusWarning
        case .high: return .statusError
        }
    }
}

// MARK: - Skeleton Loading View
struct AnalysisSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                HStack {
                    SkeletonBox(width: 120, height: 20)
                    Spacer()
                }

                Divider()

                ForEach(0..<4, id: \.self) { _ in
                    HStack {
                        SkeletonBox(width: 100, height: 16)
                        Spacer()
                        SkeletonBox(width: 60, height: 16)
                    }
                }

                Divider()

                SkeletonBox(width: .infinity, height: 40)
            }
        }
        .opacity(isAnimating ? 0.6 : 1.0)
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

struct SkeletonBox: View {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
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
