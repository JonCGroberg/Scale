//
//  NotificationDelegate_Tests.swift
//  ScaleTests
//
//  Tests for NotificationDelegate logic: todayHasWeightEntry suppression
//  and the didTapWeightReminder notification name.
//

import Testing
import Foundation
import SwiftData
@testable import Scale

struct NotificationDelegateTests {

    // MARK: - todayHasWeightEntry (used by willPresent delegate)

    @Test func todayHasWeightEntryReturnsFalseWhenNoContext() {
        let manager = NotificationManager()
        // modelContext is nil → should return false
        #expect(manager.todayHasWeightEntry() == false)
    }

    @Test func todayHasWeightEntryReturnsFalseWhenNoEntries() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self,
            configurations: config
        )
        let manager = NotificationManager()
        manager.modelContext = ModelContext(container)

        #expect(manager.todayHasWeightEntry() == false)
    }

    @Test func todayHasWeightEntryReturnsTrueWhenEntryExistsToday() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self,
            configurations: config
        )
        let context = ModelContext(container)
        let manager = NotificationManager()
        manager.modelContext = context

        let entry = WeightEntry(weight: 150.0, timestamp: Date())
        context.insert(entry)
        try context.save()

        #expect(manager.todayHasWeightEntry() == true)
    }

    @Test func todayHasWeightEntryReturnsFalseForYesterdayEntry() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self,
            configurations: config
        )
        let context = ModelContext(container)
        let manager = NotificationManager()
        manager.modelContext = context

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let entry = WeightEntry(weight: 150.0, timestamp: yesterday)
        context.insert(entry)
        try context.save()

        #expect(manager.todayHasWeightEntry() == false)
    }

    // MARK: - Notification name

    @Test func didTapWeightReminderNotificationNameIsCorrect() {
        #expect(Notification.Name.didTapWeightReminder.rawValue == "didTapWeightReminder")
    }

    // MARK: - NotificationDelegate property assignment

    @Test func delegateAcceptsNotificationManagerAssignment() {
        let delegate = NotificationDelegate()
        let manager = NotificationManager()

        delegate.notificationManager = manager

        #expect(delegate.notificationManager != nil)
    }

    @Test func delegateWithNilManagerDefaultsToNil() {
        let delegate = NotificationDelegate()
        #expect(delegate.notificationManager == nil)
    }
}
