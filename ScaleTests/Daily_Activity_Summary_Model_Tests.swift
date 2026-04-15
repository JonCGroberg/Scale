//
//  Daily_Activity_Summary_Model_Tests.swift
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

// MARK: - Daily Activity Summary Model Tests

struct DailyActivitySummaryModelTests {

    @Test func dailyActivitySummaryInitializesWithDefaults() {
        let date = Calendar.current.startOfDay(for: .now)
        let summary = DailyActivitySummary(date: date)

        #expect(summary.date == date)
        #expect(summary.stepCount == 0)
        #expect(summary.activeEnergyBurnedKilocalories == 0)
        #expect(summary.source == .appleHealth)
    }

    @Test func dailyActivitySummaryStoresCustomValues() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let summary = DailyActivitySummary(
            date: date,
            stepCount: 12_345,
            activeEnergyBurnedKilocalories: 678.9,
            source: .appleHealth
        )

        #expect(summary.date == date)
        #expect(summary.stepCount == 12_345)
        #expect(summary.activeEnergyBurnedKilocalories == 678.9)
        #expect(summary.source == .appleHealth)
    }

    @Test func dailyActivitySourceCodableRoundTripPreservesRawValue() throws {
        let encoded = try JSONEncoder().encode(DailyActivitySource.appleHealth)
        let decoded = try JSONDecoder().decode(DailyActivitySource.self, from: encoded)

        #expect(decoded == .appleHealth)
        #expect(DailyActivitySource.appleHealth.rawValue == "appleHealth")
    }
}

