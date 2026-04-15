//
//  WeightEntry_Photo_Metadata_Tests.swift
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

// MARK: - WeightEntry Photo Metadata Tests

struct WeightEntryPhotoMetadataTests {

    @Test func emptyEntryHasNoPhotosAndZeroFingerprint() {
        let entry = WeightEntry(weight: 180.0)

        #expect(entry.hasPhotos == false)
        #expect(entry.photosFingerprint == 0)
    }

    @Test func multiPhotoAssignmentRoundTripsAndExposesPrimaryPhoto() {
        let firstPhoto = Data([0x01, 0x02, 0x03])
        let secondPhoto = Data([0xAA, 0xBB, 0xCC])
        let entry = WeightEntry(weight: 180.0)

        entry.photosData = [firstPhoto, secondPhoto]

        #expect(entry.photosData == [firstPhoto, secondPhoto])
        #expect(entry.photoData == firstPhoto)
        #expect(entry.hasPhotos == true)
    }

    @Test func clearingPhotosResetsPrimaryPhotoAndHasPhotosFlag() {
        let entry = WeightEntry(weight: 180.0, photoData: Data([0x10, 0x20]))
        let originalFingerprint = entry.photosFingerprint

        entry.photosData = []

        #expect(entry.photosData.isEmpty)
        #expect(entry.photoData == nil)
        #expect(entry.hasPhotos == false)
        #expect(entry.photosFingerprint != originalFingerprint)
    }

    @Test func photosFingerprintChangesWhenStoredPhotoPayloadChanges() {
        let entry = WeightEntry(weight: 180.0)

        entry.photosData = [Data([0x01])]
        let firstFingerprint = entry.photosFingerprint
        entry.photosData = [Data([0x02])]
        let secondFingerprint = entry.photosFingerprint

        #expect(firstFingerprint != secondFingerprint)
    }

    @Test func multiPhotoPayloadPersistsThroughSwiftDataRoundTrip() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)
        let firstPhoto = Data([0x01, 0x02, 0x03])
        let secondPhoto = Data([0x04, 0x05, 0x06])
        let entry = WeightEntry(weight: 180.0)
        entry.photosData = [firstPhoto, secondPhoto]

        context.insert(entry)
        try context.save()

        let storedEntries = try context.fetch(FetchDescriptor<WeightEntry>())

        #expect(storedEntries.count == 1)
        #expect(storedEntries[0].photosData == [firstPhoto, secondPhoto])
        #expect(storedEntries[0].photoData == firstPhoto)
        #expect(storedEntries[0].hasPhotos == true)
    }
}

