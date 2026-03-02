//
//  OptimizeLockScreenWidget.swift
//  OptimizeWidget
//
//  Lock Screen Widget (Circular, Rectangular, Inline) — Shows savings summary.
//  Available on iOS 18+.
//

import WidgetKit
import SwiftUI

// MARK: - Lock Screen Timeline Provider

struct LockScreenTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: .now, data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        let data = context.isPreview ? .preview : SharedDataReader.read()
        completion(LockScreenEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let data = SharedDataReader.read()
        let entry = LockScreenEntry(date: .now, data: data)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let data: WidgetCompressionData
}

// MARK: - Lock Screen Entry View (dispatches by family)

@available(iOSApplicationExtension 18.0, *)
struct LockScreenEntryView: View {
    let entry: LockScreenEntry
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        default:
            LockScreenCircularView(entry: entry)
        }
    }
}

// MARK: - Lock Screen Circular View

@available(iOSApplicationExtension 18.0, *)
struct LockScreenCircularView: View {
    let entry: LockScreenEntry

    private var formatted: (value: String, unit: String) {
        WidgetFormatter.formatBytesCompact(entry.data.totalBytesSaved)
    }

    var body: some View {
        Gauge(value: min(entry.data.averageSavingsPercent, 100), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: -2) {
                Text(formatted.value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(formatted.unit)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.mint)
    }
}

// MARK: - Lock Screen Rectangular View

@available(iOSApplicationExtension 18.0, *)
struct LockScreenRectangularView: View {
    let entry: LockScreenEntry

    private var formatted: String {
        WidgetFormatter.formatBytes(entry.data.totalBytesSaved)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 12, weight: .bold))

            VStack(alignment: .leading, spacing: 1) {
                Text("Bu hafta: \(WidgetFormatter.formatBytes(entry.data.weeklyBytesSaved))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("Toplam: \(formatted)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lock Screen Inline View

@available(iOSApplicationExtension 18.0, *)
struct LockScreenInlineView: View {
    let entry: LockScreenEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
            Text("\(WidgetFormatter.formatBytes(entry.data.totalBytesSaved)) tasarruf")
        }
    }
}

// MARK: - Widget Definition

@available(iOSApplicationExtension 18.0, *)
struct OptimizeLockScreenWidget: Widget {
    let kind = "OptimizeLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenTimelineProvider()) { entry in
            LockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Tasarruf")
        .description("Kilit ekranında sıkıştırma tasarrufunu gösterir.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
