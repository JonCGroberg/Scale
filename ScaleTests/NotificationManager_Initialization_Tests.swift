//
//  NotificationManager_Initialization_Tests.swift
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

// MARK: - NotificationManager Initialization Tests

struct NotificationManagerTests {
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

    @Test func initializedWithIsAuthorizedFalse() {
        let manager = NotificationManager()
        // Before any authorization request, the default should be false
        #expect(manager.isAuthorized == false)
    }

    @Test func loadRemindersRoundTripsEmptyArray() {
        withClearedReminderDefaults {
            let manager = NotificationManager()
            manager.saveReminders([])
            #expect(manager.loadReminders().isEmpty)
        }
    }

    @Test func notificationBodyUsesGenericCopyBelowThreshold() {
        #expect(NotificationManager.notificationBody(forPotentialStreak: 0) == "Tap to log your weight.")
        #expect(NotificationManager.notificationBody(forPotentialStreak: 1) == "Tap to log your weight.")
    }

    @Test func notificationBodyIncludesStreakAtThresholdAndAbove() {
        #expect(NotificationManager.notificationBody(forPotentialStreak: 2) == "Keep your 2-day streak going — log your weight today!")
        #expect(NotificationManager.notificationBody(forPotentialStreak: 9) == "Keep your 9-day streak going — log your weight today!")
    }

    @Test func reminderDateComponentsMatchReminderTime() {
        let reminder = Reminder(name: "Evening", hour: 21, minute: 45)

        let components = NotificationManager.reminderDateComponents(for: reminder)

        #expect(components.hour == 21)
        #expect(components.minute == 45)
    }

    @Test func requestIdentifierUsesReminderID() {
        let reminder = Reminder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!)

        #expect(
            NotificationManager.requestIdentifier(for: reminder)
            == "weightReminder_00000000-0000-0000-0000-000000000123"
        )
    }

    @Test func makeNotificationRequestUsesReminderBodyAndCategory() {
        let reminder = Reminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000456")!,
            name: "Morning Weigh In",
            hour: 7,
            minute: 15
        )

        let request = NotificationManager.makeNotificationRequest(
            reminder: reminder,
            body: "Test body",
            categoryIdentifier: "WEIGHT_REMINDER"
        )

        #expect(request.identifier == "weightReminder_00000000-0000-0000-0000-000000000456")
        #expect(request.content.title == "Morning Weigh In")
        #expect(request.content.body == "Test body")
        #expect(request.content.categoryIdentifier == "WEIGHT_REMINDER")

        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger != nil)
        #expect(trigger?.repeats == true)
        #expect(trigger?.dateComponents.hour == 7)
        #expect(trigger?.dateComponents.minute == 15)
    }
}

