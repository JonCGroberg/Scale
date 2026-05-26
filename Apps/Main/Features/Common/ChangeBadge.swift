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
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0

    private var period: TimePeriod {
        TimePeriod.allCases[currentIndex]
    }

    private var selectedGoal: WeightGoal {
        WeightGoal(rawValue: weightGoal) ?? .defaultValue
    }

    private var summary: WeightCalculations.BadgeSummary {
        WeightCalculations.badgeSummary(from: entries, over: period)
    }

    private var goalProgress: WeightCalculations.GoalProgress? {
        guard let target = GoalProgressFeedback.target(
            for: selectedGoal,
            cutTarget: cutTargetWeight,
            bulkTarget: bulkTargetWeight
        ) else { return nil }

        return WeightCalculations.goalProgress(
            from: entries,
            goal: selectedGoal,
            targetWeight: target,
            over: period
        )
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var hasEntries: Bool {
        !entries.isEmpty
    }

    /// Splits a string ending in " lbs" into the leading body and the "lbs" suffix.
    /// E.g. "↓ 19.1/54.0 lbs" → ("↓ 19.1/54.0 ", "lbs").
    private func splitOffLbs(_ text: String) -> (body: String, lbs: String) {
        if let range = text.range(of: "lbs", options: .backwards) {
            return (String(text[..<range.lowerBound]), String(text[range.lowerBound...]))
        }
        return (text, "")
    }

    /// 0...1 positions of each mini-goal along the goal progress bar.
    private var miniGoalFractions: [Double] {
        guard let progress = goalProgress, progress.totalDistance > 0 else { return [] }
        let miniGoals = MiniGoalStore.load(for: selectedGoal)
        return miniGoals.compactMap { mg -> Double? in
            let distanceFromTarget = abs(mg.targetWeight - progress.targetWeight)
            guard distanceFromTarget > 0, distanceFromTarget < progress.totalDistance else { return nil }
            return (progress.totalDistance - distanceFromTarget) / progress.totalDistance
        }
    }

    /// 0...1 fill fraction of the goal for this period, or nil when no goal/data.
    private var goalFillFraction: Double? {
        guard let progress = goalProgress, progress.totalDistance > 0 else { return nil }
        let raw = progress.completedDistance / progress.totalDistance
        return min(max(raw, 0), 1)
    }

    var body: some View {
        HStack(spacing: 4) {
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
                .fill(.secondary.opacity(0.4))
                .frame(width: 4, height: 4)

            if !hasEntries {
                Text("No entries yet")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            } else if let lbs = summary.weightChange {
                if let goalProgress {
                    let arrow = lbs < 0 ? "↓" : "↑"
                    let numerator = String(format: "%.1f", abs(lbs))
                    let denominator = String(format: "%.1f", abs(goalProgress.totalChange))
                    Text("\(Text(arrow).foregroundStyle(tintColor).fontWeight(.bold)) \(Text(numerator).foregroundStyle(tintColor).fontWeight(.bold))\(Text("/" + denominator).foregroundStyle(tintColor).fontWeight(.bold)) \(Text("lbs").foregroundStyle(tintColor).fontWeight(.bold))  this \(period.label.lowercased())")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                } else {
                    let raw = String(format: "%+.1f lbs", lbs)
                    let (body, lbsText) = splitOffLbs(raw)
                    Text("\(Text(body).fontWeight(.bold).foregroundStyle(.primary))\(Text(lbsText).foregroundStyle(tintColor).fontWeight(.bold))  this \(period.label.lowercased())")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            } else if let goalProgress {
                let raw = GoalProgressFeedback.progressText(goalProgress)
                let (body, lbsText) = splitOffLbs(raw)
                Text("\(Text(body).fontWeight(.bold).foregroundStyle(.primary))\(Text(lbsText).foregroundStyle(tintColor).fontWeight(.bold))  in \(period.label.lowercased())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("-- lbs this \(period.label.lowercased())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .glassEffect(in: Capsule(style: .continuous))
        .overlay(alignment: .bottom) {
            if let fraction = goalFillFraction {
                GeometryReader { proxy in
                    let trackWidth = max(0, proxy.size.width - 12)
                    let boundaries = ([0.0] + miniGoalFractions + [1.0]).sorted()
                    let segCount = boundaries.count - 1
                    let gap: CGFloat = 3

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.primary.opacity(0.12))
                            .frame(width: trackWidth, height: 2)

                        ForEach(0..<segCount, id: \.self) { i in
                            let segStart = boundaries[i]
                            let segEnd = boundaries[i + 1]
                            let leftPad: CGFloat = i == 0 ? 0 : gap / 2
                            let rightPad: CGFloat = i == segCount - 1 ? 0 : gap / 2
                            let segX = trackWidth * segStart + leftPad
                            let clampedFillEnd = min(fraction, segEnd)
                            let fillW: CGFloat = {
                                guard clampedFillEnd > segStart else { return 0 }
                                let reachedEnd = clampedFillEnd >= segEnd
                                return max(0, trackWidth * (clampedFillEnd - segStart) - leftPad - (reachedEnd ? rightPad : 0))
                            }()

                            if fillW > 0 {
                                Capsule()
                                    .fill(tintColor)
                                    .frame(width: fillW, height: 2)
                                    .offset(x: segX)
                            }
                        }
                    }
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 0)
                }
            }
        }
        .clipShape(Capsule(style: .continuous))
        .animation(.snappy, value: goalFillFraction)
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
