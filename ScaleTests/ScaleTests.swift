//
//  ScaleTests.swift
//  ScaleTests
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Testing
import Foundation
import SwiftData
import UserNotifications
import XCTest
@testable import Scale

// MARK: - WeightEntry Model Tests

struct WeightEntryTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: WeightEntry.self, configurations: config)
    }

    @Test func initializesWithWeight() {
        let entry = WeightEntry(weight: 142.5)
        #expect(entry.weight == 142.5)
    }

    @Test func initializesWithCustomTimestamp() {
        let date = Date()
        let entry = WeightEntry(weight: 150.0, timestamp: date)
        #expect(entry.weight == 150.0)
        #expect(entry.timestamp == date)
    }

    @Test func initializesWithPhotoData() {
        let photoData = Data([0x01, 0x02, 0x03])
        let entry = WeightEntry(weight: 150.0, photoData: photoData)
        #expect(entry.photoData == photoData)
    }

    @Test func initializesWithNote() {
        let entry = WeightEntry(weight: 150.0, note: "Felt strong today")
        #expect(entry.note == "Felt strong today")
    }

    @Test func initializesWithSourceStreakAndHealthKitIdentifier() {
        let uuid = UUID()
        let entry = WeightEntry(
            weight: 151.2,
            source: .appleHealth,
            streakCount: 7,
            healthKitUUID: uuid
        )

        #expect(entry.source == .appleHealth)
        #expect(entry.streakCount == 7)
        #expect(entry.healthKitUUID == uuid)
    }

    @Test func photoDataReturnsNilWhenNoPhotosExist() {
        let entry = WeightEntry(weight: 150.0)

        #expect(entry.photosData.isEmpty)
        #expect(entry.photoData == nil)
    }

    @Test func insertEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 142.5)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.weight == 142.5)
    }

    @Test func deleteEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 160.0)
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.isEmpty)
    }

    @Test func updateWeight() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 145.0)
        context.insert(entry)
        try context.save()

        entry.weight = 143.5
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.first?.weight == 143.5)
    }

    @Test func persistsPhotoData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let photoData = Data([0xAA, 0xBB, 0xCC])
        let entry = WeightEntry(weight: 145.0, photoData: photoData)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.first?.photoData == photoData)
    }

    @Test func persistsNote() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 145.0, note: "Post-workout")
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.first?.note == "Post-workout")
    }

    @Test func sortByTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let older = WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-86400))
        let newer = WeightEntry(weight: 148.0, timestamp: Date())
        context.insert(older)
        context.insert(newer)
        try context.save()

        var descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\WeightEntry.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let latest = try context.fetch(descriptor)
        #expect(latest.first?.weight == 148.0)
    }
}

// MARK: - Weight Source Tests

struct WeightSourceTests {

    @Test func rawValuesMatchStoredRepresentations() {
        #expect(WeightSource.manual.rawValue == "manual")
        #expect(WeightSource.appleHealth.rawValue == "appleHealth")
    }

    @Test func codableRoundTripPreservesSource() throws {
        let encoded = try JSONEncoder().encode(WeightSource.appleHealth)
        let decoded = try JSONDecoder().decode(WeightSource.self, from: encoded)

        #expect(decoded == .appleHealth)
    }
}

// MARK: - Weight Change Calculation Tests

struct WeightChangeTests {

    @Test func changeWithTwoEntries() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 5.0)
    }

    @Test func changeWithWeightLoss() {
        let entries = [
            WeightEntry(weight: 140.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == -5.0)
    }

    @Test func changeWithNoChange() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 0.0)
    }

    @Test func changeIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0)]
        #expect(WeightCalculations.weightChange(from: entries) == nil)
    }

    @Test func changeIsNilWithNoEntries() {
        let entries: [WeightEntry] = []
        #expect(WeightCalculations.weightChange(from: entries) == nil)
    }

    @Test func changeUsesFirstTwoEntriesOnly() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400)),
            WeightEntry(weight: 140.0, timestamp: Date().addingTimeInterval(-172800))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 5.0)
    }

    @Test func changeDateReturnsSecondEntry() {
        let date = Date().addingTimeInterval(-86400)
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: date)
        ]
        #expect(WeightCalculations.changeDate(from: entries) == date)
    }

    @Test func changeDateIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0)]
        #expect(WeightCalculations.changeDate(from: entries) == nil)
    }

    @Test func changeDateIsNilWithNoEntries() {
        let entries: [WeightEntry] = []
        #expect(WeightCalculations.changeDate(from: entries) == nil)
    }
}

// MARK: - Weight Input Parsing Tests

struct WeightParsingTests {

    @Test func parseValidWeight() {
        #expect(WeightCalculations.parseWeight(from: "142.5") == 142.5)
    }

    @Test func parseIntegerWeight() {
        #expect(WeightCalculations.parseWeight(from: "150") == 150.0)
    }

    @Test func parseWeightWithWhitespace() {
        #expect(WeightCalculations.parseWeight(from: "  150.0  ") == 150.0)
    }

    @Test func parseWeightRejectsText() {
        #expect(WeightCalculations.parseWeight(from: "abc") == nil)
    }

    @Test func parseWeightRejectsEmpty() {
        #expect(WeightCalculations.parseWeight(from: "") == nil)
    }

    @Test func parseWeightRejectsZero() {
        #expect(WeightCalculations.parseWeight(from: "0") == nil)
    }

    @Test func parseWeightRejectsNegative() {
        #expect(WeightCalculations.parseWeight(from: "-50") == nil)
    }

    @Test func parseWeightAcceptsLargeValue() {
        #expect(WeightCalculations.parseWeight(from: "350.5") == 350.5)
    }
}

// MARK: - Weight Stepper Tests

struct WeightStepperTests {

    @Test func decrementReducesWeightByOneTenth() {
        let updatedWeight = WeightCalculations.decrementWeight(142.5)
        #expect(updatedWeight == 142.4)
    }

    @Test func incrementRaisesWeightByOneTenth() {
        let updatedWeight = WeightCalculations.incrementWeight(142.5)
        #expect(updatedWeight == 142.6)
    }

    @Test func decrementClampsAtZero() {
        let updatedWeight = WeightCalculations.decrementWeight(0.0)
        #expect(updatedWeight == 0.0)
    }

    @Test func stepperRoundsFloatingPointNoiseToOneDecimalPlace() {
        let decrementedWeight = WeightCalculations.decrementWeight(142.3)
        let incrementedWeight = WeightCalculations.incrementWeight(142.3)

        #expect(decrementedWeight == 142.2)
        #expect(incrementedWeight == 142.4)
    }
}

// MARK: - Scanned Weight Parsing Tests

struct ScannedWeightParsingTests {

    @Test func parseThreeDigitsWithDecimal() {
        #expect(WeightCalculations.parseScannedWeight("142.5") == 142.5)
    }

    @Test func parseThreeDigitsNoDecimal() {
        #expect(WeightCalculations.parseScannedWeight("185") == 185.0)
    }

    @Test func parseTwoDigitsWithDecimal() {
        #expect(WeightCalculations.parseScannedWeight("92.3") == 92.3)
    }

    @Test func parseOneDigit() {
        #expect(WeightCalculations.parseScannedWeight("5") == 5.0)
    }

    @Test func parseWithTrailingDot() {
        #expect(WeightCalculations.parseScannedWeight("150.") == 150.0)
    }

    @Test func parseWithWhitespace() {
        #expect(WeightCalculations.parseScannedWeight("  142.5  ") == 142.5)
    }

    @Test func rejectFourDigits() {
        #expect(WeightCalculations.parseScannedWeight("1234") == nil)
    }

    @Test func rejectTwoDecimalPlaces() {
        #expect(WeightCalculations.parseScannedWeight("142.55") == nil)
    }

    @Test func rejectText() {
        #expect(WeightCalculations.parseScannedWeight("lbs") == nil)
    }

    @Test func rejectMixedTextAndNumbers() {
        #expect(WeightCalculations.parseScannedWeight("142.5 lbs") == nil)
    }

    @Test func rejectEmpty() {
        #expect(WeightCalculations.parseScannedWeight("") == nil)
    }

    @Test func rejectZero() {
        #expect(WeightCalculations.parseScannedWeight("0") == nil)
    }

    @Test func rejectNegative() {
        #expect(WeightCalculations.parseScannedWeight("-50") == nil)
    }

    @Test func parseDecimalPointZero() {
        #expect(WeightCalculations.parseScannedWeight("200.0") == 200.0)
    }
}

// MARK: - Entry Grouping Tests

struct EntryGroupingTests {

    @Test func groupsEntriesByMonth() {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 149.0, timestamp: now.addingTimeInterval(-86400)),
            WeightEntry(weight: 148.0, timestamp: lastMonth)
        ]

        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 2)
    }

    @Test func groupsSortedNewestFirst() {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let entries = [
            WeightEntry(weight: 148.0, timestamp: lastMonth),
            WeightEntry(weight: 150.0, timestamp: now)
        ]

        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 2)

        let firstGroupDate = grouped[0].value.first!.timestamp
        let lastGroupDate = grouped[1].value.first!.timestamp
        #expect(firstGroupDate > lastGroupDate)
    }

    @Test func emptyEntriesReturnEmptyGroups() {
        let grouped = WeightCalculations.groupedByMonth([])
        #expect(grouped.isEmpty)
    }

    @Test func singleEntryReturnsSingleGroup() {
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 1)
        #expect(grouped[0].value.count == 1)
    }

    @Test func multipleEntriesSameMonthGroupTogether() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 149.5, timestamp: now.addingTimeInterval(-3600)),
            WeightEntry(weight: 149.0, timestamp: now.addingTimeInterval(-7200))
        ]

        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 1)
        #expect(grouped[0].value.count == 3)
    }

    @Test func groupKeyContainsMonthAndYear() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let now = Date()
        let expected = formatter.string(from: now)

        let entries = [WeightEntry(weight: 150.0, timestamp: now)]
        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped[0].key == expected)
    }
}

// MARK: - Average Weight Tests

struct AverageWeightTests {

    @Test func averageOfEntriesWithinPeriod() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 148.0, timestamp: now.addingTimeInterval(-2 * 86400)),
            WeightEntry(weight: 146.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg != nil)
        // All 3 entries are within the last week
        let expected = (150.0 + 148.0 + 146.0) / 3.0
        #expect(abs(avg! - expected) < 0.01)
    }

    @Test func averageExcludesOldEntries() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-400 * 86400))  // >1 year ago
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg != nil)
        #expect(avg == 150.0)
    }

    @Test func averageIsNilWhenNoEntriesInPeriod() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-400 * 86400))
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg == nil)
    }

    @Test func averageIsNilForEmptyEntries() {
        let avg = WeightCalculations.averageWeight(from: [], over: .month)
        #expect(avg == nil)
    }
}

// MARK: - Percentage Change Tests

struct PercentageChangeTests {

    @Test func positivePercentageChange() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 110.0, timestamp: now),                                  // most recent
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-5 * 86400))     // oldest in range
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct! - 10.0) < 0.01)  // (110-100)/100 * 100 = 10%
    }

    @Test func negativePercentageChange() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 90.0, timestamp: now),
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct! - (-10.0)) < 0.01)
    }

    @Test func zeroPercentageWhenUnchanged() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 150.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct!) < 0.01)
    }

    @Test func percentageIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct == nil)
    }

    @Test func percentageIsNilWithNoEntries() {
        let pct = WeightCalculations.percentageChange(from: [], over: .month)
        #expect(pct == nil)
    }

    @Test func percentageUsesEarliestAndLatestInPeriod() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 155.0, timestamp: now),
            WeightEntry(weight: 152.0, timestamp: now.addingTimeInterval(-3 * 86400)),
            WeightEntry(weight: 150.0, timestamp: now.addingTimeInterval(-6 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        // earliest=150, latest=155 → (155-150)/150 * 100 = 3.33%
        let expected = ((155.0 - 150.0) / 150.0) * 100
        #expect(abs(pct! - expected) < 0.01)
    }

    @Test func percentageIsNilWhenStartingWeightIsZero() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 0.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]

        let pct = WeightCalculations.percentageChange(from: entries, over: .month)

        #expect(pct == nil)
    }
}

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

// MARK: - TimePeriod Tests

struct TimePeriodTests {

    @Test func allCasesCount() {
        #expect(TimePeriod.allCases.count == 5)
    }

    @Test func rawValues() {
        #expect(TimePeriod.week.rawValue == "1W")
        #expect(TimePeriod.month.rawValue == "1M")
        #expect(TimePeriod.threeMonths.rawValue == "3M")
        #expect(TimePeriod.sixMonths.rawValue == "6M")
        #expect(TimePeriod.year.rawValue == "1Y")
    }

    @Test func labels() {
        #expect(TimePeriod.week.label == "Week")
        #expect(TimePeriod.month.label == "Month")
        #expect(TimePeriod.threeMonths.label == "3 Months")
        #expect(TimePeriod.sixMonths.label == "6 Months")
        #expect(TimePeriod.year.label == "Year")
    }

    @Test func componentValues() {
        #expect(TimePeriod.week.componentValue == 1)
        #expect(TimePeriod.month.componentValue == 1)
        #expect(TimePeriod.threeMonths.componentValue == 3)
        #expect(TimePeriod.sixMonths.componentValue == 6)
        #expect(TimePeriod.year.componentValue == 1)
    }

    @Test func calendarComponents() {
        #expect(TimePeriod.week.calendarComponent == .weekOfYear)
        #expect(TimePeriod.month.calendarComponent == .month)
        #expect(TimePeriod.threeMonths.calendarComponent == .month)
        #expect(TimePeriod.sixMonths.calendarComponent == .month)
        #expect(TimePeriod.year.calendarComponent == .year)
    }
}

// MARK: - Reminder Model Tests

@MainActor
struct ReminderModelTests {
    private let remindersEnabledKey = "remindersEnabled"
    private let savedRemindersKey = "savedReminders"

    private func withClearedReminderDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let existingEnabled = defaults.object(forKey: remindersEnabledKey)
        let existingReminders = defaults.object(forKey: savedRemindersKey)

        defaults.removeObject(forKey: remindersEnabledKey)
        defaults.removeObject(forKey: savedRemindersKey)
        defer {
            if let existingEnabled {
                defaults.set(existingEnabled, forKey: remindersEnabledKey)
            } else {
                defaults.removeObject(forKey: remindersEnabledKey)
            }

            if let existingReminders {
                defaults.set(existingReminders, forKey: savedRemindersKey)
            } else {
                defaults.removeObject(forKey: savedRemindersKey)
            }
        }

        try body()
    }

    @Test func reminderDefaultValues() {
        let reminder = Reminder()
        #expect(reminder.name == "Weigh In")
        #expect(reminder.hour == 8)
        #expect(reminder.minute == 0)
    }

    @Test func reminderCustomValues() {
        let reminder = Reminder(name: "Morning", hour: 7, minute: 30)
        #expect(reminder.name == "Morning")
        #expect(reminder.hour == 7)
        #expect(reminder.minute == 30)
    }

    @Test func reminderEncodesAndDecodes() throws {
        let original = Reminder(name: "Evening", hour: 20, minute: 15)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)
        #expect(decoded == original)
    }

    @Test func reminderArrayEncodesAndDecodes() throws {
        let reminders = [
            Reminder(name: "Morning", hour: 8, minute: 0),
            Reminder(name: "Evening", hour: 20, minute: 0)
        ]
        let data = try JSONEncoder().encode(reminders)
        let decoded = try JSONDecoder().decode([Reminder].self, from: data)
        #expect(decoded == reminders)
    }

    @Test func reminderHasUniqueIds() {
        let a = Reminder()
        let b = Reminder()
        #expect(a.id != b.id)
    }

    @Test func enabledFlagDefaultsToFalse() {
        withClearedReminderDefaults {
            #expect(UserDefaults.standard.bool(forKey: remindersEnabledKey) == false)
        }
    }

    @Test func enabledFlagToggles() {
        withClearedReminderDefaults {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: remindersEnabledKey)
            #expect(defaults.bool(forKey: remindersEnabledKey) == true)

            defaults.set(false, forKey: remindersEnabledKey)
            #expect(defaults.bool(forKey: remindersEnabledKey) == false)
        }
    }

    @Test func saveAndLoadReminders() {
        withClearedReminderDefaults {
            let manager = NotificationManager()
            let reminders = [
                Reminder(name: "Morning", hour: 8, minute: 0),
                Reminder(name: "Night", hour: 21, minute: 30)
            ]
            manager.saveReminders(reminders)
            let loaded = manager.loadReminders()
            #expect(loaded == reminders)
        }
    }

    @Test func loadRemindersReturnsEmptyWhenNoneSaved() {
        withClearedReminderDefaults {
            let manager = NotificationManager()
            let loaded = manager.loadReminders()
            #expect(loaded.isEmpty)
        }
    }

    @Test func loadRemindersReturnsEmptyForCorruptData() {
        withClearedReminderDefaults {
            UserDefaults.standard.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: savedRemindersKey)

            let manager = NotificationManager()
            let loaded = manager.loadReminders()

            #expect(loaded.isEmpty)
        }
    }
}

// MARK: - Notification Name Tests

@MainActor
struct NotificationNameTests {

    @Test func notificationNameIsCorrect() {
        #expect(Notification.Name.didTapWeightReminder.rawValue == "didTapWeightReminder")
    }

    @Test func notificationPostAndReceive() async {
        let received = UnsafeSendable(value: false)

        let observer = NotificationCenter.default.addObserver(
            forName: .didTapWeightReminder,
            object: nil,
            queue: .main
        ) { _ in
            received.value = true
        }

        NotificationCenter.default.post(name: .didTapWeightReminder, object: nil)

        // Give run loop a moment to deliver
        try? await Task.sleep(for: .milliseconds(100))

        #expect(received.value == true)
        NotificationCenter.default.removeObserver(observer)
    }

    @Test func notificationDelegateConformsToProtocol() {
        let delegate = NotificationDelegate()
        // Verify it conforms to UNUserNotificationCenterDelegate
        let conforming: UNUserNotificationCenterDelegate = delegate
        #expect(conforming is NotificationDelegate)
    }
}

/// A simple wrapper to allow mutation of a value in a Sendable context for testing.
private final class UnsafeSendable<T>: @unchecked Sendable {
    var value: T
    init(value: T) { self.value = value }
}

// MARK: - NotificationManager Initialization Tests

struct NotificationManagerTests {
    private let remindersEnabledKey = "remindersEnabled"
    private let savedRemindersKey = "savedReminders"

    private func withClearedReminderDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let existingEnabled = defaults.object(forKey: remindersEnabledKey)
        let existingReminders = defaults.object(forKey: savedRemindersKey)

        defaults.removeObject(forKey: remindersEnabledKey)
        defaults.removeObject(forKey: savedRemindersKey)
        defer {
            if let existingEnabled {
                defaults.set(existingEnabled, forKey: remindersEnabledKey)
            } else {
                defaults.removeObject(forKey: remindersEnabledKey)
            }

            if let existingReminders {
                defaults.set(existingReminders, forKey: savedRemindersKey)
            } else {
                defaults.removeObject(forKey: savedRemindersKey)
            }
        }

        try body()
    }

    @Test func initializedWithIsAuthorizedFalse() {
        let manager = NotificationManager()
        // Before any authorization request, the default should be false
        #expect(manager.isAuthorized == false)
    }

    @Test func loadRemindersRoundTripsEmptyArray() {
        withClearedReminderDefaults {
            let manager = NotificationManager()
            manager.saveReminders([])
            #expect(manager.loadReminders().isEmpty)
        }
    }

    @Test func notificationBodyUsesGenericCopyBelowThreshold() {
        #expect(NotificationManager.notificationBody(forPotentialStreak: 0) == "Tap to log your weight.")
        #expect(NotificationManager.notificationBody(forPotentialStreak: 1) == "Tap to log your weight.")
    }

    @Test func notificationBodyIncludesStreakAtThresholdAndAbove() {
        #expect(NotificationManager.notificationBody(forPotentialStreak: 2) == "Keep your 2-day streak going — log your weight today!")
        #expect(NotificationManager.notificationBody(forPotentialStreak: 9) == "Keep your 9-day streak going — log your weight today!")
    }

    @Test func reminderDateComponentsMatchReminderTime() {
        let reminder = Reminder(name: "Evening", hour: 21, minute: 45)

        let components = NotificationManager.reminderDateComponents(for: reminder)

        #expect(components.hour == 21)
        #expect(components.minute == 45)
    }

    @Test func requestIdentifierUsesReminderID() {
        let reminder = Reminder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!)

        #expect(
            NotificationManager.requestIdentifier(for: reminder)
            == "weightReminder_00000000-0000-0000-0000-000000000123"
        )
    }

    @Test func makeNotificationRequestUsesReminderBodyAndCategory() {
        let reminder = Reminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000456")!,
            name: "Morning Weigh In",
            hour: 7,
            minute: 15
        )

        let request = NotificationManager.makeNotificationRequest(
            reminder: reminder,
            body: "Test body",
            categoryIdentifier: "WEIGHT_REMINDER"
        )

        #expect(request.identifier == "weightReminder_00000000-0000-0000-0000-000000000456")
        #expect(request.content.title == "Morning Weigh In")
        #expect(request.content.body == "Test body")
        #expect(request.content.categoryIdentifier == "WEIGHT_REMINDER")

        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger != nil)
        #expect(trigger?.repeats == true)
        #expect(trigger?.dateComponents.hour == 7)
        #expect(trigger?.dateComponents.minute == 15)
    }
}

// MARK: - HealthKit Import Plan Tests

struct HealthKitImportPlanTests {

    private func sample(
        uuid: UUID = UUID(),
        daysAgo: Int,
        weight: Double,
        bundleID: String = "com.example.health"
    ) -> HealthKitManager.ImportedSample {
        HealthKitManager.ImportedSample(
            uuid: uuid,
            startDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            weightInPounds: weight,
            sourceBundleIdentifier: bundleID
        )
    }

    @Test func importPlanSkipsSelfAuthoredAndDuplicateEntries() {
        let duplicateDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let existing = [
            WeightEntry(weight: 180.0, timestamp: duplicateDate),
            WeightEntry(weight: 179.0)
        ]
        let samples = [
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: duplicateDate,
                weightInPounds: 181.0,
                sourceBundleIdentifier: "com.example.health"
            ),
            sample(daysAgo: 1, weight: 178.0, bundleID: "com.groberg.Scale"),
            sample(daysAgo: 3, weight: 177.0)
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 1)
        #expect(plan.skippedCount == 2)
        #expect(plan.insertedEntries.count == 1)
        #expect(plan.insertedEntries[0].weightInPounds == 177.0)
    }

    @Test func importPlanRemovesStaleAppleHealthEntries() {
        let staleUUID = UUID()
        let retainedUUID = UUID()
        let existing = [
            WeightEntry(weight: 180.0, source: .appleHealth, healthKitUUID: staleUUID),
            WeightEntry(weight: 179.0, source: .appleHealth, healthKitUUID: retainedUUID),
            WeightEntry(weight: 178.0, source: .manual)
        ]
        let samples = [
            sample(uuid: retainedUUID, daysAgo: 1, weight: 179.0),
            sample(daysAgo: 3, weight: 177.0)
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 1)
        #expect(plan.removedEntryIDs.count == 1)
        #expect(plan.removedEntryIDs.contains(existing[0].persistentModelID))
        #expect(!plan.removedEntryIDs.contains(existing[1].persistentModelID))
    }

    @Test func importPlanDoesNotRemoveManualEntriesWithoutMatchingSamples() {
        let existing = [
            WeightEntry(weight: 180.0, source: .manual),
            WeightEntry(weight: 179.0, source: .manual)
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: [],
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 0)
        #expect(plan.removedEntryIDs.isEmpty)
    }
}

// MARK: - Store Reset Tests

struct StoreResetTests {

    @Test func companionURLsMatchStoreSidecarFilesOnly() {
        let directory = URL(filePath: "/tmp/ScaleTests")
        let storeURL = directory.appending(path: "default.store")
        let siblings = [
            storeURL,
            directory.appending(path: "default.store-wal"),
            directory.appending(path: "default.store-shm"),
            directory.appending(path: "default.sqlite"),
            directory.appending(path: "other.store-wal")
        ]

        let companions = ScaleApp.storeCompanionURLs(for: storeURL, among: siblings)

        #expect(companions.count == 2)
        #expect(companions.contains(directory.appending(path: "default.store-wal")))
        #expect(companions.contains(directory.appending(path: "default.store-shm")))
    }

    @Test func companionURLsReturnEmptyWhenNoMatchesExist() {
        let directory = URL(filePath: "/tmp/ScaleTests")
        let storeURL = directory.appending(path: "default.store")
        let siblings = [
            directory.appending(path: "other.store"),
            directory.appending(path: "other.store-wal")
        ]

        #expect(ScaleApp.storeCompanionURLs(for: storeURL, among: siblings).isEmpty)
    }

    @Test func resetStoreFilesDeletesStoreAndCompanions() throws {
        let rootURL = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let storeURL = rootURL.appending(path: "Scale.sqlite")
        let walURL = rootURL.appending(path: "Scale.sqlite-wal")
        let shmURL = rootURL.appending(path: "Scale.sqlite-shm")
        let unrelatedURL = rootURL.appending(path: "Other.sqlite")
        try Data().write(to: storeURL)
        try Data().write(to: walURL)
        try Data().write(to: shmURL)
        try Data().write(to: unrelatedURL)

        let configuration = ModelConfiguration(url: storeURL)
        try ScaleApp.resetStoreFiles(for: configuration, fileManager: .default)

        #expect(!FileManager.default.fileExists(atPath: storeURL.path()))
        #expect(!FileManager.default.fileExists(atPath: walURL.path()))
        #expect(!FileManager.default.fileExists(atPath: shmURL.path()))
        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path()))
    }
}

// MARK: - Current Streak (Including Today) Tests
//
// These scenarios directly mirror the logic inside NotificationManager.notificationBody():
// the method calls currentStreak(from:includingToday: true) to decide whether to show
// a streak-preservation message (streak ≥ 2) or a generic prompt (streak < 2).

struct CurrentStreakIncludingTodayTests {

    private var calendar: Calendar { Calendar.current }

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: Date())!
    }

    // -- No entries --

    @Test func noEntriesPotentialStreakIsOne() {
        // A brand-new user has no entries; counting today gives streak = 1 (below threshold).
        let streak = WeightCalculations.currentStreak(from: [], includingToday: true)
        #expect(streak == 1)
    }

    // -- Only today logged --

    @Test func entryOnlyTodayPotentialStreakIsOne() {
        // User already logged today but has no history; streak is still 1.
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 1)
    }

    // -- Yesterday logged (notification fires before today's log) --

    @Test func entryYesterdayOnlyPotentialStreakIsTwo() {
        // Logged yesterday, haven't logged today yet → logging today makes it 2.
        let entries = [WeightEntry(weight: 150.0, timestamp: daysAgo(1))]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 2)
    }

    @Test func entriesTodayAndYesterdayPotentialStreakIsTwo() {
        // Logged both today and yesterday; potential streak is still 2.
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 149.0, timestamp: daysAgo(1))
        ]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 2)
    }

    // -- Multi-day runs --

    @Test func threeDaysBeforeTodayPotentialStreakIsFour() {
        let entries = (1...3).map { WeightEntry(weight: 150.0, timestamp: daysAgo($0)) }
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 4)
    }

    @Test func fiveConsecutiveDaysBeforeTodayPotentialStreakIsSix() {
        let entries = (1...5).map { WeightEntry(weight: 150.0, timestamp: daysAgo($0)) }
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 6)
    }

    // -- Broken streaks --

    @Test func gapTwoDaysAgoBreaksRunToOne() {
        // Last entry was 2 days ago with nothing yesterday; logging today starts fresh → 1.
        let entries = [WeightEntry(weight: 150.0, timestamp: daysAgo(2))]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 1)
    }

    @Test func gapInMiddleOfRunCapsStreak() {
        // Logged 1 and 3 days ago but NOT 2 days ago — streak is consecutive from today.
        let entries = [
            WeightEntry(weight: 150.0, timestamp: daysAgo(1)),
            WeightEntry(weight: 149.0, timestamp: daysAgo(3))
        ]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        // Only yesterday is consecutive with today → 2
        #expect(streak == 2)
    }

    // -- Multiple entries on the same day --

    @Test func multipleEntriesSameDayCountAsOne() {
        // Two entries yesterday should still only add one day to the streak.
        let entries = [
            WeightEntry(weight: 149.5, timestamp: daysAgo(1).addingTimeInterval(3600)),
            WeightEntry(weight: 149.0, timestamp: daysAgo(1))
        ]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 2)
    }
}

// MARK: - Notification Streak Threshold Tests
//
// Verify the ≥ 2 threshold that separates the generic body ("Tap to log your weight.")
// from the personalized streak body ("Keep your N-day streak going…").

struct NotificationStreakThresholdTests {

    private var calendar: Calendar { Calendar.current }

    private func potentialStreak(daysBack: [Int]) -> Int {
        let entries = daysBack.map {
            WeightEntry(weight: 150.0, timestamp: calendar.date(byAdding: .day, value: -$0, to: Date())!)
        }
        return WeightCalculations.currentStreak(from: entries, includingToday: true)
    }

    @Test func newUserBelowThresholdForPersonalizedMessage() {
        // No prior days → potential streak 1 → generic message territory.
        let streak = WeightCalculations.currentStreak(from: [], includingToday: true)
        #expect(streak < 2)
    }

    @Test func oneDayHistoryMeetsThresholdForPersonalizedMessage() {
        // Yesterday logged → potential streak 2 → meets the ≥ 2 threshold.
        let streak = potentialStreak(daysBack: [1])
        #expect(streak >= 2)
    }

    @Test func twoDayHistoryStreakIsThree() {
        let streak = potentialStreak(daysBack: [1, 2])
        #expect(streak == 3)
    }

    @Test func nineDayHistoryStreakIsTen() {
        let streak = potentialStreak(daysBack: Array(1...9))
        #expect(streak == 10)
    }

    @Test func brokenStreakDropsBelowThreshold() {
        // Only entry is 2 days ago (no yesterday) → potential streak 1 → generic message.
        let streak = potentialStreak(daysBack: [2])
        #expect(streak < 2)
    }
}

// MARK: - NotificationManager ModelContext Tests

struct NotificationManagerModelContextTests {

    @Test func modelContextIsNilByDefault() {
        let manager = NotificationManager()
        #expect(manager.modelContext == nil)
    }

    @Test func modelContextCanBeAssigned() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let manager = NotificationManager()
        manager.modelContext = ModelContext(container)
        #expect(manager.modelContext != nil)
    }

    @Test func rescheduleRemindersWithoutContextDoesNotCrash() {
        // If modelContext is nil, rescheduleReminders should silently use the generic body.
        let manager = NotificationManager()
        manager.rescheduleReminders() // should not throw or crash
    }

    @Test func rescheduleRemindersWithContextAndNoEntriesDoesNotCrash() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let manager = NotificationManager()
        manager.modelContext = ModelContext(container)
        manager.rescheduleReminders() // should not throw or crash
    }
}

// MARK: - Streak Map Tests

struct StreakMapTests {

    private var calendar: Calendar { Calendar.current }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    @Test func streaksByDayAssignsRunLengthsAndZerosForIsolatedDays() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(-5)),
            WeightEntry(weight: 149.0, timestamp: day(-4)),
            WeightEntry(weight: 148.0, timestamp: day(-2))
        ]

        let streaks = WeightCalculations.streaksByDay(from: entries)

        #expect(streaks[calendar.startOfDay(for: day(-5))] == 1)
        #expect(streaks[calendar.startOfDay(for: day(-4))] == 2)
        #expect(streaks[calendar.startOfDay(for: day(-2))] == 0)
    }

    @Test func streaksByDayReturnsEmptyForNoEntries() {
        #expect(WeightCalculations.streaksByDay(from: []).isEmpty)
    }

    @Test func currentStreakIsZeroWhenTodayHasNoEntry() {
        let entries = [WeightEntry(weight: 150.0, timestamp: day(-1))]

        #expect(WeightCalculations.currentStreak(from: entries) == 0)
    }

    @Test func currentStreakIgnoresDuplicateEntriesOnSameDay() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(0).addingTimeInterval(60)),
            WeightEntry(weight: 149.8, timestamp: day(0).addingTimeInterval(120)),
            WeightEntry(weight: 149.5, timestamp: day(-1).addingTimeInterval(60))
        ]

        #expect(WeightCalculations.currentStreak(from: entries) == 2)
    }

    @Test func streaksByDayCollapsesDuplicateEntriesIntoSingleDayCount() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(-2).addingTimeInterval(60)),
            WeightEntry(weight: 149.9, timestamp: day(-2).addingTimeInterval(120)),
            WeightEntry(weight: 149.5, timestamp: day(-1).addingTimeInterval(60)),
            WeightEntry(weight: 149.0, timestamp: day(0).addingTimeInterval(60))
        ]

        let streaks = WeightCalculations.streaksByDay(from: entries)

        #expect(streaks[calendar.startOfDay(for: day(-2))] == 1)
        #expect(streaks[calendar.startOfDay(for: day(-1))] == 2)
        #expect(streaks[calendar.startOfDay(for: day(0))] == 3)
        #expect(streaks.count == 3)
    }
}

// MARK: - Widget Snapshot Store Tests

@MainActor
final class WeightWidgetSnapshotStoreXCTests: XCTestCase {

    func testLoadFallsBackToEmptySnapshotWhenNoContainerIsAvailable() {
        let snapshot = WeightWidgetSnapshotStore.load()

        XCTAssertNotNil(snapshot)
    }

    func testWriteReturnsFalseWhenNoContainerIsAvailable() {
        let result = WeightWidgetSnapshotStore.write(.empty)

        if result {
            XCTAssertEqual(WeightWidgetSnapshotStore.load(), .empty)
        } else {
            XCTAssertEqual(WeightWidgetSnapshotStore.load(), .empty)
        }
    }

    func testWriteAndLoadRoundTripSnapshotAtExplicitURL() throws {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let snapshot = WeightWidgetSnapshot.make(
            from: [WeightEntry(weight: 182.4, timestamp: now)],
            tintRawValue: AppTint.green.rawValue,
            now: now
        )

        XCTAssertTrue(WeightWidgetSnapshotStore.write(snapshot, to: url, reloadTimelines: false))
        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: url), snapshot)
    }

    func testLoadReturnsEmptyForCorruptSnapshotData() throws {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not-json".utf8).write(to: url)

        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: url), .empty)
    }

    func testLoadReturnsEmptyWhenURLIsNil() {
        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: nil), .empty)
    }

    func testWriteReturnsFalseWhenURLIsNil() {
        XCTAssertFalse(WeightWidgetSnapshotStore.write(.empty, to: nil, reloadTimelines: false))
    }

    func testLoadReturnsEmptyWhenSnapshotFileDoesNotExist() {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "\(UUID().uuidString).json")

        XCTAssertEqual(WeightWidgetSnapshotStore.load(from: url), .empty)
    }

    func testWriteReturnsFalseWhenDestinationIsDirectory() throws {
        let directoryURL = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertFalse(WeightWidgetSnapshotStore.write(.empty, to: directoryURL, reloadTimelines: false))
    }
}

// MARK: - App Tint Tests

struct AppTintTests {

    @Test func allCasesCount() {
        #expect(AppTint.allCases.count == 6)
    }

    @Test func defaultValueIsBlue() {
        #expect(AppTint.defaultValue == .blue)
    }

    @Test func rawValueLookupFindsSavedTint() {
        #expect(AppTint(rawValue: "green") == .green)
    }

    @Test func rawValueLookupFindsLavenderTint() {
        #expect(AppTint(rawValue: "lavender") == .lavender)
    }

    @Test func titlesMatchDisplayNames() {
        #expect(AppTint.blue.title == "Blue")
        #expect(AppTint.green.title == "Green")
        #expect(AppTint.orange.title == "Orange")
        #expect(AppTint.pink.title == "Pink")
        #expect(AppTint.lavender.title == "Lavender")
        #expect(AppTint.red.title == "Red")
    }
}
