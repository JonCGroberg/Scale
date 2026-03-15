//
//  LogView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import Charts

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if entries.count >= 2 {
                                weightChart
                                    .padding(.horizontal)
                            }

                            logList
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No entries yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Weight Chart

    private var chartEntries: [WeightEntry] {
        Array(entries.reversed())
    }

    private var yDomain: ClosedRange<Double> {
        let weights = entries.map(\.weight)
        let minW = (weights.min() ?? 0) - 2
        let maxW = (weights.max() ?? 200) + 2
        return minW...maxW
    }

    private var xAxisStrideCount: Int {
        guard let oldest = entries.last?.timestamp else { return 7 }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
        return days < 14 ? 1 : 7
    }

    private var weightChart: some View {
        Chart(chartEntries) { entry in
            AreaMark(
                x: .value("Date", entry.timestamp),
                y: .value("Weight", entry.weight)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.accent.opacity(0.3), .accent.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Date", entry.timestamp),
                y: .value("Weight", entry.weight)
            )
            .foregroundStyle(.accent)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStrideCount)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel()
            }
        }
        .frame(height: 220)
    }

    // MARK: - Log List

    private var logList: some View {
        LazyVStack(spacing: 0) {
            ForEach(entries) { entry in
                logRow(entry: entry)

                if entry.id != entries.last?.id {
                    Divider()
                        .padding(.horizontal)
                }
            }
        }
    }

    private func logRow(entry: WeightEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f lbs", entry.weight))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.accent)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    LogView()
        .modelContainer(for: WeightEntry.self, inMemory: true)
}
