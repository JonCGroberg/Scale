//
//  Journal_Scroll_Target_Tests.swift
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

// MARK: - Journal Scroll Target Tests

struct JournalScrollTargetTests {

    @Test func nilFocusedEntryTargetsTodayAtBottom() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        let targetDay = JournalView.targetDay(for: nil, now: now, calendar: calendar)

        #expect(targetDay == calendar.startOfDay(for: now))
        #expect(JournalView.targetAnchor(hasFocusedEntry: false) == .bottom)
    }

    @Test func focusedEntryTargetsEntryDayAtTop() {
        let calendar = Calendar(identifier: .gregorian)
        let entryDate = Date(timeIntervalSince1970: 1_709_000_123)

        let targetDay = JournalView.targetDay(for: entryDate, calendar: calendar)

        #expect(targetDay == calendar.startOfDay(for: entryDate))
        #expect(JournalView.targetAnchor(hasFocusedEntry: true) == .top)
    }

    @Test func nilFocusedEntryUsesBottomAnchor() {
        #expect(JournalView.targetAnchor(hasFocusedEntry: false) == .bottom)
    }

    @Test func nearTopThresholdMatchesScrollGeometryRule() {
        #expect(JournalView.isNearTop(contentOffsetY: 50, topInset: 0) == true)
        #expect(JournalView.isNearTop(contentOffsetY: 80, topInset: 0) == true)
        #expect(JournalView.isNearTop(contentOffsetY: 81, topInset: 0) == false)
        #expect(JournalView.isNearTop(contentOffsetY: 100, topInset: 40) == true)
        #expect(JournalView.isNearTop(contentOffsetY: 121, topInset: 40) == false)
    }

    @Test func aprilFirstCountsAsLoggableWhenItIsToday() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 9, minute: 30))!
        let aprilFirst = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 0, minute: 1))!

        #expect(JournalView.isLoggableDay(aprilFirst, now: now, calendar: calendar) == true)
    }

    @Test func tomorrowIsNotLoggable() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 9, minute: 30))!
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 2, hour: 0, minute: 1))!

        #expect(JournalView.isLoggableDay(tomorrow, now: now, calendar: calendar) == false)
    }

    @Test func unloggedDayWithWorkoutsStillOpensCreateSheet() {
        #expect(
            JournalView.shouldPresentCreateSheet(
                hasLoggedWeight: false,
                hasWorkouts: true
            ) == true
        )
    }

    @Test func loggedDayWithWorkoutsOpensDetailSheet() {
        #expect(
            JournalView.shouldPresentCreateSheet(
                hasLoggedWeight: true,
                hasWorkouts: true
            ) == false
        )
    }
}

