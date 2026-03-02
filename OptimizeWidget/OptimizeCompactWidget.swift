//
//  OptimizeCompactWidget.swift
//  OptimizeWidget
//
//  Home Screen Small Widget — Shows total savings with trend indicator.
//  Single tap opens the main app.
//

import WidgetKit
import SwiftUI

// MARK: - Compact Timeline Provider

struct CompactTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompactEntry {
        CompactEntry(date: .now, data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (CompactEntry) -> Void) {
        let data = context.isPreview ? .preview : SharedDataReader.read()
        completion(CompactEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompactEntry>) -> Void) {
        let data = SharedDataReader.read()
        let entry = CompactEntry(date: .now, data: data)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct CompactEntry: TimelineEntry {
    let date: Date
    let data: WidgetCompressionData
}

// MARK: - Small Widget View

struct CompactSmallView: View {
    let entry: CompactEntry

    private var formatted: (value: String, unit: String) {
        WidgetFormatter.formatBytesCompact(entry.data.totalBytesSaved)
    }

    private var hasActivity: Bool {
        entry.data.weeklyBytesSaved > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.mint)
                Text("Optimize")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Big number
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatted.value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                Text(formatted.unit)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Label + trend
            HStack(spacing: 4) {
                Text("tasarruf")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)

                if hasActivity {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                }
            }

            Spacer().frame(height: 4)

            // Streak or file count
            if entry.data.streakDays > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Text("\(entry.data.streakDays) gün")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.mint)
                    Text("\(entry.data.totalFilesCompressed) dosya")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Definition

struct OptimizeCompactWidget: Widget {
    let kind = "OptimizeCompactWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompactTimelineProvider()) { entry in
            CompactSmallView(entry: entry)
        }
        .configurationDisplayName("Tasarruf Özeti")
        .description("Toplam tasarruf miktarı ve trend göstergesi.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    OptimizeCompactWidget()
} timeline: {
    CompactEntry(date: .now, data: .preview)
    CompactEntry(date: .now, data: .empty)
}
