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
        case success(imported: Int, skipped: Int)
        case error(String)
    }
    
    // MARK: - Private
    
    private let healthStore = HKHealthStore()
    
    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Import
    
    @MainActor
    func importWeightData(modelContext: ModelContext) async {
        guard isAvailable else { return }
        
        isImporting = true
        importResult = nil
        
        do {
            // Request read authorization for body mass
            let bodyMassType = HKQuantityType(.bodyMass)
            try await healthStore.requestAuthorization(toShare: [], read: [bodyMassType])
            
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
            
            // Import samples, skipping duplicates
            var importedCount = 0
            var skippedCount = 0
            let poundUnit = HKUnit.pound()
            
            for sample in samples {
                let roundedTimestamp = Int(sample.startDate.timeIntervalSinceReferenceDate.rounded())
                
                if existingTimestamps.contains(roundedTimestamp) {
                    skippedCount += 1
                    continue
                }
                
                let weightInPounds = sample.quantity.doubleValue(for: poundUnit)
                let entry = WeightEntry(weight: weightInPounds, timestamp: sample.startDate)
                modelContext.insert(entry)
                importedCount += 1
            }
            
            try modelContext.save()
            importResult = .success(imported: importedCount, skipped: skippedCount)
        } catch {
            importResult = .error(error.localizedDescription)
        }
        
        isImporting = false
    }
}
