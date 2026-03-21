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
    
    // MARK: - State
    
    var isAvailable: Bool = false
    var isImporting: Bool = false
    var importResult: ImportResult? = nil
    
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
        
        let bodyMassType = HKQuantityType(.bodyMass)
        
        do {
            try await healthStore.requestAuthorization(toShare: [bodyMassType], read: [bodyMassType])
            
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
        
        let bodyMassType = HKQuantityType(.bodyMass)
        
        do {
            try await healthStore.requestAuthorization(toShare: [bodyMassType], read: [bodyMassType])
            
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
    func importWeightData(modelContext: ModelContext) async {
        guard isAvailable else { return }
        
        isImporting = true
        importResult = nil
        
        do {
            // Request read+write authorization for body mass
            let bodyMassType = HKQuantityType(.bodyMass)
            try await healthStore.requestAuthorization(toShare: [bodyMassType], read: [bodyMassType])
            
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
}
