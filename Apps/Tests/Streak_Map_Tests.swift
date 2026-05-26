//
//  Streak_Map_Tests.swift
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

