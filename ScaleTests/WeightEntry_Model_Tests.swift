//
//  WeightEntry_Model_Tests.swift
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

// MARK: - WeightEntry Model Tests

struct WeightEntryTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: WeightEntry.self, configurations: config)
    }

    @Test func initializesWithWeight() {
        let entry = WeightEntry(weight: 142.5)
        #expect(entry.weight == 142.5)
    }

    @Test func initializesWithCustomTimestamp() {
        let date = Date()
        let entry = WeightEntry(weight: 150.0, timestamp: date)
        #expect(entry.weight == 150.0)
        #expect(entry.timestamp == date)
    }

    @Test func initializesWithPhotoData() {
        let photoData = Data([0x01, 0x02, 0x03])
        let entry = WeightEntry(weight: 150.0, photoData: photoData)
        #expect(entry.photoData == photoData)
    }

    @Test func initializesWithNote() {
        let entry = WeightEntry(weight: 150.0, note: "Felt strong today")
        #expect(entry.note == "Felt strong today")
    }

    @Test func initializesWithSourceStreakAndHealthKitIdentifier() {
        let uuid = UUID()
        let entry = WeightEntry(
            weight: 151.2,
            source: .appleHealth,
            streakCount: 7,
            healthKitUUID: uuid
        )

        #expect(entry.source == .appleHealth)
        #expect(entry.streakCount == 7)
        #expect(entry.healthKitUUID == uuid)
    }

    @Test func photoDataReturnsNilWhenNoPhotosExist() {
        let entry = WeightEntry(weight: 150.0)

        #expect(entry.photosData.isEmpty)
        #expect(entry.photoData == nil)
    }

    @Test func insertEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 142.5)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.weight == 142.5)
    }

    @Test func deleteEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 160.0)
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.isEmpty)
    }

    @Test func updateWeight() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 145.0)
        context.insert(entry)
        try context.save()

        entry.weight = 143.5
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.first?.weight == 143.5)
    }

    @Test func persistsPhotoData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let photoData = Data([0xAA, 0xBB, 0xCC])
        let entry = WeightEntry(weight: 145.0, photoData: photoData)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.first?.photoData == photoData)
    }

    @Test func persistsNote() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 145.0, note: "Post-workout")
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.first?.note == "Post-workout")
    }

    @Test func sortByTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let older = WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-86400))
        let newer = WeightEntry(weight: 148.0, timestamp: Date())
        context.insert(older)
        context.insert(newer)
        try context.save()

        var descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\WeightEntry.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let latest = try context.fetch(descriptor)
        #expect(latest.first?.weight == 148.0)
    }
}

