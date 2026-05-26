//
//  Entry_Grouping_Tests.swift
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

