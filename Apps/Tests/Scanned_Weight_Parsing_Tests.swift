//
//  Scanned_Weight_Parsing_Tests.swift
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

// MARK: - Scanned Weight Parsing Tests

struct ScannedWeightParsingTests {

    @Test func parseThreeDigitsWithDecimal() {
        #expect(WeightCalculations.parseScannedWeight("142.5") == 142.5)
    }

    @Test func parseThreeDigitsNoDecimal() {
        #expect(WeightCalculations.parseScannedWeight("185") == 185.0)
    }

    @Test func parseTwoDigitsWithDecimal() {
        #expect(WeightCalculations.parseScannedWeight("92.3") == 92.3)
    }

    @Test func parseOneDigit() {
        #expect(WeightCalculations.parseScannedWeight("5") == 5.0)
    }

    @Test func parseWithTrailingDot() {
        #expect(WeightCalculations.parseScannedWeight("150.") == 150.0)
    }

    @Test func parseWithWhitespace() {
        #expect(WeightCalculations.parseScannedWeight("  142.5  ") == 142.5)
    }

    @Test func rejectFourDigits() {
        #expect(WeightCalculations.parseScannedWeight("1234") == nil)
    }

    @Test func rejectTwoDecimalPlaces() {
        #expect(WeightCalculations.parseScannedWeight("142.55") == nil)
    }

    @Test func rejectText() {
        #expect(WeightCalculations.parseScannedWeight("lbs") == nil)
    }

    @Test func rejectMixedTextAndNumbers() {
        #expect(WeightCalculations.parseScannedWeight("142.5 lbs") == nil)
    }

    @Test func rejectEmpty() {
        #expect(WeightCalculations.parseScannedWeight("") == nil)
    }

    @Test func rejectZero() {
        #expect(WeightCalculations.parseScannedWeight("0") == nil)
    }

    @Test func rejectNegative() {
        #expect(WeightCalculations.parseScannedWeight("-50") == nil)
    }

    @Test func parseDecimalPointZero() {
        #expect(WeightCalculations.parseScannedWeight("200.0") == 200.0)
    }
}

