//
//  Reminder_Model_Tests.swift
//  ScaleTests
//
//  Split from monolithic ScaleTests.swift for maintainability.
//

import Testing
import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import XCTest
@testable import Scale

// MARK: - Reminder Model Tests

@MainActor
struct ReminderModelTests {
    private let remindersEnabledKey = "remindersEnabled"
    private let savedRemindersKey = "savedReminders"

    private func withClearedReminderDefaults(_ body: () throws -> Void) rethrows {
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
                defaults.set(existingReminders, forKey: savedRemindersKey)
            } else {
                defaults.removeObject(forKey: savedRemindersKey)
            }
        }

        try body()
    }

    @Test func reminderDefaultValues() {
        let reminder = Reminder()
        #expect(reminder.name == "Weigh In")
        #expect(reminder.hour == 8)
        #expect(reminder.minute == 0)
    }

    @Test func reminderCustomValues() {
        let reminder = Reminder(name: "Morning", hour: 7, minute: 30)
        #expect(reminder.name == "Morning")
        #expect(reminder.hour == 7)
        #expect(reminder.minute == 30)
    }

    @Test func reminderEncodesAndDecodes() throws {
        let original = Reminder(name: "Evening", hour: 20, minute: 15)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)
        #expect(decoded == original)
    }

    @Test func reminderArrayEncodesAndDecodes() throws {
        let reminders = [
            Reminder(name: "Morning", hour: 8, minute: 0),
            Reminder(name: "Evening", hour: 20, minute: 0)
        ]
        let data = try JSONEncoder().encode(reminders)
        let decoded = try JSONDecoder().decode([Reminder].self, from: data)
        #expect(decoded == reminders)
    }

    @Test func reminderHasUniqueIds() {
        let a = Reminder()
        let b = Reminder()
        #expect(a.id != b.id)
    }

    @Test func enabledFlagDefaultsToFalse() {
        withClearedReminderDefaults {
            #expect(UserDefaults.standard.bool(forKey: remindersEnabledKey) == false)
        }
    }

    @Test func enabledFlagToggles() {
        withClearedReminderDefaults {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: remindersEnabledKey)
            #expect(defaults.bool(forKey: remindersEnabledKey) == true)

            defaults.set(false, forKey: remindersEnabledKey)
            #expect(defaults.bool(forKey: remindersEnabledKey) == false)
        }
    }

    @Test func saveAndLoadReminders() {
        withClearedReminderDefaults {
            let manager = NotificationManager()
            let reminders = [
                Reminder(name: "Morning", hour: 8, minute: 0),
                Reminder(name: "Night", hour: 21, minute: 30)
            ]
            manager.saveReminders(reminders)
            let loaded = manager.loadReminders()
            #expect(loaded == reminders)
        }
    }

    @Test func loadRemindersReturnsEmptyWhenNoneSaved() {
        withClearedReminderDefaults {
            let manager = NotificationManager()
            let loaded = manager.loadReminders()
            #expect(loaded.isEmpty)
        }
    }

    @Test func loadRemindersReturnsEmptyForCorruptData() {
        withClearedReminderDefaults {
            UserDefaults.standard.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: savedRemindersKey)

            let manager = NotificationManager()
            let loaded = manager.loadReminders()

            #expect(loaded.isEmpty)
        }
    }
}

