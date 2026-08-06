//
//  CalendarDayStat.swift
//  Scale
//

import Foundation

/// The stat displayed on each logged day in the calendar (journal) view.
enum CalendarDayStat: String, CaseIterable, Identifiable {
    case weight
    case steps
    case activeCalories
    case sleep
    case workouts

    static let defaultValue: CalendarDayStat = .weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Weight"
        case .steps: "Steps"
        case .activeCalories: "Active Calories"
        case .sleep: "Sleep"
        case .workouts: "Workouts"
        }
    }

    var systemImage: String {
        switch self {
        case .weight: "scalemass.fill"
        case .steps: "figure.walk"
        case .activeCalories: "flame.fill"
        case .sleep: "bed.double.fill"
        case .workouts: "figure.run"
        }
    }
}
