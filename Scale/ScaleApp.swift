//
//  ScaleApp.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UserNotifications

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
    private let notificationManager = NotificationManager()
    @State private var selectedTab = 0

    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false

    private static let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView(selectedTab: $selectedTab)
                .environment(healthKitManager)
                .environment(notificationManager)
                .task(id: autoSyncHealthKit) {
                    guard autoSyncHealthKit else { return }
                    let context = sharedModelContainer.mainContext
                    await healthKitManager.importWeightData(modelContext: context)
                }
                .onReceive(NotificationCenter.default.publisher(for: .didTapWeightReminder)) { _ in
                    selectedTab = 0
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
// MARK: - Notification Delegate

/// Handles notification taps while the app is in the foreground or background.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationCenter.default.post(name: .didTapWeightReminder, object: nil)
    }

    // Show banner even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension Notification.Name {
    static let didTapWeightReminder = Notification.Name("didTapWeightReminder")
}

