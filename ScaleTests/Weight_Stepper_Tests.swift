//
//  Weight_Stepper_Tests.swift
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

// MARK: - Weight Stepper Tests

struct WeightStepperTests {

    @Test func decrementReducesWeightByOneTenth() {
        let updatedWeight = WeightCalculations.decrementWeight(142.5)
        #expect(updatedWeight == 142.4)
    }

    @Test func incrementRaisesWeightByOneTenth() {
        let updatedWeight = WeightCalculations.incrementWeight(142.5)
        #expect(updatedWeight == 142.6)
    }

    @Test func decrementClampsAtZero() {
        let updatedWeight = WeightCalculations.decrementWeight(0.0)
        #expect(updatedWeight == 0.0)
    }

    @Test func stepperRoundsFloatingPointNoiseToOneDecimalPlace() {
        let decrementedWeight = WeightCalculations.decrementWeight(142.3)
        let incrementedWeight = WeightCalculations.incrementWeight(142.3)

        #expect(decrementedWeight == 142.2)
        #expect(incrementedWeight == 142.4)
    }
}

