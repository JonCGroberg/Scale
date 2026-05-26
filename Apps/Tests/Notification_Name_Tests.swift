//
//  Notification_Name_Tests.swift
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

// MARK: - Notification Name Tests

@MainActor
struct NotificationNameTests {

    @Test func notificationNameIsCorrect() {
        #expect(Notification.Name.didTapWeightReminder.rawValue == "didTapWeightReminder")
    }

    @Test func notificationPostAndReceive() async {
        let received = UnsafeSendable(value: false)

        let observer = NotificationCenter.default.addObserver(
            forName: .didTapWeightReminder,
            object: nil,
            queue: .main
        ) { _ in
            received.value = true
        }

        NotificationCenter.default.post(name: .didTapWeightReminder, object: nil)

        // Give run loop a moment to deliver
        try? await Task.sleep(for: .milliseconds(100))

        #expect(received.value == true)
        NotificationCenter.default.removeObserver(observer)
    }

    @Test func notificationDelegateConformsToProtocol() {
        let delegate = NotificationDelegate()
        // Verify it conforms to UNUserNotificationCenterDelegate
        let conforming: UNUserNotificationCenterDelegate = delegate
        #expect(conforming is NotificationDelegate)
    }
}

/// A simple wrapper to allow mutation of a value in a Sendable context for testing.
private final class UnsafeSendable<T>: @unchecked Sendable {
    var value: T
    init(value: T) { self.value = value }
}

