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
    private struct StepChartPoint: Equatable, Identifiable {
        let date: Date
        let steps: Int

        var id: Date { date }
    }

    /// Holds all derived stats so they're computed once per data change, not per body evaluation.
    private struct Snapshot {
        let currentWeight: Double?
        let longestStreak: Int
        let chart: WeightCalculations.ChartSnapshot
        let chartHistory: WeightCalculations.ChartSnapshot
        let weightChangeLbs: Double?
        let averageWeight: Double?
        let goalProgress: WeightCalculations.GoalProgress?
        let stepChartPoints: [StepChartPoint]
        let sleepChartPoints: [SleepChartPoint]
        let workoutChartPoints: [WorkoutChartPoint]
        let hasSleepData: Bool
        let hasWorkoutData: Bool

        static let empty = Snapshot(
            currentWeight: nil,
            longestStreak: 0,
            chart: .empty,
            chartHistory: .empty,
            weightChangeLbs: nil,
            averageWeight: nil,
            goalProgress: nil,
            stepChartPoints: [],
            sleepChartPoints: [],
            workoutChartPoints: [],
            hasSleepData: false,
            hasWorkoutData: false
        )

        init(entries: [WeightEntry], activitySummaries: [DailyActivitySummary], sleepEntries: [SleepEntry], workoutEntries: [WorkoutEntry], period: TimePeriod, goal: WeightGoal, targetWeight: Double?) {
            currentWeight = entries.first?.weight
            longestStreak = WeightCalculations.longestStreak(from: entries)
            chart = WeightCalculations.chartSnapshot(from: entries, over: period)
            chartHistory = WeightCalculations.fullChartSnapshot(from: entries, using: period)
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

            let calendar = Calendar.current
            let cutoff = calendar.date(
                byAdding: period.calendarComponent,
                value: -period.componentValue,
                to: Date()
            ) ?? Date()

            // Calculate step chart points
            let daily: [StepChartPoint] = activitySummaries
                .lazy
                .filter { $0.date >= cutoff && $0.stepCount > 0 }
                .map { summary in
                    StepChartPoint(date: calendar.startOfDay(for: summary.date), steps: summary.stepCount)
                }
                .sorted { $0.date < $1.date }

            let stepsByDate = Dictionary(uniqueKeysWithValues: daily.map { ($0.date, $0.steps) })
            let today = calendar.startOfDay(for: Date())
            let startDay = calendar.startOfDay(for: cutoff)
            var filled: [StepChartPoint] = []
            var day = startDay
            while day <= today {
                filled.append(StepChartPoint(date: day, steps: stepsByDate[day] ?? 0))
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = nextDay
            }
            stepChartPoints = filled

            // Calculate sleep chart points (single pass per day)
            let sleepGrouped = Dictionary(grouping: sleepEntries) { calendar.startOfDay(for: $0.endDate) }
            var sleepPoints: [SleepChartPoint] = []
            var hasSleep = false
            var sleepDay = startDay
            while sleepDay <= today {
                let entries = sleepGrouped[sleepDay] ?? []
                var total: Double = 0
                var deep: Double = 0
                var core: Double = 0
                var rem: Double = 0
                var unspecified: Double = 0
                for entry in entries {
                    let hours = entry.duration / 3600
                    total += hours
                    switch entry.stage {
                    case .deep: deep += hours
                    case .core: core += hours
                    case .rem: rem += hours
                    case .unspecified: unspecified += hours
                    }
                }
                if total > 0 { hasSleep = true }
                sleepPoints.append(SleepChartPoint(
                    date: sleepDay,
                    totalHours: total,
                    deepHours: deep,
                    coreHours: core,
                    remHours: rem,
                    unspecifiedHours: unspecified
                ))
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: sleepDay) else { break }
                sleepDay = nextDay
            }
            sleepChartPoints = sleepPoints
            hasSleepData = hasSleep

            // Calculate workout chart points (single pass per day)
            let workoutGrouped = Dictionary(grouping: workoutEntries) { calendar.startOfDay(for: $0.timestamp) }
            var workoutPoints: [WorkoutChartPoint] = []
            var hasWorkout = false
            var workoutDay = startDay
            while workoutDay <= today {
                let entries = workoutGrouped[workoutDay] ?? []
                var total: Double = 0
                var strength: Double = 0
                var cardio: Double = 0
                var other: Double = 0
                for entry in entries {
                    let hours = entry.duration / 3600
                    total += hours
                    if entry.activityTypeRawValue == 50 {
                        strength += hours
                    } else if entry.activityTypeRawValue == 52 || entry.activityTypeRawValue == 13 {
                        cardio += hours
                    } else {
                        other += hours
                    }
                }
                if total > 0 { hasWorkout = true }
                workoutPoints.append(WorkoutChartPoint(
                    date: workoutDay,
                    totalHours: total,
                    strengthHours: strength,
                    cardioHours: cardio,
                    otherHours: other
                ))
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: workoutDay) else { break }
                workoutDay = nextDay
            }
            workoutChartPoints = workoutPoints
            hasWorkoutData = hasWorkout
        }

        private init(
            currentWeight: Double?,
            longestStreak: Int,
            chart: WeightCalculations.ChartSnapshot,
            chartHistory: WeightCalculations.ChartSnapshot,
            weightChangeLbs: Double?,
            averageWeight: Double?,
            goalProgress: WeightCalculations.GoalProgress?,
            stepChartPoints: [StepChartPoint],
            sleepChartPoints: [SleepChartPoint],
            workoutChartPoints: [WorkoutChartPoint],
            hasSleepData: Bool,
            hasWorkoutData: Bool
        ) {
            self.currentWeight = currentWeight
            self.longestStreak = longestStreak
            self.chart = chart
            self.chartHistory = chartHistory
            self.weightChangeLbs = weightChangeLbs
            self.averageWeight = averageWeight
            self.goalProgress = goalProgress
            self.stepChartPoints = stepChartPoints
            self.sleepChartPoints = sleepChartPoints
            self.workoutChartPoints = workoutChartPoints
            self.hasSleepData = hasSleepData
            self.hasWorkoutData = hasWorkoutData
        }
    }

    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    // Step data loaded on demand — see stepSummaries computed property.
    @Query(sort: \DailyActivitySummary.date, order: .reverse) private var dailyActivitySummaries: [DailyActivitySummary]
    @Query(sort: \SleepEntry.endDate, order: .reverse) private var allSleepEntries: [SleepEntry]
    @Query(sort: \WorkoutEntry.timestamp, order: .reverse) private var allWorkouts: [WorkoutEntry]
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @AppStorage("badgePeriodIndex") private var badgePeriodIndex: Int = 1
    private var chartPeriod: TimePeriod {
        TimePeriod.allCases[badgePeriodIndex]
    }
    @State private var snapshot: Snapshot = .empty
    @State private var miniGoals: [MiniGoal] = []
    @State private var chartScrollPosition = Date()
    @State private var selectedDate: Date? = nil

    private var hasSleepData: Bool { snapshot.hasSleepData }
    private var hasWorkoutData: Bool { snapshot.hasWorkoutData }

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

    private var currentWeightRange: (min: Double, max: Double)? {
        let weights = snapshot.chart.entries.map(\.weight)
        guard let minWeight = weights.min(), let maxWeight = weights.max() else { return nil }
        return (minWeight, maxWeight)
    }

    private var filteredActiveTargetWeight: Double? {
        guard let target = activeTargetWeight,
              let range = currentWeightRange else { return nil }
        let buffer = 5.0
        return (target >= range.min - buffer && target <= range.max + buffer) ? target : nil
    }

    private var filteredMiniGoals: [MiniGoal] {
        guard let range = currentWeightRange else { return [] }
        let buffer = 5.0
        return miniGoals.filter { $0.targetWeight >= range.min - buffer && $0.targetWeight <= range.max + buffer }
    }

    private var selectedDataPoint: (weight: Double?, steps: Int?, sleepHours: Double?, workoutHours: Double?, date: Date)? {
        guard let selectedDate else { return nil }
        let calendar = Calendar.current
        let snappedDate = calendar.startOfDay(for: selectedDate)
        let dayStart = snappedDate

        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        // Get the weight logged on this specific day, or fallback to the closest available entry
        let dayEntries = entries.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
        let weight = dayEntries.first?.weight ?? entries.min(by: { 
            abs($0.timestamp.timeIntervalSince(snappedDate)) < abs($1.timestamp.timeIntervalSince(snappedDate)) 
        })?.weight

        // Find the steps on this day
        let steps = stepChartPoints.first(where: { calendar.isDate($0.date, inSameDayAs: snappedDate) })?.steps

        // Find the sleep hours on this day
        let sleep = sleepChartPoints.first(where: { calendar.isDate($0.date, inSameDayAs: snappedDate) })?.totalHours

        // Find the workout hours on this day
        let workouts = workoutChartPoints.first(where: { calendar.isDate($0.date, inSameDayAs: snappedDate) })?.totalHours

        return (weight, steps, sleep, workouts, snappedDate)
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var weightYDomain: ClosedRange<Double> {
        let bottomPadding: Double = 1.5
        guard !snapshot.chart.entries.isEmpty else {
            let base = snapshot.chart.yDomain
            return (base.lowerBound - bottomPadding)...base.upperBound
        }

        let baseDomain = snapshot.chart.yDomain
        let goalWeights = ([filteredActiveTargetWeight] + filteredMiniGoals.map(\.targetWeight)).compactMap { $0 }
        if goalWeights.isEmpty {
            return (baseDomain.lowerBound - bottomPadding)...baseDomain.upperBound
        }

        let lowerBound = min(baseDomain.lowerBound - bottomPadding, (goalWeights.min() ?? 0) - 1)
        let upperBound = max(baseDomain.upperBound, (goalWeights.max() ?? 0) + 1)
        return lowerBound...upperBound
    }

    private var stepChartPoints: [StepChartPoint] {
        snapshot.stepChartPoints
    }

    private var maxStepCount: Int {
        max(stepChartPoints.map(\.steps).max() ?? 0, 1)
    }

    private var stepTrendPoints: [StepChartPoint] {
        let points = stepChartPoints.filter { $0.steps > 0 }
        guard points.count >= 3 else { return [] }
        let alpha = 0.3
        var smoothed: [StepChartPoint] = []
        var value = Double(points[0].steps)
        for point in points {
            value = alpha * Double(point.steps) + (1 - alpha) * value
            smoothed.append(StepChartPoint(date: point.date, steps: Int(value)))
        }
        return smoothed
    }

    private var chartXDomain: ClosedRange<Date> {
        let endDate = Date()
        let visibleStartDate = chartVisibleStartDate(endingAt: endDate)
        let firstEntryDate = snapshot.chartHistory.entries.first?.timestamp
        let firstStepDate = stepChartPoints.first?.date
        let firstDataDate = [firstEntryDate, firstStepDate].compactMap { $0 }.min() ?? visibleStartDate
        let startDate = min(firstDataDate, visibleStartDate)

        return startDate...endDate
    }

    private var chartXVisibleDomainLength: TimeInterval {
        Date().timeIntervalSince(chartVisibleStartDate())
    }

    private var stepBarWidth: MarkDimension {
        switch chartPeriod {
        case .week:
            return .fixed(24)
        case .month:
            return .fixed(6)
        case .threeMonths:
            return .fixed(1.5)
        case .sixMonths:
            return .fixed(1.25)
        case .year:
            return .fixed(1)
        }
    }

    private var chartXAxisStride: (component: Calendar.Component, count: Int) {
        switch chartPeriod {
        case .week:
            return (.day, 1)
        case .month:
            return (.day, 7)
        case .threeMonths:
            return (.month, 1)
        case .sixMonths:
            return (.month, 1)
        case .year:
            return (.month, 3)
        }
    }

    private func chartVisibleStartDate(endingAt endDate: Date = Date()) -> Date {
        Calendar.current.date(
            byAdding: chartPeriod.calendarComponent,
            value: -chartPeriod.componentValue,
            to: endDate
        ) ?? endDate
    }

    private var chartXAxisLabelFormat: Date.FormatStyle {
        switch chartPeriod {
        case .year:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        default:
            return .dateTime.month(.abbreviated).day()
        }
    }

    private var dataVersion: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        hasher.combine(entries.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(entries.first?.weight ?? 0)
        hasher.combine(dailyActivitySummaries.count)
        hasher.combine(dailyActivitySummaries.first?.date.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(dailyActivitySummaries.first?.stepCount ?? 0)
        hasher.combine(allSleepEntries.count)
        hasher.combine(allWorkouts.count)
        return hasher.finalize()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                chartCard
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            updateSnapshot()
            updateMiniGoals()
            resetChartScrollPosition()
        }
        .onChange(of: dataVersion) { _, _ in
            updateSnapshot()
        }
        .onChange(of: badgePeriodIndex) { _, _ in
            updateSnapshot()
            resetChartScrollPosition()
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
        .onChange(of: selectedDataPoint?.date) { oldValue, newValue in
            if newValue != nil, newValue != oldValue {
                Haptics.selection()
            }
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow

            Picker("Period", selection: $badgePeriodIndex) {
                ForEach(Array(TimePeriod.allCases.enumerated()), id: \.offset) { index, period in
                    Text(period.rawValue).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 12)
            .padding(.bottom, 18)

            if snapshot.chart.smoothedEntries.isEmpty {
                Text("Not enough data for this period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    labeledChart(title: "Weight", systemImage: "scalemass.fill", height: 130) { weightChart }

                    labeledChart(title: "Steps", systemImage: "shoeprints.fill", height: 80) { stepsChart }

                    if hasSleepData {
                        labeledChart(title: "Sleep", systemImage: "bed.double.fill", height: 80) { sleepChart }
                    }

                    if hasWorkoutData {
                        labeledChart(title: "Workouts", systemImage: "figure.run", height: 80) { workoutChart }
                    }
                }
            }

        }
        .padding(.vertical, 14)
    }

    // MARK: - Weight Chart

    private var weightChart: some View {
        Chart {
            ForEach(snapshot.chart.entries, id: \.timestamp) { entry in
                LineMark(
                    x: .value("Date", entry.timestamp),
                    y: .value("Weight", entry.weight),
                    series: .value("Series", "actual")
                )
                .foregroundStyle(tintColor.opacity(selectedDate == nil ? 1.0 : 0.35))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }

            ForEach(snapshot.chart.trendEntries, id: \.timestamp) { point in
                LineMark(
                    x: .value("Date", point.timestamp),
                    y: .value("Weight", point.weight),
                    series: .value("Series", "trend")
                )
                .foregroundStyle(tintColor.opacity(selectedDate == nil ? 0.30 : 0.10))
                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }

            ForEach(snapshot.chart.entries, id: \.timestamp) { entry in
                PointMark(
                    x: .value("Date", entry.timestamp),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(tintColor.opacity(selectedDate == nil ? 1.0 : 0.25))
                .symbolSize(14)
            }

            if let target = filteredActiveTargetWeight {
                RuleMark(y: .value("Goal", target))
                    .foregroundStyle(tintColor.opacity(selectedDate == nil ? 0.82 : 0.30))
                    .lineStyle(StrokeStyle(lineWidth: 1.35, dash: [4, 4]))
                    .annotation(position: .trailing, alignment: .trailing) {
                        chartGoalIcon(
                            systemName: "flag.checkered",
                            accessibilityLabel: "\(selectedGoal.targetTitle) \(target.formatted(.number.precision(.fractionLength(1)))) pounds"
                        )
                    }
            }

            ForEach(filteredMiniGoals) { miniGoal in
                RuleMark(y: .value("Mini Goal", miniGoal.targetWeight))
                    .foregroundStyle(tintColor.opacity(selectedDate == nil ? 0.46 : 0.15))
                    .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [2, 4]))
                    .annotation(position: .trailing, alignment: .trailing) {
                        chartGoalIcon(
                            systemName: "flag.fill",
                            accessibilityLabel: "\(miniGoal.name) \(miniGoal.targetWeight.formatted(.number.precision(.fractionLength(1)))) pounds"
                        )
                    }
            }

            if let selectedData = selectedDataPoint {
                RuleMark(
                    x: .value("Selected Date", selectedData.date)
                )
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                if let weight = selectedData.weight {
                    PointMark(
                        x: .value("Selected Date", selectedData.date),
                        y: .value("Selected Weight", weight)
                    )
                    .foregroundStyle(tintColor)
                    .symbolSize(80)
                }
            }
        }
        .chartYScale(domain: weightYDomain)
        .chartXScale(domain: chartVisibleStartDate()...Date())
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(String(format: "%.0f", weight))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 32, alignment: .leading)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let selectedData = selectedDataPoint, let weight = selectedData.weight {
                    selectedChartPopupOverlay(
                        proxy: proxy,
                        geometry: geometry,
                        date: selectedData.date,
                        value: weight,
                        estimatedWidth: 76,
                        estimatedHeight: 28,
                        xOffset: 0,
                        yOffset: -18
                    ) {
                        selectedValuePill(String(format: "%.1f lbs", weight))
                    }
                }
            }
        }
        .padding(.bottom, -8)
        .frame(height: 130)
    }

    // MARK: - Steps Chart

    private var stepsChart: some View {
        let selectedStepDay = selectedDate.map { Calendar.current.startOfDay(for: $0) }
        return Chart {
            ForEach(stepChartPoints) { point in
                let isSelected = selectedStepDay == point.date
                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("Steps baseline", 0),
                    yEnd: .value("Steps", point.steps),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(isSelected ? 0.85 : (selectedDate == nil ? 0.60 : 0.30)))
            }

            ForEach(stepTrendPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Trend", point.steps)
                )
                .foregroundStyle(tintColor.opacity(selectedDate == nil ? 0.38 : 0.14))
                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }

            if let selectedData = selectedDataPoint {
                RuleMark(
                    x: .value("Selected Date", selectedData.date)
                )
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                if let steps = selectedData.steps {
                    PointMark(
                        x: .value("Selected Date", selectedData.date),
                        y: .value("Selected Steps", steps)
                    )
                    .foregroundStyle(tintColor)
                    .symbolSize(50)
                }
            }
        }
        .chartYScale(domain: 0...(Double(maxStepCount) * 1.15))
        .chartXScale(domain: chartVisibleStartDate()...Date())
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                    .foregroundStyle(.primary.opacity(0.10))
                AxisTick()
                    .foregroundStyle(.primary.opacity(0.28))
                AxisValueLabel {
                    let raw = value.as(Double.self) ?? 0
                    let steps = Int(raw)
                    Text(steps >= 1_000 ? "\(steps / 1_000)k" : "\(steps)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 32, alignment: .leading)
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis(!hasSleepData && !hasWorkoutData ? .visible : .hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let selectedData = selectedDataPoint, let steps = selectedData.steps {
                    selectedChartPopupOverlay(
                        proxy: proxy,
                        geometry: geometry,
                        date: selectedData.date,
                        value: Double(steps),
                        estimatedWidth: 104,
                        estimatedHeight: 28,
                        xOffset: 0,
                        yOffset: -18
                    ) {
                        selectedValuePill("\(steps.formatted()) steps")
                    }
                }
            }
        }
        .frame(height: 80)
    }

    private func chartGoalIcon(systemName: String, accessibilityLabel: String) -> some View {
        Image(systemName: systemName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tintColor)
            .frame(width: 14, height: 14)
            .accessibilityLabel(accessibilityLabel)
            .offset(x: -8)
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 16) {
            weightDisplay

            Spacer(minLength: 8)

            compactStat(
                title: "Change",
                value: snapshot.weightChangeLbs.map { String(format: "%+.1f lbs", $0) } ?? "--",
                valueColor: snapshot.weightChangeLbs.map { $0 < 0 ? .green : ($0 > 0 ? .red : .primary) } ?? .secondary
            )

            compactStat(
                title: "Goal",
                value: snapshot.goalProgress.map { goalCompletionText($0) } ?? "--",
                valueColor: tintColor
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var weightDisplay: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selectedData = selectedDataPoint {
                if let weight = selectedData.weight {
                    Text(String(format: "%.1f", weight))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(tintColor)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                } else {
                    Text("No weight")
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(selectedData.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let weight = snapshot.currentWeight {
                Text(String(format: "%.1f", weight))
                    .font(.system(size: 36, weight: .regular, design: .rounded))
                    .contentTransition(.numericText())
                    .lineLimit(1)

                Text("lbs today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("--")
                    .font(.system(size: 36, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("No entries yet")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func compactStat(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
    }

    private func labeledChart<V: View>(title: String, systemImage: String, height: CGFloat, @ViewBuilder chart: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            chart()
        }
    }

    // MARK: - Sleep Chart

    private struct SleepChartPoint: Identifiable {
        let date: Date
        let totalHours: Double
        let deepHours: Double
        let coreHours: Double
        let remHours: Double
        let unspecifiedHours: Double
        var id: Date { date }
    }

    private var sleepChartPoints: [SleepChartPoint] {
        snapshot.sleepChartPoints
    }

    private var maxSleepHours: Double {
        max(sleepChartPoints.map(\.totalHours).max() ?? 8, 1)
    }

    private var sleepTrendPoints: [SleepChartPoint] {
        let points = sleepChartPoints.filter { $0.totalHours > 0 }
        guard points.count >= 3 else { return [] }
        let alpha = 0.3
        var smoothed: [SleepChartPoint] = []
        var value = points[0].totalHours
        for point in points {
            value = alpha * point.totalHours + (1 - alpha) * value
            smoothed.append(SleepChartPoint(
                date: point.date,
                totalHours: value,
                deepHours: 0,
                coreHours: 0,
                remHours: 0,
                unspecifiedHours: 0
            ))
        }
        return smoothed
    }

    private var sleepChart: some View {
        let selectedDay = selectedDate.map { Calendar.current.startOfDay(for: $0) }
        return Chart {
            ForEach(sleepChartPoints) { point in
                let isSelected = selectedDay == point.date
                let opacity: Double = isSelected ? 0.95 : (selectedDate == nil ? 0.80 : 0.32)
                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("Deep start", 0),
                    yEnd: .value("Deep end", point.deepHours),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(0.95 * opacity))
                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("Core start", point.deepHours),
                    yEnd: .value("Core end", point.deepHours + point.coreHours),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(0.65 * opacity))
                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("REM start", point.deepHours + point.coreHours),
                    yEnd: .value("REM end", point.deepHours + point.coreHours + point.remHours),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(0.45 * opacity))
                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("Unspecified start", point.deepHours + point.coreHours + point.remHours),
                    yEnd: .value("Unspecified end", point.totalHours),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(0.30 * opacity))
            }

            ForEach(sleepTrendPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Trend", point.totalHours)
                )
                .foregroundStyle(tintColor.opacity(selectedDate == nil ? 0.38 : 0.14))
                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }

            if let selectedData = selectedDataPoint {
                RuleMark(
                    x: .value("Selected Date", selectedData.date)
                )
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                if let sleep = selectedData.sleepHours, sleep > 0 {
                    PointMark(
                        x: .value("Selected Date", selectedData.date),
                        y: .value("Selected Sleep", sleep)
                    )
                    .foregroundStyle(tintColor)
                    .symbolSize(50)
                }
            }
        }
        .chartXScale(domain: chartVisibleStartDate()...Date())
        .chartYScale(domain: 0...(maxSleepHours * 1.2))
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                    .foregroundStyle(.primary.opacity(0.10))
                AxisValueLabel {
                    if let h = value.as(Double.self) {
                        Text("\(Int(h))h")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 32, alignment: .leading)
                    }
                }
            }
        }
        .chartXAxis(!hasWorkoutData ? .visible : .hidden)
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let selectedData = selectedDataPoint,
                   let point = sleepChartPoints.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedData.date) }),
                   point.totalHours > 0 {
                    selectedChartPopupOverlay(
                        proxy: proxy,
                        geometry: geometry,
                        date: selectedData.date,
                        value: point.totalHours,
                        estimatedWidth: 200,
                        estimatedHeight: 26,
                        xOffset: 0,
                        yOffset: -18
                    ) {
                        sleepBreakdownCard(for: point)
                    }
                }
            }
        }
        .frame(height: 80)
    }

    // MARK: - Workout Chart

    private struct WorkoutChartPoint: Identifiable {
        let date: Date
        let totalHours: Double
        let strengthHours: Double
        let cardioHours: Double
        let otherHours: Double
        var id: Date { date }
    }

    private var workoutChartPoints: [WorkoutChartPoint] {
        snapshot.workoutChartPoints
    }

    private var workoutTrendPoints: [WorkoutChartPoint] {
        let points = workoutChartPoints.filter { $0.totalHours > 0 }
        guard points.count >= 3 else { return [] }
        let alpha = 0.3
        var smoothed: [WorkoutChartPoint] = []
        var value = points[0].totalHours
        for point in points {
            value = alpha * point.totalHours + (1 - alpha) * value
            smoothed.append(WorkoutChartPoint(
                date: point.date,
                totalHours: value,
                strengthHours: 0,
                cardioHours: 0,
                otherHours: 0
            ))
        }
        return smoothed
    }

    private var maxWorkoutHours: Double {
        max(workoutChartPoints.map(\.totalHours).max() ?? 1, 0.5)
    }

    private var workoutChart: some View {
        let selectedDay = selectedDate.map { Calendar.current.startOfDay(for: $0) }
        return Chart {
            ForEach(workoutChartPoints) { point in
                let isSelected = selectedDay == point.date
                let opacity: Double = isSelected ? 0.95 : (selectedDate == nil ? 0.80 : 0.32)

                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("Strength start", 0),
                    yEnd: .value("Strength end", point.strengthHours),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(0.95 * opacity))

                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("Cardio start", point.strengthHours),
                    yEnd: .value("Cardio end", point.strengthHours + point.cardioHours),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(0.65 * opacity))

                BarMark(
                    x: .value("Date", point.date),
                    yStart: .value("Other start", point.strengthHours + point.cardioHours),
                    yEnd: .value("Other end", point.totalHours),
                    width: stepBarWidth
                )
                .foregroundStyle(tintColor.opacity(0.30 * opacity))
            }
            
            ForEach(workoutTrendPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Trend", point.totalHours)
                )
                .foregroundStyle(tintColor.opacity(selectedDate == nil ? 0.38 : 0.14))
                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }
            
            if let selectedData = selectedDataPoint {
                RuleMark(
                    x: .value("Selected Date", selectedData.date)
                )
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                if let workouts = selectedData.workoutHours, workouts > 0 {
                    PointMark(
                        x: .value("Selected Date", selectedData.date),
                        y: .value("Selected Workouts", workouts)
                    )
                    .foregroundStyle(tintColor)
                    .symbolSize(50)
                }
            }
        }
        .chartXScale(domain: chartVisibleStartDate()...Date())
        .chartYScale(domain: 0...(maxWorkoutHours * 1.2))
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                    .foregroundStyle(.primary.opacity(0.10))
                AxisValueLabel {
                    if let h = value.as(Double.self) {
                        Text(h == 0.5 ? "0.5h" : "\(Int(h))h")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 32, alignment: .leading)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: chartXAxisStride.component, count: chartXAxisStride.count)) { _ in
                AxisGridLine()
                    .foregroundStyle(.primary.opacity(0.10))
                AxisTick()
                    .foregroundStyle(.primary.opacity(0.28))
                AxisValueLabel(format: chartXAxisLabelFormat)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let selectedData = selectedDataPoint,
                   let point = workoutChartPoints.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedData.date) }),
                   point.totalHours > 0 {
                    selectedChartPopupOverlay(
                        proxy: proxy,
                        geometry: geometry,
                        date: selectedData.date,
                        value: point.totalHours,
                        estimatedWidth: 200,
                        estimatedHeight: 26,
                        xOffset: 0,
                        yOffset: -18
                    ) {
                        workoutBreakdownCard(for: point)
                    }
                }
            }
        }
        .frame(height: 80)
    }

    private func updateSnapshot() {
        let cutoff = chartVisibleStartDate()
        let filteredSleep = allSleepEntries.filter { $0.endDate >= cutoff }
        let filteredWorkouts = allWorkouts.filter { $0.timestamp >= cutoff }
        snapshot = Snapshot(
            entries: entries,
            activitySummaries: dailyActivitySummaries,
            sleepEntries: filteredSleep,
            workoutEntries: filteredWorkouts,
            period: chartPeriod,
            goal: selectedGoal,
            targetWeight: activeTargetWeight
        )
    }

    private func resetChartScrollPosition() {
        chartScrollPosition = chartVisibleStartDate()
    }

    private func updateMiniGoals() {
        miniGoals = MiniGoalStore.load(for: selectedGoal)
    }

    private func goalCompletionText(_ progress: WeightCalculations.GoalProgress) -> String {
        GoalProgressFeedback.progressText(progress)
    }

    @ViewBuilder
    private func selectedChartPopupOverlay<Content: View>(
        proxy: ChartProxy,
        geometry: GeometryProxy,
        date: Date,
        value: Double? = nil,
        estimatedWidth: CGFloat,
        estimatedHeight: CGFloat? = nil,
        laneY: CGFloat = 0,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let plotFrame = proxy.plotFrame,
           let selectedX = proxy.position(forX: date) {
            let plotRect = geometry[plotFrame]
            let proposedX = plotRect.minX + selectedX + xOffset
            let horizontalInset = estimatedWidth / 2
            let minX = plotRect.minX + horizontalInset
            let maxX = plotRect.maxX - horizontalInset
            let clampedX = maxX > minX ? min(max(proposedX, minX), maxX) : plotRect.midX
            let clampedY = selectedPopupYPosition(
                proxy: proxy,
                plotRect: plotRect,
                value: value,
                estimatedHeight: estimatedHeight,
                laneY: laneY,
                yOffset: yOffset
            )

            content()
                .position(x: clampedX, y: clampedY)
        }
    }

    private func selectedPopupYPosition(
        proxy: ChartProxy,
        plotRect: CGRect,
        value: Double?,
        estimatedHeight: CGFloat?,
        laneY: CGFloat,
        yOffset: CGFloat
    ) -> CGFloat {
        let proposedY: CGFloat
        if let value, let selectedY = proxy.position(forY: value) {
            proposedY = plotRect.minY + selectedY + yOffset
        } else {
            proposedY = plotRect.minY + laneY
        }

        guard let estimatedHeight else {
            return proposedY
        }

        let verticalInset = estimatedHeight / 2
        let minY = plotRect.minY + verticalInset
        let maxY = plotRect.maxY - verticalInset
        return maxY > minY ? min(max(proposedY, minY), maxY) : plotRect.midY
    }

    private func selectedValuePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tintColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 0.5)
            }
            .shadow(color: tintColor.opacity(0.25), radius: 4, x: 0, y: 2)
            .fixedSize(horizontal: true, vertical: true)
    }

    private func selectedBreakdownCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
        .fixedSize(horizontal: true, vertical: true)
    }

    private func sleepBreakdownCard(for point: SleepChartPoint) -> some View {
        selectedBreakdownCard {
            segmentedBreakdownBar(items: [
                (point.deepHours, "Deep", nil, tintColor.opacity(0.95)),
                (point.coreHours, "Core", nil, tintColor.opacity(0.65)),
                (point.remHours, "REM", nil, tintColor.opacity(0.45)),
                (point.unspecifiedHours, "Sleep", nil, tintColor.opacity(0.30))
            ])
        }
    }

    private func workoutBreakdownCard(for point: WorkoutChartPoint) -> some View {
        selectedBreakdownCard {
            segmentedBreakdownBar(items: [
                (point.strengthHours, nil, "figure.strengthtraining.traditional", tintColor.opacity(0.95)),
                (point.cardioHours, nil, "figure.run", tintColor.opacity(0.65)),
                (point.otherHours, nil, "figure.mixed.cardio", tintColor.opacity(0.30))
            ])
        }
    }

    private func segmentedBreakdownBar(items: [(value: Double, label: String?, icon: String?, color: Color)]) -> some View {
        let visibleItems = items.filter { $0.value > 0 }

        return HStack(spacing: 2) {
            ForEach(Array(visibleItems.enumerated()), id: \.offset) { _, item in
                segmentContent(item: item)
                    .background(item.color, in: Capsule())
            }
        }
        .opacity(visibleItems.isEmpty ? 0 : 1)
    }

    private func segmentContent(item: (value: Double, label: String?, icon: String?, color: Color)) -> some View {
        HStack(spacing: 3) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(String(format: "%.1fh", item.value))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            if let label = item.label {
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }

}

#Preview {
    OverviewView()
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self, SleepEntry.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
