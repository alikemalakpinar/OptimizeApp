//
//  BatchProcessingScreen.swift
//  optimize
//
//  Batch file compression UI with queue management
//  Features: Multiple file processing, progress tracking, queue control
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BatchProcessingScreen: View {
    @StateObject private var batchService = BatchProcessingService.shared
    @State private var showFilePicker = false
    @State private var selectedPreset: CompressionPreset = .commercial

    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Header
            NavigationHeader("", onBack: onBack) {
                if batchService.isProcessing {
                    Button(action: {
                        Haptics.warning()
                        batchService.pauseProcessing()
                    }) {
                        Text("Duraklat")
                            .font(.uiCaption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title
                    Text("Toplu İşlem")
                        .font(.displayTitle)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, Spacing.md)

                    // Progress Summary
                    if !batchService.currentProgress.isIdle {
                        BatchProgressCard(progress: batchService.currentProgress)
                            .padding(.horizontal, Spacing.md)
                    }

                    // Add Files Button
                    AddFilesCard(onTap: { showFilePicker = true })
                        .padding(.horizontal, Spacing.md)

                    // Preset Selection
                    if !batchService.queue.isEmpty {
                        PresetSelectionCard(selected: $selectedPreset)
                            .padding(.horizontal, Spacing.md)
                    }

                    // Queue Section
                    if !batchService.queue.isEmpty {
                        QueueSection(
                            items: batchService.queue,
                            onRemove: { item in
                                batchService.removeItem(item)
                            }
                        )
                        .padding(.horizontal, Spacing.md)
                    }

                    // Start Button
                    if !batchService.queue.isEmpty && !batchService.isProcessing {
                        StartProcessingButton {
                            Haptics.impact(style: .medium)
                            batchService.startProcessing()
                        }
                        .padding(.horizontal, Spacing.md)
                    }

                    // Completed Section
                    if !batchService.completedItems.isEmpty {
                        CompletedSection(
                            items: batchService.completedItems,
                            onClear: {
                                batchService.clearCompleted()
                            },
                            onRetryFailed: {
                                batchService.retryFailed()
                            }
                        )
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showFilePicker) {
            BatchDocumentPicker { urls in
                batchService.addFiles(urls, preset: selectedPreset)
            }
        }
    }
}

// MARK: - Batch Progress Card

private struct BatchProgressCard: View {
    let progress: BatchProgress

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                // Progress Bar
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(progress.summary)
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(String(format: "%.0f%%", progress.percentComplete * 100))
                            .font(.appCaptionMedium)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appSurface)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.appMint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress.percentComplete)
                        }
                    }
                    .frame(height: 8)
                }

                // Stats Row
                HStack(spacing: Spacing.lg) {
                    ProgressStat(
                        value: "\(progress.processing)",
                        label: "İşleniyor",
                        color: .blue
                    )

                    ProgressStat(
                        value: "\(progress.pending)",
                        label: "Bekliyor",
                        color: .secondary
                    )

                    ProgressStat(
                        value: "\(progress.completed)",
                        label: "Tamamlandı",
                        color: .green
                    )

                    if progress.failed > 0 {
                        ProgressStat(
                            value: "\(progress.failed)",
                            label: "Başarısız",
                            color: .red
                        )
                    }
                }

                // Saved Space
                if progress.totalBytesSaved > 0 {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(Color.appMint)

                        Text("Toplam Tasarruf: \(progress.formattedSaved)")
                            .font(.appCaptionMedium)
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }
}

private struct ProgressStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.appTitle)
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add Files Card

private struct AddFilesCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.appAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dosya Ekle")
                            .font(.appBodyMedium)
                            .foregroundStyle(.primary)

                        Text("Birden fazla dosya seçin")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preset Selection Card

private struct PresetSelectionCard: View {
    @Binding var selected: CompressionPreset

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sıkıştırma Ayarı")
                    .font(.appCaptionMedium)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach([CompressionPreset.commercial, .highQuality, .extreme, .mail], id: \.id) { preset in
                            PresetChip(
                                preset: preset,
                                isSelected: selected.id == preset.id
                            ) {
                                Haptics.selection()
                                selected = preset
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PresetChip: View {
    let preset: CompressionPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(preset.name)
                .font(.appCaption)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? Color.appAccent : Color.appSurface)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Queue Section

private struct QueueSection: View {
    let items: [BatchItem]
    let onRemove: (BatchItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Kuyruk")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(items.count) dosya")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(items) { item in
                    QueueItemRow(item: item, onRemove: { onRemove(item) })
                }
            }
        }
    }
}

private struct QueueItemRow: View {
    let item: BatchItem
    let onRemove: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: Spacing.sm) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(item.status.color.opacity(0.2))
                        .frame(width: 36, height: 36)

                    if item.status == .processing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: item.status.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(item.status.color)
                    }
                }

                // File Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.appBody)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: Spacing.xs) {
                        Text(item.formattedSize)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        if item.status == .processing {
                            Text("•")
                                .foregroundStyle(.secondary)

                            Text(String(format: "%.0f%%", item.progress * 100))
                                .font(.appCaption)
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                }

                Spacer()

                // Remove Button (only for pending)
                if item.status == .pending {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Start Processing Button

private struct StartProcessingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "play.fill")
                Text("İşlemi Başlat")
                    .font(.appBodyMedium)
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
    }
}

// MARK: - Completed Section

private struct CompletedSection: View {
    let items: [BatchItem]
    let onClear: () -> Void
    let onRetryFailed: () -> Void

    private var hasFailedItems: Bool {
        items.contains { $0.status == .failed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Tamamlanan")
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)

                Spacer()

                if hasFailedItems {
                    Button(action: onRetryFailed) {
                        Text("Yeniden Dene")
                            .font(.appCaption)
                            .foregroundStyle(.orange)
                    }
                }

                Button(action: onClear) {
                    Text("Temizle")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: Spacing.xs) {
                ForEach(items.prefix(10)) { item in
                    CompletedItemRow(item: item)
                }

                if items.count > 10 {
                    Text("ve \(items.count - 10) daha fazla...")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .padding(.top, Spacing.xs)
                }
            }
        }
    }
}

private struct CompletedItemRow: View {
    let item: BatchItem

    var body: some View {
        GlassCard {
            HStack(spacing: Spacing.sm) {
                // Status Icon
                Image(systemName: item.status.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(item.status.color)

                // File Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.appBody)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if item.status == .completed, let result = item.result {
                        HStack(spacing: Spacing.xs) {
                            Text("\(item.formattedSize) → \(ByteCountFormatter.string(fromByteCount: result.compressedSize, countStyle: .file))")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)

                            Text("(-\(result.savingsPercent)%)")
                                .font(.appCaptionMedium)
                                .foregroundStyle(Color.appMint)
                        }
                    } else if item.status == .failed {
                        Text(item.error ?? "Bilinmeyen hata")
                            .font(.appCaption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                // Duration
                if let duration = item.formattedDuration {
                    Text(duration)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Batch Document Picker

private struct BatchDocumentPicker: UIViewControllerRepresentable {
    let onSelect: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .image, .movie, .data
        ])
        picker.allowsMultipleSelection = true
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
    BatchProcessingScreen {
        print("Back")
    }
}
