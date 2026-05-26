//
//  AppTint.swift
//  Scale
//
//  Created by Codex on 3/15/26.
//

import SwiftUI

enum AppTint: String, Identifiable {
    case blue
    case green
    case orange
    case pink
    case lavender
    case red
    case custom

    static let defaultValue: AppTint = .blue

    static let presets: [AppTint] = [.blue, .green, .orange, .pink, .lavender, .red]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Blue"
        case .green: "Green"
        case .orange: "Orange"
        case .pink: "Pink"
        case .lavender: "Lavender"
        case .red: "Red"
        case .custom: "Custom"
        }
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .pink: return Color(red: 1.0, green: 0.72, blue: 0.84)
        case .lavender: return Color(red: 0.72, green: 0.66, blue: 0.96)
        case .red: return .red
        case .custom:
            guard let hex = UserDefaults.standard.string(forKey: "customTintHex"),
                  let color = Color(hex: hex)
            else { return .blue }
            return color
        }
    }
}
