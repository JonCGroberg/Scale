//
//  StreaksByDay_Extended_Tests.swift
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

// MARK: - StreaksByDay Extended Tests

struct StreaksByDayExtendedTests {

    private var calendar: Calendar { Calendar.current }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    @Test func longConsecutiveRunAssignsIncrementingValues() {
        // 7-day run ending today
        let entries = (-6...0).map { WeightEntry(weight: 150.0, timestamp: day($0)) }

        let streaks = WeightCalculations.streaksByDay(from: entries)

        for (index, offset) in (-6...0).enumerated() {
            #expect(streaks[calendar.startOfDay(for: day(offset))] == index + 1)
        }
    }

    @Test func singleEntryIsIsolated() {
        let entries = [WeightEntry(weight: 150.0, timestamp: day(-3))]

        let streaks = WeightCalculations.streaksByDay(from: entries)

        #expect(streaks[calendar.startOfDay(for: day(-3))] == 0)
        #expect(streaks.count == 1)
    }

    @Test func twoSeparateRunsWithGapBetween() {
        // Run A: day -6, -5 (2-day)
        // Gap: day -4, -3
        // Run B: day -2, -1, 0 (3-day)
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(-6)),
            WeightEntry(weight: 150.0, timestamp: day(-5)),
            WeightEntry(weight: 150.0, timestamp: day(-2)),
            WeightEntry(weight: 150.0, timestamp: day(-1)),
            WeightEntry(weight: 150.0, timestamp: day(0)),
        ]

        let streaks = WeightCalculations.streaksByDay(from: entries)

        // Run A
        #expect(streaks[calendar.startOfDay(for: day(-6))] == 1)
        #expect(streaks[calendar.startOfDay(for: day(-5))] == 2)
        // Run B
        #expect(streaks[calendar.startOfDay(for: day(-2))] == 1)
        #expect(streaks[calendar.startOfDay(for: day(-1))] == 2)
        #expect(streaks[calendar.startOfDay(for: day(0))] == 3)
    }

    @Test func multipleIsolatedDaysAllGetZero() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(-10)),
            WeightEntry(weight: 150.0, timestamp: day(-7)),
            WeightEntry(weight: 150.0, timestamp: day(-3)),
        ]

        let streaks = WeightCalculations.streaksByDay(from: entries)

        #expect(streaks.values.allSatisfy { $0 == 0 })
        #expect(streaks.count == 3)
    }

    @Test func multipleEntriesOnSameDayCountAsOneDay() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(0).addingTimeInterval(60)),
            WeightEntry(weight: 149.5, timestamp: day(0).addingTimeInterval(3600)),
            WeightEntry(weight: 151.0, timestamp: day(0).addingTimeInterval(7200)),
        ]

        let streaks = WeightCalculations.streaksByDay(from: entries)

        #expect(streaks.count == 1)
        #expect(streaks[calendar.startOfDay(for: day(0))] == 0)
    }
}

