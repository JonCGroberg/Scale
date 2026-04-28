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
        let goalProgress: WeightCalculations.GoalProgress?

        static let empty = Snapshot(
            currentWeight: nil,
            longestStreak: 0,
            chart: .empty,
            weightChangeLbs: nil,
            averageWeight: nil,
            goalProgress: nil
        )

        init(entries: [WeightEntry], period: TimePeriod, goal: WeightGoal, targetWeight: Double?) {
            currentWeight = entries.first?.weight
            longestStreak = WeightCalculations.longestStreak(from: entries)
            chart = WeightCalculations.chartSnapshot(from: entries, over: period)
            weightChangeLbs = WeightCalculations.weightChangeLbs(from: entries, over: period)
            averageWeight = WeightCalculations.averageWeight(from: entries, over: period)
            goalProgress = targetWeight.flatMap {
                WeightCalculations.goalProgress(
                    from: entries,
                    goal: goal,
                    targetWeight: $0,
                    over: period
                )
            }
        }

        private init(
            currentWeight: Double?,
            longestStreak: Int,
            chart: WeightCalculations.ChartSnapshot,
            weightChangeLbs: Double?,
            averageWeight: Double?,
            goalProgress: WeightCalculations.GoalProgress?
        ) {
            self.currentWeight = currentWeight
            self.longestStreak = longestStreak
            self.chart = chart
            self.weightChangeLbs = weightChangeLbs
            self.averageWeight = averageWeight
            self.goalProgress = goalProgress
        }
    }

    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @State private var chartPeriod: TimePeriod = .month
    @State private var snapshot: Snapshot = .empty
    @State private var miniGoals: [MiniGoal] = []

    private var selectedGoal: WeightGoal {
        WeightGoal(rawValue: weightGoal) ?? .defaultValue
    }

    private var activeTargetWeight: Double? {
        GoalProgressFeedback.target(
            for: selectedGoal,
            cutTarget: cutTargetWeight,
            bulkTarget: bulkTargetWeight
        )
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var chartYDomain: ClosedRange<Double> {
        guard !snapshot.chart.entries.isEmpty else {
            return snapshot.chart.yDomain
        }

        let goalWeights = ([activeTargetWeight] + miniGoals.map(\.targetWeight)).compactMap { $0 }
        guard !goalWeights.isEmpty else {
            return snapshot.chart.yDomain
        }

        let lowerBound = min(snapshot.chart.yDomain.lowerBound, (goalWeights.min() ?? 0) - 1)
        let upperBound = max(snapshot.chart.yDomain.upperBound, (goalWeights.max() ?? 0) + 1)
        return lowerBound...upperBound
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
                }
                .padding(.horizontal, 14)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            updateSnapshot()
            updateMiniGoals()
        }
        .onChange(of: dataVersion) { _, _ in
            updateSnapshot()
        }
        .onChange(of: chartPeriod) { _, _ in
            updateSnapshot()
        }
        .onChange(of: weightGoal) { _, _ in
            updateMiniGoals()
            updateSnapshot()
        }
        .onChange(of: cutTargetWeight) { _, _ in
            updateSnapshot()
        }
        .onChange(of: bulkTargetWeight) { _, _ in
            updateSnapshot()
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
                    if let target = activeTargetWeight {
                        RuleMark(y: .value("Goal", target))
                            .foregroundStyle(tintColor.opacity(0.82))
                            .lineStyle(StrokeStyle(lineWidth: 2.25, dash: [5, 4]))
                            .annotation(position: .leading, alignment: .leading) {
                                chartGoalIcon(
                                    systemName: "flag.checkered",
                                    accessibilityLabel: "\(selectedGoal.targetTitle) \(target.formatted(.number.precision(.fractionLength(1)))) pounds"
                                )
                            }
                    }

                    ForEach(miniGoals) { miniGoal in
                        RuleMark(y: .value("Mini Goal", miniGoal.targetWeight))
                            .foregroundStyle(tintColor.opacity(0.46))
                            .lineStyle(StrokeStyle(lineWidth: 1.35, dash: [2, 4]))
                            .annotation(position: .leading, alignment: .leading) {
                                chartGoalIcon(
                                    systemName: "flag.fill",
                                    accessibilityLabel: "\(miniGoal.name) \(miniGoal.targetWeight.formatted(.number.precision(.fractionLength(1)))) pounds"
                                )
                            }
                    }

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
                        .foregroundStyle(tintColor.opacity(0.48))
                        .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
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
                .chartYScale(domain: chartYDomain)
                .frame(height: 180)
            }

            chartMetricsSection
            lowerMetricsSection
        }
        .padding(14)
    }

    private func chartGoalIcon(systemName: String, accessibilityLabel: String) -> some View {
        Image(systemName: systemName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tintColor)
            .frame(width: 14, height: 14)
            .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Chart Stats

    private var chartMetricsSection: some View {
        VStack(spacing: 0) {
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
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.72))
        }
    }

    // MARK: - Lower Metrics

    private var lowerMetricsSection: some View {
        VStack(spacing: 0) {
            if let goalProgress = snapshot.goalProgress {
                HStack(spacing: 12) {
                    statCard(
                        title: "Goal",
                        value: goalCompletionText(goalProgress),
                        valueColor: tintColor
                    )

                    statCard(
                        title: "At This Rate",
                        value: projectedTimeText(days: goalProgress.daysRemaining),
                        valueColor: goalProgress.daysRemaining == nil ? .secondary : .primary
                    )
                }

                Divider()
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 12) {
                statCard(
                    title: "Entries",
                    value: "\(entries.count)",
                    valueColor: tintColor
                )

                longestStreakCard
            }
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

    private func updateSnapshot() {
        snapshot = Snapshot(
            entries: entries,
            period: chartPeriod,
            goal: selectedGoal,
            targetWeight: activeTargetWeight
        )
    }

    private func updateMiniGoals() {
        miniGoals = MiniGoalStore.load(for: selectedGoal)
    }

    private func projectedTimeText(days: Double?) -> String {
        guard let days else { return "--" }
        if days <= 0 { return "Reached" }
        if days < 14 {
            return "\(Int(ceil(days)))d"
        }

        let weeks = days / 7
        if weeks < 10 {
            return "\(Int(ceil(weeks)))w"
        }

        let months = days / 30.4375
        return "\(Int(ceil(months)))mo"
    }

    private func goalCompletionText(_ progress: WeightCalculations.GoalProgress) -> String {
        GoalProgressFeedback.progressText(progress)
    }

}

#Preview {
    OverviewView()
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
