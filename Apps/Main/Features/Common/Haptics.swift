//
//  Haptics.swift
//  Scale
//
//  Created by Codex on 3/15/26.
//

import UIKit

enum Haptics {
    static var isEnabledOverride: Bool?

    private static var isEnabled: Bool {
        if let isEnabledOverride {
            return isEnabledOverride
        }

        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    static func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
