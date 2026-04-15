//
//  ChartPoint_Equality_Tests.swift
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

// MARK: - ChartPoint Equality Tests

struct ChartPointEqualityTests {

    @Test func equalPointsAreEqual() {
        let date = Date()
        let a = WeightCalculations.ChartPoint(timestamp: date, weight: 180.0)
        let b = WeightCalculations.ChartPoint(timestamp: date, weight: 180.0)
        #expect(a == b)
    }

    @Test func differentWeightsMakePointsUnequal() {
        let date = Date()
        let a = WeightCalculations.ChartPoint(timestamp: date, weight: 180.0)
        let b = WeightCalculations.ChartPoint(timestamp: date, weight: 181.0)
        #expect(a != b)
    }

    @Test func differentTimestampsMakePointsUnequal() {
        let a = WeightCalculations.ChartPoint(timestamp: Date(), weight: 180.0)
        let b = WeightCalculations.ChartPoint(timestamp: Date().addingTimeInterval(60), weight: 180.0)
        #expect(a != b)
    }
}

