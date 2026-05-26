//
//  Daily_Activity_Import_Plan_Extended_Tests.swift
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

// MARK: - Daily Activity Import Plan Extended Tests

struct DailyActivityImportPlanExtendedTests {

    @Test func dailyActivityImportPlanHandlesEmptyInputs() {
        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: [],
            existingEntries: []
        )

        #expect(plan.importedCount == 0)
        #expect(plan.updatedCount == 0)
        #expect(plan.skippedCount == 0)
        #expect(plan.removedCount == 0)
    }

    @Test func dailyActivityImportPlanRemovesAllExistingWhenNoSummaries() {
        let date = Calendar.current.startOfDay(for: Date())
        let existing = [
            DailyActivitySummary(date: date, stepCount: 5_000, activeEnergyBurnedKilocalories: 300),
        ]

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: [],
            existingEntries: existing
        )

        #expect(plan.removedCount == 1)
        #expect(plan.importedCount == 0)
    }

    @Test func dailyActivityImportPlanUpdatesChangedStepCount() {
        let date = Calendar.current.startOfDay(for: Date())
        let existing = DailyActivitySummary(date: date, stepCount: 5_000, activeEnergyBurnedKilocalories: 300)
        let imported = HealthKitManager.ImportedDailyActivitySummary(
            date: date,
            stepCount: 7_000,
            activeEnergyBurnedKilocalories: 300
        )

        let plan = HealthKitManager.makeDailyActivityImportPlan(
            summaries: [imported],
            existingEntries: [existing]
        )

        #expect(plan.updatedCount == 1)
        #expect(plan.skippedCount == 0)
        #expect(plan.updatedEntries[0].1 == 7_000)
    }
}

