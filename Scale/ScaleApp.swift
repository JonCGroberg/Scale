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
        let diskConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try Self.makeModelContainer(schema: schema, configuration: diskConfiguration)
        } catch {
            NSLog("Falling back to in-memory SwiftData store after persistent store failure: %@", String(describing: error))

            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
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
                .onAppear {
                    // Provide the data store so NotificationManager can look up the
                    // current streak when scheduling reminders.
                    notificationManager.modelContext = sharedModelContainer.mainContext
                    notificationManager.rescheduleReminders()
                }
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

    static func makeModelContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        fileManager: FileManager = .default
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            try resetStoreFiles(for: configuration, fileManager: fileManager)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    static func resetStoreFiles(
        for configuration: ModelConfiguration,
        fileManager: FileManager
    ) throws {
        let storeURL = configuration.url

        if fileManager.fileExists(atPath: storeURL.path()) {
            try fileManager.removeItem(at: storeURL)
        }

        let siblingURLs = try fileManager.contentsOfDirectory(
            at: storeURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )

        for siblingURL in storeCompanionURLs(for: storeURL, among: siblingURLs) {
            try? fileManager.removeItem(at: siblingURL)
        }
    }

    static func storeCompanionURLs(for storeURL: URL, among siblingURLs: [URL]) -> [URL] {
        let baseName = storeURL.lastPathComponent
        return siblingURLs.filter { siblingURL in
            siblingURL != storeURL && siblingURL.lastPathComponent.hasPrefix(baseName)
        }
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
