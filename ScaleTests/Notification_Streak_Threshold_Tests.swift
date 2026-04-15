//
//  Notification_Streak_Threshold_Tests.swift
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

// MARK: - Notification Streak Threshold Tests
//
// Verify the ≥ 2 threshold that separates the generic body ("Tap to log your weight.")
// from the personalized streak body ("Keep your N-day streak going…").

struct NotificationStreakThresholdTests {

    private var calendar: Calendar { Calendar.current }

    private func potentialStreak(daysBack: [Int]) -> Int {
        let entries = daysBack.map {
            WeightEntry(weight: 150.0, timestamp: calendar.date(byAdding: .day, value: -$0, to: Date())!)
        }
        return WeightCalculations.currentStreak(from: entries, includingToday: true)
    }

    @Test func newUserBelowThresholdForPersonalizedMessage() {
        // No prior days → potential streak 1 → generic message territory.
        let streak = WeightCalculations.currentStreak(from: [], includingToday: true)
        #expect(streak < 2)
    }

    @Test func oneDayHistoryMeetsThresholdForPersonalizedMessage() {
        // Yesterday logged → potential streak 2 → meets the ≥ 2 threshold.
        let streak = potentialStreak(daysBack: [1])
        #expect(streak >= 2)
    }

    @Test func twoDayHistoryStreakIsThree() {
        let streak = potentialStreak(daysBack: [1, 2])
        #expect(streak == 3)
    }

    @Test func nineDayHistoryStreakIsTen() {
        let streak = potentialStreak(daysBack: Array(1...9))
        #expect(streak == 10)
    }

    @Test func brokenStreakDropsBelowThreshold() {
        // Only entry is 2 days ago (no yesterday) → potential streak 1 → generic message.
        let streak = potentialStreak(daysBack: [2])
        #expect(streak < 2)
    }
}

