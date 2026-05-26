//
//  BadgeSummary_Equality_Tests.swift
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

// MARK: - BadgeSummary Equality Tests

struct BadgeSummaryEqualityTests {

    @Test func equalSummariesAreEqual() {
        let a = WeightCalculations.BadgeSummary(streak: 5, average: 180.0, weightChange: -2.0)
        let b = WeightCalculations.BadgeSummary(streak: 5, average: 180.0, weightChange: -2.0)
        #expect(a == b)
    }

    @Test func differentStreaksMakeSummariesUnequal() {
        let a = WeightCalculations.BadgeSummary(streak: 5, average: 180.0, weightChange: nil)
        let b = WeightCalculations.BadgeSummary(streak: 6, average: 180.0, weightChange: nil)
        #expect(a != b)
    }

    @Test func nilVsNonNilWeightChangeUnequal() {
        let a = WeightCalculations.BadgeSummary(streak: 5, average: 180.0, weightChange: nil)
        let b = WeightCalculations.BadgeSummary(streak: 5, average: 180.0, weightChange: -1.0)
        #expect(a != b)
    }
}

