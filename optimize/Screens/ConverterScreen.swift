//
//  ConverterScreen.swift
//  optimize
//
//  File format converter UI
//  Features: Visual flow header, horizontal snap carousel for format selection,
//  PremiumCardStyle for selected format, comprehensive format conversion with preview
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - ConversionFileType UI Extensions

private extension ConversionFileType {
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .presentation: return "rectangle.stack.fill"
        case .spreadsheet: return "tablecells.fill"
        case .document: return "doc.text.fill"
        case .unknown: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .pdf: return .red
        case .image: return .blue
        case .video: return .purple
        case .presentation: return .orange
        case .spreadsheet: return .green
        case .document: return .indigo
        case .unknown: return .gray
        }
    }

    var label: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "Resim"
        case .video: return "Video"
        case .presentation: return "Sunum"
        case .spreadsheet: return "Tablo"
        case .document: return "Belge"
        case .unknown: return "Dosya"
        }
    }
}

private extension FormatCategory {
    var label: String {
        switch self {
        case .image: return "Resim"
        case .document: return "Belge"
        case .video: return "Video"
        }
    }
}

struct ConverterScreen: View {
    @StateObject private var converter = FileConverterService.shared
    @State private var selectedFiles: [URL] = []
    @State private var selectedFormat: ConversionFormat?
    @State private var showFilePicker = false
    @State private var conversionResult: URL?
    @State private var showResult = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var conversionOptions = ConversionOptions.default

    let onBack: () -> Void

    // Available formats based on selected file
    private var availableFormats: [ConversionFormat] {
        guard let firstFile = selectedFiles.first else { return [] }
        return converter.availableFormats(for: firstFile)
    }

    private var sourceFileType: ConversionFileType? {
        guard let firstFile = selectedFiles.first else { return nil }
        return ConversionFileType.detect(from: firstFile)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Header
            NavigationHeader("", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title
                    Text(AppStrings.Converter.title)
                        .font(.displayTitle)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, Spacing.md)

                    // Subtitle
                    Text(AppStrings.Converter.subtitle)
                        .font(.appBody)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.md)

                    // Visual Flow Header
                    if let fileType = sourceFileType {
                        ConversionFlowHeader(
                            sourceType: fileType,
                            targetFormat: selectedFormat
                        )
                        .padding(.horizontal, Spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // File Selection
                    FileSelectionCard(
                        files: selectedFiles,
                        onAdd: { showFilePicker = true },
                        onRemove: { url in
                            selectedFiles.removeAll { $0 == url }
                            selectedFormat = nil
                        }
                    )
                    .padding(.horizontal, Spacing.md)

                    // Format Selection (horizontal carousel)
                    if !selectedFiles.isEmpty {
                        FormatSelectionCard(
                            formats: availableFormats,
                            selected: $selectedFormat
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Conversion Options
                    if selectedFormat != nil {
                        ConversionOptionsCard(options: $conversionOptions, format: selectedFormat!)
                            .padding(.horizontal, Spacing.md)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Convert Button
                    if selectedFormat != nil && !selectedFiles.isEmpty {
                        ConvertButton(
                            isConverting: converter.isConverting,
                            progress: converter.progress,
                            operation: converter.currentOperation
                        ) {
                            startConversion()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Conversion Features
                    ConversionFeaturesCard()
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedFiles.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedFormat)
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView(
                contentTypes: [.pdf, .image, .movie, .presentation, .spreadsheet],
                allowsMultipleSelection: true
            ) { urls in
                Task {
                    selectedFiles = await validateSelectedFiles(urls)
                    selectedFormat = nil
                }
            }
        }
        .sheet(isPresented: $showResult) {
            if let result = conversionResult {
                ConversionResultSheet(resultURL: result) {
                    showResult = false
                    selectedFiles = []
                    selectedFormat = nil
                }
            }
        }
        .alert(AppStrings.Converter.errorTitle, isPresented: $showError) {
            Button(AppStrings.Converter.ok, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func startConversion() {
        guard let format = selectedFormat,
              let file = selectedFiles.first else { return }

        Haptics.impact(style: .medium)

        Task {
            do {
                let result = try await SecurityScopedResource.accessAsync(file) { accessibleURL in
                    await FileValidationService.shared.validate(url: accessibleURL)
                }
                if case .invalid(let error) = result {
                    let messageParts = [error.errorDescription, error.recoverySuggestion].compactMap { $0 }
                    let message = messageParts.joined(separator: "\n\n")
                    errorMessage = message
                    showError = true
                    return
                }

                if selectedFiles.count > 1 && format == .pdf {
                    // Merge multiple files to PDF
                    let result = try await converter.convertImagesToPDF(urls: selectedFiles, options: conversionOptions)
                    conversionResult = result
                } else {
                    // Single file conversion
                    let result = try await converter.convert(
                        url: file,
                        to: format,
                        options: conversionOptions
                    )
                    conversionResult = result
                }

                Haptics.success()
                showResult = true

            } catch {
                Haptics.error()
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func validateSelectedFiles(_ urls: [URL]) async -> [URL] {
        var valid: [URL] = []

        for url in urls {
            do {
                if FileValidationService.shared.needsICloudDownload(url) {
                    try FileValidationService.shared.startICloudDownload(url)
                    continue
                }
                let result = try await SecurityScopedResource.accessAsync(url) { accessibleURL in
                    await FileValidationService.shared.validate(url: accessibleURL)
                }
                if result.isValid {
                    valid.append(url)
                }
            } catch {
                continue
            }
        }

        return valid
    }
}

// MARK: - Conversion Flow Header

private struct ConversionFlowHeader: View {
    let sourceType: ConversionFileType
    let targetFormat: ConversionFormat?

    @State private var arrowOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: Spacing.lg) {
            Spacer()

            // Source icon
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(sourceType.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: sourceType.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(sourceType.color)
                }

                Text(sourceType.label)
                    .font(.appCaptionMedium)
                    .foregroundStyle(.secondary)
            }

            // Animated arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.appAccent)
                .offset(x: arrowOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        arrowOffset = 6
                    }
                }

            // Target icon
            if let format = targetFormat {
                VStack(spacing: Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(format.color.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: format.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(format.color)
                    }

                    Text(format.rawValue.uppercased())
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: Spacing.xs) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .frame(width: 56, height: 56)

                        Image(systemName: "questionmark")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary.opacity(0.4))
                    }

                    Text("?")
                        .font(.appCaptionMedium)
                        .foregroundStyle(.secondary.opacity(0.4))
                }
            }

            Spacer()
        }
        .padding(.vertical, Spacing.md)
        .animation(.spring(response: 0.4), value: targetFormat)
    }
}

// MARK: - File Selection Card

private struct FileSelectionCard: View {
    let files: [URL]
    let onAdd: () -> Void
    let onRemove: (URL) -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                // Header
                HStack {
                    Label("Dosya Seç", systemImage: "doc.badge.plus")
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)

                    Spacer()

                    if !files.isEmpty {
                        Text("\(files.count) dosya")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                if files.isEmpty {
                    // Empty State
                    Button(action: onAdd) {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.appAccent)

                            Text("Dosya Ekle")
                                .font(.appBodyMedium)
                                .foregroundStyle(.primary)

                            Text("PDF, resim veya video seçin")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Selected Files
                    VStack(spacing: Spacing.xs) {
                        ForEach(files, id: \.absoluteString) { url in
                            SelectedFileRow(url: url) {
                                onRemove(url)
                            }
                        }
                    }

                    // Add More Button
                    Button(action: onAdd) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Daha Fazla Ekle")
                        }
                        .font(.appCaption)
                        .foregroundStyle(Color.appAccent)
                    }
                }
            }
        }
    }
}

private struct SelectedFileRow: View {
    let url: URL
    let onRemove: () -> Void

    private var fileType: ConversionFileType {
        ConversionFileType.detect(from: url)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // File Icon
            Image(systemName: fileType.icon)
                .font(.system(size: 20))
                .foregroundStyle(fileType.color)
                .frame(width: 32)

            // File Name
            Text(url.lastPathComponent)
                .font(.appBody)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.sm)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

// MARK: - Format Selection Card (Horizontal Carousel)

private struct FormatSelectionCard: View {
    let formats: [ConversionFormat]
    @Binding var selected: ConversionFormat?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Çıkış Formatı", systemImage: "arrow.triangle.branch")
                .font(.appBodyMedium)
                .foregroundStyle(.primary)
                .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.md) {
                    ForEach(formats) { format in
                        FormatCard(
                            format: format,
                            isSelected: selected == format
                        ) {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.3)) {
                                selected = format
                            }
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Spacing.md)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct FormatCard: View {
    let format: ConversionFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: format.icon)
                    .font(.system(size: 32))

                Text(format.rawValue.uppercased())
                    .font(.appBodyMedium)

                Text(format.category.label)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 100, height: 120)
            .foregroundStyle(isSelected ? format.color : .secondary)
            .modifier(PremiumCardStyle(
                isPremium: isSelected,
                cornerRadius: Radius.lg
            ))
        }
        .buttonStyle(.plain)
        .scrollTransition { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                .opacity(phase.isIdentity ? 1 : 0.7)
        }
    }
}

// MARK: - Conversion Options Card

private struct ConversionOptionsCard: View {
    @Binding var options: ConversionOptions
    let format: ConversionFormat

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Ayarlar", systemImage: "slider.horizontal.3")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                // Quality Slider (for images)
                if format.category == .image && format != .png {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("Kalite")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(options.quality * 100))%")
                                .font(.appCaptionMedium)
                                .foregroundStyle(.primary)
                        }

                        Slider(value: $options.quality, in: 0.1...1.0, step: 0.05)
                            .tint(Color.appAccent)
                    }
                }

                // Video Quality (for videos)
                if format.category == .video {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Video Kalitesi")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Picker("", selection: $options.videoQuality) {
                            ForEach(VideoQuality.allCases, id: \.self) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // GIF Options
                if format == .gif {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("Kare Hızı")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(options.gifFrameRate) FPS")
                                .font(.appCaptionMedium)
                                .foregroundStyle(.primary)
                        }

                        Slider(value: Binding(
                            get: { Double(options.gifFrameRate) },
                            set: { options.gifFrameRate = Int($0) }
                        ), in: 5...30, step: 1)
                        .tint(Color.appAccent)
                    }
                }
            }
        }
    }
}

// MARK: - Convert Button

private struct ConvertButton: View {
    let isConverting: Bool
    let progress: Double
    let operation: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isConverting {
                    VStack(spacing: Spacing.xs) {
                        ProgressView(value: progress)
                            .tint(.white)
                            .accessibilityLabel("Dönüştürme ilerlemesi")
                            .accessibilityValue("\(Int(progress * 100))%")

                        Text(operation)
                            .font(.appCaption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(AppStrings.Converter.convert)
                            .font(.appBodyMedium)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                LinearGradient(
                    colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(isConverting)
    }
}

// MARK: - Conversion Features Card

private struct ConversionFeaturesCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Desteklenen Dönüşümler")
                    .font(.appCaptionMedium)
                    .foregroundStyle(.secondary)

                VStack(spacing: Spacing.sm) {
                    ConverterFeatureRow(
                        icon: "doc.fill",
                        color: .red,
                        title: "PDF",
                        description: "→ PNG, JPG, HEIC, TIFF"
                    )

                    ConverterFeatureRow(
                        icon: "photo.fill",
                        color: .blue,
                        title: "Resimler",
                        description: "→ PDF, PNG, JPG, HEIC, WebP"
                    )

                    ConverterFeatureRow(
                        icon: "film.fill",
                        color: .purple,
                        title: "Videolar",
                        description: "→ MP4, MOV, GIF"
                    )

                    ConverterFeatureRow(
                        icon: "doc.text.fill",
                        color: .indigo,
                        title: "Belgeler",
                        description: "→ PDF"
                    )
                }
            }
        }
    }
}

private struct ConverterFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.appBody)
                .foregroundStyle(.primary)
                .frame(width: 70, alignment: .leading)

            Text(description)
                .font(.appCaption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Conversion Result Sheet

private struct ConversionResultSheet: View {
    let resultURL: URL
    let onDismiss: () -> Void

    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.lg) {
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.appMint)
                    .padding(.top, Spacing.xl)

                Text(AppStrings.Converter.completedTitle)
                    .font(.appTitle)
                    .foregroundStyle(.primary)

                // File Info
                VStack(spacing: Spacing.xs) {
                    Text(resultURL.lastPathComponent)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)

                    if let size = try? FileManager.default.attributesOfItem(atPath: resultURL.path)[.size] as? Int64 {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .padding(.horizontal, Spacing.lg)

                Spacer()

                // Actions
                VStack(spacing: Spacing.sm) {
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(AppStrings.Converter.share)
                        }
                        .font(.appBodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }

                    Button(action: onDismiss) {
                        Text(AppStrings.Converter.close)
                            .font(.appBodyMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.appSurface)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppStrings.Converter.done) {
                        onDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ConverterShareSheet(items: [resultURL])
        }
    }
}

// MARK: - Converter Share Sheet

private struct ConverterShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.permittedArrowDirections = []
            if let sourceView = controller.view {
                popover.sourceView = sourceView
                popover.sourceRect = CGRect(
                    x: sourceView.bounds.midX,
                    y: sourceView.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Picker View

private struct DocumentPickerView: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onSelect: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: ([URL]) -> Void

        init(onSelect: @escaping ([URL]) -> Void) {
            self.onSelect = onSelect
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onSelect(urls)
        }
    }
}

#Preview {
    ConverterScreen {
        print("Back")
    }
}
