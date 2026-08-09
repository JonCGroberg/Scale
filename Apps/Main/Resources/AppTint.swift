//
//  AppTint.swift
//  Scale
//
//  Created by Codex on 3/15/26.
//

import SwiftUI
import UIKit

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

extension AppTint {
    /// A consistent two-color spectrum for sleep stages that never uses the active tint.
    static func sleepGradientEndpoints(excluding activeTint: AppTint) -> (Color, Color) {
        let coolCandidates: [AppTint] = [.lavender, .blue, .green, .pink, .orange, .red]
        let warmCandidates: [AppTint] = [.orange, .red, .pink, .green, .blue, .lavender]
        let start = coolCandidates.first(where: { $0 != activeTint })?.color ?? AppTint.lavender.color
        let end = warmCandidates.first(where: { $0 != activeTint })?.color ?? AppTint.orange.color
        return (start, end)
    }
}

extension Color {
    static func interpolated(from start: Color, to end: Color, amount: CGFloat) -> Color {
        let clampedAmount = min(max(amount, 0), 1)
        let startColor = UIColor(start)
        let endColor = UIColor(end)
        var startRed: CGFloat = 0
        var startGreen: CGFloat = 0
        var startBlue: CGFloat = 0
        var startAlpha: CGFloat = 0
        var endRed: CGFloat = 0
        var endGreen: CGFloat = 0
        var endBlue: CGFloat = 0
        var endAlpha: CGFloat = 0

        guard startColor.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha),
              endColor.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha)
        else {
            return start
        }

        return Color(
            red: startRed + (endRed - startRed) * clampedAmount,
            green: startGreen + (endGreen - startGreen) * clampedAmount,
            blue: startBlue + (endBlue - startBlue) * clampedAmount,
            opacity: startAlpha + (endAlpha - startAlpha) * clampedAmount
        )
    }
}
