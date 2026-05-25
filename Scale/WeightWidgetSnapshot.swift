//
//  WeightWidgetSnapshot.swift
//  Scale
//
//  Created by Codex on 3/16/26.
//

import Foundation

struct WeightWidgetSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let appTintRawValue: String
    let customTintHex: String?
    let latestWeight: Double?
    let latestTimestamp: Date?
    let streakCount: Int
    let monthAverage: Double?
    let monthPercentChange: Double?

    static let empty = WeightWidgetSnapshot(
        generatedAt: .distantPast,
        appTintRawValue: "blue",
        customTintHex: nil,
        latestWeight: nil,
        latestTimestamp: nil,
        streakCount: 0,
        monthAverage: nil,
        monthPercentChange: nil
    )

    static func make(
        from entries: [WeightEntry],
        tintRawValue: String,
        now: Date = Date()
    ) -> WeightWidgetSnapshot {
        let sortedEntries = entries.sorted { $0.timestamp > $1.timestamp }
        let summary = WeightCalculations.badgeSummary(from: sortedEntries, over: .month)
        let customTintHex: String? = tintRawValue == "custom"
            ? UserDefaults.standard.string(forKey: "customTintHex")
            : nil

        return WeightWidgetSnapshot(
            generatedAt: now,
            appTintRawValue: tintRawValue,
            customTintHex: customTintHex,
            latestWeight: sortedEntries.first?.weight,
            latestTimestamp: sortedEntries.first?.timestamp,
            streakCount: summary.streak,
            monthAverage: summary.average,
            monthPercentChange: WeightCalculations.percentageChange(from: sortedEntries, over: .month)
        )
    }
}
