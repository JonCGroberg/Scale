//
//  Big_Goal_Tests.swift
//  ScaleTests
//


import Foundation
import Testing
@testable import Scale

struct BigGoalTests {
    @Test func storageKeysAreSeparateForCutAndBulk() {
        #expect(BigGoalStore.storageKey(for: .lose) == "cutBigGoals")
        #expect(BigGoalStore.storageKey(for: .maintain) == nil)
        #expect(BigGoalStore.storageKey(for: .gain) == "bulkBigGoals")
    }

    @Test func missingStoreCreatesTheExpectedFallbackGoal() {
        let suiteName = "BigGoalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let cut = BigGoalStore.load(for: .lose, fallbackTarget: 170, defaults: defaults)
        let bulk = BigGoalStore.load(for: .gain, fallbackTarget: 195, defaults: defaults)
        let maintain = BigGoalStore.load(for: .maintain, fallbackTarget: 180, defaults: defaults)

        #expect(cut.count == 1)
        #expect(cut.first?.parentGoal == .lose)
        #expect(cut.first?.targetWeight == 170)
        #expect(bulk.count == 1)
        #expect(bulk.first?.parentGoal == .gain)
        #expect(bulk.first?.targetWeight == 195)
        #expect(maintain.isEmpty)
    }

    @Test func goalsRoundTripAndRemainIsolatedByParentGoal() {
        let suiteName = "BigGoalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let cutGoals = [
            BigGoal(parentGoal: .lose, name: "First cut", targetWeight: 175),
            BigGoal(parentGoal: .lose, name: "Second cut", targetWeight: 165),
        ]
        let bulkGoals = [BigGoal(parentGoal: .gain, name: "First bulk", targetWeight: 195)]

        BigGoalStore.save(cutGoals, for: .lose, defaults: defaults)
        BigGoalStore.save(bulkGoals, for: .gain, defaults: defaults)

        #expect(BigGoalStore.load(for: .lose, fallbackTarget: 180, defaults: defaults) == cutGoals)
        #expect(BigGoalStore.load(for: .gain, fallbackTarget: 180, defaults: defaults) == bulkGoals)
    }

    @Test func loadFiltersGoalsStoredUnderTheWrongParent() throws {
        let suiteName = "BigGoalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let valid = BigGoal(parentGoal: .lose, name: "Valid", targetWeight: 170)
        let invalid = BigGoal(parentGoal: .gain, name: "Wrong parent", targetWeight: 200)
        defaults.set(try JSONEncoder().encode([valid, invalid]), forKey: "cutBigGoals")

        #expect(BigGoalStore.load(for: .lose, fallbackTarget: 180, defaults: defaults) == [valid])
    }

    @Test func legacyGoalWithoutNameDecodesWithDefaultName() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","parentGoalRawValue":"lose","targetWeight":170}
        """.data(using: .utf8)!

        let goal = try JSONDecoder().decode(BigGoal.self, from: json)

        #expect(goal.id == id)
        #expect(goal.parentGoal == .lose)
        #expect(goal.name == "Big goal")
        #expect(goal.targetWeight == 170)
    }

    @Test func defaultTargetsExtendFivePoundsAndRespectSafetyBounds() {
        let cut = [BigGoal(parentGoal: .lose, targetWeight: 160)]
        let bulk = [BigGoal(parentGoal: .gain, targetWeight: 200)]

        #expect(BigGoalStore.defaultTarget(for: .lose, existingGoals: cut, fallbackTarget: 180) == 155)
        #expect(BigGoalStore.defaultTarget(for: .gain, existingGoals: bulk, fallbackTarget: 180) == 205)
        #expect(BigGoalStore.defaultTarget(for: .maintain, existingGoals: [], fallbackTarget: 181) == 181)
        #expect(BigGoalStore.defaultTarget(for: .lose, existingGoals: [BigGoal(parentGoal: .lose, targetWeight: 52)], fallbackTarget: 180) == 50)
        #expect(BigGoalStore.defaultTarget(for: .gain, existingGoals: [BigGoal(parentGoal: .gain, targetWeight: 698)], fallbackTarget: 180) == 700)
    }

    @Test func activeTargetChoosesTheNextUnreachedGoal() {
        let cut = [
            BigGoal(parentGoal: .lose, targetWeight: 170),
            BigGoal(parentGoal: .lose, targetWeight: 160),
            BigGoal(parentGoal: .lose, targetWeight: 150),
        ]
        let bulk = [
            BigGoal(parentGoal: .gain, targetWeight: 190),
            BigGoal(parentGoal: .gain, targetWeight: 200),
            BigGoal(parentGoal: .gain, targetWeight: 210),
        ]

        #expect(BigGoalStore.activeTarget(for: .lose, goals: cut, currentWeight: 175) == 170)
        #expect(BigGoalStore.activeTarget(for: .lose, goals: cut, currentWeight: 165) == 160)
        #expect(BigGoalStore.activeTarget(for: .gain, goals: bulk, currentWeight: 185) == 190)
        #expect(BigGoalStore.activeTarget(for: .gain, goals: bulk, currentWeight: 195) == 200)
    }

    @Test func activeTargetHandlesMissingAndCompletedGoalSets() {
        let cut = [
            BigGoal(parentGoal: .lose, targetWeight: 170),
            BigGoal(parentGoal: .lose, targetWeight: 160),
        ]
        let bulk = [
            BigGoal(parentGoal: .gain, targetWeight: 190),
            BigGoal(parentGoal: .gain, targetWeight: 200),
        ]

        #expect(BigGoalStore.activeTarget(for: .lose, goals: [], currentWeight: 180) == nil)
        #expect(BigGoalStore.activeTarget(for: .lose, goals: cut, currentWeight: nil) == 170)
        #expect(BigGoalStore.activeTarget(for: .lose, goals: cut, currentWeight: 150) == 160)
        #expect(BigGoalStore.activeTarget(for: .gain, goals: bulk, currentWeight: 210) == 200)
        #expect(BigGoalStore.activeTarget(for: .maintain, goals: cut, currentWeight: 180) == nil)
    }
}
