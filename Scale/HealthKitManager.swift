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
            
            // Build set of existing timestamps for duplicate prevention
            let existingEntries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
            let existingTimestamps: Set<Int> = Set(
                existingEntries.map { Int($0.timestamp.timeIntervalSinceReferenceDate.rounded()) }
            )
            
            // Build set of HealthKit sample UUIDs for removal detection
            let healthKitUUIDs: Set<UUID> = Set(samples.map(\.uuid))
            
            // Remove local Apple Health entries whose samples no longer exist in HealthKit
            var removedCount = 0
            let healthEntries = existingEntries.filter { $0.source == .appleHealth && $0.healthKitUUID != nil }
            for entry in healthEntries {
                if let uuid = entry.healthKitUUID, !healthKitUUIDs.contains(uuid) {
                    modelContext.delete(entry)
                    removedCount += 1
                }
            }
            
            // Import samples, skipping duplicates and samples we authored
            var importedCount = 0
            var skippedCount = 0
            let poundUnit = HKUnit.pound()
            let ourBundleID = Bundle.main.bundleIdentifier ?? ""
            
            for sample in samples {
                // Skip samples that our app wrote to HealthKit
                if sample.sourceRevision.source.bundleIdentifier == ourBundleID {
                    skippedCount += 1
                    continue
                }
                
                let roundedTimestamp = Int(sample.startDate.timeIntervalSinceReferenceDate.rounded())
                
                if existingTimestamps.contains(roundedTimestamp) {
                    skippedCount += 1
                    continue
                }
                
                let weightInPounds = sample.quantity.doubleValue(for: poundUnit)
                let entry = WeightEntry(weight: weightInPounds, timestamp: sample.startDate, source: .appleHealth, healthKitUUID: sample.uuid)
                modelContext.insert(entry)
                importedCount += 1
            }
            
            try modelContext.save()
            importResult = .success(imported: importedCount, skipped: skippedCount, removed: removedCount)
        } catch {
            importResult = .error(error.localizedDescription)
        }
        
        isImporting = false
    }
}
