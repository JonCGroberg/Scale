//
//  Goal_Overview_Progress_Tests.swift
//  ScaleTests
//
//  Created by Codex on 4/26/26.
//

import Foundation
import Testing
@testable import Scale

struct GoalOverviewProgressTests {
    @Test func cutProgressCalculatesPercentAndProjection() throws {
        let calendar = Calendar.current
        let now = Date()
        let start = try #require(calendar.date(byAdding: .day, value: -10, to: now))
        let entries = [
            WeightEntry(weight: 190, timestamp: now),
            WeightEntry(weight: 200, timestamp: start),
        ]

        let progress = try #require(WeightCalculations.goalProgress(
            from: entries,
            goal: .lose,
            targetWeight: 180,
            over: .month
        ))

        #expect(abs(progress.completedDistance - 10) < 0.01)
        #expect(abs(progress.totalDistance - 20) < 0.01)
        #expect(abs(progress.completedChange - -10) < 0.01)
        #expect(abs(progress.totalChange - -20) < 0.01)
        #expect(GoalProgressFeedback.progressText(progress) == "-10.0/20.0 lbs")
        #expect(progress.daysRemaining != nil)
        #expect(abs(progress.daysRemaining! - 10) < 0.25)
    }

    @Test func bulkProgressCalculatesPercentAndProjection() throws {
        let calendar = Calendar.current
        let now = Date()
        let start = try #require(calendar.date(byAdding: .day, value: -10, to: now))
        let entries = [
            WeightEntry(weight: 190, timestamp: now),
            WeightEntry(weight: 180, timestamp: start),
        ]

        let progress = try #require(WeightCalculations.goalProgress(
            from: entries,
            goal: .gain,
            targetWeight: 200,
            over: .month
        ))

        #expect(abs(progress.completedDistance - 10) < 0.01)
        #expect(abs(progress.totalDistance - 20) < 0.01)
        #expect(abs(progress.completedChange - 10) < 0.01)
        #expect(abs(progress.totalChange - 20) < 0.01)
        #expect(GoalProgressFeedback.progressText(progress) == "+10.0/20.0 lbs")
        #expect(progress.daysRemaining != nil)
        #expect(abs(progress.daysRemaining! - 10) < 0.25)
    }

    @Test func projectionIsNilWhenTrendMovesAwayFromGoal() throws {
        let calendar = Calendar.current
        let now = Date()
        let start = try #require(calendar.date(byAdding: .day, value: -10, to: now))
        let entries = [
            WeightEntry(weight: 205, timestamp: now),
            WeightEntry(weight: 200, timestamp: start),
        ]

        let progress = try #require(WeightCalculations.goalProgress(
            from: entries,
            goal: .lose,
            targetWeight: 180,
            over: .month
        ))

        #expect(progress.daysRemaining == nil)
    }
}
