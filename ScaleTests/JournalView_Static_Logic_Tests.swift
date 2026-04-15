//
//  JournalView_Static_Logic_Tests.swift
//  ScaleTests
//
//  Tests for JournalView static helper methods.
//

import Testing
import Foundation
import SwiftUI
@testable import Scale

struct JournalViewStaticLogicTests {

    // MARK: - isNearTop

    @Test func isNearTopReturnsTrueWhenAtTop() {
        #expect(JournalView.isNearTop(contentOffsetY: 0, topInset: 0) == true)
    }

    @Test func isNearTopReturnsTrueWithinThreshold() {
        // contentOffsetY (50) <= topInset (0) + threshold (80)
        #expect(JournalView.isNearTop(contentOffsetY: 50, topInset: 0, threshold: 80) == true)
    }

    @Test func isNearTopReturnsTrueAtExactThreshold() {
        // contentOffsetY (80) <= topInset (0) + threshold (80)
        #expect(JournalView.isNearTop(contentOffsetY: 80, topInset: 0, threshold: 80) == true)
    }

    @Test func isNearTopReturnsFalseBeyondThreshold() {
        // contentOffsetY (81) > topInset (0) + threshold (80)
        #expect(JournalView.isNearTop(contentOffsetY: 81, topInset: 0, threshold: 80) == false)
    }

    @Test func isNearTopAccountsForTopInset() {
        // contentOffsetY (100) <= topInset (50) + threshold (80) = 130
        #expect(JournalView.isNearTop(contentOffsetY: 100, topInset: 50, threshold: 80) == true)
    }

    @Test func isNearTopReturnsFalseWhenScrolledFarDown() {
        #expect(JournalView.isNearTop(contentOffsetY: 500, topInset: 0) == false)
    }

    @Test func isNearTopWithNegativeOffset() {
        // Overscroll (rubber-banding) can produce negative offsets
        #expect(JournalView.isNearTop(contentOffsetY: -20, topInset: 0) == true)
    }

    @Test func isNearTopCustomThresholdOfZero() {
        #expect(JournalView.isNearTop(contentOffsetY: 0, topInset: 0, threshold: 0) == true)
        #expect(JournalView.isNearTop(contentOffsetY: 1, topInset: 0, threshold: 0) == false)
    }

    // MARK: - targetAnchor

    @Test func targetAnchorIsTopWhenFocusedEntry() {
        #expect(JournalView.targetAnchor(hasFocusedEntry: true) == .top)
    }

    @Test func targetAnchorIsBottomWhenNoFocusedEntry() {
        #expect(JournalView.targetAnchor(hasFocusedEntry: false) == .bottom)
    }

    // MARK: - isLoggableDay

    @Test func todayIsLoggable() {
        let now = Date()
        #expect(JournalView.isLoggableDay(now, now: now) == true)
    }

    @Test func yesterdayIsLoggable() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        #expect(JournalView.isLoggableDay(yesterday, now: now) == true)
    }

    @Test func tomorrowIsNotLoggable() {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        #expect(JournalView.isLoggableDay(tomorrow, now: now) == false)
    }

    @Test func distantPastIsLoggable() {
        let now = Date()
        let distantPast = Calendar.current.date(byAdding: .year, value: -5, to: now)!
        #expect(JournalView.isLoggableDay(distantPast, now: now) == true)
    }

    // MARK: - shouldPresentCreateSheet

    @Test func showsCreateSheetWhenNoWeight() {
        #expect(JournalView.shouldPresentCreateSheet(hasLoggedWeight: false, hasWorkouts: false) == true)
    }

    @Test func showsCreateSheetWhenNoWeightButHasWorkouts() {
        #expect(JournalView.shouldPresentCreateSheet(hasLoggedWeight: false, hasWorkouts: true) == true)
    }

    @Test func showsDetailSheetWhenWeightLogged() {
        #expect(JournalView.shouldPresentCreateSheet(hasLoggedWeight: true, hasWorkouts: false) == false)
    }

    @Test func showsDetailSheetWhenWeightLoggedAndHasWorkouts() {
        #expect(JournalView.shouldPresentCreateSheet(hasLoggedWeight: true, hasWorkouts: true) == false)
    }

    // MARK: - targetDay

    @Test func targetDayReturnsFocusedEntryDate() {
        let calendar = Calendar.current
        let specificDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        let result = JournalView.targetDay(for: specificDate, calendar: calendar)
        #expect(result == calendar.startOfDay(for: specificDate))
    }

    @Test func targetDayReturnsTodayWhenNoFocusedEntry() {
        let now = Date()
        let calendar = Calendar.current
        let result = JournalView.targetDay(for: nil, now: now, calendar: calendar)
        #expect(result == calendar.startOfDay(for: now))
    }
}
