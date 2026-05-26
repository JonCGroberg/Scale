//
//  Scale_OCR_Correction_Tests.swift
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

// MARK: - Scale OCR Correction Tests

struct ScaleOCRCorrectionTests {

    // -- Letter-to-digit substitutions --

    @Test func correctsUppercaseOToZero() {
        #expect(WeightCalculations.parseScaleReading("2O0.5") == 200.5)
    }

    @Test func correctsLowercaseOToZero() {
        #expect(WeightCalculations.parseScaleReading("14o.5") == 140.5)
    }

    @Test func correctsLowercaseLToOne() {
        #expect(WeightCalculations.parseScaleReading("l42.5") == 142.5)
    }

    @Test func correctsUppercaseIToOne() {
        #expect(WeightCalculations.parseScaleReading("I42.5") == 142.5)
    }

    @Test func correctsMultipleSubstitutions() {
        #expect(WeightCalculations.parseScaleReading("lO5.O") == 105.0)
    }

    // -- Already-clean inputs pass through --

    @Test func cleanDigitsPassThrough() {
        #expect(WeightCalculations.parseScaleReading("185.3") == 185.3)
    }

    @Test func cleanWholeNumberPassesThrough() {
        #expect(WeightCalculations.parseScaleReading("200") == 200.0)
    }

    // -- Whitespace handling --

    @Test func trimsWhitespaceBeforeCorrecting() {
        #expect(WeightCalculations.parseScaleReading("  l42.5  ") == 142.5)
    }

    // -- Rejection cases still reject after correction --

    @Test func rejectsGarbageTextAfterCorrection() {
        #expect(WeightCalculations.parseScaleReading("lbs") == nil)
    }

    @Test func rejectsEmptyString() {
        #expect(WeightCalculations.parseScaleReading("") == nil)
    }

    @Test func rejectsTooManyDigitsAfterCorrection() {
        #expect(WeightCalculations.parseScaleReading("lOOO") == nil) // "1000" → 4 digits
    }

    @Test func rejectsZeroAfterCorrection() {
        #expect(WeightCalculations.parseScaleReading("O") == nil) // "0" → rejected
    }

    // -- Pipe character as 1 (common seven-segment misread) --

    @Test func correctsPipeToOne() {
        #expect(WeightCalculations.parseScaleReading("|42.5") == 142.5)
    }

    // -- Mixed noise that becomes valid after correction --

    @Test func mixedSubstitutionsProduceValidWeight() {
        #expect(WeightCalculations.parseScaleReading("I5O.l") == 150.1)
    }
}

