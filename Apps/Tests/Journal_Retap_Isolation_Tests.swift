//
//  Journal_Retap_Isolation_Tests.swift
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

// MARK: - Journal Retap Isolation Tests

struct JournalRetapIsolationTests {

    @Test func journalRetapSignalExistsOnlyThroughTabBarObserverPath() {
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 1) == false)
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 1) == .scrollJournalToBottom)
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 1, wasReselected: true) == true)
    }

    @Test func journalFallbackScrollPathTargetsTodayBottom() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        #expect(JournalView.targetDay(for: nil, now: now, calendar: calendar) == calendar.startOfDay(for: now))
        #expect(JournalView.targetAnchor(hasFocusedEntry: false) == .bottom)
    }

    @Test func currentLogicKeepsRetapAndFallbackScrollPathsAligned() {
        let shouldScrollToBottom = RootView.shouldScrollJournalToBottom(
            tappedIndex: 1,
            wasReselected: true
        )
        let fallbackAnchor = JournalView.targetAnchor(hasFocusedEntry: false)

        #expect(shouldScrollToBottom == true)
        #expect(fallbackAnchor == .bottom)
    }
}

