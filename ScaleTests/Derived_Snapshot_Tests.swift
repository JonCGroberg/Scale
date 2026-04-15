//
//  Derived_Snapshot_Tests.swift
//  ScaleTests
//
//  Split from monolithic ScaleTests.swift for maintainability.
//

import Testing
import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import XCTest
@testable import Scale

// MARK: - Derived Snapshot Tests

struct DerivedSnapshotTests {

    @Test func badgeSummaryMatchesExistingCalculations() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 178.0, timestamp: now.addingTimeInterval(-2 * 86400)),
            WeightEntry(weight: 176.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]

        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)

        #expect(summary.streak == WeightCalculations.currentStreak(from: entries))
        #expect(summary.average == WeightCalculations.averageWeight(from: entries, over: .week))
        #expect(summary.weightChange == 4.0)
    }

    @Test func chartSnapshotFiltersAndSortsEntriesInPeriod() {
        let now = Date()
        let oldEntry = WeightEntry(weight: 200.0, timestamp: now.addingTimeInterval(-40 * 86400))
        let midEntry = WeightEntry(weight: 181.0, timestamp: now.addingTimeInterval(-6 * 86400))
        let recentEntry = WeightEntry(weight: 179.0, timestamp: now.addingTimeInterval(-2 * 86400))
        let entries = [recentEntry, oldEntry, midEntry]

        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .week)

        #expect(snapshot.entries.count == 2)
        #expect(snapshot.smoothedEntries.count == 2)
        #expect(snapshot.entries[0].timestamp == midEntry.timestamp)
        #expect(snapshot.entries[1].timestamp == recentEntry.timestamp)
        #expect(snapshot.yDomain.lowerBound == 178.0)
        #expect(snapshot.yDomain.upperBound == 182.0)
    }

    @Test func chartSnapshotBuildsDampedSmoothedSeries() {
        let now = Date()
        let firstEntry = WeightEntry(weight: 180.0, timestamp: now.addingTimeInterval(-6 * 86400))
        let secondEntry = WeightEntry(weight: 190.0, timestamp: now.addingTimeInterval(-4 * 86400))
        let thirdEntry = WeightEntry(weight: 170.0, timestamp: now.addingTimeInterval(-2 * 86400))
        let entries = [thirdEntry, secondEntry, firstEntry]

        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .month)

        #expect(snapshot.smoothedEntries.count == 3)
        #expect(snapshot.smoothedEntries[0].weight == 180.0)
        #expect(abs(snapshot.smoothedEntries[1].weight - 187.0) < 0.0001)
        #expect(abs(snapshot.smoothedEntries[2].weight - 175.1) < 0.0001)
    }

    @Test func logSnapshotBuildsGroupedEntriesAndStreaks() {
        let calendar = Calendar.current
        let now = Date()
        let today = WeightEntry(weight: 180.0, timestamp: now)
        let yesterday = WeightEntry(weight: 179.0, timestamp: calendar.date(byAdding: .day, value: -1, to: now)!)
        let lastMonth = WeightEntry(weight: 182.0, timestamp: calendar.date(byAdding: .month, value: -1, to: now)!)
        let entries = [today, yesterday, lastMonth]

        let snapshot = WeightCalculations.logSnapshot(from: entries, chartPeriod: .threeMonths)
        let todayKey = calendar.startOfDay(for: today.timestamp)
        let yesterdayKey = calendar.startOfDay(for: yesterday.timestamp)

        #expect(snapshot.groupedEntries.count == 2)
        #expect(snapshot.chart.entries.count == 3)
        #expect(snapshot.chart.smoothedEntries.count == 3)
        #expect(snapshot.streaksByDay[todayKey] == 2)
        #expect(snapshot.streaksByDay[yesterdayKey] == 1)
    }

    @Test func heatmapSnapshotBuildsRequestedWeekCount() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 8)

        #expect(snapshot.weeks.count == 8)
        #expect(snapshot.weeks.allSatisfy { $0.count == 7 })
    }

    @Test func heatmapSnapshotAggregatesMultipleEntriesPerDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = [
            WeightEntry(weight: 180.0, timestamp: today.addingTimeInterval(60)),
            WeightEntry(weight: 179.5, timestamp: today.addingTimeInterval(120)),
            WeightEntry(weight: 179.0, timestamp: today.addingTimeInterval(180))
        ]

        let snapshot = WeightCalculations.heatmapSnapshot(from: entries, weeks: 1)
        let todayCell = snapshot.weeks[0].first { calendar.isDate($0.date, inSameDayAs: today) }

        #expect(todayCell?.entryCount == 3)
        #expect(todayCell?.intensity == 4)
    }

    @Test func heatmapSnapshotLeavesFutureDaysEmpty() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 1)

        let futureCells = snapshot.weeks[0].filter { $0.date > today }
        #expect(futureCells.allSatisfy { $0.entryCount == 0 && $0.intensity == 0 })
    }

    @Test func chartSnapshotIsEmptyWhenPeriodHasNoEntries() {
        let oldEntry = WeightEntry(weight: 180.0, timestamp: Date().addingTimeInterval(-500 * 86400))

        let snapshot = WeightCalculations.chartSnapshot(from: [oldEntry], over: .week)

        #expect(snapshot.entries.isEmpty)
        #expect(snapshot.smoothedEntries.isEmpty)
        #expect(snapshot.yDomain == 0...1)
    }

    @Test func heatmapSnapshotReturnsEmptyForNonPositiveWeekCounts() {
        #expect(WeightCalculations.heatmapSnapshot(from: [], weeks: 0) == .empty)
        #expect(WeightCalculations.heatmapSnapshot(from: [], weeks: -3) == .empty)
    }

    @Test func logSnapshotIsEmptyWhenEntriesAreEmpty() {
        let snapshot = WeightCalculations.logSnapshot(from: [], chartPeriod: .month)

        #expect(snapshot.groupedEntries.isEmpty)
        #expect(snapshot.streaksByDay.isEmpty)
        #expect(snapshot.chart.entries.isEmpty)
        #expect(snapshot.chart.smoothedEntries.isEmpty)
        #expect(snapshot.chart.yDomain == 0...1)
    }

}

final class WeightWidgetSnapshotXCTests: XCTestCase {

    func testSnapshotUsesLatestEntryAndMonthSummary() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 182.4, timestamp: now),
            WeightEntry(weight: 184.0, timestamp: now.addingTimeInterval(-86400)),
            WeightEntry(weight: 185.1, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(
            from: entries,
            tintRawValue: AppTint.green.rawValue,
            now: now
        )

        XCTAssertEqual(snapshot.generatedAt, now)
        XCTAssertEqual(snapshot.appTintRawValue, AppTint.green.rawValue)
        XCTAssertEqual(snapshot.latestWeight, 182.4)
        XCTAssertEqual(snapshot.latestTimestamp, now)
        XCTAssertEqual(snapshot.streakCount, 2)
        XCTAssertNotNil(snapshot.monthAverage)
        XCTAssertNotNil(snapshot.monthPercentChange)
    }

    func testSnapshotIsEmptyWhenThereAreNoEntries() {
        let snapshot = WeightWidgetSnapshot.make(
            from: [],
            tintRawValue: AppTint.blue.rawValue,
            now: .now
        )

        XCTAssertNil(snapshot.latestWeight)
        XCTAssertNil(snapshot.latestTimestamp)
        XCTAssertEqual(snapshot.streakCount, 0)
        XCTAssertNil(snapshot.monthAverage)
        XCTAssertNil(snapshot.monthPercentChange)
    }

    func testSnapshotUsesMostRecentEntryAfterSorting() {
        let now = Date()
        let older = WeightEntry(weight: 190.0, timestamp: now.addingTimeInterval(-86400))
        let newer = WeightEntry(weight: 188.2, timestamp: now)

        let snapshot = WeightWidgetSnapshot.make(
            from: [older, newer],
            tintRawValue: AppTint.red.rawValue,
            now: now
        )

        XCTAssertEqual(snapshot.latestWeight, 188.2)
        XCTAssertEqual(snapshot.latestTimestamp, now)
        XCTAssertEqual(snapshot.appTintRawValue, AppTint.red.rawValue)
    }

    func testSnapshotLeavesMonthPercentChangeNilForSingleEntry() {
        let now = Date()
        let snapshot = WeightWidgetSnapshot.make(
            from: [WeightEntry(weight: 175.0, timestamp: now)],
            tintRawValue: AppTint.orange.rawValue,
            now: now
        )

        XCTAssertEqual(snapshot.latestWeight, 175.0)
        XCTAssertEqual(snapshot.streakCount, 1)
        XCTAssertEqual(snapshot.monthAverage, 175.0)
        XCTAssertNil(snapshot.monthPercentChange)
    }

}

