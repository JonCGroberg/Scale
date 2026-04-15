//
//  HealthKit_Weight_Import_Plan_Extended_Tests.swift
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

// MARK: - HealthKit Weight Import Plan Extended Tests

struct HealthKitWeightImportPlanExtendedTests {

    @Test func importPlanImportsAllSamplesWhenStoreIsEmpty() {
        let samples = [
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: Date(),
                weightInPounds: 180.0,
                sourceBundleIdentifier: "com.other.app"
            ),
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: Date().addingTimeInterval(-86400),
                weightInPounds: 179.0,
                sourceBundleIdentifier: "com.other.app"
            ),
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: [],
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 2)
        #expect(plan.skippedCount == 0)
        #expect(plan.removedCount == 0)
    }

    @Test func importPlanSkipsAllSelfAuthoredSamples() {
        let samples = [
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: Date(),
                weightInPounds: 180.0,
                sourceBundleIdentifier: "com.groberg.Scale"
            ),
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: Date().addingTimeInterval(-86400),
                weightInPounds: 179.0,
                sourceBundleIdentifier: "com.groberg.Scale"
            ),
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: [],
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 0)
        #expect(plan.skippedCount == 2)
    }

    @Test func importPlanHandlesEmptySamplesAndEntries() {
        let plan = HealthKitManager.makeImportPlan(
            samples: [],
            existingEntries: [],
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 0)
        #expect(plan.skippedCount == 0)
        #expect(plan.removedCount == 0)
        #expect(plan.insertedEntries.isEmpty)
        #expect(plan.removedEntryIDs.isEmpty)
    }
}

