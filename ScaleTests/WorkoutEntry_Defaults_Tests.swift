//
//  WorkoutEntry_Defaults_Tests.swift
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

// MARK: - WorkoutEntry Defaults Tests

struct WorkoutEntryDefaultsTests {

    @Test func defaultSourceIsAppleHealth() {
        let entry = WorkoutEntry(activityTypeRawValue: 37, duration: 1_000)
        #expect(entry.source == .appleHealth)
    }

    @Test func defaultHealthKitUUIDIsNil() {
        let entry = WorkoutEntry(activityTypeRawValue: 37, duration: 1_000)
        #expect(entry.healthKitUUID == nil)
    }

    @Test func defaultOptionalFieldsAreNil() {
        let entry = WorkoutEntry(activityTypeRawValue: 37, duration: 1_000)
        #expect(entry.energyBurnedKilocalories == nil)
        #expect(entry.distanceMiles == nil)
    }
}

