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

    private var hasEntries: Bool {
        !entries.isEmpty
    }

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Text("\(summary.streak)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
            }

            Circle()
                .fill(.secondary.opacity(0.4))
                .frame(width: 4, height: 4)

            if !hasEntries {
                Text("No entries yet")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            } else if let lbs = summary.weightChange {
                Text("\(Text(String(format: "%+.1f lbs", lbs)).foregroundStyle(tintColor))  in \(period.label.lowercased())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("-- lbs in \(period.label.lowercased())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }
        }
        .padding(.horizontal,8 )
        .padding(.vertical,4)
   
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
        .sensoryFeedback(.selection, trigger: currentIndex)
    }
}
