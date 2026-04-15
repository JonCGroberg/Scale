//
//  Widget_Snapshot_Data_Tests.swift
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

// MARK: - Widget Snapshot Data Tests
//
// These tests verify the WeightWidgetSnapshot data layer that powers both
// home screen and lockscreen (accessory) widget views.

@MainActor
struct WidgetSnapshotDataTests {

    // MARK: - Snapshot make() produces correct data for lockscreen widgets

    @Test func snapshotPopulatesAllFieldsForLockscreen() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 182.4, timestamp: now),
            WeightEntry(weight: 184.0, timestamp: now.addingTimeInterval(-86400)),
            WeightEntry(weight: 185.1, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(
            from: entries,
            tintRawValue: AppTint.green.rawValue,
            now: now
        )

        // Lockscreen rectangular widget displays streak and trend — both must be populated
        #expect(snapshot.streakCount == 2)
        #expect(snapshot.monthPercentChange != nil)
        #expect(snapshot.latestWeight == 182.4)
        #expect(snapshot.latestTimestamp == now)
    }

    @Test func snapshotStreakCountMatchesConsecutiveDays() {
        let calendar = Calendar.current
        let now = Date()
        let entries = (0..<5).map { daysAgo in
            WeightEntry(weight: 180.0, timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        let snapshot = WeightWidgetSnapshot.make(
            from: entries,
            tintRawValue: "blue",
            now: now
        )

        // 5 consecutive days including today
        #expect(snapshot.streakCount == 5)
    }

    @Test func snapshotWithNoEntriesHasZeroStreakAndNilFields() {
        let snapshot = WeightWidgetSnapshot.make(
            from: [],
            tintRawValue: "blue",
            now: .now
        )

        // Lockscreen widgets fall back to empty state — circular shows "--", inline shows prompt
        #expect(snapshot.latestWeight == nil)
        #expect(snapshot.latestTimestamp == nil)
        #expect(snapshot.streakCount == 0)
        #expect(snapshot.monthAverage == nil)
        #expect(snapshot.monthPercentChange == nil)
    }

    @Test func snapshotWithSingleEntryHasNilPercentChange() {
        let now = Date()
        let snapshot = WeightWidgetSnapshot.make(
            from: [WeightEntry(weight: 175.0, timestamp: now)],
            tintRawValue: "orange",
            now: now
        )

        // Rectangular lockscreen widget hides trend pill when percentChange is nil
        #expect(snapshot.latestWeight == 175.0)
        #expect(snapshot.streakCount == 1)
        #expect(snapshot.monthAverage == 175.0)
        #expect(snapshot.monthPercentChange == nil)
    }

    @Test func snapshotSortsEntriesAndUsesLatest() {
        let now = Date()
        let older = WeightEntry(weight: 190.0, timestamp: now.addingTimeInterval(-86400))
        let newer = WeightEntry(weight: 188.2, timestamp: now)

        // Pass entries out of order — snapshot should still use the most recent
        let snapshot = WeightWidgetSnapshot.make(
            from: [older, newer],
            tintRawValue: "red",
            now: now
        )

        #expect(snapshot.latestWeight == 188.2)
        #expect(snapshot.latestTimestamp == now)
    }

    @Test func snapshotTintRawValueIsPreserved() {
        for tint in AppTint.allCases {
            let snapshot = WeightWidgetSnapshot.make(
                from: [WeightEntry(weight: 180.0, timestamp: .now)],
                tintRawValue: tint.rawValue,
                now: .now
            )
            #expect(snapshot.appTintRawValue == tint.rawValue)
        }
    }

    // MARK: - JSON round-trip (widget extension reads what the app writes)

    @Test func snapshotEncodesAndDecodesWithISO8601() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000) // stable reference date
        let original = WeightWidgetSnapshot.make(
            from: [
                WeightEntry(weight: 182.4, timestamp: now),
                WeightEntry(weight: 184.0, timestamp: now.addingTimeInterval(-86400))
            ],
            tintRawValue: "green",
            now: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WeightWidgetSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.latestWeight == 182.4)
        #expect(decoded.streakCount == original.streakCount)
        #expect(decoded.monthPercentChange == original.monthPercentChange)
        #expect(decoded.appTintRawValue == "green")
    }

    @Test func snapshotDecodesEmptyOptionalFieldsCorrectly() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let original = WeightWidgetSnapshot.make(
            from: [],
            tintRawValue: "blue",
            now: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WeightWidgetSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.latestWeight == nil)
        #expect(decoded.monthPercentChange == nil)
        #expect(decoded.monthAverage == nil)
    }

    // MARK: - Month average correctness (used by home + medium widgets)

    @Test func snapshotMonthAverageIsCorrectForRecentEntries() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 182.0, timestamp: now.addingTimeInterval(-86400 * 2)),
            WeightEntry(weight: 184.0, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        // All entries within the last month, average = (180+182+184)/3 = 182.0
        #expect(snapshot.monthAverage != nil)
        #expect(abs(snapshot.monthAverage! - 182.0) < 0.01)
    }

    @Test func snapshotMonthAverageExcludesOldEntries() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 200.0, timestamp: now.addingTimeInterval(-86400 * 60)) // ~2 months ago
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        // Only the recent entry should count toward the month average
        #expect(snapshot.monthAverage != nil)
        #expect(abs(snapshot.monthAverage! - 180.0) < 0.01)
    }

    // MARK: - Percent change sign (rectangular lockscreen shows colored trend)

    @Test func snapshotPercentChangeIsNegativeForWeightLoss() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 176.0, timestamp: now),
            WeightEntry(weight: 180.0, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        #expect(snapshot.monthPercentChange != nil)
        #expect(snapshot.monthPercentChange! < 0)
    }

    @Test func snapshotPercentChangeIsPositiveForWeightGain() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 185.0, timestamp: now),
            WeightEntry(weight: 180.0, timestamp: now.addingTimeInterval(-86400 * 5))
        ]

        let snapshot = WeightWidgetSnapshot.make(from: entries, tintRawValue: "blue", now: now)

        #expect(snapshot.monthPercentChange != nil)
        #expect(snapshot.monthPercentChange! > 0)
    }
}

