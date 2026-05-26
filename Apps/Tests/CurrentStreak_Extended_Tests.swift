//
//  CurrentStreak_Extended_Tests.swift
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

// MARK: - CurrentStreak Extended Tests

struct CurrentStreakExtendedTests {

    private var calendar: Calendar { Calendar.current }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    @Test func streakIsZeroWithNoEntries() {
        #expect(WeightCalculations.currentStreak(from: []) == 0)
    }

    @Test func streakIsOneWhenOnlyTodayIsLogged() {
        let entries = [WeightEntry(weight: 150.0, timestamp: day(0).addingTimeInterval(60))]
        #expect(WeightCalculations.currentStreak(from: entries) == 1)
    }

    @Test func streakIsZeroWhenOnlyYesterdayIsLogged() {
        let entries = [WeightEntry(weight: 150.0, timestamp: day(-1))]
        #expect(WeightCalculations.currentStreak(from: entries) == 0)
    }

    @Test func streakCountsConsecutiveDaysBackFromToday() {
        let entries = (0...4).map { WeightEntry(weight: 150.0, timestamp: day(-$0).addingTimeInterval(60)) }
        #expect(WeightCalculations.currentStreak(from: entries) == 5)
    }

    @Test func gapBreaksStreak() {
        // Logged today and day -1, but not day -2; day -3 exists
        let entries = [
            WeightEntry(weight: 150.0, timestamp: day(0).addingTimeInterval(60)),
            WeightEntry(weight: 150.0, timestamp: day(-1)),
            WeightEntry(weight: 150.0, timestamp: day(-3)),
        ]
        #expect(WeightCalculations.currentStreak(from: entries) == 2)
    }

    @Test func includingTodayExtendsStreakByOne() {
        let entries = [WeightEntry(weight: 150.0, timestamp: day(-1))]
        let without = WeightCalculations.currentStreak(from: entries, includingToday: false)
        let withToday = WeightCalculations.currentStreak(from: entries, includingToday: true)

        #expect(without == 0)
        #expect(withToday == 2)
    }

    @Test func includingTodayWithNoHistoryGivesOne() {
        #expect(WeightCalculations.currentStreak(from: [], includingToday: true) == 1)
    }
}

