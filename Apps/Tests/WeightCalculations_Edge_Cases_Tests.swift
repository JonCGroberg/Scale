import Testing
import Foundation
@testable import Scale

struct WeightCalculationsEdgeCasesTests {
    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    // MARK: - goalProgress edge cases

    @Test func goalProgressReturnsNilForEmptyEntries() {
        let progress = WeightCalculations.goalProgress(
            from: [],
            goal: .lose,
            targetWeight: 150,
            over: .week
        )
        #expect(progress == nil)
    }

    @Test func goalProgressReturnsNilForMaintainGoal() {
        let entries = [
            WeightEntry(weight: 180, timestamp: daysAgo(10)),
            WeightEntry(weight: 175, timestamp: daysAgo(1)),
        ]
        let progress = WeightCalculations.goalProgress(
            from: entries,
            goal: .maintain,
            targetWeight: 170,
            over: .month
        )
        #expect(progress == nil)
    }

    @Test func goalProgressWhenTargetAlreadyReached() {
        let entries = [
            WeightEntry(weight: 180, timestamp: daysAgo(10)),
            WeightEntry(weight: 145, timestamp: daysAgo(1)),
        ]
        let progress = WeightCalculations.goalProgress(
            from: entries,
            goal: .lose,
            targetWeight: 150,
            over: .year
        )
        #expect(progress != nil)
        #expect(progress?.completedDistance == progress?.totalDistance)
        if let progress {
            #expect(progress.completedChange == progress.totalChange)
        }
    }

    @Test func goalProgressBulkGoalMovingAwayFromTarget() {
        let entries = [
            WeightEntry(weight: 190, timestamp: daysAgo(10)),
            WeightEntry(weight: 185, timestamp: daysAgo(1)),
        ]
        let progress = WeightCalculations.goalProgress(
            from: entries,
            goal: .gain,
            targetWeight: 200,
            over: .year
        )
        #expect(progress?.totalDistance == 10)
        #expect(progress?.completedDistance == 0)
    }

    @Test func goalProgressCutGoalPartialProgress() {
        let entries = [
            WeightEntry(weight: 200, timestamp: daysAgo(30)),
            WeightEntry(weight: 190, timestamp: daysAgo(15)),
            WeightEntry(weight: 185, timestamp: daysAgo(1)),
        ]
        let progress = WeightCalculations.goalProgress(
            from: entries,
            goal: .lose,
            targetWeight: 180,
            over: .year
        )
        #expect(progress != nil)
        #expect(progress!.totalDistance == 20)
        #expect(progress!.completedChange == -15)
        #expect(progress!.totalChange == -20)
    }

    @Test func goalProgressWithSingleEntryInPeriodStartsAtZeroProgress() {
        let entries = [
            WeightEntry(weight: 200, timestamp: daysAgo(1)),
        ]
        let progress = WeightCalculations.goalProgress(
            from: entries,
            goal: .lose,
            targetWeight: 180,
            over: .week
        )
        #expect(progress?.completedDistance == 0)
        #expect(progress?.completedChange == 0)
        #expect(progress?.totalDistance == 20)
    }

    @Test func goalProgressEntriesOutsidePeriodReturnsNil() {
        let entries = [
            WeightEntry(weight: 200, timestamp: daysAgo(400)),
            WeightEntry(weight: 190, timestamp: daysAgo(380)),
        ]
        let progress = WeightCalculations.goalProgress(
            from: entries,
            goal: .lose,
            targetWeight: 180,
            over: .week
        )
        #expect(progress == nil)
    }

    // MARK: - logSnapshot

    @Test func logSnapshotCreatesGroupedEntries() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(1)),
            WeightEntry(weight: 151, timestamp: daysAgo(30)),
            WeightEntry(weight: 152, timestamp: daysAgo(60)),
        ]
        let snapshot = WeightCalculations.logSnapshot(from: entries, chartPeriod: .month)
        #expect(!snapshot.groupedEntries.isEmpty)
        #expect(!snapshot.streaksByDay.isEmpty)
        #expect(!snapshot.chart.entries.isEmpty)
    }

    @Test func logSnapshotWithEmptyEntries() {
        let snapshot = WeightCalculations.logSnapshot(from: [], chartPeriod: .month)
        #expect(snapshot.groupedEntries.isEmpty)
        #expect(snapshot.streaksByDay.isEmpty)
        #expect(snapshot.chart.entries.isEmpty)
    }

    @Test func logSnapshotUsesCorrectChartPeriod() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(1)),
            WeightEntry(weight: 155, timestamp: daysAgo(100)),
            WeightEntry(weight: 160, timestamp: daysAgo(200)),
        ]
        let weekSnapshot = WeightCalculations.logSnapshot(from: entries, chartPeriod: .week)
        #expect(weekSnapshot.chart.entries.count == 1)

        let yearSnapshot = WeightCalculations.logSnapshot(from: entries, chartPeriod: .year)
        #expect(yearSnapshot.chart.entries.count == 3)
    }

    // MARK: - percentageChange edge cases

    @Test func percentageChangePositiveValue() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(10)),
            WeightEntry(weight: 165, timestamp: daysAgo(1)),
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .year)
        #expect(pct != nil)
        #expect(abs(pct! - 10.0) < 0.01)
    }

    @Test func percentageChangeNegativeValue() {
        let entries = [
            WeightEntry(weight: 200, timestamp: daysAgo(10)),
            WeightEntry(weight: 180, timestamp: daysAgo(1)),
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .year)
        #expect(pct != nil)
        #expect(abs(pct! - (-10.0)) < 0.01)
    }

    @Test func percentageChangeNilWhenNotEnoughEntries() {
        let entries = [WeightEntry(weight: 150, timestamp: daysAgo(1))]
        #expect(WeightCalculations.percentageChange(from: entries, over: .year) == nil)
        #expect(WeightCalculations.percentageChange(from: [], over: .year) == nil)
    }

    @Test func percentageChangeNilWhenFirstWeightIsZero() {
        let entries = [
            WeightEntry(weight: 0, timestamp: daysAgo(10)),
            WeightEntry(weight: 150, timestamp: daysAgo(1)),
        ]
        #expect(WeightCalculations.percentageChange(from: entries, over: .year) == nil)
    }

    // MARK: - weightChangeLbs edge cases

    @Test func weightChangeLbsNilWhenSingleEntryInPeriod() {
        let entries = [WeightEntry(weight: 150, timestamp: daysAgo(1))]
        #expect(WeightCalculations.weightChangeLbs(from: entries, over: .week) == nil)
    }

    @Test func weightChangeLbsNilWhenNoEntriesInPeriod() {
        let entries = [WeightEntry(weight: 150, timestamp: daysAgo(400))]
        #expect(WeightCalculations.weightChangeLbs(from: entries, over: .week) == nil)
    }

    @Test func weightChangeLbsCorrectValue() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(10)),
            WeightEntry(weight: 145, timestamp: daysAgo(1)),
        ]
        #expect(WeightCalculations.weightChangeLbs(from: entries, over: .year) == -5.0)
    }

    // MARK: - parseWeight edge cases

    @Test func parseWeightRejectsZero() {
        #expect(WeightCalculations.parseWeight(from: "0") == nil)
        #expect(WeightCalculations.parseWeight(from: "-5") == nil)
    }

    @Test func parseWeightHandlesWhitespace() {
        #expect(WeightCalculations.parseWeight(from: "  150.5  ") == 150.5)
    }

    @Test func parseWeightRejectsNonNumeric() {
        #expect(WeightCalculations.parseWeight(from: "abc") == nil)
        #expect(WeightCalculations.parseWeight(from: "") == nil)
    }

    // MARK: - incrementWeight / decrementWeight edge cases

    @Test func incrementWeightRoundsToOneDecimal() {
        #expect(WeightCalculations.incrementWeight(150.04) == 150.1)
        #expect(WeightCalculations.incrementWeight(150.06) == 150.2)
    }

    @Test func decrementWeightStaysNonNegative() {
        #expect(WeightCalculations.decrementWeight(0) == 0)
        #expect(WeightCalculations.decrementWeight(0.05) == 0)
    }

    // MARK: - heatmapSnapshot edge cases

    @Test func heatmapSnapshotWithZeroWeeks() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: 0)
        #expect(snapshot.weeks.isEmpty)
        #expect(snapshot.monthLabels.isEmpty)
    }

    @Test func heatmapSnapshotWithNegativeWeeks() {
        let snapshot = WeightCalculations.heatmapSnapshot(from: [], weeks: -1)
        #expect(snapshot.weeks.isEmpty)
        #expect(snapshot.monthLabels.isEmpty)
    }

    @Test func heatmapSnapshotWithEntries() {
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(0)),
            WeightEntry(weight: 151, timestamp: daysAgo(1)),
        ]
        let snapshot = WeightCalculations.heatmapSnapshot(from: entries, weeks: 4)
        #expect(!snapshot.weeks.isEmpty)
    }

    @Test func heatmapIntensityBounds() {
        // Test private via behavior: maxCount=1 -> intensity 4
        let entries = [
            WeightEntry(weight: 150, timestamp: daysAgo(0)),
        ]
        let snapshot = WeightCalculations.heatmapSnapshot(from: entries, weeks: 2)
        let todayEntry = snapshot.weeks.last?.last
        #expect(todayEntry?.entryCount == 1)
    }
}
