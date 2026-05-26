//
//  WorkoutEntry_Model_Tests.swift
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

// MARK: - WorkoutEntry Model Tests

struct WorkoutEntryModelTests {

    @Test func workoutEntryInitializesWithAllFields() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let uuid = UUID()
        let workout = WorkoutEntry(
            timestamp: timestamp,
            activityTypeRawValue: 37,
            duration: 1_800,
            energyBurnedKilocalories: 450,
            distanceMiles: 3.25,
            source: .appleHealth,
            healthKitUUID: uuid
        )

        #expect(workout.timestamp == timestamp)
        #expect(workout.activityTypeRawValue == 37)
        #expect(workout.duration == 1_800)
        #expect(workout.energyBurnedKilocalories == 450)
        #expect(workout.distanceMiles == 3.25)
        #expect(workout.source == .appleHealth)
        #expect(workout.healthKitUUID == uuid)
    }

    @Test func workoutSourceCodableRoundTripPreservesRawValue() throws {
        let encoded = try JSONEncoder().encode(WorkoutSource.appleHealth)
        let decoded = try JSONDecoder().decode(WorkoutSource.self, from: encoded)

        #expect(decoded == .appleHealth)
        #expect(WorkoutSource.appleHealth.rawValue == "appleHealth")
    }
}

