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

@Model
final class WeightEntry {
    var weight: Double
    var timestamp: Date
    var source: WeightSource
    /// The consecutive-day logging streak at the time this entry was saved.
    var streakCount: Int
    /// The UUID of the corresponding HealthKit sample, used to delete it when this entry is removed.
    var healthKitUUID: UUID?
    /// All progress photos attached to this entry.
    var photosData: [Data]

    /// Convenience accessor for the first (primary) photo.
    var photoData: Data? { photosData.first }

    init(
        weight: Double,
        timestamp: Date = Date(),
        source: WeightSource = .manual,
        streakCount: Int = 0,
        healthKitUUID: UUID? = nil,
        photoData: Data? = nil
    ) {
        self.weight = weight
        self.timestamp = timestamp
        self.source = source
        self.streakCount = streakCount
        self.healthKitUUID = healthKitUUID
        self.photosData = photoData.map { [$0] } ?? []
    }
}
