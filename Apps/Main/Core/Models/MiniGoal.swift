//
//  MiniGoal.swift
//  Scale
//
//  Created by Codex on 4/27/26.
//

import Foundation

struct MiniGoal: Identifiable, Codable, Equatable {
    var id: UUID
    var parentGoalRawValue: String
    var name: String
    var targetWeight: Double

    init(
        id: UUID = UUID(),
        parentGoal: WeightGoal,
        name: String = "Mini Goal",
        targetWeight: Double
    ) {
        self.id = id
        self.parentGoalRawValue = parentGoal.rawValue
        self.name = name
        self.targetWeight = targetWeight
    }

    var parentGoal: WeightGoal? {
        WeightGoal(rawValue: parentGoalRawValue)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case parentGoalRawValue
        case name
        case targetWeight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentGoalRawValue = try container.decodeIfPresent(String.self, forKey: .parentGoalRawValue) ?? ""
        name = try container.decode(String.self, forKey: .name)
        targetWeight = try container.decode(Double.self, forKey: .targetWeight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(parentGoalRawValue, forKey: .parentGoalRawValue)
        try container.encode(name, forKey: .name)
        try container.encode(targetWeight, forKey: .targetWeight)
    }
}

enum MiniGoalStore {
    static let defaultIncrement = 5.0

    static func storageKey(for goal: WeightGoal) -> String? {
        switch goal {
        case .lose:
            "cutMiniGoals"
        case .maintain:
            nil
        case .gain:
            "bulkMiniGoals"
        }
    }

    static func load(for goal: WeightGoal, defaults: UserDefaults = .standard) -> [MiniGoal] {
        guard let key = storageKey(for: goal),
              let data = defaults.data(forKey: key),
              let miniGoals = try? JSONDecoder().decode([MiniGoal].self, from: data) else {
            return []
        }

        return miniGoals
            .filter { $0.parentGoal == goal || $0.parentGoalRawValue.isEmpty }
            .map { miniGoal in
                var attachedGoal = miniGoal
                attachedGoal.parentGoalRawValue = goal.rawValue
                return attachedGoal
            }
    }

    static func save(_ miniGoals: [MiniGoal], for goal: WeightGoal, defaults: UserDefaults = .standard) {
        guard let key = storageKey(for: goal),
              let data = try? JSONEncoder().encode(miniGoals.map { miniGoal in
                  var attachedGoal = miniGoal
                  attachedGoal.parentGoalRawValue = goal.rawValue
                  return attachedGoal
              }) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    static func defaultTarget(for goal: WeightGoal, mainTarget: Double, existingGoals: [MiniGoal]) -> Double {
        switch goal {
        case .lose:
            let furthestMiniGoal = existingGoals.map(\.targetWeight).max() ?? mainTarget
            return clampedTarget(furthestMiniGoal + defaultIncrement, for: goal, mainTarget: mainTarget)
        case .maintain:
            return mainTarget
        case .gain:
            let furthestMiniGoal = existingGoals.map(\.targetWeight).min() ?? mainTarget
            return clampedTarget(furthestMiniGoal - defaultIncrement, for: goal, mainTarget: mainTarget)
        }
    }

    static func clampedTarget(_ value: Double, for goal: WeightGoal, mainTarget: Double) -> Double {
        switch goal {
        case .lose:
            return min(max(value, mainTarget), 700)
        case .maintain:
            return min(max(value, 50), 700)
        case .gain:
            return min(max(value, 50), mainTarget)
        }
    }
}
