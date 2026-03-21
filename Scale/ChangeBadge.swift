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

            if let avg = summary.average {
                Text(String(format: "%.1f lbs", avg))
                    .font(.caption)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())

                Circle()
                    .fill(tintColor.opacity(0.4))
                    .frame(width: 4, height: 4)
            }

            Text("\(period.label) Avg")
                .font(.caption2)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)

            if let lbs = summary.weightChange {
                Circle()
                    .fill(tintColor.opacity(0.4))
                    .frame(width: 4, height: 4)

                Text(String(format: "%+.1f lbs", lbs))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(tintColor)
                    .contentTransition(.numericText())
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
