//
//  Current_Streak_Including_Today_Tests.swift
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

