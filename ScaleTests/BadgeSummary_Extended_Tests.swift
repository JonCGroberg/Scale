//
//  BadgeSummary_Extended_Tests.swift
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

// MARK: - BadgeSummary Extended Tests

struct BadgeSummaryExtendedTests {

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    @Test func emptyEntriesReturnZeroStreakAndNilFields() {
        let summary = WeightCalculations.badgeSummary(from: [], over: .week)

        #expect(summary.streak == 0)
        #expect(summary.average == nil)
        #expect(summary.weightChange == nil)
    }

    @Test func singleEntryGivesStreakOfOneAndNilWeightChange() {
        let entries = [WeightEntry(weight: 180.0, timestamp: Date())]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)

        #expect(summary.streak == 1)
        #expect(summary.average == 180.0)
        #expect(summary.weightChange == nil)
    }

    @Test func weightLossShowsNegativeChange() {
        let entries = [
            WeightEntry(weight: 175.0, timestamp: Date()),
            WeightEntry(weight: 180.0, timestamp: daysAgo(5)),
        ]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)

        #expect(summary.weightChange != nil)
        #expect(summary.weightChange! < 0)
        #expect(abs(summary.weightChange! - (-5.0)) < 0.01)
    }

    @Test func weightGainShowsPositiveChange() {
        let entries = [
            WeightEntry(weight: 185.0, timestamp: Date()),
            WeightEntry(weight: 180.0, timestamp: daysAgo(5)),
        ]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)

        #expect(summary.weightChange != nil)
        #expect(summary.weightChange! > 0)
    }

    @Test func averageIsCorrectForMultipleEntries() {
        let entries = [
            WeightEntry(weight: 180.0, timestamp: Date()),
            WeightEntry(weight: 182.0, timestamp: daysAgo(2)),
            WeightEntry(weight: 184.0, timestamp: daysAgo(4)),
        ]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)

        #expect(summary.average != nil)
        #expect(abs(summary.average! - 182.0) < 0.01)
    }

    @Test func summaryUsesCorrectTimePeriodFilter() {
        let entries = [
            WeightEntry(weight: 180.0, timestamp: Date()),
            WeightEntry(weight: 200.0, timestamp: daysAgo(400)),
        ]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)

        // Only 1 entry in the week → no weight change
        #expect(summary.average == 180.0)
        #expect(summary.weightChange == nil)
    }
}

