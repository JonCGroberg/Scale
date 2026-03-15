//
//  Item.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Foundation
import SwiftData

@Model
final class WeightEntry {
    var weight: Double
    var timestamp: Date
    
    init(weight: Double, timestamp: Date = Date()) {
        self.weight = weight
        self.timestamp = timestamp
    }
}
