//
//  Weight_Input_Parsing_Tests.swift
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

// MARK: - Weight Input Parsing Tests

struct WeightParsingTests {

    @Test func parseValidWeight() {
        #expect(WeightCalculations.parseWeight(from: "142.5") == 142.5)
    }

    @Test func parseIntegerWeight() {
        #expect(WeightCalculations.parseWeight(from: "150") == 150.0)
    }

    @Test func parseWeightWithWhitespace() {
        #expect(WeightCalculations.parseWeight(from: "  150.0  ") == 150.0)
    }

    @Test func parseWeightRejectsText() {
        #expect(WeightCalculations.parseWeight(from: "abc") == nil)
    }

    @Test func parseWeightRejectsEmpty() {
        #expect(WeightCalculations.parseWeight(from: "") == nil)
    }

    @Test func parseWeightRejectsZero() {
        #expect(WeightCalculations.parseWeight(from: "0") == nil)
    }

    @Test func parseWeightRejectsNegative() {
        #expect(WeightCalculations.parseWeight(from: "-50") == nil)
    }

    @Test func parseWeightAcceptsLargeValue() {
        #expect(WeightCalculations.parseWeight(from: "350.5") == 350.5)
    }
}

