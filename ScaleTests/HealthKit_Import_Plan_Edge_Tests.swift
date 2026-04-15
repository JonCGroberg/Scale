//
//  HealthKit_Import_Plan_Edge_Tests.swift
//  ScaleTests
//
//  Edge case tests for HealthKitManager import plan generation: duplicate timestamps,
//  mixed sources, removal of orphaned Apple Health entries.
//

import Testing
import Foundation
import SwiftData
@testable import Scale

struct HealthKitImportPlanEdgeTests {

    // MARK: - Weight Import: timestamp deduplication

    @Test func importPlanSkipsSampleWhenTimestampMatchesExistingEntry() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)

        let timestamp = Date()
        let existing = WeightEntry(weight: 180.0, timestamp: timestamp, source: .manual)
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<WeightEntry>())

        let samples = [
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: timestamp,
                weightInPounds: 180.0,
                sourceBundleIdentifier: "com.other.app"
            )
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: existingEntries,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 0)
        #expect(plan.skippedCount == 1)
    }

    @Test func importPlanRemovesOrphanedAppleHealthEntries() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)

        let orphanUUID = UUID()
        let existing = WeightEntry(weight: 180.0, timestamp: Date(), source: .appleHealth)
        existing.healthKitUUID = orphanUUID
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<WeightEntry>())

        // Samples don't include the orphan UUID
        let plan = HealthKitManager.makeImportPlan(
            samples: [],
            existingEntries: existingEntries,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 1)
        #expect(plan.removedEntryIDs.count == 1)
    }

    @Test func importPlanDoesNotRemoveManualEntries() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)

        let existing = WeightEntry(weight: 180.0, timestamp: Date(), source: .manual)
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<WeightEntry>())

        let plan = HealthKitManager.makeImportPlan(
            samples: [],
            existingEntries: existingEntries,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 0)
    }

    @Test func importPlanDoesNotRemoveAppleHealthEntriesStillInSamples() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)

        let uuid = UUID()
        let existing = WeightEntry(weight: 180.0, timestamp: Date(), source: .appleHealth)
        existing.healthKitUUID = uuid
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<WeightEntry>())

        let samples = [
            HealthKitManager.ImportedSample(
                uuid: uuid,
                startDate: Date(),
                weightInPounds: 180.0,
                sourceBundleIdentifier: "com.other.app"
            )
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: existingEntries,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 0)
    }

    @Test func importPlanMixedSourcesSkipsOwnAndImportsOthers() {
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
                sourceBundleIdentifier: "com.apple.Health"
            ),
            HealthKitManager.ImportedSample(
                uuid: UUID(),
                startDate: Date().addingTimeInterval(-172800),
                weightInPounds: 178.0,
                sourceBundleIdentifier: "com.withings.wiScaleNG"
            )
        ]

        let plan = HealthKitManager.makeImportPlan(
            samples: samples,
            existingEntries: [],
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 2)
        #expect(plan.skippedCount == 1)
    }

    // MARK: - Workout Import: duplicate UUID handling

    @Test func workoutImportPlanSkipsDuplicateUUIDs() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkoutEntry.self, configurations: config)
        let context = ModelContext(container)

        let uuid = UUID()
        let existing = WorkoutEntry(
            activityTypeRawValue: 37,
            duration: 1800,
            source: .appleHealth,
            healthKitUUID: uuid
        )
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<WorkoutEntry>())

        let workouts = [
            HealthKitManager.ImportedWorkout(
                uuid: uuid,
                startDate: Date(),
                activityTypeRawValue: 37,
                duration: 1800,
                energyBurnedKilocalories: 300,
                distanceMiles: 3.0,
                sourceBundleIdentifier: "com.apple.Health"
            )
        ]

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: workouts,
            existingEntries: existingEntries,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.importedCount == 0)
        #expect(plan.skippedCount == 1)
    }

    @Test func workoutImportPlanRemovesOrphanedEntries() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkoutEntry.self, configurations: config)
        let context = ModelContext(container)

        let orphanUUID = UUID()
        let existing = WorkoutEntry(
            activityTypeRawValue: 37,
            duration: 600,
            source: .appleHealth,
            healthKitUUID: orphanUUID
        )
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<WorkoutEntry>())

        let plan = HealthKitManager.makeWorkoutImportPlan(
            workouts: [],
            existingEntries: existingEntries,
            ourBundleID: "com.groberg.Scale"
        )

        #expect(plan.removedCount == 1)
    }

    // MARK: - Daily Activity Import: update vs insert

    @Test func dailyActivityImportPlanUpdatesChangedEnergy() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyActivitySummary.self, configurations: config)
        let context = ModelContext(container)

        let date = Calendar.current.startOfDay(for: Date())
        let existing = DailyActivitySummary(
            date: date,
            stepCount: 5000,
            activeEnergyBurnedKilocalories: 200.0
        )
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<DailyActivitySummary>())

        let summaries = [
            HealthKitManager.ImportedDailyActivitySummary(
                date: date,
                stepCount: 5000,
                activeEnergyBurnedKilocalories: 250.0  // changed
            )
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: summaries,
            existingEntries: existingEntries
        )

        #expect(plan.updatedCount == 1)
        #expect(plan.importedCount == 0)
        #expect(plan.skippedCount == 0)
    }

    @Test func dailyActivityImportPlanSkipsIdenticalData() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyActivitySummary.self, configurations: config)
        let context = ModelContext(container)

        let date = Calendar.current.startOfDay(for: Date())
        let existing = DailyActivitySummary(
            date: date,
            stepCount: 5000,
            activeEnergyBurnedKilocalories: 200.0
        )
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<DailyActivitySummary>())

        let summaries = [
            HealthKitManager.ImportedDailyActivitySummary(
                date: date,
                stepCount: 5000,
                activeEnergyBurnedKilocalories: 200.0  // identical
            )
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: summaries,
            existingEntries: existingEntries
        )

        #expect(plan.skippedCount == 1)
        #expect(plan.updatedCount == 0)
        #expect(plan.importedCount == 0)
    }

    @Test func dailyActivityImportPlanInsertsNewDates() {
        let date = Calendar.current.startOfDay(for: Date())

        let summaries = [
            HealthKitManager.ImportedDailyActivitySummary(
                date: date,
                stepCount: 8000,
                activeEnergyBurnedKilocalories: 350.0
            )
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: summaries,
            existingEntries: []
        )

        #expect(plan.importedCount == 1)
        #expect(plan.insertedEntries.count == 1)
        #expect(plan.insertedEntries[0].stepCount == 8000)
    }

    @Test func dailyActivityImportPlanRemovesStaleEntries() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyActivitySummary.self, configurations: config)
        let context = ModelContext(container)

        let date = Calendar.current.startOfDay(for: Date())
        let existing = DailyActivitySummary(date: date, stepCount: 1000)
        context.insert(existing)
        try context.save()

        let existingEntries = try context.fetch(FetchDescriptor<DailyActivitySummary>())

        // Empty summaries means all existing entries are stale
        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: [],
            existingEntries: existingEntries
        )

        #expect(plan.removedCount == 1)
    }
}
