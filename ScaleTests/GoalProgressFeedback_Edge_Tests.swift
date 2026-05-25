import Testing
import Foundation
@testable import Scale

struct GoalProgressFeedbackEdgeTests {
    // MARK: - target

    @Test func targetForLoseReturnsCutTarget() {
        #expect(GoalProgressFeedback.target(for: .lose, cutTarget: 170, bulkTarget: 200) == 170)
    }

    @Test func targetForGainReturnsBulkTarget() {
        #expect(GoalProgressFeedback.target(for: .gain, cutTarget: 170, bulkTarget: 200) == 200)
    }

    @Test func targetForMaintainReturnsNil() {
        #expect(GoalProgressFeedback.target(for: .maintain, cutTarget: 170, bulkTarget: 200) == nil)
    }

    // MARK: - distanceCloserToGoal

    @Test func distanceCloserCutGoalMovingCloser() {
        let distance = GoalProgressFeedback.distanceCloserToGoal(
            goal: .lose,
            previousWeight: 190,
            newWeight: 185,
            cutTarget: 180,
            bulkTarget: 200
        )
        #expect(distance == 5.0)
    }

    @Test func distanceCloserBulkGoalMovingCloser() {
        let distance = GoalProgressFeedback.distanceCloserToGoal(
            goal: .gain,
            previousWeight: 190,
            newWeight: 195,
            cutTarget: 170,
            bulkTarget: 200
        )
        #expect(distance == 5.0)
    }

    @Test func distanceCloserReturnsNilWhenMovingAway() {
        let distance = GoalProgressFeedback.distanceCloserToGoal(
            goal: .lose,
            previousWeight: 185,
            newWeight: 190,
            cutTarget: 180,
            bulkTarget: 200
        )
        #expect(distance == nil)
    }

    @Test func distanceCloserReturnsNilWhenNoPreviousWeight() {
        let distance = GoalProgressFeedback.distanceCloserToGoal(
            goal: .lose,
            previousWeight: nil,
            newWeight: 185,
            cutTarget: 180,
            bulkTarget: 200
        )
        #expect(distance == nil)
    }

    @Test func distanceCloserReturnsNilForMaintainGoal() {
        let distance = GoalProgressFeedback.distanceCloserToGoal(
            goal: .maintain,
            previousWeight: 190,
            newWeight: 185,
            cutTarget: 180,
            bulkTarget: 200
        )
        #expect(distance == nil)
    }

    @Test func distanceCloserReturnsNilWhenDistanceUnchanged() {
        let distance = GoalProgressFeedback.distanceCloserToGoal(
            goal: .lose,
            previousWeight: 180,
            newWeight: 180,
            cutTarget: 180,
            bulkTarget: 200
        )
        #expect(distance == nil)
    }

    // MARK: - achievedMiniGoal

    @Test func achievedMiniGoalCutGoalCrossesThreshold() {
        let miniGoals = [MiniGoal(parentGoal: .lose, name: "First", targetWeight: 185)]
        let achieved = GoalProgressFeedback.achievedMiniGoal(
            goal: .lose,
            previousWeight: 190,
            newWeight: 184,
            miniGoals: miniGoals
        )
        #expect(achieved?.name == "First")
    }

    @Test func achievedMiniGoalCutGoalDoesNotCrossThreshold() {
        let miniGoals = [MiniGoal(parentGoal: .lose, name: "First", targetWeight: 185)]
        let achieved = GoalProgressFeedback.achievedMiniGoal(
            goal: .lose,
            previousWeight: 190,
            newWeight: 188,
            miniGoals: miniGoals
        )
        #expect(achieved == nil)
    }

    @Test func achievedMiniGoalBulkGoalCrossesThreshold() {
        let miniGoals = [MiniGoal(parentGoal: .gain, name: "Bulk Target", targetWeight: 195)]
        let achieved = GoalProgressFeedback.achievedMiniGoal(
            goal: .gain,
            previousWeight: 190,
            newWeight: 196,
            miniGoals: miniGoals
        )
        #expect(achieved?.name == "Bulk Target")
    }

    @Test func achievedMiniGoalMaintainGoalNeverTriggers() {
        let miniGoals = [MiniGoal(parentGoal: .maintain, name: "Test", targetWeight: 185)]
        let achieved = GoalProgressFeedback.achievedMiniGoal(
            goal: .maintain,
            previousWeight: 190,
            newWeight: 185,
            miniGoals: miniGoals
        )
        #expect(achieved == nil)
    }

    @Test func achievedMiniGoalReturnsNilWhenNoPreviousWeight() {
        let miniGoals = [MiniGoal(parentGoal: .lose, name: "Test", targetWeight: 185)]
        let achieved = GoalProgressFeedback.achievedMiniGoal(
            goal: .lose,
            previousWeight: nil,
            newWeight: 180,
            miniGoals: miniGoals
        )
        #expect(achieved == nil)
    }

    @Test func achievedMiniGoalReturnsFirstMatchingGoal() {
        let miniGoals = [
            MiniGoal(parentGoal: .lose, name: "First", targetWeight: 190),
            MiniGoal(parentGoal: .lose, name: "Second", targetWeight: 185),
        ]
        let achieved = GoalProgressFeedback.achievedMiniGoal(
            goal: .lose,
            previousWeight: 195,
            newWeight: 189,
            miniGoals: miniGoals
        )
        #expect(achieved?.name == "First")
    }

    @Test func achievedMiniGoalEmptyMiniGoals() {
        let achieved = GoalProgressFeedback.achievedMiniGoal(
            goal: .lose,
            previousWeight: 200,
            newWeight: 180,
            miniGoals: []
        )
        #expect(achieved == nil)
    }

    // MARK: - progressText

    @Test func progressTextNegativeTotalChange() {
        let progress = WeightCalculations.GoalProgress(
            targetWeight: 180,
            completedDistance: 15,
            totalDistance: 20,
            completedChange: -15,
            totalChange: -20,
            daysRemaining: 30
        )
        #expect(GoalProgressFeedback.progressText(progress) == "Down 15.0 of 20.0 lbs")
    }

    @Test func progressTextPositiveTotalChange() {
        let progress = WeightCalculations.GoalProgress(
            targetWeight: 200,
            completedDistance: 10,
            totalDistance: 20,
            completedChange: 10,
            totalChange: 20,
            daysRemaining: nil
        )
        #expect(GoalProgressFeedback.progressText(progress) == "Up 10.0 of 20.0 lbs")
    }

    @Test func progressTextZeroCompleted() {
        let progress = WeightCalculations.GoalProgress(
            targetWeight: 180,
            completedDistance: 0,
            totalDistance: 20,
            completedChange: 0,
            totalChange: -20,
            daysRemaining: 60
        )
        #expect(GoalProgressFeedback.progressText(progress) == "Down 0.0 of 20.0 lbs")
    }

    // MARK: - nextTargetDefault

    @Test func nextTargetMaintainReturnsReachedWeight() {
        #expect(GoalProgressFeedback.nextTargetDefault(goal: .maintain, reachedWeight: 175) == 175)
    }

    @Test func nextTargetCutClampsToMinimum50() {
        #expect(GoalProgressFeedback.nextTargetDefault(goal: .lose, reachedWeight: 52) == 50)
    }

    @Test func nextTargetBulkClampsToMaximum700() {
        #expect(GoalProgressFeedback.nextTargetDefault(goal: .gain, reachedWeight: 695) == 700)
    }

    // MARK: - didReachGoal

    @Test func didReachGoalCutGoalNotYetReached() {
        #expect(!GoalProgressFeedback.didReachGoal(
            goal: .lose,
            newWeight: 181,
            cutTarget: 180,
            bulkTarget: 200
        ))
    }

    @Test func didReachGoalBulkGoalNotYetReached() {
        #expect(!GoalProgressFeedback.didReachGoal(
            goal: .gain,
            newWeight: 195,
            cutTarget: 180,
            bulkTarget: 200
        ))
    }
}
