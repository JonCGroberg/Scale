//
//  Weight_Stepper_Boundary_Tests.swift
//  ScaleTests
//
//  Tests for incrementWeight/decrementWeight boundary conditions and rounding.
//

import Testing
import Foundation
@testable import Scale

struct WeightStepperBoundaryTests {

    // MARK: - Decrement to zero boundary

    @Test func decrementAtZeroPointOneStopsAtZero() {
        let result = WeightCalculations.decrementWeight(0.1, step: 0.1)
        #expect(result == 0.0)
    }

    @Test func decrementBelowZeroClampsToZero() {
        let result = WeightCalculations.decrementWeight(0.0, step: 0.1)
        #expect(result == 0.0)
    }

    @Test func decrementFromZeroClampsToZero() {
        let result = WeightCalculations.decrementWeight(0.0, step: 1.0)
        #expect(result == 0.0)
    }

    // MARK: - Increment from zero

    @Test func incrementFromZero() {
        let result = WeightCalculations.incrementWeight(0.0, step: 0.1)
        #expect(result == 0.1)
    }

    // MARK: - Rounding precision

    @Test func incrementPreservesOneTenthPrecision() {
        // 0.1 + 0.1 should be exactly 0.2, not 0.20000000000000001
        let result = WeightCalculations.incrementWeight(0.1, step: 0.1)
        #expect(result == 0.2)
    }

    @Test func decrementPreservesOneTenthPrecision() {
        let result = WeightCalculations.decrementWeight(0.3, step: 0.1)
        #expect(result == 0.2)
    }

    @Test func incrementWithLargeStep() {
        let result = WeightCalculations.incrementWeight(100.0, step: 5.0)
        #expect(result == 105.0)
    }

    @Test func decrementWithLargeStep() {
        let result = WeightCalculations.decrementWeight(100.0, step: 5.0)
        #expect(result == 95.0)
    }

    // MARK: - Floating point edge case

    @Test func multipleIncrementsRemainPrecise() {
        var weight = 150.0
        for _ in 0..<10 {
            weight = WeightCalculations.incrementWeight(weight, step: 0.1)
        }
        // 150.0 + 10 * 0.1 = 151.0
        #expect(weight == 151.0)
    }

    @Test func multipleDecrementsRemainPrecise() {
        var weight = 151.0
        for _ in 0..<10 {
            weight = WeightCalculations.decrementWeight(weight, step: 0.1)
        }
        #expect(weight == 150.0)
    }

    // MARK: - Default step

    @Test func incrementUsesDefaultStepOfPointOne() {
        let result = WeightCalculations.incrementWeight(150.0)
        #expect(result == 150.1)
    }

    @Test func decrementUsesDefaultStepOfPointOne() {
        let result = WeightCalculations.decrementWeight(150.0)
        #expect(result == 149.9)
    }
}
