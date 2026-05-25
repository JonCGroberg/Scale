//
//  App_Tint_Tests.swift
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

// MARK: - App Tint Tests

struct AppTintTests {

    @Test func presetCasesCount() {
        #expect(AppTint.presets.count == 6)
    }

    @Test func defaultValueIsBlue() {
        #expect(AppTint.defaultValue == .blue)
    }

    @Test func rawValueLookupFindsSavedTint() {
        #expect(AppTint(rawValue: "green") == .green)
    }

    @Test func rawValueLookupFindsLavenderTint() {
        #expect(AppTint(rawValue: "lavender") == .lavender)
    }

    @Test func titlesMatchDisplayNames() {
        #expect(AppTint.blue.title == "Blue")
        #expect(AppTint.green.title == "Green")
        #expect(AppTint.orange.title == "Orange")
        #expect(AppTint.pink.title == "Pink")
        #expect(AppTint.lavender.title == "Lavender")
        #expect(AppTint.red.title == "Red")
    }

    @Test func customCaseProperties() {
        #expect(AppTint.custom.rawValue == "custom")
        #expect(AppTint.custom.title == "Custom")
    }

    @Test func customColorParsesSavedHex() {
        UserDefaults.standard.set("#FF0000", forKey: "customTintHex")
        defer { UserDefaults.standard.removeObject(forKey: "customTintHex") }
        #expect(AppTint.custom.color.toHex() == "#FF0000")
    }
}

