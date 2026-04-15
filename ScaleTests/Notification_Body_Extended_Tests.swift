//
//  Notification_Body_Extended_Tests.swift
//  ScaleTests
//
//  Extended tests for notification body generation and request construction edge cases.
//

import Testing
import Foundation
import UserNotifications
@testable import Scale

struct NotificationBodyExtendedTests {

    // MARK: - notificationBody edge cases

    @Test func streakOfExactlyTwoShowsStreakMessage() {
        let body = NotificationManager.notificationBody(forPotentialStreak: 2)
        #expect(body.contains("2-day streak"))
    }

    @Test func streakOfOneShowsGenericMessage() {
        let body = NotificationManager.notificationBody(forPotentialStreak: 1)
        #expect(body == "Tap to log your weight.")
    }

    @Test func negativeStreakShowsGenericMessage() {
        // Defensive: negative values should not crash
        let body = NotificationManager.notificationBody(forPotentialStreak: -1)
        #expect(body == "Tap to log your weight.")
    }

    @Test func largeStreakShowsCorrectMessage() {
        let body = NotificationManager.notificationBody(forPotentialStreak: 365)
        #expect(body == "Keep your 365-day streak going — log your weight today!")
    }

    // MARK: - makeNotificationRequest edge cases

    @Test func notificationRequestHasDefaultSound() {
        let reminder = Reminder(name: "Test", hour: 6, minute: 0)
        let request = NotificationManager.makeNotificationRequest(
            reminder: reminder,
            body: "Test",
            categoryIdentifier: "CAT"
        )
        #expect(request.content.sound == .default)
    }

    @Test func notificationRequestCategoryIdentifierMatches() {
        let reminder = Reminder(name: "Test", hour: 6, minute: 0)
        let request = NotificationManager.makeNotificationRequest(
            reminder: reminder,
            body: "body",
            categoryIdentifier: "CUSTOM_CAT"
        )
        #expect(request.content.categoryIdentifier == "CUSTOM_CAT")
    }

    @Test func notificationTriggerRepeats() {
        let reminder = Reminder(name: "Daily", hour: 8, minute: 30)
        let request = NotificationManager.makeNotificationRequest(
            reminder: reminder,
            body: "body",
            categoryIdentifier: "CAT"
        )
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.repeats == true)
    }

    @Test func notificationRequestIdentifierIsStable() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let reminder = Reminder(id: id, name: "Stable", hour: 0, minute: 0)

        let id1 = NotificationManager.requestIdentifier(for: reminder)
        let id2 = NotificationManager.requestIdentifier(for: reminder)

        #expect(id1 == id2)
        #expect(id1 == "weightReminder_AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
    }

    // MARK: - Reminder date components edge cases

    @Test func midnightReminderDateComponents() {
        let reminder = Reminder(name: "Midnight", hour: 0, minute: 0)
        let components = NotificationManager.reminderDateComponents(for: reminder)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test func endOfDayReminderDateComponents() {
        let reminder = Reminder(name: "Late", hour: 23, minute: 59)
        let components = NotificationManager.reminderDateComponents(for: reminder)
        #expect(components.hour == 23)
        #expect(components.minute == 59)
    }
}
