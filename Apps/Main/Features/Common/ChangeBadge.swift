//
//  ChangeBadge.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI

struct ChartDaySelection: Equatable {
    let date: Date
    let value: String
}

struct ChangeBadge: View {
    let entries: [WeightEntry]
    let showsRange: Bool
    let chartSelection: ChartDaySelection?
    let periodOverride: TimePeriod?

    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("badgePeriodIndex") private var currentIndex: Int = 2
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0

    init(
        entries: [WeightEntry],
        showsRange: Bool = false,
        chartSelection: ChartDaySelection? = nil,
        periodOverride: TimePeriod? = nil
    ) {
        self.entries = entries
        self.showsRange = showsRange
        self.chartSelection = chartSelection
        self.periodOverride = periodOverride
    }

    private var period: TimePeriod {
        periodOverride ?? TimePeriod.allCases[currentIndex]
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

        // The selected chart range controls the period-change copy in the
        // badge, not the goal itself. Using it here made the goal's starting
        // weight—and consequently its denominator and progress bar—change
        // whenever the user switched ranges.
        return WeightCalculations.goalProgress(
            from: entries,
            goal: selectedGoal,
            targetWeight: target,
            over: .year
        )
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var hasEntries: Bool {
        entries.contains(where: \.includesWeight)
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
            .frame(height: showsRange ? nil : 44)
            .padding(.bottom, showsRange ? 8 : 0)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: showsRange)
        .animation(.snappy, value: goalFillFraction)
        .animation(.snappy, value: currentIndex)
        .sensoryFeedback(.selection, trigger: currentIndex)
    }

    private var badgeContent: some View {
        VStack(spacing: 4) {
            summaryRow

            if showsRange {
                Divider()

                Picker("Time range", selection: Binding(
                    get: { period },
                    set: { newPeriod in
                        guard let index = TimePeriod.allCases.firstIndex(of: newPeriod) else { return }
                        currentIndex = index
                    }
                )) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .tint(tintColor)
                .labelsHidden()
                .accessibilityLabel("Time range")
                .frame(width: 216)
                .transition(.identity)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 4) {
            if chartSelection == nil {
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
            }

            if let chartSelection {
                Text("\(Text(chartSelection.date.formatted(.dateTime.month(.abbreviated).day())).foregroundStyle(.secondary)) \(Text("·").foregroundStyle(.secondary)) \(Text(chartSelection.value).foregroundStyle(tintColor).fontWeight(.bold))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
            } else if !hasEntries {
                Text("No entries yet")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            } else if let lbs = summary.weightChange {
                if goalProgress != nil {
                    let arrow = lbs < 0 ? "↓" : "↑"
                    let amount = String(format: "%.1f", abs(lbs))
                    Text("\(Text(arrow).foregroundStyle(tintColor).fontWeight(.bold)) \(Text(amount).foregroundStyle(tintColor).fontWeight(.bold)) \(Text("lbs").foregroundStyle(tintColor).fontWeight(.bold))  \(thisPeriodPhrase)")
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
        .frame(width: showsRange ? 244 : nil)
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

/// The overview chart's range selector, presented in the Health section header.
struct TimeRangePill: View {
    var isPillStyled = true
    var width: CGFloat = 240
    var height: CGFloat = 48
    @AppStorage("badgePeriodIndex") private var currentIndex: Int = 2
    @State private var dragStartIndex: Int?

    private var validIndex: Int {
        min(max(currentIndex, 0), TimePeriod.allCases.count - 1)
    }

    private var selectedPeriod: TimePeriod {
        TimePeriod.allCases.indices.contains(currentIndex)
            ? TimePeriod.allCases[currentIndex]
            : .today
    }

    var body: some View {
        GeometryReader { proxy in
            let selectedTitle = selectedPeriod == .today ? selectedPeriod.label : selectedPeriod.rawValue
            let handleWidth: CGFloat = selectedPeriod == .today ? 72 : 54
            let contentInset: CGFloat = isPillStyled ? 5 : 0
            let contentWidth = max(proxy.size.width - contentInset * 2, handleWidth)
            let contentHeight = max(proxy.size.height - contentInset * 2, 1)
            let travel = max(contentWidth - handleWidth, 1)
            let step = travel / CGFloat(max(TimePeriod.allCases.count - 1, 1))
            let handleOffset = CGFloat(validIndex) * step

            ZStack(alignment: .leading) {
                // Position each marker on the exact centre point of the movable
                // selection handle. A flexible HStack would inset its first and
                // last dots, making the active pill look slightly off-centre.
                ForEach(TimePeriod.allCases.indices, id: \.self) { index in
                    let isSelected = index == validIndex
                    let dotSize: CGFloat = isSelected ? 5 : 3

                    Circle()
                        .fill(isSelected ? Color.primary.opacity(0.42) : Color.primary.opacity(0.16))
                        .frame(width: dotSize, height: dotSize)
                        .position(
                            x: contentInset + (handleWidth / 2) + CGFloat(index) * step,
                            y: proxy.size.height / 2
                        )
                }

                Text(selectedTitle)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .frame(width: handleWidth, height: contentHeight)
                    .background {
                        if isPillStyled || selectedPeriod == .today {
                            Capsule().fill(Color.primary.opacity(0.22))
                        } else {
                            Circle().fill(Color.primary.opacity(0.18))
                        }
                    }
                    .offset(x: contentInset + handleOffset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartIndex == nil {
                            dragStartIndex = validIndex
                        }
                        guard let dragStartIndex else { return }
                        let stepChange = Int((value.translation.width / step).rounded())
                        currentIndex = min(max(dragStartIndex + stepChange, 0), TimePeriod.allCases.count - 1)
                    }
                    .onEnded { _ in
                        dragStartIndex = nil
                    }
            )
        }
        .frame(width: width, height: height)
        .glassEffect(isPillStyled ? .regular.interactive() : .identity, in: Capsule())
        .accessibilityLabel("Time range")
        .accessibilityValue(selectedPeriod.label)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                currentIndex = min(validIndex + 1, TimePeriod.allCases.count - 1)
            case .decrement:
                currentIndex = max(validIndex - 1, 0)
            @unknown default:
                break
            }
        }
        // Drag and accessibility adjustments both change this shared value. Using
        // the app's haptics helper ensures every actual range change has feedback.
        .onChange(of: currentIndex) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Haptics.selection()
        }
    }
}
