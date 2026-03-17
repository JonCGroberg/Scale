//
//  AppTint.swift
//  Scale
//
//  Created by Codex on 3/15/26.
//

import SwiftUI

enum AppTint: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case pink
    case lavender
    case red

    static let defaultValue: AppTint = .blue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue:
            "Blue"
        case .green:
            "Green"
        case .orange:
            "Orange"
        case .pink:
            "Pink"
        case .lavender:
            "Lavender"
        case .red:
            "Red"
        }
    }

    var color: Color {
        switch self {
        case .blue:
            .blue
        case .green:
            .green
        case .orange:
            .orange
        case .pink:
            Color(red: 1.0, green: 0.72, blue: 0.84)
        case .lavender:
            Color(red: 0.72, green: 0.66, blue: 0.96)
        case .red:
            .red
        }
    }
}
