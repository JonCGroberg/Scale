//
//  LongestStreak_Tests.swift
//  ScaleTests
//

import Testing
import Foundation
@testable import Scale

struct LongestStreakTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    @Test func longestStreakIsZeroForNoEntries() {
        #expect(WeightCalculations.longestStreak(from: []) == 0)
    }

    @Test func longestStreakCountsLongestRunNotCurrentRun() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(-8)),
            WeightEntry(weight: 150.0, timestamp: day(-7)),
            WeightEntry(weight: 150.0, timestamp: day(-6)),
            WeightEntry(weight: 150.0, timestamp: day(-4)),
            WeightEntry(weight: 150.0, timestamp: day(-3))
        ]

        #expect(WeightCalculations.longestStreak(from: entries) == 3)
    }

    @Test func longestStreakCollapsesMultipleEntriesOnSameDay() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(-2)),
            WeightEntry(weight: 151.0, timestamp: day(-2).addingTimeInterval(120)),
            WeightEntry(weight: 152.0, timestamp: day(-1)),
            WeightEntry(weight: 153.0, timestamp: day(0))
        ]

        #expect(WeightCalculations.longestStreak(from: entries) == 3)
    }
}
