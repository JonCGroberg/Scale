//
//  RootView_Tab_Action_Tests.swift
//  ScaleTests
//
//  Exhaustive tests for RootView.actionForTabTap, shouldUpdateSelectedTab,
//  and shouldScrollJournalToBottom.
//

import Testing
import Foundation
@testable import Scale

struct RootViewTabActionTests {

    // MARK: - actionForTabTap

    @Test func switchingFromLogToJournalReturnsSwitchTab() {
        let action = RootView.actionForTabTap(currentTab: 0, tappedTab: 1)
        #expect(action == .switchTab)
    }

    @Test func switchingFromJournalToSettingsReturnsSwitchTab() {
        let action = RootView.actionForTabTap(currentTab: 1, tappedTab: 2)
        #expect(action == .switchTab)
    }

    @Test func switchingFromSettingsToLogReturnsSwitchTab() {
        let action = RootView.actionForTabTap(currentTab: 2, tappedTab: 0)
        #expect(action == .switchTab)
    }

    @Test func reselectingJournalTabReturnsScrollToBottom() {
        let action = RootView.actionForTabTap(currentTab: 1, tappedTab: 1)
        #expect(action == .scrollJournalToBottom)
    }

    @Test func reselectingLogTabReturnsIgnore() {
        let action = RootView.actionForTabTap(currentTab: 0, tappedTab: 0)
        #expect(action == .ignore)
    }

    @Test func reselectingSettingsTabReturnsIgnore() {
        let action = RootView.actionForTabTap(currentTab: 2, tappedTab: 2)
        #expect(action == .ignore)
    }

    @Test func customJournalTabIndexReselectScrollsToBottom() {
        let action = RootView.actionForTabTap(currentTab: 3, tappedTab: 3, journalTabIndex: 3)
        #expect(action == .scrollJournalToBottom)
    }

    @Test func customJournalTabIndexReselectOnNonJournalIgnores() {
        let action = RootView.actionForTabTap(currentTab: 0, tappedTab: 0, journalTabIndex: 3)
        #expect(action == .ignore)
    }

    // MARK: - shouldUpdateSelectedTab

    @Test func shouldUpdateWhenTabsDiffer() {
        #expect(RootView.shouldUpdateSelectedTab(from: 0, to: 1) == true)
    }

    @Test func shouldNotUpdateWhenTabsSame() {
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 1) == false)
    }

    // MARK: - shouldScrollJournalToBottom

    @Test func scrollsWhenReselectingJournalTab() {
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 1,
                wasReselected: true,
                journalTabIndex: 1
            ) == true
        )
    }

    @Test func doesNotScrollWhenNotReselected() {
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 1,
                wasReselected: false,
                journalTabIndex: 1
            ) == false
        )
    }

    @Test func doesNotScrollWhenReselectingNonJournalTab() {
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 0,
                wasReselected: true,
                journalTabIndex: 1
            ) == false
        )
    }

    @Test func doesNotScrollWhenReselectingSettingsTab() {
        #expect(
            RootView.shouldScrollJournalToBottom(
                tappedIndex: 2,
                wasReselected: true,
                journalTabIndex: 1
            ) == false
        )
    }

    // MARK: - isPillVisible

    @Test func pillVisibleOnLogTab() {
        #expect(RootView.isPillVisible(selectedTab: 0) == true)
    }

    @Test func pillVisibleOnJournalTab() {
        #expect(RootView.isPillVisible(selectedTab: 1) == true)
    }

    @Test func pillHiddenOnSettingsTab() {
        #expect(RootView.isPillVisible(selectedTab: 2) == false)
    }

    @Test func pillVisibleWithCustomSettingsIndex() {
        #expect(RootView.isPillVisible(selectedTab: 2, settingsTab: 3) == true)
        #expect(RootView.isPillVisible(selectedTab: 3, settingsTab: 3) == false)
    }
}
