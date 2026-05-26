//
//  HealthKit_Workout_Import_Plan_Tests.swift
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

// MARK: - HealthKit Workout Import Plan Tests

struct HealthKitWorkoutImportPlanTests {

    private func workout(
        uuid: UUID = UUID(),
        daysAgo: Int,
        bundleID: String = "com.example.health",
        activityTypeRawValue: UInt = 37,
        duration: TimeInterval = 1_800,
        energyBurnedKilocalories: Double? = 320,
        distanceMiles: Double? = 3.1
    ) -> HealthKitManager.ImportedWorkout {
        HealthKitManager.ImportedWorkout(
            uuid: uuid,
            startDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            activityTypeRawValue: activityTypeRawValue,
            duration: duration,
            energyBurnedKilocalories: energyBurnedKilocalories,
            distanceMiles: distanceMiles,
            sourceBundleIdentifier: bundleID
        )
    }

    @Test func workoutImportPlanSkipsSelfAuthoredAndExistingEntries() {
        let retainedUUID = UUID()
        let existing = [
            WorkoutEntry(
                activityTypeRawValue: 37,
                duration: 1_500,
                source: .appleHealth,
                healthKitUUID: retainedUUID
            )
        ]
        let workouts = [
            workout(uuid: retainedUUID, daysAgo: 1),
            workout(daysAgo: 2, bundleID: "com.groberg.Scale"),
            workout(daysAgo: 3, activityTypeRawValue: 13, duration: 2_400)
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: workouts,
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 1)
        #expect(plan.skippedCount == 2)
        #expect(plan.insertedEntries.count == 1)
        #expect(plan.insertedEntries[0].activityTypeRawValue == 13)
        #expect(plan.insertedEntries[0].duration == 2_400)
    }

    @Test func workoutImportPlanRemovesStaleHealthKitEntries() {
        let staleUUID = UUID()
        let retainedUUID = UUID()
        let existing = [
            WorkoutEntry(activityTypeRawValue: 37, duration: 1_000, source: .appleHealth, healthKitUUID: staleUUID),
            WorkoutEntry(activityTypeRawValue: 13, duration: 2_000, source: .appleHealth, healthKitUUID: retainedUUID),
            WorkoutEntry(activityTypeRawValue: 20, duration: 3_000, source: .appleHealth, healthKitUUID: nil)
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: [workout(uuid: retainedUUID, daysAgo: 1)],
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 1)
        #expect(plan.removedEntryIDs.contains(existing[0].persistentModelID))
        #expect(!plan.removedEntryIDs.contains(existing[1].persistentModelID))
        #expect(!plan.removedEntryIDs.contains(existing[2].persistentModelID))
    }

    @Test func workoutImportPlanKeepsEntriesWithoutHealthKitUUIDs() {
        let existing = [
            WorkoutEntry(activityTypeRawValue: 37, duration: 1_000, source: .appleHealth, healthKitUUID: nil)
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: [],
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 0)
        #expect(plan.removedEntryIDs.isEmpty)
        #expect(plan.importedCount == 0)
    }
}

