//
//  Calendar_Month_Loader_Tests.swift
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

