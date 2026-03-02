//
//  OptimizeSavingsWidget.swift
//  OptimizeWidget
//
//  Home Screen Medium Widget — Shows compression stats with weekly graph.
//  Provides "Compress Now" deep link to the main app.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct SavingsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavingsEntry {
        SavingsEntry(date: .now, data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SavingsEntry) -> Void) {
        let data = context.isPreview ? .preview : SharedDataReader.read()
        completion(SavingsEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavingsEntry>) -> Void) {
        let data = SharedDataReader.read()
        let entry = SavingsEntry(date: .now, data: data)
        // Refresh every 4 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct SavingsEntry: TimelineEntry {
    let date: Date
    let data: WidgetCompressionData
}

// MARK: - Medium Widget View

struct SavingsMediumView: View {
    let entry: SavingsEntry

    private var formattedTotal: (value: String, unit: String) {
        WidgetFormatter.formatBytesCompact(entry.data.totalBytesSaved)
    }

    private var formattedWeekly: String {
        WidgetFormatter.formatBytes(entry.data.weeklyBytesSaved)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: Main stat
            VStack(alignment: .leading, spacing: 4) {
                // App icon + name
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.mint)
                    Text("Optimize")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Total saved
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formattedTotal.value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text(formattedTotal.unit)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text("toplam tasarruf")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Right: Stats column
            VStack(alignment: .trailing, spacing: 8) {
                // Weekly stat
                StatPill(
                    icon: "calendar",
                    value: formattedWeekly,
                    label: "bu hafta"
                )

                // Files compressed
                StatPill(
                    icon: "doc.fill",
                    value: "\(entry.data.totalFilesCompressed)",
                    label: "dosya"
                )

                // Streak
                if entry.data.streakDays > 0 {
                    StatPill(
                        icon: "flame.fill",
                        value: "\(entry.data.streakDays)",
                        label: "gün seri"
                    )
                }

                Spacer()

                // Average savings
                HStack(spacing: 4) {
                    Image(systemName: "percent")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.0f", entry.data.averageSavingsPercent))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text("ort.")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.mint)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.mint)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Definition

struct OptimizeSavingsWidget: Widget {
    let kind = "OptimizeSavingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavingsTimelineProvider()) { entry in
            SavingsMediumView(entry: entry)
        }
        .configurationDisplayName("Sıkıştırma İstatistikleri")
        .description("Toplam tasarruf, haftalık istatistikler ve ortalama sıkıştırma oranı.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    OptimizeSavingsWidget()
} timeline: {
    SavingsEntry(date: .now, data: .preview)
    SavingsEntry(date: .now, data: .empty)
}
