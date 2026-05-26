//
//  Custom_Navigation_Performance_Regression_Tests.swift
//  ScaleTests
//
//  Created by Jonathan Groberg on 5/23/26.
//

import Testing
import Foundation
import SwiftData
@testable import Scale

struct CustomNavigationPerformanceRegressionTests {

    // MARK: - Custom Bottom Navigation Actions

    @Test func journalToOverviewTabSwitchAction() {
        let action = RootView.actionForTabTap(currentTab: 1, tappedTab: 3)
        #expect(action == .switchTab)
    }

    @Test func overviewToJournalTabSwitchAction() {
        let action = RootView.actionForTabTap(currentTab: 3, tappedTab: 1)
        #expect(action == .switchTab)
    }

    @Test func journalReselectScrollsToBottom() {
        let action = RootView.actionForTabTap(currentTab: 1, tappedTab: 1)
        #expect(action == .scrollJournalToBottom)
    }

    @Test func overviewReselectIgnores() {
        let action = RootView.actionForTabTap(currentTab: 3, tappedTab: 3)
        #expect(action == .ignore)
    }

    @Test func shouldUpdateTabBetweenJournalAndOverview() {
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 3) == true)
        #expect(RootView.shouldUpdateSelectedTab(from: 3, to: 1) == true)
    }

    @Test func shouldNotUpdateTabWhenTappingSameIndex() {
        #expect(RootView.shouldUpdateSelectedTab(from: 3, to: 3) == false)
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 1) == false)
    }

    @Test func tabPillIsVisibleOnOverviewAndJournal() {
        #expect(RootView.isPillVisible(selectedTab: 1) == true)
        #expect(RootView.isPillVisible(selectedTab: 3) == true)
    }

    // MARK: - Transient Photo Cache Verification

    @Test func weightEntryPhotoStorageCaching() {
        let photo1 = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let photo2 = Data([0xCA, 0xFE, 0xBA, 0xBE])
        
        let entry = WeightEntry(weight: 165.0)
        #expect(entry.photosData.isEmpty)
        
        // Write photo array (saves to storage & in-memory cache)
        entry.photosData = [photo1, photo2]
        #expect(entry.photosData.count == 2)
        #expect(entry.photosData[0] == photo1)
        #expect(entry.photosData[1] == photo2)
        
        // Update photos (updates both)
        let photo3 = Data([0x01, 0x02, 0x03])
        entry.photosData = [photo3]
        #expect(entry.photosData.count == 1)
        #expect(entry.photoData == photo3)
    }

    @Test func weightEntryPhotoFingerprintChangesOnPhotoUpdates() {
        let entry = WeightEntry(weight: 155.0)
        let fingerprint1 = entry.photosFingerprint
        
        entry.photosData = [Data([0x11, 0x22])]
        let fingerprint2 = entry.photosFingerprint
        #expect(fingerprint1 != fingerprint2)
        
        entry.photosData = []
        let fingerprint3 = entry.photosFingerprint
        #expect(fingerprint2 != fingerprint3)
    }
}
