//
//  ScaleTests.swift
//  ScaleTests
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Testing
import Foundation
import SwiftData
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
