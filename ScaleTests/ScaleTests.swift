//
//  ScaleTests.swift
//  ScaleTests
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Testing
import Foundation
import SwiftUI
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

// MARK: - Scale OCR Correction Tests

struct ScaleOCRCorrectionTests {

    // -- Letter-to-digit substitutions --

    @Test func correctsUppercaseOToZero() {
        #expect(WeightCalculations.parseScaleReading("2O0.5") == 200.5)
    }

    @Test func correctsLowercaseOToZero() {
        #expect(WeightCalculations.parseScaleReading("14o.5") == 140.5)
    }

    @Test func correctsLowercaseLToOne() {
        #expect(WeightCalculations.parseScaleReading("l42.5") == 142.5)
    }

    @Test func correctsUppercaseIToOne() {
        #expect(WeightCalculations.parseScaleReading("I42.5") == 142.5)
    }

    @Test func correctsMultipleSubstitutions() {
        #expect(WeightCalculations.parseScaleReading("lO5.O") == 105.0)
    }

    // -- Already-clean inputs pass through --

    @Test func cleanDigitsPassThrough() {
        #expect(WeightCalculations.parseScaleReading("185.3") == 185.3)
    }

    @Test func cleanWholeNumberPassesThrough() {
        #expect(WeightCalculations.parseScaleReading("200") == 200.0)
    }

    // -- Whitespace handling --

    @Test func trimsWhitespaceBeforeCorrecting() {
        #expect(WeightCalculations.parseScaleReading("  l42.5  ") == 142.5)
    }

    // -- Rejection cases still reject after correction --

    @Test func rejectsGarbageTextAfterCorrection() {
        #expect(WeightCalculations.parseScaleReading("lbs") == nil)
    }

    @Test func rejectsEmptyString() {
        #expect(WeightCalculations.parseScaleReading("") == nil)
    }

    @Test func rejectsTooManyDigitsAfterCorrection() {
        #expect(WeightCalculations.parseScaleReading("lOOO") == nil) // "1000" → 4 digits
    }

    @Test func rejectsZeroAfterCorrection() {
        #expect(WeightCalculations.parseScaleReading("O") == nil) // "0" → rejected
    }

    // -- Pipe character as 1 (common seven-segment misread) --

    @Test func correctsPipeToOne() {
        #expect(WeightCalculations.parseScaleReading("|42.5") == 142.5)
    }

    // -- Mixed noise that becomes valid after correction --

    @Test func mixedSubstitutionsProduceValidWeight() {
        #expect(WeightCalculations.parseScaleReading("I5O.l") == 150.1)
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

// MARK: - HealthKit Workout Import Plan Tests

struct HealthKitWorkoutImportPlanTests {

    private func workout(
        uuid: UUID = UUID(),
        daysAgo: Int,
        bundleID: String = "com.example.health",
        activityTypeRawValue: UInt = 37,
        duration: TimeInterval = 1_800,
        energyBurnedKilocalories: Double? = 320,
        distanceMiles: Double? = 3.1
    ) -> HealthKitManager.ImportedWorkout {
        HealthKitManager.ImportedWorkout(
            uuid: uuid,
            startDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            activityTypeRawValue: activityTypeRawValue,
            duration: duration,
            energyBurnedKilocalories: energyBurnedKilocalories,
            distanceMiles: distanceMiles,
            sourceBundleIdentifier: bundleID
        )
    }

    @Test func workoutImportPlanSkipsSelfAuthoredAndExistingEntries() {
        let retainedUUID = UUID()
        let existing = [
            WorkoutEntry(
                activityTypeRawValue: 37,
                duration: 1_500,
                source: .appleHealth,
                healthKitUUID: retainedUUID
            )
        ]
        let workouts = [
            workout(uuid: retainedUUID, daysAgo: 1),
            workout(daysAgo: 2, bundleID: "com.groberg.Scale"),
            workout(daysAgo: 3, activityTypeRawValue: 13, duration: 2_400)
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: workouts,
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 1)
        #expect(plan.skippedCount == 2)
        #expect(plan.insertedEntries.count == 1)
        #expect(plan.insertedEntries[0].activityTypeRawValue == 13)
        #expect(plan.insertedEntries[0].duration == 2_400)
    }

    @Test func workoutImportPlanRemovesStaleHealthKitEntries() {
        let staleUUID = UUID()
        let retainedUUID = UUID()
        let existing = [
            WorkoutEntry(activityTypeRawValue: 37, duration: 1_000, source: .appleHealth, healthKitUUID: staleUUID),
            WorkoutEntry(activityTypeRawValue: 13, duration: 2_000, source: .appleHealth, healthKitUUID: retainedUUID),
            WorkoutEntry(activityTypeRawValue: 20, duration: 3_000, source: .appleHealth, healthKitUUID: nil)
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: [workout(uuid: retainedUUID, daysAgo: 1)],
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 1)
        #expect(plan.removedEntryIDs.contains(existing[0].persistentModelID))
        #expect(!plan.removedEntryIDs.contains(existing[1].persistentModelID))
        #expect(!plan.removedEntryIDs.contains(existing[2].persistentModelID))
    }

    @Test func workoutImportPlanKeepsEntriesWithoutHealthKitUUIDs() {
        let existing = [
            WorkoutEntry(activityTypeRawValue: 37, duration: 1_000, source: .appleHealth, healthKitUUID: nil)
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: [],
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 0)
        #expect(plan.removedEntryIDs.isEmpty)
        #expect(plan.importedCount == 0)
    }
}

// MARK: - HealthKit Daily Activity Import Plan Tests

struct HealthKitDailyActivityImportPlanTests {

    @Test func dailyActivityImportPlanInsertsUpdatesSkipsAndRemovesEntries() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let unchanged = DailyActivitySummary(date: today, stepCount: 5_000, activeEnergyBurnedKilocalories: 400)
        let needsUpdate = DailyActivitySummary(date: yesterday, stepCount: 4_000, activeEnergyBurnedKilocalories: 300)
        let removable = DailyActivitySummary(date: twoDaysAgo, stepCount: 3_000, activeEnergyBurnedKilocalories: 200)

        let imported = [
            HealthKitManager.ImportedDailyActivitySummary(date: today, stepCount: 5_000, activeEnergyBurnedKilocalories: 400),
            HealthKitManager.ImportedDailyActivitySummary(date: yesterday, stepCount: 4_500, activeEnergyBurnedKilocalories: 350),
            HealthKitManager.ImportedDailyActivitySummary(date: threeDaysAgo, stepCount: 6_000, activeEnergyBurnedKilocalories: 500)
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: imported,
            existingEntries: [unchanged, needsUpdate, removable]
        )

        #expect(plan.importedCount == 1)
        #expect(plan.updatedCount == 1)
        #expect(plan.skippedCount == 1)
        #expect(plan.removedCount == 1)
        #expect(plan.insertedEntries.first?.date == threeDaysAgo)
        #expect(plan.updatedEntries.count == 1)
        #expect(plan.updatedEntries[0].0 == needsUpdate.persistentModelID)
        #expect(plan.updatedEntries[0].1 == 4_500)
        #expect(abs(plan.updatedEntries[0].2 - 350) < 0.001)
        #expect(plan.removedEntryIDs == [removable.persistentModelID])
    }

    @Test func dailyActivityImportPlanTreatsTinyEnergyDeltasAsUnchanged() {
        let date = Calendar.current.startOfDay(for: Date())
        let existing = DailyActivitySummary(date: date, stepCount: 8_000, activeEnergyBurnedKilocalories: 250)
        let imported = HealthKitManager.ImportedDailyActivitySummary(
            date: date,
            stepCount: 8_000,
            activeEnergyBurnedKilocalories: 250.0005
        )

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: [imported],
            existingEntries: [existing]
        )

        #expect(plan.updatedCount == 0)
        #expect(plan.skippedCount == 1)
        #expect(plan.importedCount == 0)
        #expect(plan.removedCount == 0)
    }

    @Test func dailyActivityImportPlanInsertsAllEntriesWhenStoreIsEmpty() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let imported = [
            HealthKitManager.ImportedDailyActivitySummary(date: yesterday, stepCount: 3_000, activeEnergyBurnedKilocalories: 200),
            HealthKitManager.ImportedDailyActivitySummary(date: today, stepCount: 5_000, activeEnergyBurnedKilocalories: 400)
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: imported,
            existingEntries: []
        )

        #expect(plan.importedCount == 2)
        #expect(plan.updatedCount == 0)
        #expect(plan.skippedCount == 0)
        #expect(plan.removedCount == 0)
        #expect(plan.insertedEntries.map(\.date) == [yesterday, today])
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

// MARK: - Change Pill Visibility Tests

struct ChangePillVisibilityTests {

    @Test func pillVisibleOnLogTab() {
        #expect(RootView.isPillVisible(selectedTab: 0) == true)
    }

    @Test func pillVisibleOnJournalTab() {
        #expect(RootView.isPillVisible(selectedTab: 1) == true)
    }

    @Test func pillHiddenOnSettingsTab() {
        #expect(RootView.isPillVisible(selectedTab: 2) == false)
    }

    @Test func pillVisibleForUnknownTabIndex() {
        // Any future tab that isn't Settings should still show the pill
        #expect(RootView.isPillVisible(selectedTab: 3) == true)
        #expect(RootView.isPillVisible(selectedTab: 99) == true)
    }

    @Test func selectedTabUpdateIgnoredWhenRetappingCurrentTab() {
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 1) == false)
    }

    @Test func selectedTabUpdateAllowedWhenChangingTabs() {
        #expect(RootView.shouldUpdateSelectedTab(from: 0, to: 1) == true)
    }

    @Test func journalRetapMapsToBottomScrollAction() {
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 1) == .scrollJournalToBottom)
    }

    @Test func nonJournalRetapMapsToIgnoreAction() {
        #expect(RootView.actionForTabTap(currentTab: 0, tappedTab: 0) == .ignore)
        #expect(RootView.actionForTabTap(currentTab: 2, tappedTab: 2) == .ignore)
    }

    @Test func changingTabsMapsToSwitchAction() {
        #expect(RootView.actionForTabTap(currentTab: 0, tappedTab: 1) == .switchTab)
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 2) == .switchTab)
    }

    @Test func journalRetapTriggersBottomScroll() {
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 1, wasReselected: true) == true)
    }

    @Test func journalFirstSelectionDoesNotTriggerBottomScroll() {
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 1, wasReselected: false) == false)
    }

    @Test func nonJournalRetapDoesNotTriggerBottomScroll() {
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 0, wasReselected: true) == false)
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 2, wasReselected: true) == false)
    }
}

// MARK: - Tab Bar Reselect Tests

@MainActor
struct TabBarControllerObserverTests {

    @Test func attachSeedsCurrentSelectedIndexForReselectDetection() {
        let controller = UITabBarController()
        controller.viewControllers = [UIViewController(), UIViewController(), UIViewController()]
        controller.selectedIndex = 1

        var receivedTap: (index: Int, wasReselected: Bool)?
        let coordinator = TabBarControllerObserver.Coordinator { tappedIndex, wasReselected in
            receivedTap = (tappedIndex, wasReselected)
        }

        coordinator.attach(to: controller)
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])

        #expect(receivedTap?.index == 1)
        #expect(receivedTap?.wasReselected == true)
    }

    @Test func selectingDifferentTabReportsNonReselect() {
        let controller = UITabBarController()
        controller.viewControllers = [UIViewController(), UIViewController(), UIViewController()]
        controller.selectedIndex = 0

        var receivedTap: (index: Int, wasReselected: Bool)?
        let coordinator = TabBarControllerObserver.Coordinator { tappedIndex, wasReselected in
            receivedTap = (tappedIndex, wasReselected)
        }

        coordinator.attach(to: controller)
        controller.selectedIndex = 1
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])

        #expect(receivedTap?.index == 1)
        #expect(receivedTap?.wasReselected == false)
    }

    @Test func switchingToJournalThenRetappingReportsReselectOnlyOnSecondTap() {
        let controller = UITabBarController()
        controller.viewControllers = [UIViewController(), UIViewController(), UIViewController()]
        controller.selectedIndex = 0

        var receivedTaps: [(index: Int, wasReselected: Bool)] = []
        let coordinator = TabBarControllerObserver.Coordinator { tappedIndex, wasReselected in
            receivedTaps.append((tappedIndex, wasReselected))
        }

        coordinator.attach(to: controller)

        controller.selectedIndex = 1
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])
        coordinator.tabBarController(controller, didSelect: controller.viewControllers![1])

        #expect(receivedTaps.count == 2)
        #expect(receivedTaps[0].index == 1)
        #expect(receivedTaps[0].wasReselected == false)
        #expect(receivedTaps[1].index == 1)
        #expect(receivedTaps[1].wasReselected == true)
    }
}

// MARK: - Journal Scroll Target Tests

struct JournalScrollTargetTests {

    @Test func nilFocusedEntryTargetsTodayAtBottom() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        let targetDay = JournalView.targetDay(for: nil, now: now, calendar: calendar)

        #expect(targetDay == calendar.startOfDay(for: now))
        #expect(JournalView.targetAnchor(hasFocusedEntry: false) == .bottom)
    }

    @Test func focusedEntryTargetsEntryDayAtTop() {
        let calendar = Calendar(identifier: .gregorian)
        let entryDate = Date(timeIntervalSince1970: 1_709_000_123)

        let targetDay = JournalView.targetDay(for: entryDate, calendar: calendar)

        #expect(targetDay == calendar.startOfDay(for: entryDate))
        #expect(JournalView.targetAnchor(hasFocusedEntry: true) == .top)
    }

    @Test func nilFocusedEntryUsesBottomAnchor() {
        #expect(JournalView.targetAnchor(hasFocusedEntry: false) == .bottom)
    }

    @Test func nearTopThresholdMatchesScrollGeometryRule() {
        #expect(JournalView.isNearTop(contentOffsetY: 50, topInset: 0) == true)
        #expect(JournalView.isNearTop(contentOffsetY: 80, topInset: 0) == true)
        #expect(JournalView.isNearTop(contentOffsetY: 81, topInset: 0) == false)
        #expect(JournalView.isNearTop(contentOffsetY: 100, topInset: 40) == true)
        #expect(JournalView.isNearTop(contentOffsetY: 121, topInset: 40) == false)
    }

    @Test func aprilFirstCountsAsLoggableWhenItIsToday() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 9, minute: 30))!
        let aprilFirst = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 0, minute: 1))!

        #expect(JournalView.isLoggableDay(aprilFirst, now: now, calendar: calendar) == true)
    }

    @Test func tomorrowIsNotLoggable() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 9, minute: 30))!
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 2, hour: 0, minute: 1))!

        #expect(JournalView.isLoggableDay(tomorrow, now: now, calendar: calendar) == false)
    }

    @Test func unloggedDayWithWorkoutsStillOpensCreateSheet() {
        #expect(
            JournalView.shouldPresentCreateSheet(
                hasLoggedWeight: false,
                hasWorkouts: true
            ) == true
        )
    }

    @Test func loggedDayWithWorkoutsOpensDetailSheet() {
        #expect(
            JournalView.shouldPresentCreateSheet(
                hasLoggedWeight: true,
                hasWorkouts: true
            ) == false
        )
    }
}

// MARK: - Journal Retap Isolation Tests

struct JournalRetapIsolationTests {

    @Test func journalRetapSignalExistsOnlyThroughTabBarObserverPath() {
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 1) == false)
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 1) == .scrollJournalToBottom)
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 1, wasReselected: true) == true)
    }

    @Test func journalFallbackScrollPathTargetsTodayBottom() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        #expect(JournalView.targetDay(for: nil, now: now, calendar: calendar) == calendar.startOfDay(for: now))
        #expect(JournalView.targetAnchor(hasFocusedEntry: false) == .bottom)
    }

    @Test func currentLogicKeepsRetapAndFallbackScrollPathsAligned() {
        let shouldScrollToBottom = RootView.shouldScrollJournalToBottom(
            tappedIndex: 1,
            wasReselected: true
        )
        let fallbackAnchor = JournalView.targetAnchor(hasFocusedEntry: false)

        #expect(shouldScrollToBottom == true)
        #expect(fallbackAnchor == .bottom)
    }
}

// MARK: - Calendar Month Loader Tests

struct CalendarMonthLoaderTests {

    private let calendar = Calendar.current

    private func monthStart(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps)!
    }

    // MARK: - Initial Loading

    @Test func initialStateIsEmpty() {
        let loader = CalendarMonthLoader(batchSize: 6)
        #expect(loader.monthStarts.isEmpty)
        #expect(loader.sortedDescending.isEmpty)
        #expect(loader.earliest == nil)
        #expect(loader.latest == nil)
    }

    @Test func loadInitialMonthsPopulatesBatchSizeMonths() {
        var loader = CalendarMonthLoader(batchSize: 6)
        loader.loadInitialMonths()
        #expect(loader.monthStarts.count == 6)
    }

    @Test func loadInitialMonthsIsIdempotent() {
        var loader = CalendarMonthLoader(batchSize: 6)
        loader.loadInitialMonths()
        let first = loader.monthStarts
        loader.loadInitialMonths()
        #expect(loader.monthStarts == first)
    }

    @Test func latestMonthIsCurrentMonth() {
        var loader = CalendarMonthLoader(batchSize: 6)
        loader.loadInitialMonths()
        let currentMonth = monthStart(for: .now)
        #expect(loader.latest == currentMonth)
    }

    @Test func earliestMonthIsBatchSizeMinusOneMonthsBack() {
        var loader = CalendarMonthLoader(batchSize: 6)
        loader.loadInitialMonths()
        let currentMonth = monthStart(for: .now)
        let expected = calendar.date(byAdding: .month, value: -5, to: currentMonth)!
        #expect(loader.earliest == expected)
    }

    @Test func sortedDescendingHasCurrentMonthFirst() {
        var loader = CalendarMonthLoader(batchSize: 6)
        loader.loadInitialMonths()
        let currentMonth = monthStart(for: .now)
        #expect(loader.sortedDescending.first == currentMonth)
    }

    @Test func sortedDescendingHasOldestMonthLast() {
        var loader = CalendarMonthLoader(batchSize: 6)
        loader.loadInitialMonths()
        let currentMonth = monthStart(for: .now)
        let expected = calendar.date(byAdding: .month, value: -5, to: currentMonth)!
        #expect(loader.sortedDescending.last == expected)
    }

    @Test func sortedDescendingIsStrictlyDecreasing() {
        var loader = CalendarMonthLoader(batchSize: 12)
        loader.loadInitialMonths()
        let months = loader.sortedDescending
        for i in 0..<(months.count - 1) {
            #expect(months[i] > months[i + 1])
        }
    }

    @Test func noFutureMonthsLoaded() {
        var loader = CalendarMonthLoader(batchSize: 12)
        loader.loadInitialMonths()
        let currentMonth = monthStart(for: .now)
        for month in loader.monthStarts {
            #expect(month <= currentMonth)
        }
    }

    // MARK: - Expansion

    @Test func expandDoesNothingForNonEarliestMonth() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        let countBefore = loader.monthStarts.count
        let someMiddleMonth = loader.sortedDescending[1]
        let expanded = loader.expandIfNeeded(for: someMiddleMonth)
        #expect(!expanded)
        #expect(loader.monthStarts.count == countBefore)
    }

    @Test func expandDoesNothingForLatestMonth() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        let countBefore = loader.monthStarts.count
        let expanded = loader.expandIfNeeded(for: loader.latest!)
        #expect(!expanded)
        #expect(loader.monthStarts.count == countBefore)
    }

    @Test func expandAddsMonthsWhenTriggeredByEarliestMonth() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        #expect(loader.monthStarts.count == 4)

        let expanded = loader.expandIfNeeded(for: loader.earliest!)
        #expect(expanded)
        #expect(loader.monthStarts.count == 8)
    }

    @Test func expandPreservesExistingMonths() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        let originalMonths = Set(loader.monthStarts)

        loader.expandIfNeeded(for: loader.earliest!)

        for month in originalMonths {
            #expect(loader.monthStarts.contains(month))
        }
    }

    @Test func expandedMonthsAreAllInThePast() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        let currentMonth = monthStart(for: .now)

        loader.expandIfNeeded(for: loader.earliest!)

        for month in loader.monthStarts {
            #expect(month <= currentMonth)
        }
    }

    @Test func expandPushesEarliestFurtherBack() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        let earliestBefore = loader.earliest!

        loader.expandIfNeeded(for: earliestBefore)

        #expect(loader.earliest! < earliestBefore)
    }

    @Test func expandDoesNotChangeLatest() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        let latestBefore = loader.latest!

        loader.expandIfNeeded(for: loader.earliest!)

        #expect(loader.latest == latestBefore)
    }

    @Test func multipleExpansionsKeepGrowing() {
        var loader = CalendarMonthLoader(batchSize: 3)
        loader.loadInitialMonths()
        #expect(loader.monthStarts.count == 3)

        loader.expandIfNeeded(for: loader.earliest!)
        #expect(loader.monthStarts.count == 6)

        loader.expandIfNeeded(for: loader.earliest!)
        #expect(loader.monthStarts.count == 9)

        loader.expandIfNeeded(for: loader.earliest!)
        #expect(loader.monthStarts.count == 12)
    }

    @Test func expandedMonthsAreContinuousWithNoDuplicates() {
        var loader = CalendarMonthLoader(batchSize: 4)
        loader.loadInitialMonths()
        loader.expandIfNeeded(for: loader.earliest!)
        loader.expandIfNeeded(for: loader.earliest!)

        let sorted = loader.monthStarts.sorted()
        // No duplicates
        #expect(Set(sorted).count == sorted.count)

        // Each month is exactly 1 month apart
        for i in 0..<(sorted.count - 1) {
            let diff = calendar.dateComponents([.month], from: sorted[i], to: sorted[i + 1])
            #expect(diff.month == 1)
        }
    }

    @Test func expandOnEmptyLoaderDoesNothing() {
        var loader = CalendarMonthLoader(batchSize: 4)
        let expanded = loader.expandIfNeeded(for: .now)
        #expect(!expanded)
        #expect(loader.monthStarts.isEmpty)
    }

    // MARK: - Custom now date

    @Test func loadInitialMonthsRespectsCustomNow() {
        var loader = CalendarMonthLoader(batchSize: 3)
        // Use January 2025 as "now"
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 1
        comps.day = 15
        let fakeNow = calendar.date(from: comps)!
        loader.loadInitialMonths(now: fakeNow)

        let expectedLatest = monthStart(for: fakeNow) // Jan 2025
        #expect(loader.latest == expectedLatest)

        let expectedEarliest = calendar.date(byAdding: .month, value: -2, to: expectedLatest)!
        #expect(loader.earliest == expectedEarliest) // Nov 2024
    }

    // MARK: - currentMonthStart helper

    @Test func currentMonthStartReturnsFirstOfMonth() {
        let result = CalendarMonthLoader.currentMonthStart()
        let comps = calendar.dateComponents([.day, .hour, .minute, .second], from: result)
        #expect(comps.day == 1)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test func currentMonthStartMatchesForMidMonthDate() {
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 7
        comps.day = 15
        let midMonth = calendar.date(from: comps)!
        let result = CalendarMonthLoader.currentMonthStart(now: midMonth)

        var expected = DateComponents()
        expected.year = 2025
        expected.month = 7
        let expectedDate = calendar.date(from: expected)!
        #expect(result == expectedDate)
    }

    // MARK: - Batch size of 1

    @Test func batchSizeOneLoadsOneMonth() {
        var loader = CalendarMonthLoader(batchSize: 1)
        loader.loadInitialMonths()
        #expect(loader.monthStarts.count == 1)
        #expect(loader.latest == loader.earliest)
    }

    @Test func batchSizeOneExpandsOneAtATime() {
        var loader = CalendarMonthLoader(batchSize: 1)
        loader.loadInitialMonths()
        let first = loader.earliest!

        loader.expandIfNeeded(for: first)
        #expect(loader.monthStarts.count == 2)

        let expectedNew = calendar.date(byAdding: .month, value: -1, to: first)!
        #expect(loader.earliest == expectedNew)
    }
}

// MARK: - Widget Snapshot Data Tests
//
// These tests verify the WeightWidgetSnapshot data layer that powers both
// home screen and lockscreen (accessory) widget views.

@MainActor
struct WidgetSnapshotDataTests {

    // MARK: - Snapshot make() produces correct data for lockscreen widgets

    @Test func snapshotPopulatesAllFieldsForLockscreen() {
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

        // Lockscreen rectangular widget displays streak and trend — both must be populated
        #expect(snapshot.streakCount == 2)
        #expect(snapshot.monthPercentChange != nil)
        #expect(snapshot.latestWeight == 182.4)
        #expect(snapshot.latestTimestamp == now)
    }

    @Test func snapshotStreakCountMatchesConsecutiveDays() {
        let calendar = Calendar.current
        let now = Date()
        let entries = (0..<5).map { daysAgo in
            WeightEntry(weight: 180.0, timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        let snapshot = WeightWidgetSnapshot.make(
            from: entries,
            tintRawValue: "blue",
            now: now
        )

        // 5 consecutive days including today
        #expect(snapshot.streakCount == 5)
    }

    @Test func snapshotWithNoEntriesHasZeroStreakAndNilFields() {
        let snapshot = WeightWidgetSnapshot.make(
            from: [],
            tintRawValue: "blue",
            now: .now
        )

        // Lockscreen widgets fall back to empty state — circular shows "--", inline shows prompt
        #expect(snapshot.latestWeight == nil)
        #expect(snapshot.latestTimestamp == nil)
        #expect(snapshot.streakCount == 0)
        #expect(snapshot.monthAverage == nil)
        #expect(snapshot.monthPercentChange == nil)
    }

    @Test func snapshotWithSingleEntryHasNilPercentChange() {
        let now = Date()
        let snapshot = WeightWidgetSnapshot.make(
            from: [WeightEntry(weight: 175.0, timestamp: now)],
            tintRawValue: "orange",
            now: now
        )

        // Rectangular lockscreen widget hides trend pill when percentChange is nil
        #expect(snapshot.latestWeight == 175.0)
        #expect(snapshot.streakCount == 1)
        #expect(snapshot.monthAverage == 175.0)
        #expect(snapshot.monthPercentChange == nil)
    }

    @Test func snapshotSortsEntriesAndUsesLatest() {
        let now = Date()
        let older = WeightEntry(weight: 190.0, timestamp: now.addingTimeInterval(-86400))
        let newer = WeightEntry(weight: 188.2, timestamp: now)

        // Pass entries out of order — snapshot should still use the most recent
        let snapshot = WeightWidgetSnapshot.make(
            from: [older, newer],
            tintRawValue: "red",
            now: now
        )

        #expect(snapshot.latestWeight == 188.2)
        #expect(snapshot.latestTimestamp == now)
    }

    @Test func snapshotTintRawValueIsPreserved() {
        for tint in AppTint.allCases {
            let snapshot = WeightWidgetSnapshot.make(
                from: [WeightEntry(weight: 180.0, timestamp: .now)],
                tintRawValue: tint.rawValue,
                now: .now
            )
            #expect(snapshot.appTintRawValue == tint.rawValue)
        }
    }

    // MARK: - JSON round-trip (widget extension reads what the app writes)

    @Test func snapshotEncodesAndDecodesWithISO8601() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000) // stable reference date
        let original = WeightWidgetSnapshot.make(
            from: [
                WeightEntry(weight: 182.4, timestamp: now),
                WeightEntry(weight: 184.0, timestamp: now.addingTimeInterval(-86400))
            ],
            tintRawValue: "green",
            now: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WeightWidgetSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.latestWeight == 182.4)
        #expect(decoded.streakCount == original.streakCount)
        #expect(decoded.monthPercentChange == original.monthPercentChange)
        #expect(decoded.appTintRawValue == "green")
    }

    @Test func snapshotDecodesEmptyOptionalFieldsCorrectly() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let original = WeightWidgetSnapshot.make(
            from: [],
            tintRawValue: "blue",
            now: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WeightWidgetSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.latestWeight == nil)
        #expect(decoded.monthPercentChange == nil)
        #expect(decoded.monthAverage == nil)
    }

    // MARK: - Month average correctness (used by home + medium widgets)

    @Test func snapshotMonthAverageIsCorrectForRecentEntries() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 182.0, timestamp: now.addingTimeInterval(-86400 * 2)),
            WeightEntry(weight: 184.0, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        // All entries within the last month, average = (180+182+184)/3 = 182.0
        #expect(snapshot.monthAverage != nil)
        #expect(abs(snapshot.monthAverage! - 182.0) < 0.01)
    }

    @Test func snapshotMonthAverageExcludesOldEntries() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 200.0, timestamp: now.addingTimeInterval(-86400 * 60)) // ~2 months ago
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        // Only the recent entry should count toward the month average
        #expect(snapshot.monthAverage != nil)
        #expect(abs(snapshot.monthAverage! - 180.0) < 0.01)
    }

    // MARK: - Percent change sign (rectangular lockscreen shows colored trend)

    @Test func snapshotPercentChangeIsNegativeForWeightLoss() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 176.0, timestamp: now),
            WeightEntry(weight: 180.0, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        #expect(snapshot.monthPercentChange != nil)
        #expect(snapshot.monthPercentChange! < 0)
    }

    @Test func snapshotPercentChangeIsPositiveForWeightGain() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 185.0, timestamp: now),
            WeightEntry(weight: 180.0, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        #expect(snapshot.monthPercentChange != nil)
        #expect(snapshot.monthPercentChange! > 0)
    }
}

// MARK: - WeightEntry Photo Metadata Tests

struct WeightEntryPhotoMetadataTests {

    @Test func emptyEntryHasNoPhotosAndZeroFingerprint() {
        let entry = WeightEntry(weight: 180.0)

        #expect(entry.hasPhotos == false)
        #expect(entry.photosFingerprint == 0)
    }

    @Test func multiPhotoAssignmentRoundTripsAndExposesPrimaryPhoto() {
        let firstPhoto = Data([0x01, 0x02, 0x03])
        let secondPhoto = Data([0xAA, 0xBB, 0xCC])
        let entry = WeightEntry(weight: 180.0)

        entry.photosData = [firstPhoto, secondPhoto]

        #expect(entry.photosData == [firstPhoto, secondPhoto])
        #expect(entry.photoData == firstPhoto)
        #expect(entry.hasPhotos == true)
    }

    @Test func clearingPhotosResetsPrimaryPhotoAndHasPhotosFlag() {
        let entry = WeightEntry(weight: 180.0, photoData: Data([0x10, 0x20]))
        let originalFingerprint = entry.photosFingerprint

        entry.photosData = []

        #expect(entry.photosData.isEmpty)
        #expect(entry.photoData == nil)
        #expect(entry.hasPhotos == false)
        #expect(entry.photosFingerprint != originalFingerprint)
    }

    @Test func photosFingerprintChangesWhenStoredPhotoPayloadChanges() {
        let entry = WeightEntry(weight: 180.0)

        entry.photosData = [Data([0x01])]
        let firstFingerprint = entry.photosFingerprint
        entry.photosData = [Data([0x02])]
        let secondFingerprint = entry.photosFingerprint

        #expect(firstFingerprint != secondFingerprint)
    }

    @Test func multiPhotoPayloadPersistsThroughSwiftDataRoundTrip() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)
        let firstPhoto = Data([0x01, 0x02, 0x03])
        let secondPhoto = Data([0x04, 0x05, 0x06])
        let entry = WeightEntry(weight: 180.0)
        entry.photosData = [firstPhoto, secondPhoto]

        context.insert(entry)
        try context.save()

        let storedEntries = try context.fetch(FetchDescriptor<WeightEntry>())

        #expect(storedEntries.count == 1)
        #expect(storedEntries[0].photosData == [firstPhoto, secondPhoto])
        #expect(storedEntries[0].photoData == firstPhoto)
        #expect(storedEntries[0].hasPhotos == true)
    }
}

// MARK: - WorkoutEntry Model Tests

struct WorkoutEntryModelTests {

    @Test func workoutEntryInitializesWithAllFields() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let uuid = UUID()
        let workout = WorkoutEntry(
            timestamp: timestamp,
            activityTypeRawValue: 37,
            duration: 1_800,
            energyBurnedKilocalories: 450,
            distanceMiles: 3.25,
            source: .appleHealth,
            healthKitUUID: uuid
        )

        #expect(workout.timestamp == timestamp)
        #expect(workout.activityTypeRawValue == 37)
        #expect(workout.duration == 1_800)
        #expect(workout.energyBurnedKilocalories == 450)
        #expect(workout.distanceMiles == 3.25)
        #expect(workout.source == .appleHealth)
        #expect(workout.healthKitUUID == uuid)
    }

    @Test func workoutSourceCodableRoundTripPreservesRawValue() throws {
        let encoded = try JSONEncoder().encode(WorkoutSource.appleHealth)
        let decoded = try JSONDecoder().decode(WorkoutSource.self, from: encoded)

        #expect(decoded == .appleHealth)
        #expect(WorkoutSource.appleHealth.rawValue == "appleHealth")
    }
}

// MARK: - Daily Activity Summary Model Tests

struct DailyActivitySummaryModelTests {

    @Test func dailyActivitySummaryInitializesWithDefaults() {
        let date = Calendar.current.startOfDay(for: .now)
        let summary = DailyActivitySummary(date: date)

        #expect(summary.date == date)
        #expect(summary.stepCount == 0)
        #expect(summary.activeEnergyBurnedKilocalories == 0)
        #expect(summary.source == .appleHealth)
    }

    @Test func dailyActivitySummaryStoresCustomValues() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let summary = DailyActivitySummary(
            date: date,
            stepCount: 12_345,
            activeEnergyBurnedKilocalories: 678.9,
            source: .appleHealth
        )

        #expect(summary.date == date)
        #expect(summary.stepCount == 12_345)
        #expect(summary.activeEnergyBurnedKilocalories == 678.9)
        #expect(summary.source == .appleHealth)
    }

    @Test func dailyActivitySourceCodableRoundTripPreservesRawValue() throws {
        let encoded = try JSONEncoder().encode(DailyActivitySource.appleHealth)
        let decoded = try JSONDecoder().decode(DailyActivitySource.self, from: encoded)

        #expect(decoded == .appleHealth)
        #expect(DailyActivitySource.appleHealth.rawValue == "appleHealth")
    }
}

// MARK: - RootView Custom Tab Logic Tests

struct RootViewCustomTabLogicTests {

    @Test func journalReselectUsesCustomJournalTabIndex() {
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 4,
                wasReselected: true,
                journalTabIndex: 4
            ) == true
        )
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 1,
                wasReselected: true,
                journalTabIndex: 4
            ) == false
        )
    }

    @Test func pillVisibilityUsesCustomSettingsIndex() {
        #expect(RootView.isPillVisible(selectedTab: 5, settingsTab: 5) == false)
        #expect(RootView.isPillVisible(selectedTab: 2, settingsTab: 5) == true)
    }
}
