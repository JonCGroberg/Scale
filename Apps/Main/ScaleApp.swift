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
            WorkoutEntry.self,
            DailyActivitySummary.self,
            SleepEntry.self,
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
    @State private var selectedTab = 3
    @State private var didInitializeTab = false
    @State private var showLog = false

    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false
    @AppStorage("badgePeriodIndex") private var badgePeriodIndex = 0
    @AppStorage("hasCompletedOnboarding_v2") private var hasCompletedOnboarding = false

    private static let notificationDelegate = NotificationDelegate()

    init() {
        Self.notificationDelegate.notificationManager = notificationManager
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView(selectedTab: $selectedTab, showLog: $showLog)
                    .environment(healthKitManager)
                    .environment(notificationManager)
                    .onAppear {
                        if !didInitializeTab {
                            selectedTab = 3
                            badgePeriodIndex = 0
                            didInitializeTab = true
                        }
                        
                        // Provide the data store so NotificationManager can look up the
                        // current streak when scheduling reminders.
                        notificationManager.modelContext = sharedModelContainer.mainContext
                        notificationManager.rescheduleReminders()

                        // Mock data is opt-in for Debug screenshots only. Keeping this
                        // behind an explicit launch argument prevents a fresh real user
                        // install from being seeded or backfilled at startup.
                        if Self.isMockDataSeedingEnabled {
                            populateMockDataIfNeeded()
                        }

                        // Automatically open the log sheet if the user hasn't
                        // recorded a weight entry today yet.
                        // if !notificationManager.todayHasWeightEntry() {
                        //     showLog = true
                        // }
                    }
                    .task(id: autoSyncHealthKit) {
                        guard autoSyncHealthKit else { return }
                        let context = sharedModelContainer.mainContext
                        await healthKitManager.importAllData(modelContext: context)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .didTapWeightReminder)) { _ in
                        showLog = true
                    }
            } else {
                OnboardingView()
                    .environment(healthKitManager)
                    .environment(notificationManager)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private static var isMockDataSeedingEnabled: Bool {
        #if DEBUG
        shouldSeedMockData(arguments: ProcessInfo.processInfo.arguments, isDebugBuild: true)
        #else
        false
        #endif
    }

    static func shouldSeedMockData(arguments: [String], isDebugBuild: Bool) -> Bool {
        isDebugBuild && arguments.contains("-seedMockData")
    }

    private func populateMockDataIfNeeded() {
        let context = sharedModelContainer.mainContext
        do {
            let descriptor = FetchDescriptor<WeightEntry>()
            let count = try context.fetchCount(descriptor)

            if count > 0 {
                try backfillMockSleepIfNeeded(in: context)
                try backfillMockActivityIfNeeded(in: context)
                return
            }
            
            // Set some beautiful defaults so it matches
            UserDefaults.standard.set("lose", forKey: "weightGoal")
            UserDefaults.standard.set(178.0, forKey: "cutTargetWeight")
            UserDefaults.standard.set("blue", forKey: "appTint")
            
            // Pre-populate mock mini goals for 'lose' weight goal
            let miniGoals = [
                MiniGoal(parentGoal: .lose, name: "First Milestone", targetWeight: 183.0),
                MiniGoal(parentGoal: .lose, name: "Midway Point", targetWeight: 181.0),
                MiniGoal(parentGoal: .lose, name: "Almost There", targetWeight: 179.5)
            ]
            MiniGoalStore.save(miniGoals, for: .lose)
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            // Weight decreases smoothly from 185.0 to 178.6 over 30 days
            for dayOffset in (0..<30).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                
                let progressFraction = Double(30 - dayOffset) / 30.0
                let simulatedWeight = 185.0 - (6.4 * progressFraction) + Double.random(in: -0.4...0.4)
                let roundedWeight = round(simulatedWeight * 10) / 10.0
                
                let notes = [
                    "Feeling lighter today",
                    "Morning weigh-in, post-cardio",
                    "Hydrated and feeling energized",
                    "Great sleep last night",
                    "Consistency is paying off!",
                    "Weight is steady",
                    "After morning run"
                ]
                let note = dayOffset % 4 == 0 ? notes.randomElement() : nil
                
                let entry = WeightEntry(
                    weight: roundedWeight,
                    timestamp: date,
                    source: .manual,
                    note: note,
                    streakCount: 30 - dayOffset
                )
                context.insert(entry)
                
                // Add daily activity
                let steps = Int.random(in: 8500...13000)
                let activeEnergy = Double.random(in: 350...650)
                let activity = DailyActivitySummary(
                    date: date,
                    stepCount: steps,
                    activeEnergyBurnedKilocalories: activeEnergy
                )
                context.insert(activity)

                Self.insertMockSleepForDay(date: date, context: context)
                
                // Add a workout every 3 days
                if dayOffset % 3 == 0 {
                    // HKWorkoutActivityType running is 52, cycling is 13, functionalStrengthTraining is 50
                    let activityType: UInt = dayOffset % 6 == 0 ? 52 : (dayOffset % 9 == 0 ? 13 : 50)
                    let duration = TimeInterval.random(in: 1800...3600)
                    let energy = duration / 60.0 * 8.5
                    let workout = WorkoutEntry(
                        timestamp: calendar.date(byAdding: .hour, value: 8, to: date) ?? date,
                        activityTypeRawValue: activityType,
                        duration: duration,
                        energyBurnedKilocalories: energy,
                        distanceMiles: activityType == 52 ? (duration / 60.0 * 0.1) : nil
                    )
                    context.insert(workout)
                }
            }
            
            try context.save()
            NSLog("Successfully pre-populated 30 days of mock weight entries, workouts, activity summaries, sleep entries, and mini goals.")
        } catch {
            NSLog("Failed to pre-populate mock data: %@", String(describing: error))
        }
    }

    static func resetAndPopulateMockData(context: ModelContext) {
        do {
            // Clear existing models
            try context.delete(model: WeightEntry.self)
            try context.delete(model: WorkoutEntry.self)
            try context.delete(model: DailyActivitySummary.self)
            try context.delete(model: SleepEntry.self)
            try context.save()
            
            // Set beautiful defaults
            UserDefaults.standard.set("lose", forKey: "weightGoal")
            UserDefaults.standard.set(178.0, forKey: "cutTargetWeight")
            UserDefaults.standard.set("blue", forKey: "appTint")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_v2")
            
            // Set mock mini goals
            let miniGoals = [
                MiniGoal(parentGoal: .lose, name: "First Milestone", targetWeight: 183.0),
                MiniGoal(parentGoal: .lose, name: "Midway Point", targetWeight: 181.0),
                MiniGoal(parentGoal: .lose, name: "Almost There", targetWeight: 179.5)
            ]
            MiniGoalStore.save(miniGoals, for: .lose)
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            // Weight decreases smoothly from 185.0 to 178.6 over 30 days
            for dayOffset in (0..<30).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                
                let progressFraction = Double(30 - dayOffset) / 30.0
                let simulatedWeight = 185.0 - (6.4 * progressFraction) + Double.random(in: -0.4...0.4)
                let roundedWeight = round(simulatedWeight * 10) / 10.0
                
                let notes = [
                    "Feeling lighter today",
                    "Morning weigh-in, post-cardio",
                    "Hydrated and feeling energized",
                    "Great sleep last night",
                    "Consistency is paying off!",
                    "Weight is steady",
                    "After morning run"
                ]
                let note = dayOffset % 4 == 0 ? notes.randomElement() : nil
                
                let entry = WeightEntry(
                    weight: roundedWeight,
                    timestamp: date,
                    source: .manual,
                    note: note,
                    streakCount: 30 - dayOffset
                )
                context.insert(entry)
                
                // Add daily activity
                let steps = Int.random(in: 8500...13000)
                let activeEnergy = Double.random(in: 350...650)
                let activity = DailyActivitySummary(
                    date: date,
                    stepCount: steps,
                    activeEnergyBurnedKilocalories: activeEnergy
                )
                context.insert(activity)

                Self.insertMockSleepForDay(date: date, context: context)
                
                // Add a workout every 3 days
                if dayOffset % 3 == 0 {
                    let activityType: UInt = dayOffset % 6 == 0 ? 52 : (dayOffset % 9 == 0 ? 13 : 50)
                    let duration = TimeInterval.random(in: 1800...3600)
                    let energy = duration / 60.0 * 8.5
                    let workout = WorkoutEntry(
                        timestamp: calendar.date(byAdding: .hour, value: 8, to: date) ?? date,
                        activityTypeRawValue: activityType,
                        duration: duration,
                        energyBurnedKilocalories: energy,
                        distanceMiles: activityType == 52 ? (duration / 60.0 * 0.1) : nil
                    )
                    context.insert(workout)
                }
            }
            
            try context.save()
            NSLog("Developer Reset: Successfully purged database and repopulated 30 days of mock weight entries, workouts, activity summaries, and sleep entries.")
        } catch {
            NSLog("Developer Reset: Failed to purge/repopulate mock data: %@", String(describing: error))
        }
    }

    private func backfillMockActivityIfNeeded(in context: ModelContext) throws {
        let activityCount = try context.fetchCount(FetchDescriptor<DailyActivitySummary>())
        guard activityCount == 0 else { return }

        let calendar = Calendar.current
        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.timestamp) })

        for day in uniqueDays {
            context.insert(
                DailyActivitySummary(
                    date: day,
                    stepCount: Int.random(in: 8500...13000),
                    activeEnergyBurnedKilocalories: Double.random(in: 350...650)
                )
            )
        }

        try context.save()
    }

    private static func insertMockSleepForDay(date: Date, context: ModelContext) {
        let calendar = Calendar.current
        guard let sleepEnd = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date) else { return }
        
        let deepStart = calendar.date(byAdding: .hour, value: -8, to: sleepEnd)!
        let deepEnd = calendar.date(byAdding: .minute, value: 90, to: deepStart)!
        context.insert(
            SleepEntry(
                startDate: deepStart,
                endDate: deepEnd,
                duration: deepEnd.timeIntervalSince(deepStart),
                stage: .deep
            )
        )
        
        let coreStart = deepEnd
        let coreEnd = calendar.date(byAdding: .hour, value: 4, to: coreStart)!
        context.insert(
            SleepEntry(
                startDate: coreStart,
                endDate: coreEnd,
                duration: coreEnd.timeIntervalSince(coreStart),
                stage: .core
            )
        )
        
        let remStart = coreEnd
        let remEnd = calendar.date(byAdding: .minute, value: 90, to: remStart)!
        context.insert(
            SleepEntry(
                startDate: remStart,
                endDate: remEnd,
                duration: remEnd.timeIntervalSince(remStart),
                stage: .rem
            )
        )

        let unspecifiedStart = remEnd
        let unspecifiedEnd = sleepEnd
        context.insert(
            SleepEntry(
                startDate: unspecifiedStart,
                endDate: unspecifiedEnd,
                duration: unspecifiedEnd.timeIntervalSince(unspecifiedStart),
                stage: .unspecified
            )
        )
    }

    private func backfillMockSleepIfNeeded(in context: ModelContext) throws {
        let sleepCount = try context.fetchCount(FetchDescriptor<SleepEntry>())
        guard sleepCount == 0 else { return }

        let calendar = Calendar.current
        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.timestamp) })

        for day in uniqueDays {
            Self.insertMockSleepForDay(date: day, context: context)
        }

        try context.save()
        NSLog("Backfilled mock sleep entries with rich stages.")
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
    /// Set by the app so the delegate can check if today already has a log.
    var notificationManager: NotificationManager?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationCenter.default.post(name: .didTapWeightReminder, object: nil)
    }

    // Show banner even when the app is in the foreground,
    // but suppress it if the user already logged today.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notificationManager?.todayHasWeightEntry() == true {
            return []
        }
        return [.banner, .sound]
    }
}

extension Notification.Name {
    static let didTapWeightReminder = Notification.Name("didTapWeightReminder")
    static let didMoveCloserToGoal = Notification.Name("didMoveCloserToGoal")
    static let didReachWeightGoal = Notification.Name("didReachWeightGoal")
    static let didLogFirstWeight = Notification.Name("didLogFirstWeight")
    static let didSetNewMaxStreak = Notification.Name("didSetNewMaxStreak")
}
