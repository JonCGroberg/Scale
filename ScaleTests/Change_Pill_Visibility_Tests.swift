//
//  Change_Pill_Visibility_Tests.swift
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

// MARK: - Change Pill Visibility Tests

struct ChangePillVisibilityTests {

    @Test func pillVisibleOnLogTab() {
        #expect(RootView.isPillVisible(selectedTab: 0) == true)
    }

    @Test func pillVisibleOnJournalTab() {
        #expect(RootView.isPillVisible(selectedTab: 1) == true)
    }

    @Test func pillHiddenOnSettingsTab() {
        #expect(RootView.isPillVisible(selectedTab: 4) == false)
    }

    @Test func pillVisibleForUnknownTabIndex() {
        // Any future tab that isn't Settings should still show the pill
        #expect(RootView.isPillVisible(selectedTab: 2) == true)
        #expect(RootView.isPillVisible(selectedTab: 99) == true)
    }

    @Test func selectedTabUpdateIgnoredWhenRetappingCurrentTab() {
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 1) == false)
    }

    @Test func selectedTabUpdateAllowedWhenChangingTabs() {
        #expect(RootView.shouldUpdateSelectedTab(from: 0, to: 1) == true)
    }

    @Test func journalRetapMapsToBottomScrollAction() {
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 1) == .scrollJournalToBottom)
    }

    @Test func nonJournalRetapMapsToIgnoreAction() {
        #expect(RootView.actionForTabTap(currentTab: 0, tappedTab: 0) == .ignore)
        #expect(RootView.actionForTabTap(currentTab: 2, tappedTab: 2) == .ignore)
    }

    @Test func changingTabsMapsToSwitchAction() {
        #expect(RootView.actionForTabTap(currentTab: 0, tappedTab: 1) == .switchTab)
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 2) == .switchTab)
    }

    @Test func journalRetapTriggersBottomScroll() {
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 1, wasReselected: true) == true)
    }

    @Test func journalFirstSelectionDoesNotTriggerBottomScroll() {
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 1, wasReselected: false) == false)
    }

    @Test func nonJournalRetapDoesNotTriggerBottomScroll() {
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 0, wasReselected: true) == false)
        #expect(RootView.shouldScrollJournalToBottom(tappedIndex: 2, wasReselected: true) == false)
    }
}

