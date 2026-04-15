//
//  HealthKitManager_ImportResult_Tests.swift
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

// MARK: - HealthKitManager ImportResult Tests

struct HealthKitImportResultTests {

    @Test func successResultEquality() {
        let a = HealthKitManager.ImportResult.success(imported: 3, skipped: 2, removed: 1)
        let b = HealthKitManager.ImportResult.success(imported: 3, skipped: 2, removed: 1)
        #expect(a == b)
    }

    @Test func successResultInequality() {
        let a = HealthKitManager.ImportResult.success(imported: 3, skipped: 2, removed: 1)
        let b = HealthKitManager.ImportResult.success(imported: 5, skipped: 0, removed: 0)
        #expect(a != b)
    }

    @Test func errorResultEquality() {
        let a = HealthKitManager.ImportResult.error("fail")
        let b = HealthKitManager.ImportResult.error("fail")
        #expect(a == b)
    }

    @Test func errorResultInequality() {
        let a = HealthKitManager.ImportResult.error("fail")
        let b = HealthKitManager.ImportResult.error("different")
        #expect(a != b)
    }

    @Test func successAndErrorAreNotEqual() {
        let success = HealthKitManager.ImportResult.success(imported: 0, skipped: 0, removed: 0)
        let error = HealthKitManager.ImportResult.error("error")
        #expect(success != error)
    }
}

