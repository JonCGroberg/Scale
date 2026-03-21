//
//  NotificationManager.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/16/26.
//

import Foundation
import UserNotifications
import SwiftData

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

    /// A reference to the main model context, used to read the current streak when scheduling notifications.
    var modelContext: ModelContext?

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
            let request = Self.makeNotificationRequest(
                reminder: reminder,
                body: notificationBody(),
                categoryIdentifier: categoryIdentifier
            )

            center.add(request)
        }
    }

    // MARK: - Notification Body

    /// Generates a streak-aware notification body.
    /// A potential streak of 2 or more (i.e. logging today would continue a consecutive run)
    /// surfaces a motivating message; otherwise a generic prompt is shown.
    private func notificationBody() -> String {
        guard let context = modelContext else {
            return Self.notificationBody(forPotentialStreak: 0)
        }
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        // `includingToday: true` returns what the streak will be once today is logged,
        // which is exactly what we want to motivate the user to act on.
        let potentialStreak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        return Self.notificationBody(forPotentialStreak: potentialStreak)
    }

    static func notificationBody(forPotentialStreak potentialStreak: Int) -> String {
        if potentialStreak >= 2 {
            return "Keep your \(potentialStreak)-day streak going — log your weight today!"
        }
        return "Tap to log your weight."
    }

    static func reminderDateComponents(for reminder: Reminder) -> DateComponents {
        var dateComponents = DateComponents()
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute
        return dateComponents
    }

    static func requestIdentifier(for reminder: Reminder) -> String {
        "weightReminder_\(reminder.id.uuidString)"
    }

    static func makeNotificationRequest(
        reminder: Reminder,
        body: String,
        categoryIdentifier: String
    ) -> UNNotificationRequest {
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: reminderDateComponents(for: reminder),
            repeats: true
        )

        let content = UNMutableNotificationContent()
        content.title = reminder.name
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        return UNNotificationRequest(
            identifier: requestIdentifier(for: reminder),
            content: content,
            trigger: trigger
        )
    }
}
