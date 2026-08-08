//
//  ChangeBadge.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI

struct ChangeBadge: View {
    let entries: [WeightEntry]
    let showsRange: Bool

    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("badgePeriodIndex") private var currentIndex: Int = 2
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0

    init(entries: [WeightEntry], showsRange: Bool = false) {
        self.entries = entries
        self.showsRange = showsRange
    }

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

    /// "this week" / "today" — reads naturally after "... lbs ".
    private var thisPeriodPhrase: String {
        period == .today ? "today" : "this \(period.label.lowercased())"
    }

    /// "in week" / "today" — reads naturally after "... lbs ".
    private var inPeriodPhrase: String {
        period == .today ? "today" : "in \(period.label.lowercased())"
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
        // Keep one glass host alive across tabs. The overview-only range control
        // expands inside this badge instead of replacing it with a second pill.
        badgeContent
            .frame(width: showsRange ? 244 : nil)
            .padding(.bottom, showsRange ? 8 : 0)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: showsRange)
        .animation(.snappy, value: goalFillFraction)
        .animation(.snappy, value: currentIndex)
        .sensoryFeedback(.selection, trigger: currentIndex)
    }

    private var periodSwipeGesture: some Gesture {
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
    }

    private var badgeContent: some View {
        VStack(spacing: 4) {
            summaryRow
                .simultaneousGesture(periodSwipeGesture)

            if showsRange {
                Divider()

                Picker("Chart range", selection: $currentIndex) {
                    ForEach(Array(TimePeriod.allCases.enumerated()), id: \.offset) { index, period in
                        Text(period.rawValue).tag(index)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 216)
                .transition(.identity)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
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
                    Text("\(Text(arrow).foregroundStyle(tintColor).fontWeight(.bold)) \(Text(numerator).foregroundStyle(tintColor).fontWeight(.bold))\(Text("/" + denominator).foregroundStyle(tintColor).fontWeight(.bold)) \(Text("lbs").foregroundStyle(tintColor).fontWeight(.bold))  \(thisPeriodPhrase)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                } else {
                    let raw = String(format: "%+.1f lbs", lbs)
                    let (body, lbsText) = splitOffLbs(raw)
                    Text("\(Text(body).fontWeight(.bold).foregroundStyle(.primary))\(Text(lbsText).foregroundStyle(tintColor).fontWeight(.bold))  \(thisPeriodPhrase)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            } else if let goalProgress {
                let raw = GoalProgressFeedback.progressText(goalProgress)
                let (body, lbsText) = splitOffLbs(raw)
                Text("\(Text(body).fontWeight(.bold).foregroundStyle(.primary))\(Text(lbsText).foregroundStyle(tintColor).fontWeight(.bold))  \(inPeriodPhrase)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("-- lbs \(thisPeriodPhrase)")
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
    }
}
