import SwiftUI
import ConfettiSwiftUI
import Vortex

enum CelebrationType {
    case confetti
    case fireworks
}

struct GoalCelebrationView: View {
    let tintColor: Color
    var message: Text = Text("Closer to goal")
    var systemImage = "target"
    var type: CelebrationType = .confetti

    @State private var isAnimating = false
    @State private var confettiTrigger = 0

    private var fireworksSystem: VortexSystem {
        let system = VortexSystem.fireworks.makeUniqueCopy()
        system.burstCount = 8
        return system
    }

    var body: some View {
        ZStack {
            if type == .fireworks {
                VortexViewReader { proxy in
                    VortexView(fireworksSystem) {
                        Circle()
                            .fill(.white)
                            .blendMode(.plusLighter)
                            .frame(width: 24)
                            .blur(radius: 4)
                            .tag("circle")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .onAppear {
                        proxy.burst()
                    }
                }
            }

            Label {
                message
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: systemImage)
            }
                .padding(.horizontal, 18)
                .frame(height: 46)
                .glassEffect(
                    .regular.tint(tintColor.opacity(0.14)),
                    in: Capsule(style: .continuous)
                )
                .scaleEffect(isAnimating ? 1 : 0.82)
                .opacity(isAnimating ? 1 : 0)

            if type == .confetti {
                Color.clear
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                isAnimating = true
            }
            if type == .confetti {
                confettiTrigger += 1
            }
        }
    }
}
