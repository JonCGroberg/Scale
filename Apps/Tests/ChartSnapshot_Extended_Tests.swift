//
//  ChartSnapshot_Extended_Tests.swift
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

// MARK: - ChartSnapshot Extended Tests

struct ChartSnapshotExtendedTests {

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    @Test func chartSnapshotEmptyReturnsStableDefaults() {
        let empty = WeightCalculations.ChartSnapshot.empty

        #expect(empty.entries.isEmpty)
        #expect(empty.smoothedEntries.isEmpty)
        #expect(empty.trendEntries.isEmpty)
        #expect(empty.yDomain == 0...1)
    }

    @Test func chartSnapshotSingleEntryProducesOnePointSeries() {
        let entries = [WeightEntry(weight: 175.0, timestamp: Date())]
        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .week)

        #expect(snapshot.entries.count == 1)
        #expect(snapshot.smoothedEntries.count == 1)
        #expect(snapshot.trendEntries.count == 1)
        // First smoothed point should equal the raw value
        #expect(snapshot.smoothedEntries[0].weight == 175.0)
    }

    @Test func trendEntriesAreSmoother() {
        let entries = [
            WeightEntry(weight: 180.0, timestamp: daysAgo(6)),
            WeightEntry(weight: 190.0, timestamp: daysAgo(4)),
            WeightEntry(weight: 170.0, timestamp: daysAgo(2)),
        ]

        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .month)

        // Trend (lower alpha) should be smoother than smoothed
        // Both start at the same point, but trend should deviate less from previous
        #expect(snapshot.trendEntries.count == 3)
        #expect(snapshot.smoothedEntries.count == 3)

        let smoothedRange = snapshot.smoothedEntries.map(\.weight).max()! - snapshot.smoothedEntries.map(\.weight).min()!
        let trendRange = snapshot.trendEntries.map(\.weight).max()! - snapshot.trendEntries.map(\.weight).min()!

        #expect(trendRange < smoothedRange)
        #expect(trendRange > 5.0)
    }

    @Test func yDomainProvidesOnePoundPaddingAroundExtremes() {
        let entries = [
            WeightEntry(weight: 175.0, timestamp: daysAgo(3)),
            WeightEntry(weight: 185.0, timestamp: Date()),
        ]
        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .week)

        #expect(snapshot.yDomain.lowerBound == 174.0)
        #expect(snapshot.yDomain.upperBound == 186.0)
    }
}
