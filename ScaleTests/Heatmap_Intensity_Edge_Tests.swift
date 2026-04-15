//
//  Heatmap_Intensity_Edge_Tests.swift
//  ScaleTests
//
//  Tests for heatmapIntensity edge cases and heatmapSnapshot zero-weeks boundary.
//

import Testing
import Foundation
@testable import Scale

struct HeatmapIntensityEdgeTests {

    // MARK: - heatmapSnapshot boundaries

    @Test func heatmapSnapshotWithZeroWeeksReturnsEmpty() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 0)
        #expect(snapshot == .empty)
    }

    @Test func heatmapSnapshotWithOneWeekProducesOneWeek() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 1)
        #expect(snapshot.weeks.count == 1)
        #expect(snapshot.weeks.first?.count == 7)
    }

    @Test func heatmapFutureDaysHaveZeroEntryCount() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        // Create an entry timestamped tomorrow (should not count)
        let futureEntry = WeightEntry(weight: 150.0, timestamp: tomorrow)
        let snapshot = WeightCalculations.heatmapSnapshot(from: [futureEntry], weeks: 1)

        let allDays = snapshot.weeks.flatMap { $0 }
        let tomorrowCell = allDays.first { calendar.isDate($0.date, inSameDayAs: tomorrow) }
        // Future days should have count 0 regardless of entries
        #expect(tomorrowCell?.entryCount == 0)
        #expect(tomorrowCell?.intensity == 0)
    }

    @Test func heatmapDaysWithNoEntriesHaveZeroIntensity() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 2)
        let allDays = snapshot.weeks.flatMap { $0 }
        #expect(allDays.allSatisfy { $0.intensity == 0 })
        #expect(allDays.allSatisfy { $0.entryCount == 0 })
    }

    @Test func heatmapMultipleEntriesSameDayAggregateCount() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<3).map { i in
            WeightEntry(weight: 150.0 + Double(i), timestamp: today.addingTimeInterval(TimeInterval(i * 3600)))
        }

        let snapshot = WeightCalculations.heatmapSnapshot(from: entries, weeks: 1)
        let todayCell = snapshot.weeks.flatMap { $0 }.first { calendar.isDate($0.date, inSameDayAs: today) }

        #expect(todayCell?.entryCount == 3)
        // maxCount == 3 and count == 3, so scaled == 1.0 → intensity == 4
        #expect(todayCell?.intensity == 4)
    }

    @Test func heatmapTwoDaysWithDifferentCountsScaleCorrectly() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Yesterday: 1 entry, Today: 4 entries → maxCount = 4
        var entries = [WeightEntry(weight: 150.0, timestamp: yesterday)]
        entries += (0..<4).map { i in
            WeightEntry(weight: 160.0, timestamp: today.addingTimeInterval(TimeInterval(i * 60)))
        }

        let snapshot = WeightCalculations.heatmapSnapshot(from: entries, weeks: 1)
        let allDays = snapshot.weeks.flatMap { $0 }

        let todayCell = allDays.first { calendar.isDate($0.date, inSameDayAs: today) }
        let yesterdayCell = allDays.first { calendar.isDate($0.date, inSameDayAs: yesterday) }

        #expect(todayCell?.intensity == 4) // 4/4 = 1.0 → 4
        #expect(yesterdayCell?.intensity == 1) // 1/4 = 0.25 → 1
    }

    // MARK: - Month labels

    @Test func heatmapMonthLabelsHaveUniqueWeekIndices() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 26)
        let indices = snapshot.monthLabels.map(\.weekIndex)
        #expect(Set(indices).count == indices.count, "Month labels should have unique week indices")
    }

    @Test func heatmapMonthLabelsAreInAscendingOrder() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 26)
        let indices = snapshot.monthLabels.map(\.weekIndex)
        #expect(indices == indices.sorted())
    }
}
