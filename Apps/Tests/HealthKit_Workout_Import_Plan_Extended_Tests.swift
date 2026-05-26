//
//  HealthKit_Workout_Import_Plan_Extended_Tests.swift
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

// MARK: - HealthKit Workout Import Plan Extended Tests

struct HealthKitWorkoutImportPlanExtendedTests {

    @Test func workoutImportPlanImportsAllWhenStoreIsEmpty() {
        let workouts = [
            HealthKitManager.ImportedWorkout(
                uuid: UUID(),
                startDate: Date(),
                activityTypeRawValue: 37,
                duration: 1_800,
                energyBurnedKilocalories: 300,
                distanceMiles: 3.0,
                sourceBundleIdentifier: "com.other.app"
            ),
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: workouts,
            existingEntries: [],
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 1)
        #expect(plan.skippedCount == 0)
        #expect(plan.removedCount == 0)
    }

    @Test func workoutImportPlanHandlesEmptyInputs() {
        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: [],
            existingEntries: [],
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 0)
        #expect(plan.skippedCount == 0)
        #expect(plan.removedCount == 0)
    }

    @Test func workoutImportPlanPreservesNilOptionalFields() {
        let workouts = [
            HealthKitManager.ImportedWorkout(
                uuid: UUID(),
                startDate: Date(),
                activityTypeRawValue: 37,
                duration: 600,
                energyBurnedKilocalories: nil,
                distanceMiles: nil,
                sourceBundleIdentifier: "com.other.app"
            ),
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: workouts,
            existingEntries: [],
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 1)
        #expect(plan.insertedEntries[0].energyBurnedKilocalories == nil)
        #expect(plan.insertedEntries[0].distanceMiles == nil)
    }
}

