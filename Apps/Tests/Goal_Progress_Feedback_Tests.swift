//
//  Goal_Progress_Feedback_Tests.swift
//  ScaleTests
//
//  Created by Codex on 4/26/26.
//

import Testing
@testable import Scale

struct GoalProgressFeedbackTests {
    @Test func cutGoalTriggersWhenWeightMovesCloserToCutTarget() {
        #expect(GoalProgressFeedback.isCloserToGoal(
            goal: .lose,
            previousWeight: 190,
            newWeight: 185,
            cutTarget: 180,
            bulkTarget: 200
        ))
    }

    @Test func bulkGoalTriggersWhenWeightMovesCloserToBulkTarget() {
        #expect(GoalProgressFeedback.isCloserToGoal(
            goal: .gain,
            previousWeight: 185,
            newWeight: 190,
            cutTarget: 170,
            bulkTarget: 200
        ))
    }

    @Test func maintainGoalDoesNotTriggerCelebration() {
        #expect(!GoalProgressFeedback.isCloserToGoal(
            goal: .maintain,
            previousWeight: 185,
            newWeight: 184,
            cutTarget: 170,
            bulkTarget: 200
        ))
    }

    @Test func missingPreviousWeightDoesNotTriggerCelebration() {
        #expect(!GoalProgressFeedback.isCloserToGoal(
            goal: .lose,
            previousWeight: nil,
            newWeight: 184,
            cutTarget: 170,
            bulkTarget: 200
        ))
    }

    @Test func cutGoalIsReachedAtOrBelowTarget() {
        #expect(GoalProgressFeedback.didReachGoal(
            goal: .lose,
            newWeight: 180,
            cutTarget: 180,
            bulkTarget: 200
        ))
        #expect(GoalProgressFeedback.didReachGoal(
            goal: .lose,
            newWeight: 179.9,
            cutTarget: 180,
            bulkTarget: 200
        ))
    }

    @Test func bulkGoalIsReachedAtOrAboveTarget() {
        #expect(GoalProgressFeedback.didReachGoal(
            goal: .gain,
            newWeight: 200,
            cutTarget: 180,
            bulkTarget: 200
        ))
        #expect(GoalProgressFeedback.didReachGoal(
            goal: .gain,
            newWeight: 200.1,
            cutTarget: 180,
            bulkTarget: 200
        ))
    }

    @Test func maintainGoalIsNeverReached() {
        #expect(!GoalProgressFeedback.didReachGoal(
            goal: .maintain,
            newWeight: 180,
            cutTarget: 180,
            bulkTarget: 200
        ))
    }

    @Test func nextCutTargetDefaultsTenPoundsBelowReachedWeight() {
        #expect(GoalProgressFeedback.nextTargetDefault(goal: .lose, reachedWeight: 172) == 162)
    }

    @Test func nextBulkTargetDefaultsTenPoundsAboveReachedWeight() {
        #expect(GoalProgressFeedback.nextTargetDefault(goal: .gain, reachedWeight: 188) == 198)
    }

    @Test func nextTargetDefaultsStayInsideSupportedWeightRange() {
        #expect(GoalProgressFeedback.nextTargetDefault(goal: .lose, reachedWeight: 55) == 50)
        #expect(GoalProgressFeedback.nextTargetDefault(goal: .gain, reachedWeight: 695) == 700)
    }
}
