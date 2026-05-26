//
//  WidgetSupport.swift
//  ScaleWidget
//
//  Created by Codex on 3/16/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

    static let preview = WeightWidgetSnapshot(
        generatedAt: .now,
        appTintRawValue: "green",
        customTintHex: nil,
        latestWeight: 182.4,
        latestTimestamp: .now.addingTimeInterval(-4_200),
        streakCount: 6,
        monthAverage: 183.1,
        monthPercentChange: -1.4
    )
}

enum WeightWidgetSnapshotStore {
    static let appGroupID = "group.groberg.Scale"
    static let widgetKind = "groberg.Scale.weight-summary"
    static let addWeightWidgetKind = "groberg.Scale.add-weight"

    private static let fileName = "WeightWidgetSnapshot.json"
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func load(fileManager: FileManager = .default) -> WeightWidgetSnapshot {
        guard
            let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
            let data = try? Data(contentsOf: containerURL.appendingPathComponent(fileName, conformingTo: .json)),
            let snapshot = try? decoder.decode(WeightWidgetSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }
}

enum WidgetTintPalette {
    static func color(for rawValue: String, customHex: String? = nil) -> Color {
        if rawValue == "custom", let hex = customHex ?? UserDefaults.standard.string(forKey: "customTintHex") {
            return Color(hex: hex) ?? .blue
        }
        switch rawValue {
        case "green":
            return .green
        case "orange":
            return .orange
        case "pink":
            return Color(red: 1.0, green: 0.72, blue: 0.84)
        case "lavender":
            return Color(red: 0.72, green: 0.66, blue: 0.96)
        case "red":
            return .red
        default:
            return .blue
        }
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension WeightWidgetSnapshot {
    var latestWeightText: String {
        latestWeight.map(\.formattedWeight) ?? "--"
    }

    var relativeDateText: String {
        guard let latestTimestamp else { return "Waiting for data" }
        return latestTimestamp.formatted(.relative(presentation: .named))
    }

    var monthTrendText: String? {
        guard let monthPercentChange else { return nil }
        let sign = monthPercentChange > 0 ? "+" : ""
        return "\(sign)\(monthPercentChange.formatted(.number.precision(.fractionLength(1))))%"
    }

    var monthPercentChangeColor: Color {
        guard let monthPercentChange else { return .secondary }
        if monthPercentChange < 0 {
            return .green
        }
        if monthPercentChange > 0 {
            return .orange
        }
        return .secondary
    }

    var inlineText: String {
        guard let latestWeight else { return "Scale: log your first weight" }
        return "Scale \(latestWeight.formattedWeight) lb • \(streakCount)d streak"
    }

    var inlineStreakText: String {
        if streakCount > 0 {
            return "Scale \(streakCount)d streak"
        }
        return "Scale: log your first weight"
    }

    var circularValueText: String {
        if let latestWeight {
            return latestWeight.formattedWeight
        }
        return "--"
    }

    var circularCaptionText: String {
        latestWeight == nil ? "LOG" : "\(streakCount)D"
    }

    var streakText: String {
        "\(streakCount)"
    }

    var streakSubtitleText: String {
        streakCount == 1 ? "day" : "days"
    }
}

extension Double {
    var formattedWeight: String {
        formatted(.number.precision(.fractionLength(1)))
    }
}
