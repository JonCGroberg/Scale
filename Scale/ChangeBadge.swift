//
//  ChangeBadge.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI

struct ChangeBadge: View {
    let entries: [WeightEntry]

    @State private var currentIndex: Int = 1  // default to month (index 1)
    @GestureState private var dragOffset: CGFloat = 0

    private var period: TimePeriod {
        TimePeriod.allCases[currentIndex]
    }

    private var average: Double? {
        WeightCalculations.averageWeight(from: entries, over: period)
    }

    private var percentChange: Double? {
        WeightCalculations.percentageChange(from: entries, over: period)
    }

    private var streak: Int {
        WeightCalculations.currentStreak(from: entries)
    }

    var body: some View {
        HStack(spacing: 6) {
            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Text("\(streak)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }

                Circle()
                    .fill(.accent.opacity(0.4))
                    .frame(width: 4, height: 4)
            }

            if let avg = average {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.text.clipboard")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)

                    Text(String(format: "%.1f lbs", avg))
                        .font(.caption)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }

                Circle()
                    .fill(.accent.opacity(0.4))
                    .frame(width: 4, height: 4)
            }

            Text("\(period.label) Avg")
                .font(.caption2)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)

            if let pct = percentChange {
                Circle()
                    .fill(.accent.opacity(0.4))
                    .frame(width: 4, height: 4)

                Text(String(format: "%+.1f%%", pct))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(pct <= 0 ? .green : .red)
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
                        // Swipe left → next period
                        withAnimation(.snappy) {
                            currentIndex = min(currentIndex + 1, TimePeriod.allCases.count - 1)
                        }
                    } else if value.translation.width > threshold {
                        // Swipe right → previous period
                        withAnimation(.snappy) {
                            currentIndex = max(currentIndex - 1, 0)
                        }
                    }
                }
        )
    }
}
