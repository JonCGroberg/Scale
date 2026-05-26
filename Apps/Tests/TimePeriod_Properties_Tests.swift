//
//  TimePeriod_Properties_Tests.swift
//  ScaleTests
//
//  Tests for TimePeriod calendarComponent, componentValue, and label properties.
//

import Testing
import Foundation
@testable import Scale

struct TimePeriodPropertiesTests {

    // MARK: - calendarComponent

    @Test func weekCalendarComponentIsWeekOfYear() {
        #expect(TimePeriod.week.calendarComponent == .weekOfYear)
    }

    @Test func monthCalendarComponentIsMonth() {
        #expect(TimePeriod.month.calendarComponent == .month)
    }

    @Test func threeMonthsCalendarComponentIsMonth() {
        #expect(TimePeriod.threeMonths.calendarComponent == .month)
    }

    @Test func sixMonthsCalendarComponentIsMonth() {
        #expect(TimePeriod.sixMonths.calendarComponent == .month)
    }

    @Test func yearCalendarComponentIsYear() {
        #expect(TimePeriod.year.calendarComponent == .year)
    }

    // MARK: - componentValue

    @Test func weekComponentValueIsOne() {
        #expect(TimePeriod.week.componentValue == 1)
    }

    @Test func monthComponentValueIsOne() {
        #expect(TimePeriod.month.componentValue == 1)
    }

    @Test func threeMonthsComponentValueIsThree() {
        #expect(TimePeriod.threeMonths.componentValue == 3)
    }

    @Test func sixMonthsComponentValueIsSix() {
        #expect(TimePeriod.sixMonths.componentValue == 6)
    }

    @Test func yearComponentValueIsOne() {
        #expect(TimePeriod.year.componentValue == 1)
    }

    // MARK: - label

    @Test func weekLabelIsWeek() {
        #expect(TimePeriod.week.label == "Week")
    }

    @Test func monthLabelIsMonth() {
        #expect(TimePeriod.month.label == "Month")
    }

    @Test func threeMonthsLabelIs3Months() {
        #expect(TimePeriod.threeMonths.label == "3 Months")
    }

    @Test func sixMonthsLabelIs6Months() {
        #expect(TimePeriod.sixMonths.label == "6 Months")
    }

    @Test func yearLabelIsYear() {
        #expect(TimePeriod.year.label == "Year")
    }

    // MARK: - Date arithmetic integration

    @Test func calendarComponentAndValueProduceCorrectDateOffset() {
        let calendar = Calendar.current
        let now = Date()

        for period in TimePeriod.allCases {
            let cutoff = calendar.date(
                byAdding: period.calendarComponent,
                value: -period.componentValue,
                to: now
            )
            #expect(cutoff != nil, "Date arithmetic should succeed for \(period.rawValue)")
            #expect(cutoff! < now, "\(period.rawValue) cutoff should be in the past")
        }
    }
}
