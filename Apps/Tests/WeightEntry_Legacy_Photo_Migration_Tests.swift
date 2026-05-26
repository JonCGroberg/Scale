//
//  WeightEntry_Legacy_Photo_Migration_Tests.swift
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

// MARK: - WeightEntry Legacy Photo Migration Tests

struct WeightEntryLegacyPhotoMigrationTests {

    @Test func legacyPhotoDataInitializerStoresAsSingleElementArray() {
        let photoBytes = Data([0x89, 0x50, 0x4E, 0x47])
        let entry = WeightEntry(weight: 180.0, photoData: photoBytes)

        #expect(entry.photosData.count == 1)
        #expect(entry.photosData[0] == photoBytes)
        #expect(entry.photoData == photoBytes)
    }

    @Test func nilPhotoDataInitializerLeavesPhotosEmpty() {
        let entry = WeightEntry(weight: 180.0, photoData: nil)

        #expect(entry.photosData.isEmpty)
        #expect(entry.photoData == nil)
        #expect(entry.hasPhotos == false)
    }

    @Test func photosDataMultiplePhotosRoundTrips() {
        let photo1 = Data([0x01, 0x02])
        let photo2 = Data([0x03, 0x04])
        let photo3 = Data([0x05, 0x06])

        let entry = WeightEntry(weight: 180.0)
        entry.photosData = [photo1, photo2, photo3]

        #expect(entry.photosData.count == 3)
        #expect(entry.photosData == [photo1, photo2, photo3])
        #expect(entry.photoData == photo1)
    }

    @Test func replacingPhotosUpdatesFingerprint() {
        let entry = WeightEntry(weight: 180.0, photoData: Data([0x01]))
        let fp1 = entry.photosFingerprint

        entry.photosData = [Data([0xFF, 0xFE])]
        let fp2 = entry.photosFingerprint

        #expect(fp1 != fp2)
    }
}

