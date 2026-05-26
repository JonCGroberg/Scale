//
//  Weight_Goal_Settings_Tests.swift
//  ScaleTests
//
//  Created by Codex on 4/26/26.
//

import Testing
@testable import Scale

struct WeightGoalSettingsTests {
    @Test func defaultGoalIsMaintain() {
        #expect(WeightGoal.defaultValue == .maintain)
    }

    @Test func onlyCutAndBulkShowTarget() {
        #expect(WeightGoal.lose.showsTarget)
        #expect(!WeightGoal.maintain.showsTarget)
        #expect(WeightGoal.gain.showsTarget)
    }

    @Test func goalLabelsMatchCutMaintainBulkLanguage() {
        #expect(WeightGoal.lose.subtitle == "Cut")
        #expect(WeightGoal.maintain.title == "Maintain")
        #expect(WeightGoal.gain.subtitle == "Bulk")
    }

    @Test func cutAndBulkTargetsUseMainGoalLanguage() {
        #expect(WeightGoal.lose.targetTitle == "Main Goal")
        #expect(WeightGoal.maintain.targetTitle == "Goal")
        #expect(WeightGoal.gain.targetTitle == "Main Goal")
    }

    @Test func cutAndBulkUseSeparateTargetStorageKeys() {
        #expect(WeightGoal.lose.targetStorageKey == "cutTargetWeight")
        #expect(WeightGoal.maintain.targetStorageKey == nil)
        #expect(WeightGoal.gain.targetStorageKey == "bulkTargetWeight")
    }
}
