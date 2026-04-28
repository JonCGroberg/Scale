//
//  GoalProgressFeedback.swift
//  Scale
//
//  Created by Codex on 4/26/26.
//

import Foundation

enum GoalProgressFeedback {
    static func target(for goal: WeightGoal, cutTarget: Double, bulkTarget: Double) -> Double? {
        switch goal {
        case .lose:
            cutTarget
        case .maintain:
            nil
        case .gain:
            bulkTarget
        }
    }

    static func isCloserToGoal(
        goal: WeightGoal,
        previousWeight: Double?,
        newWeight: Double,
        cutTarget: Double,
        bulkTarget: Double
    ) -> Bool {
        guard let previousWeight,
              let target = target(for: goal, cutTarget: cutTarget, bulkTarget: bulkTarget) else {
            return false
        }

        return abs(newWeight - target) < abs(previousWeight - target)
    }

    static func didReachGoal(
        goal: WeightGoal,
        newWeight: Double,
        cutTarget: Double,
        bulkTarget: Double
    ) -> Bool {
        switch goal {
        case .lose:
            newWeight <= cutTarget
        case .maintain:
            false
        case .gain:
            newWeight >= bulkTarget
        }
    }

    static func nextTargetDefault(goal: WeightGoal, reachedWeight: Double) -> Double {
        switch goal {
        case .lose:
            max(reachedWeight - 10, 50)
        case .maintain:
            reachedWeight
        case .gain:
            min(reachedWeight + 10, 700)
        }
    }

    static func progressText(_ progress: WeightCalculations.GoalProgress) -> String {
        let sign = progress.totalChange < 0 ? "-" : "+"
        return String(
            format: "%@%.1f/%.1f lbs",
            sign,
            abs(progress.completedChange),
            abs(progress.totalChange)
        )
    }
}
