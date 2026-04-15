//
//  Weight_Source_Tests.swift
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

// MARK: - Weight Source Tests

struct WeightSourceTests {

    @Test func rawValuesMatchStoredRepresentations() {
        #expect(WeightSource.manual.rawValue == "manual")
        #expect(WeightSource.appleHealth.rawValue == "appleHealth")
    }

    @Test func codableRoundTripPreservesSource() throws {
        let encoded = try JSONEncoder().encode(WeightSource.appleHealth)
        let decoded = try JSONDecoder().decode(WeightSource.self, from: encoded)

        #expect(decoded == .appleHealth)
    }
}

