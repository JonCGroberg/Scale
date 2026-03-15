//
//  WeightCalculations.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Foundation

enum WeightCalculations {

    /// Calculate the weight change between the two most recent entries.
    /// - Parameter entries: Weight entries sorted most-recent-first.
    /// - Returns: The difference in pounds (positive = gained), or nil if fewer than 2 entries.
    static func weightChange(from entries: [WeightEntry]) -> Double? {
        guard entries.count >= 2 else { return nil }
        return entries[0].weight - entries[1].weight
    }

    /// The timestamp of the second-most-recent entry (the comparison baseline).
    static func changeDate(from entries: [WeightEntry]) -> Date? {
        guard entries.count >= 2 else { return nil }
        return entries[1].timestamp
    }

    /// Parse a user-entered weight string into a valid positive Double.
    static func parseWeight(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    /// Parse text recognized by the scale scanner.
    /// Accepts 1-3 digits with an optional single decimal digit (e.g. "142.5", "85", "200.0").
    static func parseScannedWeight(_ transcript: String) -> Double? {
        let trimmed = transcript.trimmingCharacters(in: .whitespaces)
        guard trimmed.wholeMatch(of: /^\d{1,3}(\.\d{0,1})?$/) != nil,
              let weight = Double(trimmed), weight > 0 else {
            return nil
        }
        return weight
    }

    /// Group weight entries by month/year, sorted newest-first.
    static func groupedByMonth(_ entries: [WeightEntry]) -> [(key: String, value: [WeightEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.timestamp)
        }

        return grouped.sorted { a, b in
            guard let dateA = a.value.first?.timestamp,
                  let dateB = b.value.first?.timestamp else { return false }
            return dateA > dateB
        }
    }
}
