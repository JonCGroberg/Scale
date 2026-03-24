//
//  WeightCalculations.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Foundation

enum TimePeriod: String, CaseIterable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"

    var calendarComponent: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .threeMonths: return .month
        case .sixMonths: return .month
        case .year: return .year
        }
    }

    var componentValue: Int {
        switch self {
        case .week: return 1
        case .month: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .year: return 1
        }
    }

    var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .year: return "Year"
        }
    }
}

enum WeightCalculations {
    struct ChartPoint: Equatable {
        let timestamp: Date
        let weight: Double
    }

    struct BadgeSummary: Equatable {
        let streak: Int
        let average: Double?
        let weightChange: Double?
    }

    struct ChartSnapshot {
        let entries: [WeightEntry]
        let smoothedEntries: [ChartPoint]
        let yDomain: ClosedRange<Double>

        static let empty = ChartSnapshot(entries: [], smoothedEntries: [], yDomain: 0...1)
    }

    struct LogSnapshot {
        let groupedEntries: [(key: String, value: [WeightEntry])]
        let streaksByDay: [Date: Int]
        let chart: ChartSnapshot
    }

    struct HeatmapDay: Equatable {
        let date: Date
        let entryCount: Int
        let intensity: Int
    }

    struct HeatmapMonthLabel: Equatable {
        let title: String
        let weekIndex: Int
    }

    struct HeatmapSnapshot: Equatable {
        let weeks: [[HeatmapDay]]
        let monthLabels: [HeatmapMonthLabel]

        static let empty = HeatmapSnapshot(weeks: [], monthLabels: [])
    }


    /// Calculate the weight change between the two most recent entries.
    /// - Parameter entries: Weight entries sorted most-recent-first.
    /// - Returns: The difference in pounds (positive = gained), or nil if fewer than 2 entries.
    static func weightChange(from entries: [WeightEntry]) -> Double? {
        guard entries.count >= 2 else { return nil }
        return entries[0].weight - entries[1].weight
    }

    /// The timestamp of the second-most-recent entry (the comparison baseline).
    static func changeDate(from entries: [WeightEntry]) -> Date? {
        guard entries.count >= 2 else { return nil }
        return entries[1].timestamp
    }

    /// Average weight over a given time period.
    /// - Parameters:
    ///   - entries: Weight entries sorted most-recent-first.
    ///   - period: The time period to average over.
    /// - Returns: The average weight, or nil if no entries fall within the period.
    static func averageWeight(from entries: [WeightEntry], over period: TimePeriod) -> Double? {
        let filtered = entriesWithin(period, from: entries)
        guard !filtered.isEmpty else { return nil }

        let total = filtered.reduce(0.0) { $0 + $1.weight }
        return total / Double(filtered.count)
    }

    static func badgeSummary(from entries: [WeightEntry], over period: TimePeriod) -> BadgeSummary {
        let filtered = entriesWithin(period, from: entries).sorted { $0.timestamp < $1.timestamp }
        let average = filtered.isEmpty ? nil : filtered.reduce(0.0) { $0 + $1.weight } / Double(filtered.count)
        let weightChange: Double?
        if filtered.count >= 2, let first = filtered.first, let last = filtered.last {
            weightChange = last.weight - first.weight
        } else {
            weightChange = nil
        }

        return BadgeSummary(
            streak: currentStreak(from: entries),
            average: average,
            weightChange: weightChange
        )
    }

    static func chartSnapshot(from entries: [WeightEntry], over period: TimePeriod) -> ChartSnapshot {
        let filteredEntries = entriesWithin(period, from: entries).sorted { $0.timestamp < $1.timestamp }
        guard !filteredEntries.isEmpty else { return .empty }

        let weights = filteredEntries.map(\.weight)
        let minWeight = (weights.min() ?? 0) - 1
        let maxWeight = (weights.max() ?? 0) + 1
        let smoothedEntries = exponentiallySmoothedChartPoints(
            from: filteredEntries,
            alpha: smoothingAlpha(for: period)
        )

        return ChartSnapshot(
            entries: filteredEntries,
            smoothedEntries: smoothedEntries,
            yDomain: minWeight...maxWeight
        )
    }

    static func logSnapshot(from entries: [WeightEntry], chartPeriod: TimePeriod) -> LogSnapshot {
        LogSnapshot(
            groupedEntries: groupedByMonth(entries),
            streaksByDay: streaksByDay(from: entries),
            chart: chartSnapshot(from: entries, over: chartPeriod)
        )
    }

    static func heatmapSnapshot(from entries: [WeightEntry], weeks: Int = 26) -> HeatmapSnapshot {
        guard weeks > 0 else { return .empty }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfCurrentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: startOfCurrentWeek) else {
            return .empty
        }

        let countsByDay = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        .mapValues(\.count)

        let maxCount = countsByDay.values.max() ?? 0
        var heatmapWeeks: [[HeatmapDay]] = []
        var monthLabels: [HeatmapMonthLabel] = []
        var previousMonth: Int?

        for weekIndex in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: startDate) else {
                continue
            }

            let month = calendar.component(.month, from: weekStart)
            if previousMonth != month {
                monthLabels.append(
                    HeatmapMonthLabel(
                        title: weekStart.formatted(.dateTime.month(.abbreviated)),
                        weekIndex: weekIndex
                    )
                )
                previousMonth = month
            }

            var days: [HeatmapDay] = []
            for weekdayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: weekdayOffset, to: weekStart) else {
                    continue
                }

                let day = calendar.startOfDay(for: date)
                let count = day > today ? 0 : (countsByDay[day] ?? 0)
                days.append(
                    HeatmapDay(
                        date: day,
                        entryCount: count,
                        intensity: heatmapIntensity(for: count, maxCount: maxCount)
                    )
                )
            }

            heatmapWeeks.append(days)
        }

        return HeatmapSnapshot(weeks: heatmapWeeks, monthLabels: monthLabels)
    }

    /// Parse a user-entered weight string into a valid positive Double.
    static func parseWeight(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    static func incrementWeight(_ weight: Double, step: Double = 0.1) -> Double {
        steppedWeight(from: weight, delta: step)
    }

    static func decrementWeight(_ weight: Double, step: Double = 0.1) -> Double {
        steppedWeight(from: weight, delta: -step)
    }

    /// Parse text recognized by the scale scanner.
    /// Accepts 1-3 digits with an optional single decimal digit (e.g. "142.5", "85", "200.0").
    static func parseScannedWeight(_ transcript: String) -> Double? {
        let trimmed = transcript.trimmingCharacters(in: .whitespaces)
        guard trimmed.wholeMatch(of: /^\d{1,3}(\.\d{0,1})?$/) != nil,
              let weight = Double(trimmed), weight > 0 else {
            return nil
        }
        return weight
    }

    /// Percentage weight change over a given time period.
    /// Compares the most recent entry to the earliest entry within the period.
    /// - Returns: The percentage change, or nil if fewer than 2 entries in the period.
    static func percentageChange(from entries: [WeightEntry], over period: TimePeriod) -> Double? {
        let filtered = entriesWithin(period, from: entries).sorted { $0.timestamp < $1.timestamp }
        guard filtered.count >= 2,
              let first = filtered.first,
              let last = filtered.last,
              first.weight != 0 else { return nil }

        return ((last.weight - first.weight) / first.weight) * 100
    }

    static func weightChangeLbs(from entries: [WeightEntry], over period: TimePeriod) -> Double? {
        let filtered = entriesWithin(period, from: entries).sorted { $0.timestamp < $1.timestamp }
        guard filtered.count >= 2,
              let first = filtered.first,
              let last = filtered.last else { return nil }
        return last.weight - first.weight
    }

    /// Current logging streak: consecutive days (including today) with at least one entry.
    /// - Parameters:
    ///   - entries: Weight entries sorted most-recent-first.
    ///   - includingToday: When `true`, count today even if no entry exists yet (used when about to save).
    /// - Returns: The number of consecutive days with entries ending today, or 0 if none today.
    static func currentStreak(from entries: [WeightEntry], includingToday: Bool = false) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Collect unique logged days
        var loggedDays = Set<Date>()
        for entry in entries {
            loggedDays.insert(calendar.startOfDay(for: entry.timestamp))
        }
        if includingToday {
            loggedDays.insert(today)
        }

        guard loggedDays.contains(today) else { return 0 }

        // Walk backwards from today
        var streak = 0
        var day = today
        while loggedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    /// Compute the streak value for every unique logged day.
    /// Every day that is part of a consecutive run of 2+ days gets a value > 0.
    /// Days that are isolated (no adjacent logged days) get 0.
    /// Within a run, day 1 gets 1, day 2 gets 2, etc.
    /// - Parameter entries: All weight entries (any order).
    static func streaksByDay(from entries: [WeightEntry]) -> [Date: Int] {
        let calendar = Calendar.current
        var loggedDays = Set<Date>()
        for entry in entries {
            loggedDays.insert(calendar.startOfDay(for: entry.timestamp))
        }

        guard !loggedDays.isEmpty else { return [:] }

        let sorted = loggedDays.sorted()

        // Build runs of consecutive days
        var runs: [[Date]] = []
        var currentRun: [Date] = [sorted[0]]

        for i in 1..<sorted.count {
            let previous = sorted[i - 1]
            let current = sorted[i]
            if calendar.date(byAdding: .day, value: 1, to: previous) == current {
                currentRun.append(current)
            } else {
                runs.append(currentRun)
                currentRun = [current]
            }
        }
        runs.append(currentRun)

        // Assign streak counts: isolated days get 0, multi-day runs get 1...N
        var result: [Date: Int] = [:]
        for run in runs {
            if run.count == 1 {
                result[run[0]] = 0
            } else {
                for (index, day) in run.enumerated() {
                    result[day] = index + 1
                }
            }
        }

        return result
    }

    /// Group weight entries by month/year, sorted newest-first.
    static func groupedByMonth(_ entries: [WeightEntry]) -> [(key: String, value: [WeightEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.timestamp)
        }

        return grouped.sorted { a, b in
            guard let dateA = a.value.first?.timestamp,
                  let dateB = b.value.first?.timestamp else { return false }
            return dateA > dateB
        }
    }

    private static func entriesWithin(_ period: TimePeriod, from entries: [WeightEntry]) -> [WeightEntry] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(
            byAdding: period.calendarComponent,
            value: -period.componentValue,
            to: Date()
        ) else { return [] }

        return entries.filter { $0.timestamp >= cutoff }
    }

    private static func smoothingAlpha(for period: TimePeriod) -> Double {
        switch period {
        case .week:
            0.80
        case .month:
            0.70
        case .threeMonths:
            0.60
        case .sixMonths:
            0.50
        case .year:
            0.42
        }
    }

    private static func exponentiallySmoothedChartPoints(
        from entries: [WeightEntry],
        alpha: Double
    ) -> [ChartPoint] {
        guard let firstEntry = entries.first else { return [] }

        var smoothedWeight = firstEntry.weight

        return entries.map { entry in
            smoothedWeight = alpha * entry.weight + (1 - alpha) * smoothedWeight
            return ChartPoint(timestamp: entry.timestamp, weight: smoothedWeight)
        }
    }

    private static func heatmapIntensity(for count: Int, maxCount: Int) -> Int {
        guard count > 0, maxCount > 0 else { return 0 }
        if maxCount == 1 { return 4 }

        let scaled = Double(count) / Double(maxCount)
        switch scaled {
        case ..<0.34:
            return 1
        case ..<0.67:
            return 2
        case ..<1.0:
            return 3
        default:
            return 4
        }
    }

    private static func steppedWeight(from weight: Double, delta: Double) -> Double {
        let updatedWeight = max(0, weight + delta)
        return (updatedWeight * 10).rounded() / 10
    }
}
