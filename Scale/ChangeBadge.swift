//
//  ChangeBadge.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI

struct ChangeBadge: View {
    let entries: [WeightEntry]

    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("badgePeriodIndex") private var currentIndex: Int = 1

    private var period: TimePeriod {
        TimePeriod.allCases[currentIndex]
    }

    private var summary: WeightCalculations.BadgeSummary {
        WeightCalculations.badgeSummary(from: entries, over: period)
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    var body: some View {
        HStack(spacing: 6) {
            if summary.streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Text("\(summary.streak)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }

                Circle()
                    .fill(tintColor.opacity(0.4))
                    .frame(width: 4, height: 4)
            }

            if let lbs = summary.weightChange {
                let direction = lbs >= 0 ? "Up" : "Down"
                Text("\(direction) \(String(format: "%.1f", abs(lbs))) lbs this \(period.label)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tintColor)
                    .contentTransition(.numericText())
            } else {
                Text("No change this \(period.label)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect()
        .animation(.snappy, value: currentIndex)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let threshold: CGFloat = 30
                    if value.translation.width < -threshold {
                        withAnimation(.snappy) {
                            currentIndex = min(currentIndex + 1, TimePeriod.allCases.count - 1)
                        }
                    } else if value.translation.width > threshold {
                        withAnimation(.snappy) {
                            currentIndex = max(currentIndex - 1, 0)
                        }
                    }
                }
        )
    }
}
