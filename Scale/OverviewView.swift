//
//  OverviewView.swift
//  Scale
//
//  Created by Jonathan Groberg on 4/23/26.
//

import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    /// Holds all derived stats so they're computed once per data change, not per body evaluation.
    private struct Snapshot {
        let currentWeight: Double?
        let longestStreak: Int
        let chart: WeightCalculations.ChartSnapshot
        let weightChangeLbs: Double?
        let averageWeight: Double?

        static let empty = Snapshot(
            currentWeight: nil,
            longestStreak: 0,
            chart: .empty,
            weightChangeLbs: nil,
            averageWeight: nil
        )

        init(entries: [WeightEntry], period: TimePeriod) {
            currentWeight = entries.first?.weight
            longestStreak = WeightCalculations.longestStreak(from: entries)
            chart = WeightCalculations.chartSnapshot(from: entries, over: period)
            weightChangeLbs = WeightCalculations.weightChangeLbs(from: entries, over: period)
            averageWeight = WeightCalculations.averageWeight(from: entries, over: period)
        }

        private init(currentWeight: Double?, longestStreak: Int, chart: WeightCalculations.ChartSnapshot, weightChangeLbs: Double?, averageWeight: Double?) {
            self.currentWeight = currentWeight
            self.longestStreak = longestStreak
            self.chart = chart
            self.weightChangeLbs = weightChangeLbs
            self.averageWeight = averageWeight
        }
    }

    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @State private var chartPeriod: TimePeriod = .month
    @State private var snapshot: Snapshot = .empty

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var dataVersion: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        hasher.combine(entries.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(entries.first?.weight ?? 0)
        return hasher.finalize()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    currentWeightCard
                    chartCard
                    entriesSection
                }
                .padding(.horizontal, 14)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            snapshot = Snapshot(entries: entries, period: chartPeriod)
        }
        .onChange(of: dataVersion) { _, _ in
            snapshot = Snapshot(entries: entries, period: chartPeriod)
        }
        .onChange(of: chartPeriod) { _, _ in
            snapshot = Snapshot(entries: entries, period: chartPeriod)
        }
    }

    // MARK: - Current Weight Card

    private var currentWeightCard: some View {
        VStack(spacing: 8) {
            if let weight = snapshot.currentWeight {
                Text(String(format: "%.1f", weight))
                    .font(.system(size: 56, weight: .regular, design: .rounded))
                    .contentTransition(.numericText())

                Text("lbs today")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.system(size: 56, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("No entries yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }


        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: $chartPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if snapshot.chart.smoothedEntries.isEmpty {
                Text("Not enough data for this period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart {
                    ForEach(snapshot.chart.entries, id: \.timestamp) { entry in
                        LineMark(
                            x: .value("Date", entry.timestamp),
                            y: .value("Weight", entry.weight),
                            series: .value("Series", "actual")
                        )
                        .foregroundStyle(tintColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }

                    ForEach(snapshot.chart.trendEntries, id: \.timestamp) { point in
                        LineMark(
                            x: .value("Date", point.timestamp),
                            y: .value("Weight", point.weight),
                            series: .value("Series", "trend")
                        )
                        .foregroundStyle(tintColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .interpolationMethod(.catmullRom)
                    }

                    ForEach(snapshot.chart.entries, id: \.timestamp) { entry in
                        PointMark(
                            x: .value("Date", entry.timestamp),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(tintColor)
                        .symbolSize(28)
                    }
                }
                .chartYScale(domain: snapshot.chart.yDomain)
                .frame(height: 180)
            }

            chartStatsRow
        }
        .padding(14)
    }

    // MARK: - Chart Stats

    private var chartStatsRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Change",
                value: snapshot.weightChangeLbs.map { String(format: "%+.1f lbs", $0) } ?? "--",
                valueColor: snapshot.weightChangeLbs.map { $0 < 0 ? .green : ($0 > 0 ? .red : .primary) } ?? .secondary
            )

            statCard(
                title: "Average",
                value: snapshot.averageWeight.map { String(format: "%.1f lbs", $0) } ?? "--",
                valueColor: .primary
            )
        }
    }

    // MARK: - Entries

    private var entriesSection: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Entries",
                value: "\(entries.count)",
                valueColor: tintColor
            )

            longestStreakCard
        }
    }

    private var longestStreakCard: some View {
        VStack(spacing: 6) {
            Text("Longest Streak")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                if snapshot.longestStreak > 0 {
                    Image(systemName: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                }

                Text(snapshot.longestStreak > 0 ? "\(snapshot.longestStreak)d" : "--")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .foregroundStyle(snapshot.longestStreak > 0 ? .orange : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func statCard(title: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }


}

#Preview {
    OverviewView()
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
