//
//  ScaleWidget.swift
//  ScaleWidget
//
//  Created by Codex on 3/16/26.
//

import SwiftUI
import WidgetKit

struct ScaleWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WeightWidgetSnapshot
}

struct ScaleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScaleWidgetEntry {
        ScaleWidgetEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScaleWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? WeightWidgetSnapshot.preview : WeightWidgetSnapshotStore.load()
        completion(ScaleWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScaleWidgetEntry>) -> Void) {
        let entry = ScaleWidgetEntry(date: .now, snapshot: WeightWidgetSnapshotStore.load())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct ScaleWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ScaleWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            ScaleHomeWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            tintColor.opacity(0.24),
                            Color(.systemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        case .systemMedium:
            ScaleMediumWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            tintColor.opacity(0.20),
                            Color(.systemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        case .accessoryRectangular:
            ScaleRectangularWidgetView(snapshot: entry.snapshot)
        case .accessoryCircular:
            ScaleCircularWidgetView(snapshot: entry.snapshot)
        case .accessoryInline:
            ScaleInlineWidgetView(snapshot: entry.snapshot)
        default:
            ScaleHomeWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
    }

    private var tintColor: Color {
        WidgetTintPalette.color(for: entry.snapshot.appTintRawValue)
    }
}

struct ScaleHomeWidgetView: View {
    let snapshot: WeightWidgetSnapshot

    private var tintColor: Color {
        WidgetTintPalette.color(for: snapshot.appTintRawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Scale", systemImage: "scalemass.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tintColor)
                Spacer()
                Text(snapshot.relativeDateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let latestWeight = snapshot.latestWeight {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(latestWeight.formattedWeight)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                    Text("lb")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    MetricPill(
                        title: "Streak",
                        value: "\(snapshot.streakCount)d",
                        tintColor: tintColor
                    )

                    if let trendText = snapshot.monthTrendText {
                        MetricPill(
                            title: "30D",
                            value: trendText,
                            tintColor: tintColor
                        )
                    }
                }

                if let monthAverage = snapshot.monthAverage {
                    Text("Avg \(monthAverage.formattedWeight) lb this month")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No entries yet")
                        .font(.headline)
                    Text("Open Scale and log your first weight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct AddWeightSmallWidgetView: View {
    let snapshot: WeightWidgetSnapshot

    private var tintColor: Color {
        WidgetTintPalette.color(for: snapshot.appTintRawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(snapshot.streakText)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(tintColor)
                .minimumScaleFactor(0.6)

            Text(snapshot.streakSubtitleText)
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ScaleMediumWidgetView: View {
    let snapshot: WeightWidgetSnapshot

    private var tintColor: Color {
        WidgetTintPalette.color(for: snapshot.appTintRawValue)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Scale", systemImage: "scalemass.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tintColor)

                if let latestWeight = snapshot.latestWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(latestWeight.formattedWeight)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.7)
                        Text("lb")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(snapshot.relativeDateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No entries yet")
                        .font(.title3.weight(.semibold))
                    Text("Open Scale and log your first weight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                MetricPill(
                    title: "Streak",
                    value: "\(snapshot.streakCount)d",
                    tintColor: tintColor
                )

                if let trendText = snapshot.monthTrendText {
                    MetricPill(
                        title: "30D",
                        value: trendText,
                        tintColor: tintColor
                    )
                }

                if let monthAverage = snapshot.monthAverage {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Avg")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(monthAverage.formattedWeight) lb")
                            .font(.headline.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct ScaleRectangularWidgetView: View {
    let snapshot: WeightWidgetSnapshot

    private var tintColor: Color {
        WidgetTintPalette.color(for: snapshot.appTintRawValue)
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(snapshot.latestWeightText)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Text(snapshot.relativeDateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(snapshot.streakCount)d")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(tintColor)
                    Text("streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let trendText = snapshot.monthTrendText {
                        Text(trendText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(snapshot.monthPercentChangeColor)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct ScaleCircularWidgetView: View {
    let snapshot: WeightWidgetSnapshot

    private var tintColor: Color {
        WidgetTintPalette.color(for: snapshot.appTintRawValue)
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: "scalemass.fill")
                    .font(.caption2)
                    .foregroundStyle(tintColor)
                Text(snapshot.circularValueText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text(snapshot.circularCaptionText)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ScaleInlineWidgetView: View {
    let snapshot: WeightWidgetSnapshot

    var body: some View {
        Text(snapshot.inlineText)
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let tintColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tintColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tintColor.opacity(0.14), in: Capsule())
    }
}

struct ScaleWidget: Widget {
    let kind = WeightWidgetSnapshotStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScaleWidgetProvider()) { entry in
            ScaleWidgetView(entry: entry)
        }
        .configurationDisplayName("Weight Summary")
        .description("Show your latest weight, streak, and 30-day trend.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct AddWeightWidget: Widget {
    let kind = WeightWidgetSnapshotStore.addWeightWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScaleWidgetProvider()) { entry in
            AddWeightSmallWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            WidgetTintPalette.color(for: entry.snapshot.appTintRawValue).opacity(0.24),
                            Color(.systemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Add Weight")
        .description("Open Scale and keep your streak going.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    ScaleWidget()
} timeline: {
    ScaleWidgetEntry(date: .now, snapshot: .preview)
}

#Preview(as: .accessoryRectangular) {
    ScaleWidget()
} timeline: {
    ScaleWidgetEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    ScaleWidget()
} timeline: {
    ScaleWidgetEntry(date: .now, snapshot: .preview)
}

#Preview("Add Weight", as: .systemSmall) {
    AddWeightWidget()
} timeline: {
    ScaleWidgetEntry(date: .now, snapshot: .preview)
}
