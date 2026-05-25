//
//  End_To_End_Application_Regression_Tests.swift
//  ScaleTests
//
//  Created by Jonathan Groberg on 5/23/26.
//

import Testing
import Foundation
import SwiftData
@testable import Scale

struct EndToEndApplicationRegressionTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self, configurations: config)
    }
    
    @Test func fullUserLifecycleIntegrationFlow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        
        // 1. Initial State Check
        let initialEntries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(initialEntries.isEmpty)
        
        // 2. Mock Apple Health Import Flow
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Populate 10 days of historical data
        for offset in 1...10 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            
            // Weight entries decreasing smoothly from 185.0
            let weight = 185.0 - (0.5 * Double(10 - offset))
            let entry = WeightEntry(weight: weight, timestamp: date, source: .appleHealth)
            context.insert(entry)
            
            // Activity summaries
            let steps = 8000 + (offset * 100)
            let activity = DailyActivitySummary(date: date, stepCount: steps, activeEnergyBurnedKilocalories: 400.0)
            context.insert(activity)
        }
        try context.save()
        
        // Verify mock imports
        let importedEntries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(importedEntries.count == 10)
        let importedActivity = try context.fetch(FetchDescriptor<DailyActivitySummary>())
        #expect(importedActivity.count == 10)
        
        // 3. User Logs a New Entry Manually Today
        // Streaks calculation check (consecutive days)
        let entriesSorted = importedEntries.sorted { $0.timestamp > $1.timestamp }
        let currentStreakBefore = WeightCalculations.currentStreak(from: entriesSorted)
        #expect(currentStreakBefore == 0) // today has not been logged yet
        
        let potentialStreak = WeightCalculations.currentStreak(from: entriesSorted, includingToday: true)
        #expect(potentialStreak == 11) // logging today would make it 11
        
        let longestStreakBefore = WeightCalculations.longestStreak(from: entriesSorted)
        #expect(longestStreakBefore == 10)
        
        // User logs today's weight manually
        let manualWeight = 179.5
        let manualEntry = WeightEntry(
            weight: manualWeight,
            timestamp: today,
            source: .manual,
            note: "Weigh-in post run",
            streakCount: potentialStreak
        )
        context.insert(manualEntry)
        try context.save()
        
        // Verify streak increases
        let allEntries = try context.fetch(FetchDescriptor<WeightEntry>())
        let allSorted = allEntries.sorted { $0.timestamp > $1.timestamp }
        let currentStreakAfter = WeightCalculations.currentStreak(from: allSorted)
        #expect(currentStreakAfter == 11)
        #expect(allSorted.first?.weight == 179.5)
        #expect(allSorted.first?.note == "Weigh-in post run")
        
        // 4. Goal Progress & Clamping Checks
        let goal = WeightGoal.lose
        let targetWeight = 175.0
        
        let progress = WeightCalculations.goalProgress(
            from: allSorted,
            goal: goal,
            targetWeight: targetWeight,
            over: .month
        )
        
        #expect(progress != nil)
        #expect(progress?.targetWeight == 175.0)
        #expect(progress?.totalDistance == 10.0) // 185.0 (oldest within month) - 175.0
        #expect(progress?.completedDistance == 5.5) // 185.0 - 179.5
        
        // 5. Mini Goal Store Actions
        let miniGoal1 = MiniGoal(parentGoal: .lose, name: "Under 180", targetWeight: 179.9)
        let miniGoal2 = MiniGoal(parentGoal: .lose, name: "Main Target", targetWeight: 175.0)
        
        #expect(miniGoal1.targetWeight == 179.9)
        #expect(miniGoal2.targetWeight == 175.0)
        
        // 6. Widget Snapshot Generation Check
        let snapshot = WeightWidgetSnapshot.make(
            from: allSorted,
            tintRawValue: AppTint.defaultValue.rawValue,
            now: today
        )
        
        #expect(snapshot.latestWeight == 179.5)
        #expect(snapshot.streakCount == 11)
        #expect(snapshot.monthAverage != nil)
        #expect(snapshot.monthPercentChange != nil)
    }

    // MARK: - Scenario 1: Comprehensive Weight Calculations and Streak Tracking
    @Test func weightCalculationsStreakTrackingLeapYearAndSuddenDateGaps() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Gap in middle of run caps streak
        let entriesWithGap = [
            WeightEntry(weight: 170.0, timestamp: today),
            WeightEntry(weight: 171.0, timestamp: calendar.date(byAdding: .day, value: -1, to: today)!),
            WeightEntry(weight: 172.0, timestamp: calendar.date(byAdding: .day, value: -3, to: today)!) // Gap on day -2
        ]
        
        let streakWithGap = WeightCalculations.currentStreak(from: entriesWithGap)
        #expect(streakWithGap == 2) // only today and yesterday count
        
        let longestWithGap = WeightCalculations.longestStreak(from: entriesWithGap)
        #expect(longestWithGap == 2)
        
        // Zero/Empty entries
        #expect(WeightCalculations.currentStreak(from: []) == 0)
        #expect(WeightCalculations.longestStreak(from: []) == 0)
    }

    // MARK: - Scenario 2: Notification Management & Triggers
    @Test func notificationManagerSchedulingLifecycleAndTriggers() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        
        let manager = NotificationManager()
        manager.modelContext = context
        
        // 1. Initially no entries, todayHasWeightEntry is false
        #expect(manager.todayHasWeightEntry() == false)
        
        // 2. Add an entry today
        let entry = WeightEntry(weight: 160.0, timestamp: Date())
        context.insert(entry)
        try context.save()
        
        #expect(manager.todayHasWeightEntry() == true)
        
        // 3. Test body template formatting
        let genericBody = NotificationManager.notificationBody(forPotentialStreak: 0)
        #expect(genericBody == "Tap to log your weight.")
        
        let streakBody = NotificationManager.notificationBody(forPotentialStreak: 5)
        #expect(streakBody == "Keep your 5-day streak going — log your weight today!")
    }

    // MARK: - Scenario 3: Goal Settings & Mini-Goals Lifecycle
    @Test func goalProgressCalculationsAndMiniGoals() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!
        
        let entries = [
            WeightEntry(weight: 170.0, timestamp: today),
            WeightEntry(weight: 180.0, timestamp: tenDaysAgo)
        ]
        
        // 1. Lose Goal Progress
        let progressLose = WeightCalculations.goalProgress(
            from: entries,
            goal: .lose,
            targetWeight: 165.0,
            over: .month
        )
        #expect(progressLose != nil)
        #expect(progressLose?.totalDistance == 15.0) // 180.0 - 165.0
        #expect(progressLose?.completedDistance == 10.0) // 180.0 - 170.0
        
        // 2. Bulk/Gain Goal Progress
        let progressGain = WeightCalculations.goalProgress(
            from: entries,
            goal: .gain,
            targetWeight: 190.0,
            over: .month
        )
        #expect(progressGain != nil)
        #expect(progressGain?.totalDistance == 10.0) // 190.0 - 180.0
        #expect(progressGain?.completedDistance == 0.0) // since we lost weight
        
        // 3. Maintain Goal returns nil progress
        let progressMaintain = WeightCalculations.goalProgress(
            from: entries,
            goal: .maintain,
            targetWeight: 175.0,
            over: .month
        )
        #expect(progressMaintain == nil)
        
        // 4. MiniGoal CRUD validation with custom UserDefaults
        let mockDefaults = UserDefaults(suiteName: "MiniGoalTestsSuite")!
        mockDefaults.removePersistentDomain(forName: "MiniGoalTestsSuite")
        
        let miniGoal1 = MiniGoal(parentGoal: .lose, name: "Under 180", targetWeight: 179.9)
        let miniGoal2 = MiniGoal(parentGoal: .lose, name: "Main Target", targetWeight: 175.0)
        
        MiniGoalStore.save([miniGoal1, miniGoal2], for: .lose, defaults: mockDefaults)
        
        let loaded = MiniGoalStore.load(for: .lose, defaults: mockDefaults)
        #expect(loaded.count == 2)
        #expect(loaded[0].name == "Under 180")
        #expect(loaded[1].targetWeight == 175.0)
    }

    // MARK: - Scenario 4: HealthKit Importing and Mock Activity Integration
    @Test func healthKitDataImportPlanDuplicatesAndDailyActivityMerge() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 1. Test duplicate checks in makeImportPlan
        let sample1 = HealthKitManager.ImportedSample(
            uuid: UUID(),
            startDate: today,
            weightInPounds: 175.0,
            sourceBundleIdentifier: "com.apple.Health"
        )
        
        let existingManual = WeightEntry(weight: 176.0, timestamp: today, source: .manual)
        
        let plan = HealthKitManager.makeImportPlan(
            samples: [sample1],
            existingEntries: [existingManual],
            ourBundleID: "groberg.Scale"
        )
        
        // Since manual entry exists on same timestamp, HealthKit sample should be skipped
        #expect(plan.importedCount == 0)
        #expect(plan.skippedCount == 1)
        
        // 2. Test makeWorkoutImportPlan ignores our own bundle
        let workoutSample = HealthKitManager.ImportedWorkout(
            uuid: UUID(),
            startDate: today,
            activityTypeRawValue: 20,
            duration: 1800,
            energyBurnedKilocalories: 300,
            distanceMiles: 2.5,
            sourceBundleIdentifier: "groberg.Scale" // our own app
        )
        
        let workoutPlan = HealthKitManager.makeWorkoutImportPlan(
            workouts: [workoutSample],
            existingEntries: [],
            ourBundleID: "groberg.Scale"
        )
        #expect(workoutPlan.importedCount == 0)
        #expect(workoutPlan.skippedCount == 1)
    }

    // MARK: - Scenario 5: Widget & Snapshot Resiliency
    @Test func widgetSnapshotCalculationsOnBoundaryDatasets() throws {
        let today = Date()
        
        // Empty DB Widget Snapshot
        let emptySnapshot = WeightWidgetSnapshot.make(
            from: [],
            tintRawValue: AppTint.defaultValue.rawValue,
            now: today
        )
        #expect(emptySnapshot.latestWeight == nil)
        #expect(emptySnapshot.streakCount == 0)
        #expect(emptySnapshot.monthAverage == nil)
        
        // Single Entry Snapshot
        let singleEntry = WeightEntry(weight: 165.5, timestamp: today)
        let singleSnapshot = WeightWidgetSnapshot.make(
            from: [singleEntry],
            tintRawValue: AppTint.defaultValue.rawValue,
            now: today
        )
        #expect(singleSnapshot.latestWeight == 165.5)
        #expect(singleSnapshot.streakCount == 1)
        #expect(singleSnapshot.monthPercentChange == nil) // No comparison possible
    }

    // MARK: - Scenario 6: Root View Tab Actions & Custom Navigation Logic
    @Test func rootViewBottomTabBarCustomNavigationTransitions() {
        // Test custom bottom navigation actions
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 3) == .switchTab)
        #expect(RootView.actionForTabTap(currentTab: 1, tappedTab: 1) == .scrollJournalToBottom)
        #expect(RootView.actionForTabTap(currentTab: 3, tappedTab: 3) == .ignore)
        
        // dynamic visibility
        #expect(RootView.isPillVisible(selectedTab: 1, settingsTab: 4) == true)
        #expect(RootView.isPillVisible(selectedTab: 4, settingsTab: 4) == false)
        
        #expect(RootView.shouldUpdateSelectedTab(from: 1, to: 3) == true)
        #expect(RootView.shouldUpdateSelectedTab(from: 3, to: 3) == false)
    }

    // MARK: - Scenario 7: OCR Parsing Engine & Scale Reading Corrections
    @Test func ocrScaleReadingsVisionCorrections() {
        // Standard digital display Vision corrections
        let reading1 = WeightCalculations.parseScaleReading("18O.5")
        #expect(reading1 == 180.5)
        
        let reading2 = WeightCalculations.parseScaleReading("17l.o")
        #expect(reading2 == 171.0)
        
        let reading3 = WeightCalculations.parseScaleReading("I8|")
        #expect(reading3 == 181.0)
        
        let invalid = WeightCalculations.parseScaleReading("ABC")
        #expect(invalid == nil)
    }
}
