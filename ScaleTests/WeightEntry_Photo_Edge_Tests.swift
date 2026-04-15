//
//  WeightEntry_Photo_Edge_Tests.swift
//  ScaleTests
//
//  Tests for photo encoding edge cases: init with photo, legacy fallback, fingerprint stability.
//

import Testing
import Foundation
import SwiftData
@testable import Scale

struct WeightEntryPhotoEdgeTests {

    // MARK: - Init with photoData

    @Test func initWithPhotoDataSetsPhotosArray() {
        let data = Data([0xDE, 0xAD])
        let entry = WeightEntry(weight: 180.0, photoData: data)

        #expect(entry.photosData == [data])
        #expect(entry.photoData == data)
        #expect(entry.hasPhotos == true)
    }

    @Test func initWithNilPhotoDataHasNoPhotos() {
        let entry = WeightEntry(weight: 180.0, photoData: nil)

        #expect(entry.photosData.isEmpty)
        #expect(entry.photoData == nil)
        #expect(entry.hasPhotos == false)
        #expect(entry.photosFingerprint == 0)
    }

    // MARK: - Multiple photos

    @Test func threePhotosRoundTrip() {
        let photos = [Data([0x01]), Data([0x02]), Data([0x03])]
        let entry = WeightEntry(weight: 150.0)
        entry.photosData = photos

        #expect(entry.photosData.count == 3)
        #expect(entry.photosData == photos)
        #expect(entry.photoData == Data([0x01])) // primary is first
    }

    @Test func replacingPhotosUpdatesFingerprintAndPrimary() {
        let entry = WeightEntry(weight: 150.0)
        entry.photosData = [Data([0xAA])]
        let fp1 = entry.photosFingerprint
        let primary1 = entry.photoData

        entry.photosData = [Data([0xBB]), Data([0xCC])]
        let fp2 = entry.photosFingerprint
        let primary2 = entry.photoData

        #expect(fp1 != fp2)
        #expect(primary1 != primary2)
        #expect(primary2 == Data([0xBB]))
    }

    // MARK: - Fingerprint zero vs non-zero

    @Test func fingerprintIsZeroOnlyWhenNoPhotos() {
        let entry = WeightEntry(weight: 180.0)
        #expect(entry.photosFingerprint == 0)

        entry.photosData = [Data([0x01])]
        #expect(entry.photosFingerprint != 0)

        entry.photosData = []
        #expect(entry.photosFingerprint == 0)
    }

    // MARK: - hasPhotos reflects storage

    @Test func hasPhotosIsTrueOnlyWhenStorageExists() {
        let entry = WeightEntry(weight: 180.0)
        #expect(entry.hasPhotos == false)

        entry.photosData = [Data([0xFF])]
        #expect(entry.hasPhotos == true)

        entry.photosData = []
        #expect(entry.hasPhotos == false)
    }

    // MARK: - SwiftData round-trip with empty photos

    @Test func emptyPhotosPersistCorrectlyThroughSwiftData() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)

        let entry = WeightEntry(weight: 180.0)
        context.insert(entry)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(stored.count == 1)
        #expect(stored[0].photosData.isEmpty)
        #expect(stored[0].hasPhotos == false)
    }
}
