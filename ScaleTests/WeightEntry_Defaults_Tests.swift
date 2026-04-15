//
//  WeightEntry_Defaults_Tests.swift
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

// MARK: - WeightEntry Defaults Tests

struct WeightEntryDefaultsTests {

    @Test func defaultSourceIsManual() {
        let entry = WeightEntry(weight: 180.0)
        #expect(entry.source == .manual)
    }

    @Test func defaultStreakCountIsZero() {
        let entry = WeightEntry(weight: 180.0)
        #expect(entry.streakCount == 0)
    }

    @Test func defaultHealthKitUUIDIsNil() {
        let entry = WeightEntry(weight: 180.0)
        #expect(entry.healthKitUUID == nil)
    }

    @Test func defaultNoteIsNil() {
        let entry = WeightEntry(weight: 180.0)
        #expect(entry.note == nil)
    }

    @Test func timestampDefaultsToNow() {
        let before = Date()
        let entry = WeightEntry(weight: 180.0)
        let after = Date()

        #expect(entry.timestamp >= before)
        #expect(entry.timestamp <= after)
    }
}

