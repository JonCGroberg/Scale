//
//  NotificationManager_Scheduling_Tests.swift
//  ScaleTests
//
//  Tests for NotificationManager reminder persistence, loading, and
//  the notification body generation logic.
//

import Testing
import Foundation
import SwiftData
@testable import Scale

struct NotificationManagerSchedulingTests {

    private let remindersEnabledKey = "remindersEnabled"
    private let savedRemindersKey = "savedReminders"

    private func withClearedDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let existingEnabled = defaults.object(forKey: remindersEnabledKey)
        let existingReminders = defaults.object(forKey: savedRemindersKey)

        defaults.removeObject(forKey: remindersEnabledKey)
        defaults.removeObject(forKey: savedRemindersKey)
        defer {
            if let existingEnabled {
                defaults.set(existingEnabled, forKey: remindersEnabledKey)
            } else {
                defaults.removeObject(forKey: remindersEnabledKey)
            }
            if let existingReminders {
                defaults.set(existingReminders, forKey: remindersEnabledKey)
            } else {
                defaults.removeObject(forKey: savedRemindersKey)
            }
        }

        try body()
    }

    // MARK: - Reminder persistence

    @Test func saveAndLoadRemindersRoundTrip() {
        withClearedDefaults {
            let manager = NotificationManager()
            let reminders = [
                Reminder(name: "Morning", hour: 7, minute: 0),
                Reminder(name: "Evening", hour: 20, minute: 30)
            ]

            manager.saveReminders(reminders)
            let loaded = manager.loadReminders()

            #expect(loaded.count == 2)
            #expect(loaded[0].name == "Morning")
            #expect(loaded[0].hour == 7)
            #expect(loaded[1].name == "Evening")
            #expect(loaded[1].hour == 20)
            #expect(loaded[1].minute == 30)
        }
    }

    @Test func loadRemindersReturnsEmptyWhenNothingSaved() {
        withClearedDefaults {
            let manager = NotificationManager()
            let loaded = manager.loadReminders()
            #expect(loaded.isEmpty)
        }
    }

    @Test func saveEmptyArrayClearsReminders() {
        withClearedDefaults {
            let manager = NotificationManager()
            manager.saveReminders([Reminder(name: "Test", hour: 8, minute: 0)])
            manager.saveReminders([])

            let loaded = manager.loadReminders()
            #expect(loaded.isEmpty)
        }
    }

    // MARK: - todayHasWeightEntry with SwiftData

    @Test func todayHasWeightEntryWithMultipleTodayEntries() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self,
            configurations: config
        )
        let context = ModelContext(container)
        let manager = NotificationManager()
        manager.modelContext = context

        // Insert multiple entries today
        context.insert(WeightEntry(weight: 150.0, timestamp: Date()))
        context.insert(WeightEntry(weight: 151.0, timestamp: Date().addingTimeInterval(-3600)))
        try context.save()

        #expect(manager.todayHasWeightEntry() == true)
    }

    @Test func todayHasWeightEntryWithOnlyTomorrowEntry() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self,
            configurations: config
        )
        let context = ModelContext(container)
        let manager = NotificationManager()
        manager.modelContext = context

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        context.insert(WeightEntry(weight: 150.0, timestamp: tomorrow))
        try context.save()

        #expect(manager.todayHasWeightEntry() == false)
    }

    // MARK: - Notification body with streak context

    @Test func notificationBodyBelowStreakThresholdIsGeneric() {
        for streak in [-5, -1, 0, 1] {
            let body = NotificationManager.notificationBody(forPotentialStreak: streak)
            #expect(body == "Tap to log your weight.")
        }
    }

    @Test func notificationBodyAtStreakThresholdIncludesCount() {
        let body = NotificationManager.notificationBody(forPotentialStreak: 2)
        #expect(body.contains("2-day"))
    }

    @Test func notificationBodyForLargeStreakIncludesCount() {
        let body = NotificationManager.notificationBody(forPotentialStreak: 365)
        #expect(body.contains("365-day"))
    }

    // MARK: - makeNotificationRequest properties

    @Test func notificationRequestContentHasDefaultSound() {
        let reminder = Reminder(name: "Test", hour: 9, minute: 0)
        let request = NotificationManager.makeNotificationRequest(
            reminder: reminder,
            body: "Test",
            categoryIdentifier: "CAT"
        )

        #expect(request.content.sound == .default)
    }

    @Test func notificationRequestTitleMatchesReminderName() {
        let reminder = Reminder(name: "Custom Name", hour: 12, minute: 0)
        let request = NotificationManager.makeNotificationRequest(
            reminder: reminder,
            body: "Body",
            categoryIdentifier: "CAT"
        )

        #expect(request.content.title == "Custom Name")
    }
}
