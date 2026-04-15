//
//  HealthKit_Daily_Activity_Import_Plan_Tests.swift
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

// MARK: - HealthKit Daily Activity Import Plan Tests

struct HealthKitDailyActivityImportPlanTests {

    @Test func dailyActivityImportPlanInsertsUpdatesSkipsAndRemovesEntries() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let unchanged = DailyActivitySummary(date: today, stepCount: 5_000, activeEnergyBurnedKilocalories: 400)
        let needsUpdate = DailyActivitySummary(date: yesterday, stepCount: 4_000, activeEnergyBurnedKilocalories: 300)
        let removable = DailyActivitySummary(date: twoDaysAgo, stepCount: 3_000, activeEnergyBurnedKilocalories: 200)

        let imported = [
            HealthKitManager.ImportedDailyActivitySummary(date: today, stepCount: 5_000, activeEnergyBurnedKilocalories: 400),
            HealthKitManager.ImportedDailyActivitySummary(date: yesterday, stepCount: 4_500, activeEnergyBurnedKilocalories: 350),
            HealthKitManager.ImportedDailyActivitySummary(date: threeDaysAgo, stepCount: 6_000, activeEnergyBurnedKilocalories: 500)
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: imported,
            existingEntries: [unchanged, needsUpdate, removable]
        )

        #expect(plan.importedCount == 1)
        #expect(plan.updatedCount == 1)
        #expect(plan.skippedCount == 1)
        #expect(plan.removedCount == 1)
        #expect(plan.insertedEntries.first?.date == threeDaysAgo)
        #expect(plan.updatedEntries.count == 1)
        #expect(plan.updatedEntries[0].0 == needsUpdate.persistentModelID)
        #expect(plan.updatedEntries[0].1 == 4_500)
        #expect(abs(plan.updatedEntries[0].2 - 350) < 0.001)
        #expect(plan.removedEntryIDs == [removable.persistentModelID])
    }

    @Test func dailyActivityImportPlanTreatsTinyEnergyDeltasAsUnchanged() {
        let date = Calendar.current.startOfDay(for: Date())
        let existing = DailyActivitySummary(date: date, stepCount: 8_000, activeEnergyBurnedKilocalories: 250)
        let imported = HealthKitManager.ImportedDailyActivitySummary(
            date: date,
            stepCount: 8_000,
            activeEnergyBurnedKilocalories: 250.0005
        )

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: [imported],
            existingEntries: [existing]
        )

        #expect(plan.updatedCount == 0)
        #expect(plan.skippedCount == 1)
        #expect(plan.importedCount == 0)
        #expect(plan.removedCount == 0)
    }

    @Test func dailyActivityImportPlanInsertsAllEntriesWhenStoreIsEmpty() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let imported = [
            HealthKitManager.ImportedDailyActivitySummary(date: yesterday, stepCount: 3_000, activeEnergyBurnedKilocalories: 200),
            HealthKitManager.ImportedDailyActivitySummary(date: today, stepCount: 5_000, activeEnergyBurnedKilocalories: 400)
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: imported,
            existingEntries: []
        )

        #expect(plan.importedCount == 2)
        #expect(plan.updatedCount == 0)
        #expect(plan.skippedCount == 0)
        #expect(plan.removedCount == 0)
        #expect(plan.insertedEntries.map(\.date) == [yesterday, today])
    }
}

