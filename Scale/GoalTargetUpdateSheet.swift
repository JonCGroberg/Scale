//
//  GoalTargetUpdateSheet.swift
//  Scale
//
//  Created by Codex on 4/26/26.
//

import SwiftUI

struct GoalTargetUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0

    let goal: WeightGoal
    let reachedWeight: Double
    let tintColor: Color

    @State private var targetText = ""
    @FocusState private var targetFieldFocused: Bool

    private var currentTarget: Double {
        switch goal {
        case .lose:
            GoalProgressFeedback.nextTargetDefault(goal: goal, reachedWeight: reachedWeight)
        case .maintain:
            cutTargetWeight
        case .gain:
            GoalProgressFeedback.nextTargetDefault(goal: goal, reachedWeight: reachedWeight)
        }
    }

    private var title: String {
        switch goal {
        case .lose:
            "Main goal reached"
        case .maintain:
            "Goal reached"
        case .gain:
            "Main goal reached"
        }
    }

    private var prompt: String {
        switch goal {
        case .lose:
            "Set your next main goal."
        case .maintain:
            "Set your next goal."
        case .gain:
            "Set your next main goal."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("Goal", text: $targetText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .foregroundStyle(tintColor)
                            .monospacedDigit()
                            .focused($targetFieldFocused)

                        Text("lbs")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text(prompt)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTarget()
                    }
                    .fontWeight(.semibold)
                    .disabled(WeightCalculations.parseWeight(from: targetText) == nil)
                }
            }
            .onAppear {
                targetText = String(format: "%.1f", currentTarget)
                targetFieldFocused = true
            }
        }
        .presentationDetents([.height(260), .medium])
        .liquidGlassSheetPresentation()
    }

    private func saveTarget() {
        guard let value = WeightCalculations.parseWeight(from: targetText) else {
            return
        }

        let clampedValue = min(max(value, 50), 700)
        switch goal {
        case .lose:
            cutTargetWeight = clampedValue
        case .maintain:
            break
        case .gain:
            bulkTargetWeight = clampedValue
        }

        Haptics.success()
        dismiss()
    }
}
