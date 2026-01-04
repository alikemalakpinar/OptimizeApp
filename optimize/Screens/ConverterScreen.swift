//
//  ConverterScreen.swift
//  optimize
//
//  File format converter UI
//  Supports comprehensive format conversion with preview
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Header
            NavigationHeader("", onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title
                    Text("Dosya Dönüştürücü")
                        .font(.displayTitle)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, Spacing.md)

                    // Subtitle
                    Text("PDF, resim ve video dosyalarını farklı formatlara dönüştürün")
                        .font(.appBody)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.md)

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

                    // Format Selection
                    if !selectedFiles.isEmpty {
                        FormatSelectionCard(
                            formats: availableFormats,
                            selected: $selectedFormat
                        )
                        .padding(.horizontal, Spacing.md)
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
                selectedFiles = urls
                selectedFormat = nil
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
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) {}
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
            Image(systemName: iconForType)
                .font(.system(size: 20))
                .foregroundStyle(colorForType)
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

    private var iconForType: String {
        switch fileType {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .presentation: return "rectangle.stack.fill"
        case .spreadsheet: return "tablecells.fill"
        case .document: return "doc.text.fill"
        case .unknown: return "doc.fill"
        }
    }

    private var colorForType: Color {
        switch fileType {
        case .pdf: return .red
        case .image: return .blue
        case .video: return .purple
        case .presentation: return .orange
        case .spreadsheet: return .green
        case .document: return .indigo
        case .unknown: return .gray
        }
    }
}

// MARK: - Format Selection Card

private struct FormatSelectionCard: View {
    let formats: [ConversionFormat]
    @Binding var selected: ConversionFormat?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Çıkış Formatı", systemImage: "arrow.triangle.branch")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    ForEach(formats) { format in
                        FormatButton(
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
            }
        }
    }
}

private struct FormatButton: View {
    let format: ConversionFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: format.icon)
                    .font(.system(size: 20))

                Text(format.rawValue)
                    .font(.appCaptionMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? format.color.opacity(0.2) : Color.appSurface)
            .foregroundStyle(isSelected ? format.color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .stroke(isSelected ? format.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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

                        Text(operation)
                            .font(.appCaption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Dönüştür")
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

                Text("Dönüşüm Tamamlandı!")
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
                            Text("Paylaş")
                        }
                        .font(.appBodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }

                    Button(action: onDismiss) {
                        Text("Kapat")
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
                    Button("Bitti") {
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
        UIActivityViewController(activityItems: items, applicationActivities: nil)
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
