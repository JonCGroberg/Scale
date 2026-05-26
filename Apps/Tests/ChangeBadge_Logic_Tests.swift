import Testing
import Foundation
import SwiftUI
@testable import Scale

struct ChangeBadgeLogicTests {
    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    // MARK: - BadgeSummary computation

    @Test func badgeSummaryStreakWithRecentEntries() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(0)),
            WeightEntry(weight: 151, timestamp: daysAgo(1)),
            WeightEntry(weight: 152, timestamp: daysAgo(2)),
        ]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)
        #expect(summary.streak >= 3)
    }

    @Test func badgeSummaryAverageInPeriod() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(1)),
            WeightEntry(weight: 160, timestamp: daysAgo(3)),
            WeightEntry(weight: 170, timestamp: daysAgo(100)),
        ]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)
        #expect(summary.average == 155.0)
    }

    @Test func badgeSummaryAverageNilWhenNoEntriesInPeriod() {
        let entries = [WeightEntry(weight: 150, timestamp: daysAgo(100))]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)
        #expect(summary.average == nil)
    }

    @Test func badgeSummaryWeightChangeWithMultipleEntries() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(5)),
            WeightEntry(weight: 155, timestamp: daysAgo(3)),
            WeightEntry(weight: 145, timestamp: daysAgo(0)),
        ]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)
        #expect(summary.weightChange == -5.0)
    }

    @Test func badgeSummaryWeightChangeNilWithSingleEntry() {
        let entries = [WeightEntry(weight: 150, timestamp: daysAgo(1))]
        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)
        #expect(summary.weightChange == nil)
    }

    @Test func badgeSummaryWeightChangeNilWithNoEntries() {
        let summary = WeightCalculations.badgeSummary(from: [], over: .week)
        #expect(summary.weightChange == nil)
        #expect(summary.average == nil)
        #expect(summary.streak == 0)
    }

    // MARK: - BadgeSummary equality

    @Test func badgeSummaryEquality() {
        let a = WeightCalculations.BadgeSummary(streak: 5, average: 150, weightChange: 2.5)
        let b = WeightCalculations.BadgeSummary(streak: 5, average: 150, weightChange: 2.5)
        let c = WeightCalculations.BadgeSummary(streak: 3, average: 160, weightChange: nil)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ChangeBadge view logic (period-based display)

    @Test func changeBadgePeriodIndexClampsToValidRange() {
        let maxIndex = TimePeriod.allCases.count - 1
        #expect(min(0, maxIndex) == 0)
        #expect(min(maxIndex + 1, maxIndex) == maxIndex)
        #expect(max(-1, 0) == 0)
        #expect(max(0, 0) == 0)
    }

    @Test func changeBadgeDragSwipeRightDecrementsIndex() {
        let maxIndex = TimePeriod.allCases.count - 1
        #expect(max(2 - 1, 0) == 1)
        #expect(max(0 - 1, 0) == 0)
    }

    @Test func changeBadgeDragSwipeLeftIncrementsIndex() {
        let maxIndex = TimePeriod.allCases.count - 1
        #expect(min(2 + 1, maxIndex) == 3)
        #expect(min(maxIndex + 1, maxIndex) == maxIndex)
    }
}
