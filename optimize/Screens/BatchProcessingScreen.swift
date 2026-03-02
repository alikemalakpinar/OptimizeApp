//
//  BatchProcessingScreen.swift
//  optimize
//
//  Batch file compression UI with queue management
//  Features: DragDrop zone, CompressionEngineVisual, matchedGeometry transitions,
//  celebration bursts, progress tracking, queue control
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BatchProcessingScreen: View {
    @StateObject private var batchService = BatchProcessingService.shared
    @State private var showFilePicker = false
    @State private var selectedPreset: CompressionPreset = .commercial
    @State private var showShareSheet = false
    @State private var showFileSaver = false
    @State private var selectedItemForShare: BatchItem?

    // Phase 2 additions
    @Namespace private var batchNamespace
    @State private var celebratingItemId: UUID?
    @State private var previousCompletedCount: Int = 0

    let onBack: () -> Void

    /// Map batch progress to ProcessingStage for CompressionEngineVisual
    private var currentStage: ProcessingStage {
        let pct = batchService.currentProgress.percentComplete
        if pct < 0.1 { return .preparing }
        if pct < 0.9 { return .optimizing }
        return .downloading
    }

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

                    // Progress: CompressionEngineVisual when processing, stats card otherwise
                    if !batchService.currentProgress.isIdle {
                        if batchService.isProcessing {
                            VStack(spacing: Spacing.md) {
                                CompressionEngineVisual(
                                    progress: batchService.currentProgress.percentComplete,
                                    stage: currentStage,
                                    size: 160
                                )

                                // Inline stats row
                                BatchProgressStatsRow(progress: batchService.currentProgress)
                            }
                            .padding(.horizontal, Spacing.md)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            BatchProgressCard(progress: batchService.currentProgress)
                                .padding(.horizontal, Spacing.md)
                                .transition(.opacity)
                        }
                    }

                    // Empty state: DragDropZone + Add Files
                    if batchService.queue.isEmpty && batchService.completedItems.isEmpty {
                        CompactDropZone(supportedTypes: .all) { urls in
                            Task {
                                let validURLs = await validateBatchFiles(urls)
                                batchService.addFiles(validURLs, preset: selectedPreset)
                            }
                        }
                        .frame(minHeight: 180)
                        .padding(.horizontal, Spacing.md)

                        AddFilesCard(onTap: { showFilePicker = true })
                            .padding(.horizontal, Spacing.md)
                    } else {
                        // Non-empty state: compact add button
                        AddFilesCard(onTap: { showFilePicker = true })
                            .padding(.horizontal, Spacing.md)
                    }

                    // Preset Selection
                    if !batchService.queue.isEmpty {
                        PresetSelectionCard(selected: $selectedPreset)
                            .padding(.horizontal, Spacing.md)
                    }

                    // Queue Section
                    if !batchService.queue.isEmpty {
                        QueueSection(
                            items: batchService.queue,
                            namespace: batchNamespace,
                            onRemove: { item in
                                batchService.removeItem(item)
                            }
                        )
                        .padding(.horizontal, Spacing.md)
                    }

                    // Start Button (Premium only - batch processing)
                    if !batchService.queue.isEmpty && !batchService.isProcessing {
                        StartProcessingButton {
                            if SubscriptionManager.shared.canBatchProcess {
                                Haptics.impact(style: .medium)
                                batchService.startProcessing()
                            } else {
                                Haptics.warning()
                                NotificationCenter.default.post(
                                    name: .showPaywallForFeature,
                                    object: nil,
                                    userInfo: ["feature": PremiumFeature.batchProcessing]
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }

                    // Completed Section
                    if !batchService.completedItems.isEmpty {
                        CompletedSection(
                            items: batchService.completedItems,
                            namespace: batchNamespace,
                            celebratingItemId: celebratingItemId,
                            onClear: {
                                batchService.clearCompleted()
                            },
                            onRetryFailed: {
                                batchService.retryFailed()
                            },
                            onShare: { item in
                                shareItem(item)
                            },
                            onSave: { item in
                                saveItem(item)
                            }
                        )
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: batchService.isProcessing)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showFilePicker) {
            BatchDocumentPicker { urls in
                Task {
                    let validURLs = await validateBatchFiles(urls)
                    batchService.addFiles(validURLs, preset: selectedPreset)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let item = selectedItemForShare, let resultURL = item.result?.compressedURL {
                BatchShareSheet(items: [resultURL])
            }
        }
        .sheet(isPresented: $showFileSaver) {
            if let item = selectedItemForShare, let resultURL = item.result?.compressedURL {
                BatchFileExporter(url: resultURL) { success in
                    showFileSaver = false
                    if success {
                        Haptics.success()
                    }
                }
            }
        }
        // Detect item completion for CelebrationBurstView
        .onChange(of: batchService.completedItems.count) { oldCount, newCount in
            if newCount > oldCount, let lastItem = batchService.completedItems.last,
               lastItem.status == .completed {
                withAnimation(.spring(response: 0.3)) {
                    celebratingItemId = lastItem.id
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if celebratingItemId == lastItem.id {
                        celebratingItemId = nil
                    }
                }
            }
        }
    }

    private func shareItem(_ item: BatchItem) {
        selectedItemForShare = item
        showShareSheet = true
    }

    private func saveItem(_ item: BatchItem) {
        selectedItemForShare = item
        showFileSaver = true
    }

    private func validateBatchFiles(_ urls: [URL]) async -> [URL] {
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

// MARK: - Batch Progress Stats Row (compact inline stats below engine visual)

private struct BatchProgressStatsRow: View {
    let progress: BatchProgress

    var body: some View {
        GlassCard {
            VStack(spacing: Spacing.sm) {
                // Progress bar
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
                .frame(height: 6)

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
                }
            }
        }
    }
}

// MARK: - Batch Progress Card (non-processing summary)

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
    var namespace: Namespace.ID
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
                    QueueItemRow(item: item, namespace: namespace, onRemove: { onRemove(item) })
                }
            }
        }
    }
}

private struct QueueItemRow: View {
    let item: BatchItem
    var namespace: Namespace.ID
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
        .matchedGeometryEffect(id: item.id, in: namespace)
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
    var namespace: Namespace.ID
    let celebratingItemId: UUID?
    let onClear: () -> Void
    let onRetryFailed: () -> Void
    let onShare: (BatchItem) -> Void
    let onSave: (BatchItem) -> Void

    private var hasFailedItems: Bool {
        items.contains { $0.status == .failed }
    }

    private var successfulItems: [BatchItem] {
        items.filter { $0.status == .completed }
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
                    Text(AppStrings.Batch.clear)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }

            // Bulk actions for all completed items
            if successfulItems.count > 1 {
                HStack(spacing: Spacing.sm) {
                    Text("\(successfulItems.count) dosya hazır")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Share All button
                    Button(action: {
                        if let firstItem = successfulItems.first {
                            onShare(firstItem)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12))
                            Text(AppStrings.Batch.shareAll)
                                .font(.appCaption)
                        }
                        .foregroundStyle(Color.appAccent)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }

            LazyVStack(spacing: Spacing.xs) {
                ForEach(items) { item in
                    CompletedItemRow(
                        item: item,
                        namespace: namespace,
                        isCelebrating: celebratingItemId == item.id,
                        onShare: { onShare(item) },
                        onSave: { onSave(item) }
                    )
                }
            }
        }
    }
}

private struct CompletedItemRow: View {
    let item: BatchItem
    var namespace: Namespace.ID
    let isCelebrating: Bool
    let onShare: () -> Void
    let onSave: () -> Void

    @State private var showActions = false

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
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
                            Text(item.error ?? AppStrings.Batch.unknownError)
                                .font(.appCaption)
                                .foregroundStyle(.red)
                        }
                    }

                    Spacer()

                    // Actions toggle for completed items
                    if item.status == .completed {
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                showActions.toggle()
                            }
                            Haptics.selection()
                        }) {
                            Image(systemName: showActions ? "chevron.up.circle.fill" : "ellipsis.circle")
                                .font(.system(size: 22))
                                .foregroundStyle(showActions ? Color.appAccent : .secondary)
                        }
                    } else if let duration = item.formattedDuration {
                        Text(duration)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Expandable action buttons
                if showActions && item.status == .completed {
                    HStack(spacing: Spacing.sm) {
                        // Share Button
                        Button(action: {
                            Haptics.impact()
                            onShare()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .medium))
                                Text(AppStrings.UI.share)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                LinearGradient(
                                    colors: [Color.appMint, Color.appTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }

                        // Save Button
                        Button(action: {
                            Haptics.impact()
                            onSave()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 14, weight: .medium))
                                Text(AppStrings.UI.save)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color.appAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.appAccent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                    }
                    .padding(.top, Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .matchedGeometryEffect(id: item.id, in: namespace)
        .overlay {
            CelebrationBurstView(trigger: isCelebrating)
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

// MARK: - Batch Share Sheet

private struct BatchShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad fix: prevent crash by providing sourceView
        if let popover = controller.popoverPresentationController {
            if let sourceView = controller.view {
                popover.sourceView = sourceView
                popover.sourceRect = CGRect(
                    x: sourceView.bounds.midX,
                    y: sourceView.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Batch File Exporter

private struct BatchFileExporter: UIViewControllerRepresentable {
    let url: URL
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: (Bool) -> Void

        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete(true)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete(false)
        }
    }
}

#Preview {
    BatchProcessingScreen {
        print("Back")
    }
}
