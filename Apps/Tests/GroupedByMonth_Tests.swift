//
//  GroupedByMonth_Tests.swift
//  ScaleTests
//
//  Tests for WeightCalculations.groupedByMonth ordering, keys, and grouping behavior.
//

import Testing
import Foundation
@testable import Scale

struct GroupedByMonthTests {

    private var calendar: Calendar { Calendar.current }

    @Test func emptyEntriesReturnsEmptyGroups() {
        let result = WeightCalculations.groupedByMonth([])
        #expect(result.isEmpty)
    }

    @Test func singleEntryProducesOneGroup() {
        let entry = WeightEntry(weight: 150.0, timestamp: Date())
        let result = WeightCalculations.groupedByMonth([entry])

        #expect(result.count == 1)
        #expect(result[0].value.count == 1)
    }

    @Test func entriesInSameMonthGroupedTogether() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 151.0, timestamp: now.addingTimeInterval(-3600)),
            WeightEntry(weight: 152.0, timestamp: now.addingTimeInterval(-7200))
        ]

        let result = WeightCalculations.groupedByMonth(entries)

        #expect(result.count == 1)
        #expect(result[0].value.count == 3)
    }

    @Test func entriesInDifferentMonthsProduceSeparateGroups() {
        let now = Date()
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now)!

        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 155.0, timestamp: twoMonthsAgo)
        ]

        let result = WeightCalculations.groupedByMonth(entries)

        #expect(result.count == 2)
    }

    @Test func groupsAreSortedNewestFirst() {
        let now = Date()
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now)!

        let entries = [
            WeightEntry(weight: 150.0, timestamp: twoMonthsAgo),
            WeightEntry(weight: 155.0, timestamp: now),
            WeightEntry(weight: 152.0, timestamp: oneMonthAgo)
        ]

        let result = WeightCalculations.groupedByMonth(entries)

        #expect(result.count == 3)
        // First group should contain the newest entry
        #expect(result[0].value.first?.weight == 155.0)
        // Last group should contain the oldest entry
        #expect(result[2].value.first?.weight == 150.0)
    }

    @Test func groupKeyMatchesMonthYearFormat() {
        let components = DateComponents(year: 2026, month: 3, day: 15)
        let date = calendar.date(from: components)!
        let entry = WeightEntry(weight: 150.0, timestamp: date)

        let result = WeightCalculations.groupedByMonth([entry])

        #expect(result.count == 1)
        #expect(result[0].key == "March 2026")
    }

    @Test func multipleEntriesSameMonthAllAppearInGroup() {
        let components = DateComponents(year: 2026, month: 1, day: 1)
        let jan1 = calendar.date(from: components)!
        let jan15 = calendar.date(byAdding: .day, value: 14, to: jan1)!
        let jan31 = calendar.date(byAdding: .day, value: 30, to: jan1)!

        let entries = [
            WeightEntry(weight: 150.0, timestamp: jan1),
            WeightEntry(weight: 151.0, timestamp: jan15),
            WeightEntry(weight: 152.0, timestamp: jan31)
        ]

        let result = WeightCalculations.groupedByMonth(entries)

        #expect(result.count == 1)
        #expect(result[0].key == "January 2026")
        #expect(result[0].value.count == 3)
    }
}
