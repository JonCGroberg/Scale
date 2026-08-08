//
//  Photo_Only_Moment_Tests.swift
//  ScaleTests
//

import Testing
import Foundation
import SwiftData
@testable import Scale

@MainActor
struct PhotoOnlyMomentTests {
    @Test func weightEntriesRemainWeightLogsByDefault() {
        let entry = WeightEntry(weight: 180)
        #expect(entry.includesWeight)
    }

    @Test func photoOnlyMomentPersistsWithoutBecomingAWeightLog() throws {
        let container = try ModelContainer(
            for: WeightEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let photo = Data([0x01, 0x02, 0x03])
        let moment = WeightEntry(weight: 0, includesWeight: false, photoData: photo)

        context.insert(moment)
        try context.save()

        let saved = try #require(context.fetch(FetchDescriptor<WeightEntry>()).first)
        #expect(!saved.includesWeight)
        #expect(saved.photoData == photo)
        #expect(saved.hasPhotos)
    }

    @Test func photoOnlyMomentsAreExcludedFromAllWeightMetrics() {
        let now = Date()
        let newestPhoto = WeightEntry(
            weight: 0,
            includesWeight: false,
            timestamp: now,
            photoData: Data([0xAA])
        )
        let newestWeight = WeightEntry(weight: 178, timestamp: now.addingTimeInterval(-60))
        let olderWeight = WeightEntry(weight: 180, timestamp: now.addingTimeInterval(-86_400))
        let entries = [newestPhoto, newestWeight, olderWeight]

        #expect(WeightCalculations.weightChange(from: entries) == -2)
        #expect(WeightCalculations.changeDate(from: entries) == olderWeight.timestamp)
        #expect(WeightCalculations.averageWeight(from: entries, over: .month) == 179)
        #expect(WeightCalculations.chartSnapshot(from: entries, over: .month).entries.count == 2)
        #expect(WeightCalculations.heatmapSnapshot(from: entries, weeks: 1).weeks.flatMap { $0 }.reduce(0) { $0 + $1.entryCount } == 2)
    }

    @Test func photoOnlyMomentDoesNotAdvanceWeightStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let photoToday = WeightEntry(weight: 0, includesWeight: false, timestamp: today, photoData: Data([0xBB]))
        let weightYesterday = WeightEntry(weight: 180, timestamp: yesterday)

        #expect(WeightCalculations.currentStreak(from: [photoToday, weightYesterday]) == 0)
        #expect(WeightCalculations.currentDisplayStreak(from: [photoToday, weightYesterday]) == 1)
    }

    @Test func photoOnlyMomentDoesNotSatisfyTodaysWeightReminder() throws {
        let container = try ModelContainer(
            for: WeightEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(
            WeightEntry(
                weight: 0,
                includesWeight: false,
                timestamp: Date(),
                photoData: Data([0xBC])
            )
        )
        try context.save()

        let manager = NotificationManager()
        manager.modelContext = context

        #expect(!manager.todayHasWeightEntry())
    }

    @Test func widgetUsesLatestActualWeightWhenNewerPhotoMomentExists() {
        let now = Date()
        let photo = WeightEntry(weight: 0, includesWeight: false, timestamp: now, photoData: Data([0xCC]))
        let weight = WeightEntry(weight: 177.5, timestamp: now.addingTimeInterval(-60))

        let snapshot = WeightWidgetSnapshot.make(from: [photo, weight], tintRawValue: "blue", now: now)

        #expect(snapshot.latestWeight == 177.5)
        #expect(snapshot.latestTimestamp == weight.timestamp)
    }

    @Test func photoMomentAtSameTimestampDoesNotBlockHealthKitImport() {
        let timestamp = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let photo = WeightEntry(weight: 0, includesWeight: false, timestamp: timestamp, photoData: Data([0xDD]))
        let sample = HealthKitManager.ImportedSample(
            uuid: UUID(),
            startDate: timestamp,
            weightInPounds: 176,
            sourceBundleIdentifier: "com.example.health"
        )

        let plan = HealthKitManager.makeImportPlan(
            samples: [sample],
            existingEntries: [photo],
            ourBundleID: "groberg.Scale"
        )

        #expect(plan.importedCount == 1)
        #expect(plan.skippedCount == 0)
    }
}
