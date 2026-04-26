//
//  HealthKitManager.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import HealthKit
import Observation
import SwiftData

@Observable
final class HealthKitManager {
    struct ImportedSample: Equatable {
        let uuid: UUID
        let startDate: Date
        let weightInPounds: Double
        let sourceBundleIdentifier: String
    }

    struct PendingImportEntry: Equatable {
        let uuid: UUID
        let timestamp: Date
        let weightInPounds: Double
    }

    struct ImportPlan: Equatable {
        let removedEntryIDs: [PersistentIdentifier]
        let insertedEntries: [PendingImportEntry]
        let importedCount: Int
        let skippedCount: Int
        let removedCount: Int
    }

    struct ImportedWorkout: Equatable {
        let uuid: UUID
        let startDate: Date
        let activityTypeRawValue: UInt
        let duration: TimeInterval
        let energyBurnedKilocalories: Double?
        let distanceMiles: Double?
        let sourceBundleIdentifier: String
    }

    struct PendingWorkoutImportEntry: Equatable {
        let uuid: UUID
        let timestamp: Date
        let activityTypeRawValue: UInt
        let duration: TimeInterval
        let energyBurnedKilocalories: Double?
        let distanceMiles: Double?
    }

    struct WorkoutImportPlan: Equatable {
        let removedEntryIDs: [PersistentIdentifier]
        let insertedEntries: [PendingWorkoutImportEntry]
        let importedCount: Int
        let skippedCount: Int
        let removedCount: Int
    }

    struct ImportedDailyActivitySummary: Equatable {
        let date: Date
        let stepCount: Int
        let activeEnergyBurnedKilocalories: Double
    }

    struct DailyActivityImportPlan {
        let removedEntryIDs: [PersistentIdentifier]
        let insertedEntries: [ImportedDailyActivitySummary]
        let updatedEntries: [(PersistentIdentifier, Int, Double)]
        let importedCount: Int
        let updatedCount: Int
        let removedCount: Int
        let skippedCount: Int
    }
    
    // MARK: - State
    
    var isAvailable: Bool = false
    var isImporting: Bool = false
    var importResult: ImportResult? = nil
    var isImportingWorkouts: Bool = false
    var workoutImportResult: ImportResult? = nil
    var isImportingDailyActivity: Bool = false
    var dailyActivityImportResult: ImportResult? = nil
    
    enum ImportResult: Equatable {
        case success(imported: Int, skipped: Int, removed: Int)
        case error(String)
    }
    
    // MARK: - Private
    
    private let healthStore = HKHealthStore()
    
    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Save to HealthKit
    
    /// Saves a weight sample to HealthKit and returns the sample's UUID on success.
    func saveWeight(_ weightInPounds: Double, date: Date = Date()) async -> UUID? {
        guard isAvailable else { return nil }

        do {
            try await requestWeightAuthorization()

            let bodyMassType = HKQuantityType(.bodyMass)
            let quantity = HKQuantity(unit: .pound(), doubleValue: weightInPounds)
            let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)
            try await healthStore.save(sample)
            return sample.uuid
        } catch {
            // Save to HealthKit is best-effort; the entry is already persisted locally
            return nil
        }
    }
    
    // MARK: - Delete from HealthKit
    
    /// Deletes a previously saved HealthKit sample by UUID.
    func deleteWeight(sampleUUID: UUID) async {
        guard isAvailable else { return }

        do {
            try await requestWeightAuthorization()

            let bodyMassType = HKQuantityType(.bodyMass)
            let predicate = HKQuery.predicateForObject(with: sampleUUID)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: bodyMassType, predicate: predicate)],
                sortDescriptors: []
            )
            let samples = try await descriptor.result(for: healthStore)
            
            for sample in samples {
                try await healthStore.delete(sample)
            }
        } catch {
            // Deletion is best-effort
        }
    }
    
    // MARK: - Import
    
    @MainActor
    func importWeightData(modelContext: ModelContext, authorizationRequested: Bool = false) async {
        guard isAvailable else { return }
        
        isImporting = true
        importResult = nil
        
        do {
            if !authorizationRequested {
                try await requestWeightAuthorization()
            }

            let bodyMassType = HKQuantityType(.bodyMass)
            // Fetch all body mass samples
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: bodyMassType)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
            )
            let samples = try await descriptor.result(for: healthStore)
            
            let existingEntries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
            let poundUnit = HKUnit.pound()
            let ourBundleID = Bundle.main.bundleIdentifier ?? ""

            let importedSamples = samples.map {
                ImportedSample(
                    uuid: $0.uuid,
                    startDate: $0.startDate,
                    weightInPounds: $0.quantity.doubleValue(for: poundUnit),
                    sourceBundleIdentifier: $0.sourceRevision.source.bundleIdentifier
                )
            }
            let plan = Self.makeImportPlan(
                samples: importedSamples,
                existingEntries: existingEntries,
                ourBundleID: ourBundleID
            )

            for entry in existingEntries where plan.removedEntryIDs.contains(entry.persistentModelID) {
                modelContext.delete(entry)
            }

            for pendingEntry in plan.insertedEntries {
                let entry = WeightEntry(
                    weight: pendingEntry.weightInPounds,
                    timestamp: pendingEntry.timestamp,
                    source: .appleHealth,
                    healthKitUUID: pendingEntry.uuid
                )
                modelContext.insert(entry)
            }
            
            try modelContext.save()
            let refreshedEntries = try modelContext.fetch(
                FetchDescriptor<WeightEntry>(
                    sortBy: [SortDescriptor(\WeightEntry.timestamp, order: .reverse)]
                )
            )
            WeightWidgetSnapshotStore.refresh(using: refreshedEntries)
            importResult = .success(
                imported: plan.importedCount,
                skipped: plan.skippedCount,
                removed: plan.removedCount
            )
        } catch {
            importResult = .error(error.localizedDescription)
        }
        
        isImporting = false
    }

    @MainActor
    func importWorkoutData(modelContext: ModelContext, authorizationRequested: Bool = false) async {
        guard isAvailable else { return }

        isImportingWorkouts = true
        workoutImportResult = nil

        do {
            if !authorizationRequested {
                try await requestWorkoutAuthorization()
            }

            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout()],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
            )
            let workouts = try await descriptor.result(for: healthStore)

            let existingEntries = try modelContext.fetch(FetchDescriptor<WorkoutEntry>())
            let calorieUnit = HKUnit.largeCalorie()
            let mileUnit = HKUnit.mile()
            let ourBundleID = Bundle.main.bundleIdentifier ?? ""

            let importedWorkouts = workouts.map {
                ImportedWorkout(
                    uuid: $0.uuid,
                    startDate: $0.startDate,
                    activityTypeRawValue: $0.workoutActivityType.rawValue,
                    duration: $0.duration,
                    energyBurnedKilocalories: Self.activeEnergyBurned(for: $0)?.doubleValue(for: calorieUnit),
                    distanceMiles: $0.totalDistance?.doubleValue(for: mileUnit),
                    sourceBundleIdentifier: $0.sourceRevision.source.bundleIdentifier
                )
            }
            let plan = Self.makeWorkoutImportPlan(
                workouts: importedWorkouts,
                existingEntries: existingEntries,
                ourBundleID: ourBundleID
            )

            for entry in existingEntries where plan.removedEntryIDs.contains(entry.persistentModelID) {
                modelContext.delete(entry)
            }

            for pendingEntry in plan.insertedEntries {
                let entry = WorkoutEntry(
                    timestamp: pendingEntry.timestamp,
                    activityTypeRawValue: pendingEntry.activityTypeRawValue,
                    duration: pendingEntry.duration,
                    energyBurnedKilocalories: pendingEntry.energyBurnedKilocalories,
                    distanceMiles: pendingEntry.distanceMiles,
                    source: .appleHealth,
                    healthKitUUID: pendingEntry.uuid
                )
                modelContext.insert(entry)
            }

            try modelContext.save()
            workoutImportResult = .success(
                imported: plan.importedCount,
                skipped: plan.skippedCount,
                removed: plan.removedCount
            )
        } catch {
            workoutImportResult = .error(error.localizedDescription)
        }

        isImportingWorkouts = false
    }

    @MainActor
    func importDailyActivityData(modelContext: ModelContext, authorizationRequested: Bool = false) async {
        guard isAvailable else { return }

        isImportingDailyActivity = true
        dailyActivityImportResult = nil

        do {
            if !authorizationRequested {
                try await requestDailyActivityAuthorization()
            }

            let endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
            let startDate = Calendar.current.date(byAdding: .year, value: -5, to: endDate) ?? .distantPast

            let stepStats = try await dailyCumulativeStatistics(
                for: HKQuantityType(.stepCount),
                startDate: startDate,
                endDate: endDate
            )
            let activeEnergyStats = try await dailyCumulativeStatistics(
                for: HKQuantityType(.activeEnergyBurned),
                startDate: startDate,
                endDate: endDate
            )

            let existingEntries = try modelContext.fetch(FetchDescriptor<DailyActivitySummary>())
            let importedEntries = mergeDailyActivitySummaries(
                stepStats: stepStats,
                activeEnergyStats: activeEnergyStats
            )
            let plan = Self.makeDailyActivityImportPlan(
                summaries: importedEntries,
                existingEntries: existingEntries
            )

            let existingEntriesByID = Dictionary(uniqueKeysWithValues: existingEntries.map { ($0.persistentModelID, $0) })

            for removedEntryID in plan.removedEntryIDs {
                if let entry = existingEntriesByID[removedEntryID] {
                    modelContext.delete(entry)
                }
            }

            for updatedEntry in plan.updatedEntries {
                guard let entry = existingEntriesByID[updatedEntry.0] else { continue }
                entry.stepCount = updatedEntry.1
                entry.activeEnergyBurnedKilocalories = updatedEntry.2
            }

            for summary in plan.insertedEntries {
                modelContext.insert(
                    DailyActivitySummary(
                        date: summary.date,
                        stepCount: summary.stepCount,
                        activeEnergyBurnedKilocalories: summary.activeEnergyBurnedKilocalories,
                        source: .appleHealth
                    )
                )
            }

            try modelContext.save()
            dailyActivityImportResult = .success(
                imported: plan.importedCount + plan.updatedCount,
                skipped: plan.skippedCount,
                removed: plan.removedCount
            )
        } catch {
            dailyActivityImportResult = .error(error.localizedDescription)
        }

        isImportingDailyActivity = false
    }

    @MainActor
    func importAllData(modelContext: ModelContext) async {
        guard isAvailable else { return }

        do {
            try await requestImportAuthorization()
        } catch {
            let message = error.localizedDescription
            importResult = .error(message)
            workoutImportResult = .error(message)
            dailyActivityImportResult = .error(message)
            return
        }

        await importWeightData(modelContext: modelContext, authorizationRequested: true)
        await importWorkoutData(modelContext: modelContext, authorizationRequested: true)
        await importDailyActivityData(modelContext: modelContext, authorizationRequested: true)
    }

    func requestImportPermission() async -> Bool {
        guard isAvailable else { return false }

        do {
            try await requestImportAuthorization()
            return true
        } catch {
            return false
        }
    }

    static func makeImportPlan(
        samples: [ImportedSample],
        existingEntries: [WeightEntry],
        ourBundleID: String
    ) -> ImportPlan {
        let existingTimestamps = Set(
            existingEntries.map { Int($0.timestamp.timeIntervalSinceReferenceDate.rounded()) }
        )
        let healthKitUUIDs = Set(samples.map(\.uuid))
        let removableEntries = existingEntries.filter {
            guard $0.source == .appleHealth, let uuid = $0.healthKitUUID else {
                return false
            }
            return !healthKitUUIDs.contains(uuid)
        }

        var insertedEntries: [PendingImportEntry] = []
        var skippedCount = 0

        for sample in samples {
            if sample.sourceBundleIdentifier == ourBundleID {
                skippedCount += 1
                continue
            }

            let roundedTimestamp = Int(sample.startDate.timeIntervalSinceReferenceDate.rounded())
            if existingTimestamps.contains(roundedTimestamp) {
                skippedCount += 1
                continue
            }

            insertedEntries.append(
                PendingImportEntry(
                    uuid: sample.uuid,
                    timestamp: sample.startDate,
                    weightInPounds: sample.weightInPounds
                )
            )
        }

        return ImportPlan(
            removedEntryIDs: removableEntries.map(\.persistentModelID),
            insertedEntries: insertedEntries,
            importedCount: insertedEntries.count,
            skippedCount: skippedCount,
            removedCount: removableEntries.count
        )
    }

    static func makeWorkoutImportPlan(
        workouts: [ImportedWorkout],
        existingEntries: [WorkoutEntry],
        ourBundleID: String
    ) -> WorkoutImportPlan {
        let importedUUIDs = Set(workouts.map(\.uuid))
        let existingUUIDs = Set(existingEntries.compactMap(\.healthKitUUID))
        let removableEntries = existingEntries.filter {
            guard let uuid = $0.healthKitUUID else {
                return false
            }
            return !importedUUIDs.contains(uuid)
        }

        var insertedEntries: [PendingWorkoutImportEntry] = []
        var skippedCount = 0

        for workout in workouts {
            if workout.sourceBundleIdentifier == ourBundleID || existingUUIDs.contains(workout.uuid) {
                skippedCount += 1
                continue
            }

            insertedEntries.append(
                PendingWorkoutImportEntry(
                    uuid: workout.uuid,
                    timestamp: workout.startDate,
                    activityTypeRawValue: workout.activityTypeRawValue,
                    duration: workout.duration,
                    energyBurnedKilocalories: workout.energyBurnedKilocalories,
                    distanceMiles: workout.distanceMiles
                )
            )
        }

        return WorkoutImportPlan(
            removedEntryIDs: removableEntries.map(\.persistentModelID),
            insertedEntries: insertedEntries,
            importedCount: insertedEntries.count,
            skippedCount: skippedCount,
            removedCount: removableEntries.count
        )
    }

    static func makeDailyActivityImportPlan(
        summaries: [ImportedDailyActivitySummary],
        existingEntries: [DailyActivitySummary]
    ) -> DailyActivityImportPlan {
        let existingByDate = Dictionary(uniqueKeysWithValues: existingEntries.map { ($0.date, $0) })
        let importedDates = Set(summaries.map(\.date))
        let removableEntries = existingEntries.filter { !importedDates.contains($0.date) }

        var insertedEntries: [ImportedDailyActivitySummary] = []
        var updatedEntries: [(PersistentIdentifier, Int, Double)] = []
        var skippedCount = 0

        for summary in summaries {
            if let existingEntry = existingByDate[summary.date] {
                if existingEntry.stepCount == summary.stepCount &&
                    abs(existingEntry.activeEnergyBurnedKilocalories - summary.activeEnergyBurnedKilocalories) < 0.001 {
                    skippedCount += 1
                } else {
                    updatedEntries.append((
                        existingEntry.persistentModelID,
                        summary.stepCount,
                        summary.activeEnergyBurnedKilocalories
                    ))
                }
            } else {
                insertedEntries.append(summary)
            }
        }

        return DailyActivityImportPlan(
            removedEntryIDs: removableEntries.map(\.persistentModelID),
            insertedEntries: insertedEntries,
            updatedEntries: updatedEntries,
            importedCount: insertedEntries.count,
            updatedCount: updatedEntries.count,
            removedCount: removableEntries.count,
            skippedCount: skippedCount
        )
    }

    private func requestWeightAuthorization() async throws {
        let bodyMassType = HKQuantityType(.bodyMass)
        try await healthStore.requestAuthorization(toShare: [bodyMassType], read: [bodyMassType])
    }

    private func requestWorkoutAuthorization() async throws {
        let workoutType = HKObjectType.workoutType()
        try await healthStore.requestAuthorization(toShare: [], read: [workoutType])
    }

    private func requestDailyActivityAuthorization() async throws {
        let stepType = HKQuantityType(.stepCount)
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        try await healthStore.requestAuthorization(toShare: [], read: [stepType, activeEnergyType])
    }

    private func requestImportAuthorization() async throws {
        let bodyMassType = HKQuantityType(.bodyMass)
        let workoutType = HKObjectType.workoutType()
        let stepType = HKQuantityType(.stepCount)
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)

        try await healthStore.requestAuthorization(
            toShare: [bodyMassType],
            read: [bodyMassType, workoutType, stepType, activeEnergyType]
        )
    }

    private func dailyCumulativeStatistics(
        for quantityType: HKQuantityType,
        startDate: Date,
        endDate: Date
    ) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: samplePredicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: healthStore)

        var values: [Date: Double] = [:]
        collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            guard let quantity = statistics.sumQuantity() else { return }
            let value: Double
            if quantityType.identifier == HKQuantityTypeIdentifier.stepCount.rawValue {
                value = quantity.doubleValue(for: .count())
            } else {
                value = quantity.doubleValue(for: .largeCalorie())
            }
            values[statistics.startDate] = value
        }
        return values
    }

    func mergeDailyActivitySummaries(
        stepStats: [Date: Double],
        activeEnergyStats: [Date: Double]
    ) -> [ImportedDailyActivitySummary] {
        let dates = Set(stepStats.keys).union(activeEnergyStats.keys)
        return dates.sorted().map { date in
            ImportedDailyActivitySummary(
                date: Calendar.current.startOfDay(for: date),
                stepCount: Int((stepStats[date] ?? 0).rounded()),
                activeEnergyBurnedKilocalories: activeEnergyStats[date] ?? 0
            )
        }
    }

    private static func activeEnergyBurned(for workout: HKWorkout) -> HKQuantity? {
        workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()
    }
}
