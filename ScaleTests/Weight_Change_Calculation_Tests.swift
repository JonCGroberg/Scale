//
//  Weight_Change_Calculation_Tests.swift
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

// MARK: - Weight Change Calculation Tests

struct WeightChangeTests {

    @Test func changeWithTwoEntries() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 5.0)
    }

    @Test func changeWithWeightLoss() {
        let entries = [
            WeightEntry(weight: 140.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == -5.0)
    }

    @Test func changeWithNoChange() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 0.0)
    }

    @Test func changeIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0)]
        #expect(WeightCalculations.weightChange(from: entries) == nil)
    }

    @Test func changeIsNilWithNoEntries() {
        let entries: [WeightEntry] = []
        #expect(WeightCalculations.weightChange(from: entries) == nil)
    }

    @Test func changeUsesFirstTwoEntriesOnly() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400)),
            WeightEntry(weight: 140.0, timestamp: Date().addingTimeInterval(-172800))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 5.0)
    }

    @Test func changeDateReturnsSecondEntry() {
        let date = Date().addingTimeInterval(-86400)
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: date)
        ]
        #expect(WeightCalculations.changeDate(from: entries) == date)
    }

    @Test func changeDateIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0)]
        #expect(WeightCalculations.changeDate(from: entries) == nil)
    }

    @Test func changeDateIsNilWithNoEntries() {
        let entries: [WeightEntry] = []
        #expect(WeightCalculations.changeDate(from: entries) == nil)
    }
}

