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

    var body: some View {
        HStack(spacing: 6) {
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.accent.opacity(0.1), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.accent.opacity(0.2), lineWidth: 1)
        )
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
