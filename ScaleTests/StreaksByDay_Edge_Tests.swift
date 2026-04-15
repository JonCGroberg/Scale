//
//  StreaksByDay_Edge_Tests.swift
//  ScaleTests
//
//  Edge case tests for WeightCalculations.streaksByDay: isolated days, long runs,
//  multiple entries per day, and gaps.
//

import Testing
import Foundation
@testable import Scale

struct StreaksByDayEdgeTests {

    private var calendar: Calendar { Calendar.current }

    @Test func emptyEntriesReturnsEmptyDictionary() {
        let result = WeightCalculations.streaksByDay(from: [])
        #expect(result.isEmpty)
    }

    @Test func singleDayReturnsZeroStreak() {
        let entry = WeightEntry(weight: 150.0, timestamp: Date())
        let result = WeightCalculations.streaksByDay(from: [entry])

        #expect(result.count == 1)
        // Isolated day gets 0
        #expect(result.values.first == 0)
    }

    @Test func twoConsecutiveDaysGetStreaksOneAndTwo() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let entries = [
            WeightEntry(weight: 150.0, timestamp: yesterday),
            WeightEntry(weight: 151.0, timestamp: today)
        ]

        let result = WeightCalculations.streaksByDay(from: entries)

        #expect(result[yesterday] == 1)
        #expect(result[today] == 2)
    }

    @Test func fiveConsecutiveDaysGetIncreasingStreaks() {
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<5).map { daysAgo in
            WeightEntry(weight: 150.0, timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: today)!)
        }

        let result = WeightCalculations.streaksByDay(from: entries)

        #expect(result.count == 5)
        // Day 0 (oldest) gets 1, day 4 (newest/today) gets 5
        for i in 0..<5 {
            let day = calendar.date(byAdding: .day, value: -(4 - i), to: today)!
            #expect(result[day] == i + 1)
        }
    }

    @Test func gapCreatesSeperateRuns() {
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -4, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -3, to: today)!
        // gap on day -2
        let day4 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day5 = today

        let entries = [day1, day2, day4, day5].map {
            WeightEntry(weight: 150.0, timestamp: $0)
        }

        let result = WeightCalculations.streaksByDay(from: entries)

        #expect(result.count == 4)
        // First run: 2 days
        #expect(result[day1] == 1)
        #expect(result[day2] == 2)
        // Second run: 2 days
        #expect(result[day4] == 1)
        #expect(result[day5] == 2)
    }

    @Test func multipleEntriesSameDayCountAsOneDay() {
        let today = calendar.startOfDay(for: Date())
        let entries = [
            WeightEntry(weight: 150.0, timestamp: today.addingTimeInterval(3600)),
            WeightEntry(weight: 151.0, timestamp: today.addingTimeInterval(7200)),
            WeightEntry(weight: 152.0, timestamp: today.addingTimeInterval(10800))
        ]

        let result = WeightCalculations.streaksByDay(from: entries)

        // Only one unique day, isolated → 0
        #expect(result.count == 1)
        #expect(result[today] == 0)
    }

    @Test func isolatedDaysSurroundedByGapsAllGetZero() {
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -6, to: today)!
        // gap
        let day3 = calendar.date(byAdding: .day, value: -4, to: today)!
        // gap
        let day5 = calendar.date(byAdding: .day, value: -2, to: today)!
        // gap
        let day7 = today

        let entries = [day1, day3, day5, day7].map {
            WeightEntry(weight: 150.0, timestamp: $0)
        }

        let result = WeightCalculations.streaksByDay(from: entries)

        // All isolated
        #expect(result.values.allSatisfy { $0 == 0 })
    }

    @Test func entriesInReverseChronologicalOrderStillGroupCorrectly() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        // Newest first (reverse order)
        let entries = [
            WeightEntry(weight: 150.0, timestamp: today),
            WeightEntry(weight: 151.0, timestamp: yesterday),
            WeightEntry(weight: 152.0, timestamp: twoDaysAgo)
        ]

        let result = WeightCalculations.streaksByDay(from: entries)

        #expect(result[twoDaysAgo] == 1)
        #expect(result[yesterday] == 2)
        #expect(result[today] == 3)
    }
}
