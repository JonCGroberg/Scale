//
//  TimePeriod_Extended_Tests.swift
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

// MARK: - TimePeriod Extended Tests

struct TimePeriodExtendedTests {

    @Test func weekRawValueRoundTrips() {
        let period = TimePeriod(rawValue: "1W")
        #expect(period == .week)
    }

    @Test func invalidRawValueReturnsNil() {
        #expect(TimePeriod(rawValue: "2W") == nil)
        #expect(TimePeriod(rawValue: "") == nil)
        #expect(TimePeriod(rawValue: "month") == nil)
    }

    @Test func allCasesContainsAllExpectedValues() {
        let expected: [TimePeriod] = [.week, .month, .threeMonths, .sixMonths, .year]
        #expect(TimePeriod.allCases == expected)
    }
}
