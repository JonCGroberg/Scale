//
//  ChartSnapshot_Empty_Tests.swift
//  ScaleTests
//
//  Tests for ChartSnapshot.empty and edge cases in chartSnapshot computation.
//

import Testing
import Foundation
@testable import Scale

struct ChartSnapshotEmptyTests {

    @Test func emptyChartSnapshotHasNoEntries() {
        let empty = WeightCalculations.ChartSnapshot.empty
        #expect(empty.entries.isEmpty)
        #expect(empty.smoothedEntries.isEmpty)
        #expect(empty.trendEntries.isEmpty)
    }

    @Test func emptyChartSnapshotYDomain() {
        let empty = WeightCalculations.ChartSnapshot.empty
        #expect(empty.yDomain == 0...1)
    }

    @Test func chartSnapshotFromEmptyEntriesReturnsEmpty() {
        let snapshot = WeightCalculations.chartSnapshot(from: [], over: .week)
        #expect(snapshot.entries.isEmpty)
        #expect(snapshot.smoothedEntries.isEmpty)
        #expect(snapshot.trendEntries.isEmpty)
    }

    @Test func chartSnapshotFromSingleRecentEntryProducesOnePoint() {
        let entry = WeightEntry(weight: 150.0, timestamp: Date())
        let snapshot = WeightCalculations.chartSnapshot(from: [entry], over: .week)

        #expect(snapshot.entries.count == 1)
        #expect(snapshot.smoothedEntries.count == 1)
        #expect(snapshot.trendEntries.count == 1)
    }

    @Test func chartSnapshotYDomainPadsOneAboveAndBelow() {
        let entry = WeightEntry(weight: 200.0, timestamp: Date())
        let snapshot = WeightCalculations.chartSnapshot(from: [entry], over: .week)

        #expect(snapshot.yDomain.lowerBound == 199.0)
        #expect(snapshot.yDomain.upperBound == 201.0)
    }

    @Test func chartSnapshotSmoothedFirstPointEqualsRawWeight() {
        let entry = WeightEntry(weight: 150.0, timestamp: Date())
        let snapshot = WeightCalculations.chartSnapshot(from: [entry], over: .week)

        #expect(snapshot.smoothedEntries.first?.weight == 150.0)
        #expect(snapshot.trendEntries.first?.weight == 150.0)
    }

    @Test func chartSnapshotWithMultipleEntriesHasCorrectCount() {
        let now = Date()
        let entries = (0..<5).map { i in
            WeightEntry(
                weight: 150.0 + Double(i),
                timestamp: now.addingTimeInterval(TimeInterval(-i * 3600))
            )
        }
        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .week)

        #expect(snapshot.entries.count == 5)
        #expect(snapshot.smoothedEntries.count == 5)
        #expect(snapshot.trendEntries.count == 5)
    }

    @Test func chartSnapshotEntriesAreSortedChronologically() {
        let now = Date()
        let entries = (0..<5).map { i in
            WeightEntry(
                weight: 150.0,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 86400))
            )
        }
        // Entries are passed newest-first, snapshot should sort oldest-first
        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .week)

        let timestamps = snapshot.entries.map(\.timestamp)
        #expect(timestamps == timestamps.sorted())
    }

    // MARK: - logSnapshot

    @Test func logSnapshotFromEmptyEntriesHasEmptyChart() {
        let snapshot = WeightCalculations.logSnapshot(from: [], chartPeriod: .month)
        #expect(snapshot.groupedEntries.isEmpty)
        #expect(snapshot.streaksByDay.isEmpty)
        #expect(snapshot.chart.entries.isEmpty)
    }
}
