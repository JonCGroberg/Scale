//
//  NotificationManager_ModelContext_Tests.swift
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

// MARK: - NotificationManager ModelContext Tests

struct NotificationManagerModelContextTests {

    @Test func modelContextIsNilByDefault() {
        let manager = NotificationManager()
        #expect(manager.modelContext == nil)
    }

    @Test func modelContextCanBeAssigned() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let manager = NotificationManager()
        manager.modelContext = ModelContext(container)
        #expect(manager.modelContext != nil)
    }

    @Test func rescheduleRemindersWithoutContextDoesNotCrash() {
        // If modelContext is nil, rescheduleReminders should silently use the generic body.
        let manager = NotificationManager()
        manager.rescheduleReminders() // should not throw or crash
    }

    @Test func rescheduleRemindersWithContextAndNoEntriesDoesNotCrash() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let manager = NotificationManager()
        manager.modelContext = ModelContext(container)
        manager.rescheduleReminders() // should not throw or crash
    }
}

