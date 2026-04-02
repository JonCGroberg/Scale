//
//  CalendarMonthLoader.swift
//  Scale
//
//  Manages lazy loading of calendar months, starting from the current month
//  and expanding only into the past on demand.
//

import Foundation

struct CalendarMonthLoader {
    private(set) var monthStarts: [Date] = []
    let batchSize: Int
    private let calendar = Calendar.current

    init(batchSize: Int = 6) {
        self.batchSize = batchSize
    }

    /// The current month's start date (first day, midnight).
    static func currentMonthStart(using calendar: Calendar = .current, now: Date = .now) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: now)
    }

    /// Loads the initial batch of months backward from the current month (inclusive).
    /// No-op if months are already loaded.
    mutating func loadInitialMonths(now: Date = .now) {
        guard monthStarts.isEmpty else { return }
        let anchor = Self.currentMonthStart(using: calendar, now: now)
        monthStarts = (0..<batchSize).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: anchor)
        }
    }

    /// If `month` is the earliest loaded month, prepend another batch into the past.
    /// Returns `true` if expansion occurred.
    @discardableResult
    mutating func expandIfNeeded(for month: Date) -> Bool {
        guard let earliest = monthStarts.min(), month == earliest else { return false }
        guard let start = calendar.date(byAdding: .month, value: -batchSize, to: earliest) else { return false }
        let additional = (0..<batchSize).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: start)
        }
        monthStarts = Array(Set(monthStarts + additional)).sorted()
        return true
    }

    /// Months sorted descending (current month first).
    var sortedDescending: [Date] {
        monthStarts.sorted(by: >)
    }

    /// The earliest (oldest) loaded month, if any.
    var earliest: Date? {
        monthStarts.min()
    }

    /// The latest (newest) loaded month, if any.
    var latest: Date? {
        monthStarts.max()
    }
}
