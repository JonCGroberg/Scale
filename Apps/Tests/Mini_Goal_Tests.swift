//
//  Mini_Goal_Tests.swift
//  ScaleTests
//
//  Created by Codex on 4/27/26.
//

import Foundation
import Testing
@testable import Scale

struct MiniGoalTests {
    @Test func storageKeysAreSeparateForCutAndBulk() {
        #expect(MiniGoalStore.storageKey(for: .lose) == "cutMiniGoals")
        #expect(MiniGoalStore.storageKey(for: .maintain) == nil)
        #expect(MiniGoalStore.storageKey(for: .gain) == "bulkMiniGoals")
    }

    @Test func miniGoalsRoundTripThroughDefaults() {
        let suiteName = "MiniGoalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let goals = [
            MiniGoal(parentGoal: .lose, name: "First", targetWeight: 175),
            MiniGoal(parentGoal: .lose, name: "Second", targetWeight: 170),
        ]

        MiniGoalStore.save(goals, for: .lose, defaults: defaults)
        #expect(MiniGoalStore.load(for: .lose, defaults: defaults) == goals)
        #expect(MiniGoalStore.load(for: .gain, defaults: defaults).isEmpty)
    }

    @Test func saveAttachesMiniGoalsToParentGoal() {
        let suiteName = "MiniGoalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let unattached = MiniGoal(parentGoal: .lose, name: "Bulk Step", targetWeight: 190)

        MiniGoalStore.save([unattached], for: .gain, defaults: defaults)
        let loaded = MiniGoalStore.load(for: .gain, defaults: defaults)

        #expect(loaded.count == 1)
        #expect(loaded.first?.parentGoal == .gain)
    }

    @Test func defaultCutMiniGoalsStepUpFromMainGoalByFive() {
        let firstTarget = MiniGoalStore.defaultTarget(for: .lose, mainTarget: 160, existingGoals: [])
        let secondTarget = MiniGoalStore.defaultTarget(
            for: .lose,
            mainTarget: 160,
            existingGoals: [MiniGoal(parentGoal: .lose, targetWeight: firstTarget)]
        )

        #expect(firstTarget == 165)
        #expect(secondTarget == 170)
    }

    @Test func defaultBulkMiniGoalsStepDownFromMainGoalByFive() {
        let firstTarget = MiniGoalStore.defaultTarget(for: .gain, mainTarget: 190, existingGoals: [])
        let secondTarget = MiniGoalStore.defaultTarget(
            for: .gain,
            mainTarget: 190,
            existingGoals: [MiniGoal(parentGoal: .gain, targetWeight: firstTarget)]
        )

        #expect(firstTarget == 185)
        #expect(secondTarget == 180)
    }

    @Test func miniGoalTargetsStayWithinMainGoalBounds() {
        #expect(MiniGoalStore.clampedTarget(150, for: .lose, mainTarget: 160) == 160)
        #expect(MiniGoalStore.clampedTarget(200, for: .gain, mainTarget: 190) == 190)
    }

    @Test func parentBigGoalRelationshipRoundTripsThroughCodable() throws {
        let bigGoalID = UUID()
        let goal = MiniGoal(
            parentGoal: .lose,
            parentBigGoalID: bigGoalID,
            name: "First checkpoint",
            targetWeight: 175
        )

        let decoded = try JSONDecoder().decode(MiniGoal.self, from: JSONEncoder().encode(goal))

        #expect(decoded == goal)
        #expect(decoded.parentBigGoalID == bigGoalID)
    }

    @Test func legacyMiniGoalWithoutBigGoalRelationshipStillDecodes() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","parentGoalRawValue":"lose","name":"Legacy","targetWeight":175}
        """.data(using: .utf8)!

        let goal = try JSONDecoder().decode(MiniGoal.self, from: json)

        #expect(goal.id == id)
        #expect(goal.parentGoal == .lose)
        #expect(goal.parentBigGoalID == nil)
    }
}
