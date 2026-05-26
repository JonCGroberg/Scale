//
//  Percentage_Change_Tests.swift
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

// MARK: - Percentage Change Tests

struct PercentageChangeTests {

    @Test func positivePercentageChange() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 110.0, timestamp: now),                                  // most recent
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-5 * 86400))     // oldest in range
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct! - 10.0) < 0.01)  // (110-100)/100 * 100 = 10%
    }

    @Test func negativePercentageChange() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 90.0, timestamp: now),
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct! - (-10.0)) < 0.01)
    }

    @Test func zeroPercentageWhenUnchanged() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 150.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct!) < 0.01)
    }

    @Test func percentageIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct == nil)
    }

    @Test func percentageIsNilWithNoEntries() {
        let pct = WeightCalculations.percentageChange(from: [], over: .month)
        #expect(pct == nil)
    }

    @Test func percentageUsesEarliestAndLatestInPeriod() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 155.0, timestamp: now),
            WeightEntry(weight: 152.0, timestamp: now.addingTimeInterval(-3 * 86400)),
            WeightEntry(weight: 150.0, timestamp: now.addingTimeInterval(-6 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        // earliest=150, latest=155 → (155-150)/150 * 100 = 3.33%
        let expected = ((155.0 - 150.0) / 150.0) * 100
        #expect(abs(pct! - expected) < 0.01)
    }

    @Test func percentageIsNilWhenStartingWeightIsZero() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 0.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]

        let pct = WeightCalculations.percentageChange(from: entries, over: .month)

        #expect(pct == nil)
    }
}

