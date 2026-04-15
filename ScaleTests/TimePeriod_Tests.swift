//
//  TimePeriod_Tests.swift
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

// MARK: - TimePeriod Tests

struct TimePeriodTests {

    @Test func allCasesCount() {
        #expect(TimePeriod.allCases.count == 5)
    }

    @Test func rawValues() {
        #expect(TimePeriod.week.rawValue == "1W")
        #expect(TimePeriod.month.rawValue == "1M")
        #expect(TimePeriod.threeMonths.rawValue == "3M")
        #expect(TimePeriod.sixMonths.rawValue == "6M")
        #expect(TimePeriod.year.rawValue == "1Y")
    }

    @Test func labels() {
        #expect(TimePeriod.week.label == "Week")
        #expect(TimePeriod.month.label == "Month")
        #expect(TimePeriod.threeMonths.label == "3 Months")
        #expect(TimePeriod.sixMonths.label == "6 Months")
        #expect(TimePeriod.year.label == "Year")
    }

    @Test func componentValues() {
        #expect(TimePeriod.week.componentValue == 1)
        #expect(TimePeriod.month.componentValue == 1)
        #expect(TimePeriod.threeMonths.componentValue == 3)
        #expect(TimePeriod.sixMonths.componentValue == 6)
        #expect(TimePeriod.year.componentValue == 1)
    }

    @Test func calendarComponents() {
        #expect(TimePeriod.week.calendarComponent == .weekOfYear)
        #expect(TimePeriod.month.calendarComponent == .month)
        #expect(TimePeriod.threeMonths.calendarComponent == .month)
        #expect(TimePeriod.sixMonths.calendarComponent == .month)
        #expect(TimePeriod.year.calendarComponent == .year)
    }
}

