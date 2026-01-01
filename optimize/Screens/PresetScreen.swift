//
//  PresetScreen.swift
//  optimize
//
//  Preset selection screen with quality preview simulation
//

import SwiftUI

struct PresetScreen: View {
    let file: FileInfo
    let analysisResult: AnalysisResult
    let isProUser: Bool

    @State private var selectedPresetId: String
    @State private var wifiOnly = true
    @State private var deleteAfterProcess = false
    @State private var customTargetMB: Double

    let presets: [CompressionPreset]
    let onCompress: (CompressionPreset) -> Void
    let onBack: () -> Void
    let onShowPaywall: () -> Void

    private let recommendedPresetId: String

    init(
        file: FileInfo,
        analysisResult: AnalysisResult,
        isProUser: Bool = false,
        presets: [CompressionPreset] = CompressionPreset.defaultPresets,
        onCompress: @escaping (CompressionPreset) -> Void,
        onBack: @escaping () -> Void,
        onShowPaywall: @escaping () -> Void
    ) {
        self.file = file
        self.analysisResult = analysisResult
        self.isProUser = isProUser
        self.presets = presets
        self.onCompress = onCompress
        self.onBack = onBack
        self.onShowPaywall = onShowPaywall

        let defaultPreset = PresetScreen.recommendedPresetId(for: analysisResult)
        let suggestedTargetMB = max(5, min(50, file.sizeMB * 0.6))
        self.recommendedPresetId = defaultPreset
        _selectedPresetId = State(initialValue: defaultPreset)
        _customTargetMB = State(initialValue: suggestedTargetMB)
    }

    var selectedPreset: CompressionPreset? {
        if selectedPresetId == "custom" {
            // Return custom preset with user-defined target size
            return CompressionPreset(
                id: "custom",
                name: "Custom Size",
                description: "\(Int(customTargetMB)) MB target",
                icon: "slider.horizontal.3",
                targetSizeMB: Int(customTargetMB),
                quality: .custom,
                isProOnly: false // Already unlocked if selected
            )
        }
        return presets.first { $0.id == selectedPresetId }
    }

    private var recommendedPreset: CompressionPreset? {
        presets.first { $0.id == recommendedPresetId }
    }

    private var estimatedSavingsPercent: Int {
        guard let preset = selectedPreset else { return 0 }
        return PresetScreen.estimatedSavingsPercent(
            for: preset,
            analysis: analysisResult
        )
    }

    private var estimatedOutputSizeText: String {
        guard let preset = selectedPreset else { return "-" }
        let estimatedMB = PresetScreen.estimatedOutputSizeMB(
            for: preset,
            file: file,
            analysis: analysisResult
        )
        let estimatedBytes = Int64(estimatedMB * 1_000_000)
        return ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
    }

    private static func recommendedPresetId(for analysis: AnalysisResult) -> String {
        if analysis.estimatedSavings == .high || analysis.imageDensity == .high {
            return "mail"
        } else if analysis.imageDensity == .medium {
            return "whatsapp"
        } else {
            return "quality"
        }
    }

    private static func estimatedSavingsPercent(for preset: CompressionPreset, analysis: AnalysisResult) -> Int {
        let base: Double
        switch analysis.estimatedSavings {
        case .high: base = 0.65
        case .medium: base = 0.45
        case .low: base = 0.28
        }

        let presetAdjustment: Double
        switch preset.quality {
        case .low: presetAdjustment = 0.12
        case .medium: presetAdjustment = 0.05
        case .high: presetAdjustment = 0.0
        case .custom: presetAdjustment = 0.08
        }

        let combined = max(0.15, min(0.9, base + presetAdjustment))
        return Int(combined * 100)
    }

    private static func estimatedOutputSizeMB(for preset: CompressionPreset, file: FileInfo, analysis: AnalysisResult) -> Double {
        let savingsPercent = Double(estimatedSavingsPercent(for: preset, analysis: analysis)) / 100
        let reduced = max(1, file.sizeMB * (1 - savingsPercent))

        if let target = preset.targetSizeMB {
            return max(1, min(Double(target), reduced))
        }

        return reduced
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact Navigation Header
            NavigationHeader("Target", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    OutcomeSummaryCard(
                        file: file,
                        analysis: analysisResult,
                        selectedPreset: selectedPreset,
                        recommendedPresetId: recommendedPresetId,
                        recommendedPreset: recommendedPreset,
                        estimatedSavingsPercent: estimatedSavingsPercent,
                        estimatedOutputText: estimatedOutputSizeText
                    )

                    // Quality Preview Card
                    QualityPreviewCard(selectedPresetId: selectedPresetId)

                    ValuePropGrid()

                    if !isProUser {
                        InfoBanner(
                            type: .info,
                            message: "Özel hedefler, 50 MB üzeri dosyalar ve sınırsız kullanım için Pro'ya geç.",
                            dismissable: false
                        )
                    }

                    // Preset Grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Spacing.sm),
                            GridItem(.flexible(), spacing: Spacing.sm)
                        ],
                        spacing: Spacing.sm
                    ) {
                        ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                            EnhancedPresetCard(
                                preset: preset,
                                isSelected: selectedPresetId == preset.id
                            ) {
                                if preset.isProOnly {
                                    onShowPaywall()
                                } else {
                                    withAnimation(AppAnimation.spring) {
                                        selectedPresetId = preset.id
                                    }
                                    Haptics.selection()
                                }
                            }
                            .accessibilityLabel("\(preset.name), \(preset.description)")
                            .accessibilityValue(selectedPresetId == preset.id ? "Selected" : "Not selected")
                            .accessibilityHint(preset.isProOnly ? "Pro feature, tap to unlock" : "Tap to select")
                            .accessibilityAddTraits(selectedPresetId == preset.id ? .isSelected : [])
                            .staggeredAppearance(index: index)
                        }
                    }

                    // Custom Size Slider (shown when custom preset is selected)
                    if selectedPresetId == "custom" {
                        CustomSizeSlider(targetMB: $customTargetMB)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Settings section
                    GlassCard {
                        VStack(spacing: Spacing.md) {
                            ToggleRow(
                                title: "Process on Wi-Fi",
                                subtitle: "Don't use mobile data",
                                icon: "wifi",
                                isOn: $wifiOnly
                            )

                            Divider()

                            ToggleRow(
                                title: "Delete after processing",
                                subtitle: "Remove original file",
                                icon: "trash",
                                isOn: $deleteAfterProcess
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
                    title: "Compress",
                    icon: "bolt.fill",
                    isDisabled: selectedPreset == nil
                ) {
                    if let preset = selectedPreset {
                        Haptics.impact()
                        onCompress(preset)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.appBackground)
        }
        .appBackgroundLayered()
    }
}

// MARK: - Outcome Summary Card
struct OutcomeSummaryCard: View {
    let file: FileInfo
    let analysis: AnalysisResult
    let selectedPreset: CompressionPreset?
    let recommendedPresetId: String
    let recommendedPreset: CompressionPreset?
    let estimatedSavingsPercent: Int
    let estimatedOutputText: String

    private var badgeLabel: String {
        if let preset = selectedPreset {
            return preset.id == recommendedPresetId ? "Recommended" : "Selected"
        }
        if let recommendedPreset {
            return "Recommended: \(recommendedPreset.name)"
        }
        return "Recommended"
    }

    private var badgeColor: Color {
        if let preset = selectedPreset, preset.id == recommendedPresetId {
            return .appMint
        }
        return .appAccent
    }

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(selectedPreset?.name ?? "Choose the right target")
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)

                        Text("\(analysis.imageDensity.rawValue) content • \(file.sizeFormatted)")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(badgeLabel)
                        .font(.appCaptionMedium)
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(badgeColor.opacity(Opacity.subtle))
                        .clipShape(Capsule())
                }

                EstimatedSavings(
                    originalSize: file.sizeFormatted,
                    estimatedSize: estimatedOutputText,
                    savingsPercent: estimatedSavingsPercent
                )

                HStack(spacing: Spacing.sm) {
                    BenefitRow(
                        icon: "sparkles",
                        title: "Smart optimization",
                        subtitle: "Adjusted for image density"
                    )

                    BenefitRow(
                        icon: "bolt.fill",
                        title: "Real-time progress",
                        subtitle: "Watch as compression begins"
                    )
                }
            }
        }
    }
}

// MARK: - Value Prop Grid
struct ValuePropGrid: View {
    private let items: [ValuePropItemModel] = [
        .init(
            icon: "lock.shield",
            title: "On-device security",
            subtitle: "Files processed without cloud upload"
        ),
        .init(
            icon: "hand.thumbsup",
            title: "Quality guarantee",
            subtitle: "Text stays sharp, colors balanced"
        ),
        .init(
            icon: "clock.arrow.2.circlepath",
            title: "Time saver",
            subtitle: "One-tap ready-to-share sizes"
        ),
        .init(
            icon: "arrow.uturn.backward",
            title: "Retry protection",
            subtitle: "Quick retry if something fails"
        )
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Fine-tune for higher success")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.sm),
                        GridItem(.flexible(), spacing: Spacing.sm)
                    ],
                    spacing: Spacing.sm
                ) {
                    ForEach(items) { item in
                        ValuePropItem(item: item)
                    }
                }
            }
        }
    }
}

struct ValuePropItemModel: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

struct ValuePropItem: View {
    let item: ValuePropItemModel

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(Opacity.subtle))
                    .frame(width: 32, height: 32)

                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.title)
                    .font(.appCaptionMedium)
                    .foregroundStyle(.primary)

                Text(item.subtitle)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(Color.appMint.opacity(Opacity.subtle))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.appMint)
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.appCaptionMedium)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Quality Preview Card
struct QualityPreviewCard: View {
    let selectedPresetId: String?

    private var blurAmount: CGFloat {
        switch selectedPresetId {
        case "mail": return 2.0
        case "whatsapp": return 1.0
        case "quality": return 0.0
        case "custom": return 0.5
        default: return 0.0
        }
    }

    private var qualityLabel: String {
        switch selectedPresetId {
        case "mail": return "Medium Quality"
        case "whatsapp": return "Good Quality"
        case "quality": return "Best Quality"
        case "custom": return "Custom Settings"
        default: return "Preview"
        }
    }

    private var qualityColor: Color {
        switch selectedPresetId {
        case "mail": return .statusWarning
        case "whatsapp": return .appMint
        case "quality": return .appAccent
        case "custom": return .purple
        default: return .secondary
        }
    }

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                HStack {
                    Text("Quality Preview")
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(qualityLabel)
                        .font(.appCaptionMedium)
                        .foregroundStyle(qualityColor)
                }

                // Preview image simulation
                ZStack {
                    // Sample "image" with varying blur
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                        .overlay(
                            // Fake content
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: 30, height: 30)

                                    VStack(alignment: .leading, spacing: 3) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 80, height: 8)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.4))
                                            .frame(width: 50, height: 6)
                                    }
                                }

                                Spacer()

                                HStack(spacing: 4) {
                                    ForEach(0..<4, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 40, height: 30)
                                    }
                                }
                            }
                            .padding(Spacing.sm)
                        )
                        .blur(radius: blurAmount)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                    // Quality indicator overlay
                    if blurAmount > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Compressed")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedPresetId)
            }
        }
    }
}

// MARK: - Enhanced Preset Card with Flip Effect for Pro
struct EnhancedPresetCard: View {
    let preset: CompressionPreset
    var isSelected: Bool = false
    let onTap: () -> Void

    @State private var isFlipped = false
    @State private var isShaking = false

    // Custom icon colors for platforms
    private var iconColor: Color {
        switch preset.id {
        case "whatsapp": return Color(red: 0.15, green: 0.68, blue: 0.38) // WhatsApp green
        case "mail": return .blue
        case "quality": return .appAccent
        case "custom": return .purple
        default: return .appAccent
        }
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // Front of card
                frontContent
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )

                // Back of card (Pro info)
                if preset.isProOnly {
                    backContent
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(isFlipped ? 0 : -180),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        }
        .buttonStyle(.pressable)
        .offset(x: isShaking ? -5 : 0)
    }

    private var frontContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Icon and Pro badge row
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? iconColor : Color.appSurface)
                        .frame(width: 44, height: 44)

                    Image(systemName: preset.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : iconColor)
                }

                Spacer()

                if preset.isProOnly {
                    ProBadge()
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(iconColor)
                }
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(preset.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(preset.isProOnly ? .secondary : .primary)

                Text(preset.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(isSelected ? iconColor.opacity(Opacity.subtle) : Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    isSelected ? iconColor : Color.clear,
                    lineWidth: 2
                )
        )
        .opacity(preset.isProOnly ? 0.85 : 1.0)
    }

    private var backContent: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.goldAccent, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Pro Feature")
                .font(.appBodyMedium)
                .foregroundStyle(.primary)

            Text("Tap to unlock")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.proGradientStart.opacity(0.1), Color.proGradientEnd.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.proGradientStart, .proGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private func handleTap() {
        if preset.isProOnly {
            // Flip animation for locked preset
            withAnimation {
                isFlipped.toggle()
            }
            Haptics.warning()

            // Auto-flip back and trigger paywall
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isFlipped = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onTap()
                }
            }
        } else {
            onTap()
        }
    }
}

// MARK: - Pro Badge (Crown style)
struct ProBadge: View {
    @State private var isGlowing = false

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "crown.fill")
                .font(.system(size: 10, weight: .bold))
            Text("PRO")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(
            LinearGradient(
                colors: [.goldAccent, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: Color.goldAccent.opacity(isGlowing ? 0.6 : 0.2), radius: isGlowing ? 8 : 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

// MARK: - Custom Size Slider
struct CustomSizeSlider: View {
    @Binding var targetMB: Double

    private let minMB: Double = 1
    private let maxMB: Double = 50

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                HStack {
                    Text("Target Size")
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(Int(targetMB)) MB")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.purple)
                }

                // Slider
                VStack(spacing: Spacing.xs) {
                    Slider(value: $targetMB, in: minMB...maxMB, step: 1) { isEditing in
                        // Only trigger haptic when user finishes dragging
                        if !isEditing {
                            Haptics.selection()
                        }
                    }
                        .tint(Color.purple)

                    // Labels
                    HStack {
                        Text("\(Int(minMB)) MB")
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Text("\(Int(maxMB)) MB")
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Size recommendations
                HStack(spacing: Spacing.sm) {
                    SizeChip(size: 5, currentSize: $targetMB)
                    SizeChip(size: 10, currentSize: $targetMB)
                    SizeChip(size: 25, currentSize: $targetMB)
                    SizeChip(size: 50, currentSize: $targetMB)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Target size selector")
        .accessibilityValue("\(Int(targetMB)) megabytes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                targetMB = min(targetMB + 5, maxMB)
            case .decrement:
                targetMB = max(targetMB - 5, minMB)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Size Chip
struct SizeChip: View {
    let size: Int
    @Binding var currentSize: Double

    var isSelected: Bool {
        Int(currentSize) == size
    }

    var body: some View {
        Button(action: {
            withAnimation(AppAnimation.spring) {
                currentSize = Double(size)
            }
            Haptics.selection()
        }) {
            Text("\(size)")
                .font(.appCaptionMedium)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? Color.purple : Color.appSurface)
                .clipShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(size) megabytes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    PresetScreen(
        file: FileInfo(
            name: "Demo.pdf",
            url: URL(fileURLWithPath: "/demo.pdf"),
            size: 32_000_000,
            pageCount: 12,
            fileType: .pdf
        ),
        analysisResult: AnalysisResult(
            pageCount: 12,
            imageCount: 24,
            imageDensity: .medium,
            estimatedSavings: .medium,
            isAlreadyOptimized: false,
            originalDPI: 300
        ),
        onCompress: { preset in
            print("Selected: \(preset.name)")
        },
        onBack: {},
        onShowPaywall: {}
    )
}
