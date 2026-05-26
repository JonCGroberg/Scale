//
//  Average_Weight_Tests.swift
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

// MARK: - Average Weight Tests

struct AverageWeightTests {

    @Test func averageOfEntriesWithinPeriod() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 148.0, timestamp: now.addingTimeInterval(-2 * 86400)),
            WeightEntry(weight: 146.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg != nil)
        // All 3 entries are within the last week
        let expected = (150.0 + 148.0 + 146.0) / 3.0
        #expect(abs(avg! - expected) < 0.01)
    }

    @Test func averageExcludesOldEntries() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-400 * 86400))  // >1 year ago
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg != nil)
        #expect(avg == 150.0)
    }

    @Test func averageIsNilWhenNoEntriesInPeriod() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-400 * 86400))
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg == nil)
    }

    @Test func averageIsNilForEmptyEntries() {
        let avg = WeightCalculations.averageWeight(from: [], over: .month)
        #expect(avg == nil)
    }
}

