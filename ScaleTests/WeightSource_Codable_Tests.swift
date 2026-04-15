//
//  WeightSource_Codable_Tests.swift
//  ScaleTests
//
//  Tests for WeightSource, WorkoutSource, and DailyActivitySource enum serialization.
//

import Testing
import Foundation
@testable import Scale

struct WeightSourceCodableTests {

    // MARK: - WeightSource

    @Test func weightSourceManualRawValue() {
        #expect(WeightSource.manual.rawValue == "manual")
    }

    @Test func weightSourceAppleHealthRawValue() {
        #expect(WeightSource.appleHealth.rawValue == "appleHealth")
    }

    @Test func weightSourceRoundTripsViaCodable() throws {
        let original = WeightSource.manual
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeightSource.self, from: data)
        #expect(decoded == original)
    }

    @Test func weightSourceAppleHealthRoundTripsViaCodable() throws {
        let original = WeightSource.appleHealth
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeightSource.self, from: data)
        #expect(decoded == original)
    }

    @Test func invalidWeightSourceRawValueReturnsNil() {
        #expect(WeightSource(rawValue: "unknown") == nil)
        #expect(WeightSource(rawValue: "") == nil)
    }

    // MARK: - WorkoutSource

    @Test func workoutSourceAppleHealthRawValue() {
        #expect(WorkoutSource.appleHealth.rawValue == "appleHealth")
    }

    @Test func workoutSourceRoundTripsViaCodable() throws {
        let data = try JSONEncoder().encode(WorkoutSource.appleHealth)
        let decoded = try JSONDecoder().decode(WorkoutSource.self, from: data)
        #expect(decoded == .appleHealth)
    }

    // MARK: - DailyActivitySource

    @Test func dailyActivitySourceAppleHealthRawValue() {
        #expect(DailyActivitySource.appleHealth.rawValue == "appleHealth")
    }

    @Test func dailyActivitySourceRoundTripsViaCodable() throws {
        let data = try JSONEncoder().encode(DailyActivitySource.appleHealth)
        let decoded = try JSONDecoder().decode(DailyActivitySource.self, from: data)
        #expect(decoded == .appleHealth)
    }
}
