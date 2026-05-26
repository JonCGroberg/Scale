//
//  Heatmap_Snapshot_Extended_Tests.swift
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

// MARK: - Heatmap Snapshot Extended Tests

struct HeatmapSnapshotExtendedTests {

    private var calendar: Calendar { Calendar.current }

    @Test func heatmapMonthLabelsSpanAtLeastOneMonth() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 8)

        #expect(!snapshot.monthLabels.isEmpty)
        // Each label should have a non-empty title
        #expect(snapshot.monthLabels.allSatisfy { !$0.title.isEmpty })
    }

    @Test func heatmapIntensityScalesWithCount() {
        let today = calendar.startOfDay(for: Date())
        // Create entries with varying counts per day
        let entries = (0..<10).map { i in
            WeightEntry(weight: 150.0, timestamp: today.addingTimeInterval(TimeInterval(i * 60)))
        }

        let snapshot = WeightCalculations.heatmapSnapshot(from: entries, weeks: 1)
        let todayCell = snapshot.weeks.flatMap { $0 }.first { calendar.isDate($0.date, inSameDayAs: today) }

        #expect(todayCell?.entryCount == 10)
        #expect(todayCell?.intensity == 4)
    }

    @Test func heatmapSingleEntryGetsMaxIntensity() {
        let today = calendar.startOfDay(for: Date())
        let entries = [WeightEntry(weight: 150.0, timestamp: today.addingTimeInterval(60))]

        let snapshot = WeightCalculations.heatmapSnapshot(from: entries, weeks: 1)
        let todayCell = snapshot.weeks.flatMap { $0 }.first { calendar.isDate($0.date, inSameDayAs: today) }

        // When maxCount == 1, intensity should be 4
        #expect(todayCell?.entryCount == 1)
        #expect(todayCell?.intensity == 4)
    }

    @Test func heatmapMonthLabelsStartAtFirstWeek() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 26)

        // The first month label should be at week 0
        #expect(snapshot.monthLabels.first?.weekIndex == 0)
    }

    @Test func heatmapEmptySnapshotEquality() {
        let empty1 = WeightCalculations.HeatmapSnapshot.empty
        let empty2 = WeightCalculations.HeatmapSnapshot(weeks: [], monthLabels: [])

        #expect(empty1 == empty2)
    }
}

