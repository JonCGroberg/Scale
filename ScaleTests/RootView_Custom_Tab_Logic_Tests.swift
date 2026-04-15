//
//  RootView_Custom_Tab_Logic_Tests.swift
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

// MARK: - RootView Custom Tab Logic Tests

struct RootViewCustomTabLogicTests {

    @Test func journalReselectUsesCustomJournalTabIndex() {
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 4,
                wasReselected: true,
                journalTabIndex: 4
            ) == true
        )
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 1,
                wasReselected: true,
                journalTabIndex: 4
            ) == false
        )
    }

    @Test func pillVisibilityUsesCustomSettingsIndex() {
        #expect(RootView.isPillVisible(selectedTab: 5, settingsTab: 5) == false)
        #expect(RootView.isPillVisible(selectedTab: 2, settingsTab: 5) == true)
    }
}

