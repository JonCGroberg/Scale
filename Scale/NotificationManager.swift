//
//  NotificationManager.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/16/26.
//

import Foundation
import UserNotifications

/// A single saved reminder with a user-chosen name and time.
struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var hour: Int
    var minute: Int

    init(id: UUID = UUID(), name: String = "Weigh In", hour: Int = 8, minute: Int = 0) {
        self.id = id
        self.name = name
        self.hour = hour
        self.minute = minute
    }
}

@Observable
final class NotificationManager {
    private(set) var isAuthorized = false

    private let center = UNUserNotificationCenter.current()
    private let categoryIdentifier = "WEIGHT_REMINDER"
    private static let remindersKey = "savedReminders"

    init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
        await MainActor.run { isAuthorized = authorized }
    }

    // MARK: - Reminder Storage

    func loadReminders() -> [Reminder] {
        guard let data = UserDefaults.standard.data(forKey: Self.remindersKey),
              let reminders = try? JSONDecoder().decode([Reminder].self, from: data) else {
            return []
        }
        return reminders
    }

    func saveReminders(_ reminders: [Reminder]) {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: Self.remindersKey)
        }
        rescheduleReminders()
    }

    // MARK: - Scheduling

    /// Reschedule all reminders based on the user's saved preferences.
    func rescheduleReminders() {
        let enabled = UserDefaults.standard.bool(forKey: "remindersEnabled")
        let reminders = loadReminders()

        // Remove existing reminders
        center.removeAllPendingNotificationRequests()

        guard enabled, !reminders.isEmpty else { return }

        for reminder in reminders {
            var dateComponents = DateComponents()
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = reminder.name
            content.body = "Tap to log your weight and keep your streak going."
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier

            let request = UNNotificationRequest(
                identifier: "weightReminder_\(reminder.id.uuidString)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }
}
