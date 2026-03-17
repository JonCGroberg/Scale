//
//  ScaleApp.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData

@main
struct ScaleApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WeightEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If the existing store is incompatible with the current schema,
            // delete it and create a fresh one.
            let url = modelConfiguration.url
            do {
                try FileManager.default.removeItem(at: url)
                // Also remove journal/wal files if present
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + "-wal"))
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + "-shm"))
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    private let healthKitManager = HealthKitManager()

    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(healthKitManager)
                .task(id: autoSyncHealthKit) {
                    guard autoSyncHealthKit else { return }
                    let context = sharedModelContainer.mainContext
                    await healthKitManager.importWeightData(modelContext: context)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
