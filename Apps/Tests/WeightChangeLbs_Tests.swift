//
//  WeightChangeLbs_Tests.swift
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

// MARK: - WeightChangeLbs Tests

struct WeightChangeLbsTests {

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    @Test func positiveChangeForWeightGain() {
        let entries = [
            WeightEntry(weight: 155.0, timestamp: Date()),
            WeightEntry(weight: 150.0, timestamp: daysAgo(5)),
        ]
        let change = WeightCalculations.weightChangeLbs(from: entries, over: .week)
        #expect(change != nil)
        #expect(change == 5.0)
    }

    @Test func negativeChangeForWeightLoss() {
        let entries = [
            WeightEntry(weight: 145.0, timestamp: Date()),
            WeightEntry(weight: 150.0, timestamp: daysAgo(5)),
        ]
        let change = WeightCalculations.weightChangeLbs(from: entries, over: .week)
        #expect(change != nil)
        #expect(change == -5.0)
    }

    @Test func nilForSingleEntry() {
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        #expect(WeightCalculations.weightChangeLbs(from: entries, over: .week) == nil)
    }

    @Test func nilForNoEntries() {
        #expect(WeightCalculations.weightChangeLbs(from: [], over: .month) == nil)
    }

    @Test func nilWhenEntriesOutsidePeriod() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: daysAgo(400)),
            WeightEntry(weight: 145.0, timestamp: daysAgo(401)),
        ]
        #expect(WeightCalculations.weightChangeLbs(from: entries, over: .week) == nil)
    }

    @Test func zeroChangeWhenWeightUnchanged() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 150.0, timestamp: daysAgo(3)),
        ]
        let change = WeightCalculations.weightChangeLbs(from: entries, over: .week)
        #expect(change == 0.0)
    }

    @Test func usesEarliestAndLatestInPeriod() {
        let entries = [
            WeightEntry(weight: 155.0, timestamp: Date()),
            WeightEntry(weight: 152.0, timestamp: daysAgo(3)),
            WeightEntry(weight: 150.0, timestamp: daysAgo(6)),
        ]
        let change = WeightCalculations.weightChangeLbs(from: entries, over: .week)
        #expect(change != nil)
        // earliest=150, latest=155 → 5.0
        #expect(change == 5.0)
    }
}

