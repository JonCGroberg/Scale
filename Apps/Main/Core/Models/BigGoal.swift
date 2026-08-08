import Foundation

struct BigGoal: Identifiable, Codable, Equatable {
    var id: UUID
    var parentGoalRawValue: String
    var name: String
    var targetWeight: Double

    init(id: UUID = UUID(), parentGoal: WeightGoal, name: String = "Big goal", targetWeight: Double) {
        self.id = id
        self.parentGoalRawValue = parentGoal.rawValue
        self.name = name
        self.targetWeight = targetWeight
    }

    var parentGoal: WeightGoal? {
        WeightGoal(rawValue: parentGoalRawValue)
    }

    private enum CodingKeys: String, CodingKey {
        case id, parentGoalRawValue, name, targetWeight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentGoalRawValue = try container.decode(String.self, forKey: .parentGoalRawValue)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Big goal"
        targetWeight = try container.decode(Double.self, forKey: .targetWeight)
    }
}

enum BigGoalStore {
    static let defaultIncrement = 5.0

    static func storageKey(for goal: WeightGoal) -> String? {
        switch goal {
        case .lose: "cutBigGoals"
        case .maintain: nil
        case .gain: "bulkBigGoals"
        }
    }

    static func load(for goal: WeightGoal, fallbackTarget: Double, defaults: UserDefaults = .standard) -> [BigGoal] {
        guard let key = storageKey(for: goal),
              let data = defaults.data(forKey: key),
              let goals = try? JSONDecoder().decode([BigGoal].self, from: data) else {
            return goal.showsTarget ? [BigGoal(parentGoal: goal, targetWeight: fallbackTarget)] : []
        }

        return goals.filter { $0.parentGoal == goal }
    }

    static func save(_ goals: [BigGoal], for goal: WeightGoal, defaults: UserDefaults = .standard) {
        guard let key = storageKey(for: goal),
              let data = try? JSONEncoder().encode(goals) else { return }
        defaults.set(data, forKey: key)
    }

    static func defaultTarget(for goal: WeightGoal, existingGoals: [BigGoal], fallbackTarget: Double) -> Double {
        switch goal {
        case .lose:
            return max((existingGoals.map(\.targetWeight).min() ?? fallbackTarget) - defaultIncrement, 50)
        case .maintain:
            return fallbackTarget
        case .gain:
            return min((existingGoals.map(\.targetWeight).max() ?? fallbackTarget) + defaultIncrement, 700)
        }
    }

    static func activeTarget(for goal: WeightGoal, goals: [BigGoal], currentWeight: Double?) -> Double? {
        guard !goals.isEmpty else { return nil }
        guard let currentWeight else { return goals.first?.targetWeight }

        switch goal {
        case .lose:
            return goals
                .filter { $0.targetWeight < currentWeight }
                .map(\.targetWeight)
                .max() ?? goals.map(\.targetWeight).min()
        case .gain:
            return goals
                .filter { $0.targetWeight > currentWeight }
                .map(\.targetWeight)
                .min() ?? goals.map(\.targetWeight).max()
        case .maintain:
            return nil
        }
    }
}
