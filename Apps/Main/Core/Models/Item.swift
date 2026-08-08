//
//  Item.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Foundation
import SwiftData

enum WeightSource: String, Codable {
    case manual
    case appleHealth
}

enum WorkoutSource: String, Codable {
    case appleHealth
}

enum DailyActivitySource: String, Codable {
    case appleHealth
}

enum SleepSource: String, Codable {
    case appleHealth
}

@Model
final class WeightEntry {
    var weight: Double
    /// `false` for a photo-only moment. Keeping the numeric field non-optional
    /// makes this an additive, migration-safe schema change for existing stores.
    var includesWeight: Bool = true
    var timestamp: Date
    var source: WeightSource
    var note: String?
    /// The consecutive-day logging streak at the time this entry was saved.
    var streakCount: Int
    /// The UUID of the corresponding HealthKit sample, used to delete it when this entry is removed.
    var healthKitUUID: UUID?
    /// Stored as an encoded blob because SwiftData/Core Data does not reliably bridge `[Data]`.
    private var photosStorage: Data?

    @Transient private var decodedPhotosCache: [Data]?

    /// All progress photos attached to this entry.
    var photosData: [Data] {
        get {
            if let cached = decodedPhotosCache {
                return cached
            }
            let decoded = Self.decodePhotos(from: photosStorage)
            decodedPhotosCache = decoded
            return decoded
        }
        set {
            photosStorage = Self.encodePhotos(newValue)
            decodedPhotosCache = newValue
        }
    }

    /// Convenience accessor for the first (primary) photo.
    var photoData: Data? { photosData.first }

    /// Fast metadata for UI invalidation without decoding the stored photo blob.
    var hasPhotos: Bool { photosStorage != nil }

    /// Tracks photo changes cheaply so scrolling views can refresh cached thumbnails when needed.
    var photosFingerprint: Int { photosStorage?.hashValue ?? 0 }

    init(
        weight: Double,
        includesWeight: Bool = true,
        timestamp: Date = Date(),
        source: WeightSource = .manual,
        note: String? = nil,
        streakCount: Int = 0,
        healthKitUUID: UUID? = nil,
        photoData: Data? = nil
    ) {
        self.weight = weight
        self.includesWeight = includesWeight
        self.timestamp = timestamp
        self.source = source
        self.note = note
        self.streakCount = streakCount
        self.healthKitUUID = healthKitUUID
        self.photosStorage = Self.encodePhotos(photoData.map { [$0] } ?? [])
    }

    private static func encodePhotos(_ photos: [Data]) -> Data? {
        guard !photos.isEmpty else { return nil }
        return try? JSONEncoder().encode(photos)
    }

    private static func decodePhotos(from storage: Data?) -> [Data] {
        guard let storage else { return [] }

        if let photos = try? JSONDecoder().decode([Data].self, from: storage) {
            return photos
        }

        // Preserve older single-photo records if they exist in the store.
        return [storage]
    }
}

@Model
final class WorkoutEntry {
    var timestamp: Date
    var activityTypeRawValue: UInt
    var duration: TimeInterval
    var energyBurnedKilocalories: Double?
    var distanceMiles: Double?
    var source: WorkoutSource
    /// The UUID of the corresponding HealthKit workout, used to deduplicate imports.
    var healthKitUUID: UUID?

    init(
        timestamp: Date = Date(),
        activityTypeRawValue: UInt,
        duration: TimeInterval,
        energyBurnedKilocalories: Double? = nil,
        distanceMiles: Double? = nil,
        source: WorkoutSource = .appleHealth,
        healthKitUUID: UUID? = nil
    ) {
        self.timestamp = timestamp
        self.activityTypeRawValue = activityTypeRawValue
        self.duration = duration
        self.energyBurnedKilocalories = energyBurnedKilocalories
        self.distanceMiles = distanceMiles
        self.source = source
        self.healthKitUUID = healthKitUUID
    }
}

@Model
final class DailyActivitySummary {
    var date: Date
    var stepCount: Int
    var activeEnergyBurnedKilocalories: Double
    var source: DailyActivitySource

    init(
        date: Date,
        stepCount: Int = 0,
        activeEnergyBurnedKilocalories: Double = 0,
        source: DailyActivitySource = .appleHealth
    ) {
        self.date = date
        self.stepCount = stepCount
        self.activeEnergyBurnedKilocalories = activeEnergyBurnedKilocalories
        self.source = source
    }
}

enum SleepStage: String, Codable {
    case core
    case deep
    case rem
    case unspecified
}

@Model
final class SleepEntry {
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var source: SleepSource
    var stageRawValue: String?
    /// The UUID of the corresponding HealthKit category sample, used to deduplicate imports.
    var healthKitUUID: UUID?

    var stage: SleepStage {
        get { stageRawValue.flatMap(SleepStage.init(rawValue:)) ?? .unspecified }
        set { stageRawValue = newValue.rawValue }
    }

    init(
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        source: SleepSource = .appleHealth,
        stage: SleepStage = .unspecified,
        healthKitUUID: UUID? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.source = source
        self.stageRawValue = stage.rawValue
        self.healthKitUUID = healthKitUUID
    }
}
