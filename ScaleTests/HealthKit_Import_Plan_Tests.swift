//
//  HealthKit_Import_Plan_Tests.swift
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

// MARK: - HealthKit Import Plan Tests

struct HealthKitImportPlanTests {

    private func sample(
        uuid: UUID = UUID(),
        daysAgo: Int,
        weight: Double,
        bundleID: String = "com.example.health"
    ) -> HealthKitManager.ImportedSample {
        HealthKitManager.ImportedSample(
            uuid: uuid,
            startDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            weightInPounds: weight,
            sourceBundleIdentifier: bundleID
        )
    }

    @Test func importPlanSkipsSelfAuthoredAndDuplicateEntries() {
        let duplicateDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let existing = [
            WeightEntry(weight: 180.0, timestamp: duplicateDate),
            WeightEntry(weight: 179.0)
        ]
        let samples = [
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: duplicateDate,
                weightInPounds: 181.0,
                sourceBundleIdentifier: "com.example.health"
            ),
            sample(daysAgo: 1, weight: 178.0, bundleID: "com.groberg.Scale"),
            sample(daysAgo: 3, weight: 177.0)
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 1)
        #expect(plan.skippedCount == 2)
        #expect(plan.insertedEntries.count == 1)
        #expect(plan.insertedEntries[0].weightInPounds == 177.0)
    }

    @Test func importPlanRemovesStaleAppleHealthEntries() {
        let staleUUID = UUID()
        let retainedUUID = UUID()
        let existing = [
            WeightEntry(weight: 180.0, source: .appleHealth, healthKitUUID: staleUUID),
            WeightEntry(weight: 179.0, source: .appleHealth, healthKitUUID: retainedUUID),
            WeightEntry(weight: 178.0, source: .manual)
        ]
        let samples = [
            sample(uuid: retainedUUID, daysAgo: 1, weight: 179.0),
            sample(daysAgo: 3, weight: 177.0)
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 1)
        #expect(plan.removedEntryIDs.count == 1)
        #expect(plan.removedEntryIDs.contains(existing[0].persistentModelID))
        #expect(!plan.removedEntryIDs.contains(existing[1].persistentModelID))
    }

    @Test func importPlanDoesNotRemoveManualEntriesWithoutMatchingSamples() {
        let existing = [
            WeightEntry(weight: 180.0, source: .manual),
            WeightEntry(weight: 179.0, source: .manual)
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: [],
            existingEntries: existing,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 0)
        #expect(plan.removedEntryIDs.isEmpty)
    }
}

