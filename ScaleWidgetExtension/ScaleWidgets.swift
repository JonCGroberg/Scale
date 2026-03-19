//
//  ScaleWidgets.swift
//  ScaleWidgetExtension
//
//  Created by Codex on 3/16/26.
//

import SwiftUI
import WidgetKit

private struct WeightWidgetSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let appTintRawValue: String
    let latestWeight: Double?
    let latestTimestamp: Date?
    let streakCount: Int
    let monthAverage: Double?
    let monthPercentChange: Double?

    static let empty = WeightWidgetSnapshot(
        generatedAt: .distantPast,
        appTintRawValue: "blue",
        latestWeight: nil,
        latestTimestamp: nil,
        streakCount: 0,
        monthAverage: nil,
        monthPercentChange: nil
    )
}

private enum WeightWidgetSnapshotStore {
    static let appGroupID = "group.groberg.Scale"
    static let widgetKind = "groberg.Scale.weight-summary"

    static func load() -> WeightWidgetSnapshot {
        guard
            let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
            let data = try? Data(contentsOf: containerURL.appendingPathComponent("WeightWidgetSnapshot.json")),
            let snapshot = try? JSONDecoder.widgetSnapshotDecoder.decode(WeightWidgetSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }
}

private extension JSONDecoder {
    static let widgetSnapshotDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct WeightWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WeightWidgetSnapshot
}

private struct WeightSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeightWidgetEntry {
        WeightWidgetEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeightWidgetEntry) -> Void) {
        completion(WeightWidgetEntry(date: Date(), snapshot: WeightWidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightWidgetEntry>) -> Void) {
        let entry = WeightWidgetEntry(date: Date(), snapshot: WeightWidgetSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct ScaleWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeightSummaryWidget()
    }
}

private struct WeightSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WeightWidgetSnapshotStore.widgetKind, provider: WeightSummaryProvider()) { entry in
            WeightSummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Weight Summary")
        .description("See your latest weigh-in, streak, and monthly trend.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct WeightSummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WeightWidgetEntry

    private var tintColor: Color {
        switch entry.snapshot.appTintRawValue {
        case "green":
            .green
        case "orange":
            .orange
        case "pink":
            Color(red: 1.0, green: 0.72, blue: 0.84)
        case "lavender":
            Color(red: 0.72, green: 0.66, blue: 0.96)
        case "red":
            .red
        default:
            .blue
        }
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    tintColor.opacity(0.22),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Spacer(minLength: 0)
            latestWeightBlock
            footerRow
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                header
                latestWeightBlock
                lastLoggedLabel
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                statPill(title: "Streak", value: "\(entry.snapshot.streakCount)")
                statPill(title: "1M Avg", value: formattedWeight(entry.snapshot.monthAverage))
                statPill(title: "Trend", value: formattedPercent(entry.snapshot.monthPercentChange))
            }
        }
        .padding()
    }

    private var header: some View {
        Text("Scale")
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private var latestWeightBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let latestWeight = entry.snapshot.latestWeight {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", latestWeight))
                        .font(.system(size: family == .systemSmall ? 34 : 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("lbs")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No entries")
                    .font(.title3.weight(.semibold))
                Text("Log your first weight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footerRow: some View {
        HStack {
            streakBadge
            Spacer(minLength: 8)
            lastLoggedLabel
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(entry.snapshot.streakCount)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.orange.opacity(0.14), in: Capsule())
    }

    private var lastLoggedLabel: some View {
        Group {
            if let latestTimestamp = entry.snapshot.latestTimestamp {
                Text(latestTimestamp, style: .relative)
            } else {
                Text("Waiting for data")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formattedWeight(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f lbs", value)
    }

    private func formattedPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.1f%%", value)
    }
}

#Preview(as: .systemSmall) {
    ScaleWidgetBundle()
} timeline: {
    WeightWidgetEntry(
        date: .now,
        snapshot: WeightWidgetSnapshot(
            generatedAt: .now,
            appTintRawValue: "blue",
            latestWeight: 182.4,
            latestTimestamp: .now.addingTimeInterval(-3600 * 12),
            streakCount: 6,
            monthAverage: 183.1,
            monthPercentChange: -1.6
        )
    )
}

