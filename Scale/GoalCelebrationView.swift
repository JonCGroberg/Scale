//
//  GoalCelebrationView.swift
//  Scale
//
//  Created by Codex on 4/26/26.
//

import SwiftUI
import ConfettiSwiftUI

struct GoalCelebrationView: View {
    let tintColor: Color
    var message = "Closer to goal"
    var systemImage = "target"

    @State private var isAnimating = false
    @State private var confettiTrigger = 0

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .glassEffect(
                .regular.tint(tintColor.opacity(0.14)),
                in: Capsule(style: .continuous)
            )
            .scaleEffect(isAnimating ? 1 : 0.82)
            .opacity(isAnimating ? 1 : 0)
            .confettiCannon(
                trigger: $confettiTrigger,
                num: 70,
                colors: [tintColor, .pink, .orange, .mint, .cyan, .yellow],
                confettiSize: 11,
                radius: 360,
                repetitions: 2,
                repetitionInterval: 0.22,
                hapticFeedback: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                    isAnimating = true
                }
                confettiTrigger += 1
            }
    }
}
