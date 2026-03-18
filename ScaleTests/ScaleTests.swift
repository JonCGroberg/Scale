//
//  ScaleTests.swift
//  ScaleTests
//
//  Created by Jonathan Groberg on 3/15/26.
//

import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import Scale

// MARK: - WeightEntry Model Tests

struct WeightEntryTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: WeightEntry.self, configurations: config)
    }

    @Test func initializesWithWeight() {
        let entry = WeightEntry(weight: 142.5)
        #expect(entry.weight == 142.5)
    }

    @Test func initializesWithCustomTimestamp() {
        let date = Date()
        let entry = WeightEntry(weight: 150.0, timestamp: date)
        #expect(entry.weight == 150.0)
        #expect(entry.timestamp == date)
    }

    @Test func insertEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 142.5)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.weight == 142.5)
    }

    @Test func deleteEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 160.0)
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.isEmpty)
    }

    @Test func updateWeight() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = WeightEntry(weight: 145.0)
        context.insert(entry)
        try context.save()

        entry.weight = 143.5
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.first?.weight == 143.5)
    }

    @Test func sortByTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let older = WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-86400))
        let newer = WeightEntry(weight: 148.0, timestamp: Date())
        context.insert(older)
        context.insert(newer)
        try context.save()

        var descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\WeightEntry.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let latest = try context.fetch(descriptor)
        #expect(latest.first?.weight == 148.0)
    }
}

// MARK: - Weight Change Calculation Tests

struct WeightChangeTests {

    @Test func changeWithTwoEntries() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 5.0)
    }

    @Test func changeWithWeightLoss() {
        let entries = [
            WeightEntry(weight: 140.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == -5.0)
    }

    @Test func changeWithNoChange() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-86400))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 0.0)
    }

    @Test func changeIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0)]
        #expect(WeightCalculations.weightChange(from: entries) == nil)
    }

    @Test func changeIsNilWithNoEntries() {
        let entries: [WeightEntry] = []
        #expect(WeightCalculations.weightChange(from: entries) == nil)
    }

    @Test func changeUsesFirstTwoEntriesOnly() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: Date().addingTimeInterval(-86400)),
            WeightEntry(weight: 140.0, timestamp: Date().addingTimeInterval(-172800))
        ]
        let change = WeightCalculations.weightChange(from: entries)
        #expect(change == 5.0)
    }

    @Test func changeDateReturnsSecondEntry() {
        let date = Date().addingTimeInterval(-86400)
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 145.0, timestamp: date)
        ]
        #expect(WeightCalculations.changeDate(from: entries) == date)
    }

    @Test func changeDateIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0)]
        #expect(WeightCalculations.changeDate(from: entries) == nil)
    }

    @Test func changeDateIsNilWithNoEntries() {
        let entries: [WeightEntry] = []
        #expect(WeightCalculations.changeDate(from: entries) == nil)
    }
}

// MARK: - Weight Input Parsing Tests

struct WeightParsingTests {

    @Test func parseValidWeight() {
        #expect(WeightCalculations.parseWeight(from: "142.5") == 142.5)
    }

    @Test func parseIntegerWeight() {
        #expect(WeightCalculations.parseWeight(from: "150") == 150.0)
    }

    @Test func parseWeightWithWhitespace() {
        #expect(WeightCalculations.parseWeight(from: "  150.0  ") == 150.0)
    }

    @Test func parseWeightRejectsText() {
        #expect(WeightCalculations.parseWeight(from: "abc") == nil)
    }

    @Test func parseWeightRejectsEmpty() {
        #expect(WeightCalculations.parseWeight(from: "") == nil)
    }

    @Test func parseWeightRejectsZero() {
        #expect(WeightCalculations.parseWeight(from: "0") == nil)
    }

    @Test func parseWeightRejectsNegative() {
        #expect(WeightCalculations.parseWeight(from: "-50") == nil)
    }

    @Test func parseWeightAcceptsLargeValue() {
        #expect(WeightCalculations.parseWeight(from: "350.5") == 350.5)
    }
}

// MARK: - Scanned Weight Parsing Tests

struct ScannedWeightParsingTests {

    @Test func parseThreeDigitsWithDecimal() {
        #expect(WeightCalculations.parseScannedWeight("142.5") == 142.5)
    }

    @Test func parseThreeDigitsNoDecimal() {
        #expect(WeightCalculations.parseScannedWeight("185") == 185.0)
    }

    @Test func parseTwoDigitsWithDecimal() {
        #expect(WeightCalculations.parseScannedWeight("92.3") == 92.3)
    }

    @Test func parseOneDigit() {
        #expect(WeightCalculations.parseScannedWeight("5") == 5.0)
    }

    @Test func parseWithTrailingDot() {
        #expect(WeightCalculations.parseScannedWeight("150.") == 150.0)
    }

    @Test func parseWithWhitespace() {
        #expect(WeightCalculations.parseScannedWeight("  142.5  ") == 142.5)
    }

    @Test func rejectFourDigits() {
        #expect(WeightCalculations.parseScannedWeight("1234") == nil)
    }

    @Test func rejectTwoDecimalPlaces() {
        #expect(WeightCalculations.parseScannedWeight("142.55") == nil)
    }

    @Test func rejectText() {
        #expect(WeightCalculations.parseScannedWeight("lbs") == nil)
    }

    @Test func rejectMixedTextAndNumbers() {
        #expect(WeightCalculations.parseScannedWeight("142.5 lbs") == nil)
    }

    @Test func rejectEmpty() {
        #expect(WeightCalculations.parseScannedWeight("") == nil)
    }

    @Test func rejectZero() {
        #expect(WeightCalculations.parseScannedWeight("0") == nil)
    }

    @Test func rejectNegative() {
        #expect(WeightCalculations.parseScannedWeight("-50") == nil)
    }

    @Test func parseDecimalPointZero() {
        #expect(WeightCalculations.parseScannedWeight("200.0") == 200.0)
    }
}

// MARK: - Entry Grouping Tests

struct EntryGroupingTests {

    @Test func groupsEntriesByMonth() {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 149.0, timestamp: now.addingTimeInterval(-86400)),
            WeightEntry(weight: 148.0, timestamp: lastMonth)
        ]

        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 2)
    }

    @Test func groupsSortedNewestFirst() {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let entries = [
            WeightEntry(weight: 148.0, timestamp: lastMonth),
            WeightEntry(weight: 150.0, timestamp: now)
        ]

        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 2)

        let firstGroupDate = grouped[0].value.first!.timestamp
        let lastGroupDate = grouped[1].value.first!.timestamp
        #expect(firstGroupDate > lastGroupDate)
    }

    @Test func emptyEntriesReturnEmptyGroups() {
        let grouped = WeightCalculations.groupedByMonth([])
        #expect(grouped.isEmpty)
    }

    @Test func singleEntryReturnsSingleGroup() {
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 1)
        #expect(grouped[0].value.count == 1)
    }

    @Test func multipleEntriesSameMonthGroupTogether() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 149.5, timestamp: now.addingTimeInterval(-3600)),
            WeightEntry(weight: 149.0, timestamp: now.addingTimeInterval(-7200))
        ]

        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped.count == 1)
        #expect(grouped[0].value.count == 3)
    }

    @Test func groupKeyContainsMonthAndYear() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let now = Date()
        let expected = formatter.string(from: now)

        let entries = [WeightEntry(weight: 150.0, timestamp: now)]
        let grouped = WeightCalculations.groupedByMonth(entries)
        #expect(grouped[0].key == expected)
    }
}

// MARK: - Average Weight Tests

struct AverageWeightTests {

    @Test func averageOfEntriesWithinPeriod() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 148.0, timestamp: now.addingTimeInterval(-2 * 86400)),
            WeightEntry(weight: 146.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg != nil)
        // All 3 entries are within the last week
        let expected = (150.0 + 148.0 + 146.0) / 3.0
        #expect(abs(avg! - expected) < 0.01)
    }

    @Test func averageExcludesOldEntries() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-400 * 86400))  // >1 year ago
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg != nil)
        #expect(avg == 150.0)
    }

    @Test func averageIsNilWhenNoEntriesInPeriod() {
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date().addingTimeInterval(-400 * 86400))
        ]
        let avg = WeightCalculations.averageWeight(from: entries, over: .week)
        #expect(avg == nil)
    }

    @Test func averageIsNilForEmptyEntries() {
        let avg = WeightCalculations.averageWeight(from: [], over: .month)
        #expect(avg == nil)
    }
}

// MARK: - Percentage Change Tests

struct PercentageChangeTests {

    @Test func positivePercentageChange() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 110.0, timestamp: now),                                  // most recent
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-5 * 86400))     // oldest in range
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct! - 10.0) < 0.01)  // (110-100)/100 * 100 = 10%
    }

    @Test func negativePercentageChange() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 90.0, timestamp: now),
            WeightEntry(weight: 100.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct! - (-10.0)) < 0.01)
    }

    @Test func zeroPercentageWhenUnchanged() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 150.0, timestamp: now),
            WeightEntry(weight: 150.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        #expect(abs(pct!) < 0.01)
    }

    @Test func percentageIsNilWithOneEntry() {
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct == nil)
    }

    @Test func percentageIsNilWithNoEntries() {
        let pct = WeightCalculations.percentageChange(from: [], over: .month)
        #expect(pct == nil)
    }

    @Test func percentageUsesEarliestAndLatestInPeriod() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 155.0, timestamp: now),
            WeightEntry(weight: 152.0, timestamp: now.addingTimeInterval(-3 * 86400)),
            WeightEntry(weight: 150.0, timestamp: now.addingTimeInterval(-6 * 86400))
        ]
        let pct = WeightCalculations.percentageChange(from: entries, over: .week)
        #expect(pct != nil)
        // earliest=150, latest=155 → (155-150)/150 * 100 = 3.33%
        let expected = ((155.0 - 150.0) / 150.0) * 100
        #expect(abs(pct! - expected) < 0.01)
    }
}

// MARK: - Derived Snapshot Tests

struct DerivedSnapshotTests {

    @Test func badgeSummaryMatchesExistingCalculations() {
        let now = Date()
        let entries = [
            WeightEntry(weight: 180.0, timestamp: now),
            WeightEntry(weight: 178.0, timestamp: now.addingTimeInterval(-2 * 86400)),
            WeightEntry(weight: 176.0, timestamp: now.addingTimeInterval(-5 * 86400))
        ]

        let summary = WeightCalculations.badgeSummary(from: entries, over: .week)

        #expect(summary.streak == WeightCalculations.currentStreak(from: entries))
        #expect(summary.average == WeightCalculations.averageWeight(from: entries, over: .week))
        #expect(summary.percentChange == WeightCalculations.percentageChange(from: entries, over: .week))
    }

    @Test func chartSnapshotFiltersAndSortsEntriesInPeriod() {
        let now = Date()
        let oldEntry = WeightEntry(weight: 200.0, timestamp: now.addingTimeInterval(-40 * 86400))
        let midEntry = WeightEntry(weight: 181.0, timestamp: now.addingTimeInterval(-6 * 86400))
        let recentEntry = WeightEntry(weight: 179.0, timestamp: now.addingTimeInterval(-2 * 86400))
        let entries = [recentEntry, oldEntry, midEntry]

        let snapshot = WeightCalculations.chartSnapshot(from: entries, over: .week)

        #expect(snapshot.entries.count == 2)
        #expect(snapshot.entries[0].timestamp == midEntry.timestamp)
        #expect(snapshot.entries[1].timestamp == recentEntry.timestamp)
        #expect(snapshot.yDomain.lowerBound == 178.0)
        #expect(snapshot.yDomain.upperBound == 182.0)
    }

    @Test func logSnapshotBuildsGroupedEntriesAndStreaks() {
        let calendar = Calendar.current
        let now = Date()
        let today = WeightEntry(weight: 180.0, timestamp: now)
        let yesterday = WeightEntry(weight: 179.0, timestamp: calendar.date(byAdding: .day, value: -1, to: now)!)
        let lastMonth = WeightEntry(weight: 182.0, timestamp: calendar.date(byAdding: .month, value: -1, to: now)!)
        let entries = [today, yesterday, lastMonth]

        let snapshot = WeightCalculations.logSnapshot(from: entries, chartPeriod: .threeMonths)
        let todayKey = calendar.startOfDay(for: today.timestamp)
        let yesterdayKey = calendar.startOfDay(for: yesterday.timestamp)

        #expect(snapshot.groupedEntries.count == 2)
        #expect(snapshot.chart.entries.count == 3)
        #expect(snapshot.streaksByDay[todayKey] == 2)
        #expect(snapshot.streaksByDay[yesterdayKey] == 1)
    }
}

// MARK: - TimePeriod Tests

struct TimePeriodTests {

    @Test func allCasesCount() {
        #expect(TimePeriod.allCases.count == 5)
    }

    @Test func rawValues() {
        #expect(TimePeriod.week.rawValue == "1W")
        #expect(TimePeriod.month.rawValue == "1M")
        #expect(TimePeriod.threeMonths.rawValue == "3M")
        #expect(TimePeriod.sixMonths.rawValue == "6M")
        #expect(TimePeriod.year.rawValue == "1Y")
    }

    @Test func labels() {
        #expect(TimePeriod.week.label == "Week")
        #expect(TimePeriod.month.label == "Month")
        #expect(TimePeriod.threeMonths.label == "3 Months")
        #expect(TimePeriod.sixMonths.label == "6 Months")
        #expect(TimePeriod.year.label == "Year")
    }

    @Test func componentValues() {
        #expect(TimePeriod.week.componentValue == 1)
        #expect(TimePeriod.month.componentValue == 1)
        #expect(TimePeriod.threeMonths.componentValue == 3)
        #expect(TimePeriod.sixMonths.componentValue == 6)
        #expect(TimePeriod.year.componentValue == 1)
    }

    @Test func calendarComponents() {
        #expect(TimePeriod.week.calendarComponent == .weekOfYear)
        #expect(TimePeriod.month.calendarComponent == .month)
        #expect(TimePeriod.threeMonths.calendarComponent == .month)
        #expect(TimePeriod.sixMonths.calendarComponent == .month)
        #expect(TimePeriod.year.calendarComponent == .year)
    }
}

// MARK: - Reminder Model Tests

struct ReminderModelTests {

    @Test func reminderDefaultValues() {
        let reminder = Reminder()
        #expect(reminder.name == "Weigh In")
        #expect(reminder.hour == 8)
        #expect(reminder.minute == 0)
    }

    @Test func reminderCustomValues() {
        let reminder = Reminder(name: "Morning", hour: 7, minute: 30)
        #expect(reminder.name == "Morning")
        #expect(reminder.hour == 7)
        #expect(reminder.minute == 30)
    }

    @Test func reminderEncodesAndDecodes() throws {
        let original = Reminder(name: "Evening", hour: 20, minute: 15)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)
        #expect(decoded == original)
    }

    @Test func reminderArrayEncodesAndDecodes() throws {
        let reminders = [
            Reminder(name: "Morning", hour: 8, minute: 0),
            Reminder(name: "Evening", hour: 20, minute: 0)
        ]
        let data = try JSONEncoder().encode(reminders)
        let decoded = try JSONDecoder().decode([Reminder].self, from: data)
        #expect(decoded == reminders)
    }

    @Test func reminderHasUniqueIds() {
        let a = Reminder()
        let b = Reminder()
        #expect(a.id != b.id)
    }

    @Test func enabledFlagDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "remindersEnabled")
        #expect(UserDefaults.standard.bool(forKey: "remindersEnabled") == false)
    }

    @Test func enabledFlagToggles() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "remindersEnabled")
        #expect(defaults.bool(forKey: "remindersEnabled") == true)

        defaults.set(false, forKey: "remindersEnabled")
        #expect(defaults.bool(forKey: "remindersEnabled") == false)
    }

    @Test func saveAndLoadReminders() {
        let manager = NotificationManager()
        let reminders = [
            Reminder(name: "Morning", hour: 8, minute: 0),
            Reminder(name: "Night", hour: 21, minute: 30)
        ]
        manager.saveReminders(reminders)
        let loaded = manager.loadReminders()
        #expect(loaded == reminders)
    }

    @Test func loadRemindersReturnsEmptyWhenNoneSaved() {
        UserDefaults.standard.removeObject(forKey: "savedReminders")
        let manager = NotificationManager()
        let loaded = manager.loadReminders()
        #expect(loaded.isEmpty)
    }
}

// MARK: - Notification Name Tests

struct NotificationNameTests {

    @Test func notificationNameIsCorrect() {
        #expect(Notification.Name.didTapWeightReminder.rawValue == "didTapWeightReminder")
    }

    @Test func notificationPostAndReceive() async {
        let received = UnsafeSendable(value: false)

        let observer = NotificationCenter.default.addObserver(
            forName: .didTapWeightReminder,
            object: nil,
            queue: .main
        ) { _ in
            received.value = true
        }

        NotificationCenter.default.post(name: .didTapWeightReminder, object: nil)

        // Give run loop a moment to deliver
        try? await Task.sleep(for: .milliseconds(100))

        #expect(received.value == true)
        NotificationCenter.default.removeObserver(observer)
    }

    @Test func notificationDelegateConformsToProtocol() {
        let delegate = NotificationDelegate()
        // Verify it conforms to UNUserNotificationCenterDelegate
        let conforming: UNUserNotificationCenterDelegate = delegate
        #expect(conforming is NotificationDelegate)
    }
}

/// A simple wrapper to allow mutation of a value in a Sendable context for testing.
private final class UnsafeSendable<T>: @unchecked Sendable {
    var value: T
    init(value: T) { self.value = value }
}

// MARK: - NotificationManager Initialization Tests

struct NotificationManagerTests {

    @Test func initializedWithIsAuthorizedFalse() {
        let manager = NotificationManager()
        // Before any authorization request, the default should be false
        #expect(manager.isAuthorized == false)
    }
}

// MARK: - Current Streak (Including Today) Tests
//
// These scenarios directly mirror the logic inside NotificationManager.notificationBody():
// the method calls currentStreak(from:includingToday: true) to decide whether to show
// a streak-preservation message (streak ≥ 2) or a generic prompt (streak < 2).

struct CurrentStreakIncludingTodayTests {

    private var calendar: Calendar { Calendar.current }

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: Date())!
    }

    // -- No entries --

    @Test func noEntriesPotentialStreakIsOne() {
        // A brand-new user has no entries; counting today gives streak = 1 (below threshold).
        let streak = WeightCalculations.currentStreak(from: [], includingToday: true)
        #expect(streak == 1)
    }

    // -- Only today logged --

    @Test func entryOnlyTodayPotentialStreakIsOne() {
        // User already logged today but has no history; streak is still 1.
        let entries = [WeightEntry(weight: 150.0, timestamp: Date())]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 1)
    }

    // -- Yesterday logged (notification fires before today's log) --

    @Test func entryYesterdayOnlyPotentialStreakIsTwo() {
        // Logged yesterday, haven't logged today yet → logging today makes it 2.
        let entries = [WeightEntry(weight: 150.0, timestamp: daysAgo(1))]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 2)
    }

    @Test func entriesTodayAndYesterdayPotentialStreakIsTwo() {
        // Logged both today and yesterday; potential streak is still 2.
        let entries = [
            WeightEntry(weight: 150.0, timestamp: Date()),
            WeightEntry(weight: 149.0, timestamp: daysAgo(1))
        ]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 2)
    }

    // -- Multi-day runs --

    @Test func threeDaysBeforeTodayPotentialStreakIsFour() {
        let entries = (1...3).map { WeightEntry(weight: 150.0, timestamp: daysAgo($0)) }
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 4)
    }

    @Test func fiveConsecutiveDaysBeforeTodayPotentialStreakIsSix() {
        let entries = (1...5).map { WeightEntry(weight: 150.0, timestamp: daysAgo($0)) }
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 6)
    }

    // -- Broken streaks --

    @Test func gapTwoDaysAgoBreaksRunToOne() {
        // Last entry was 2 days ago with nothing yesterday; logging today starts fresh → 1.
        let entries = [WeightEntry(weight: 150.0, timestamp: daysAgo(2))]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 1)
    }

    @Test func gapInMiddleOfRunCapsStreak() {
        // Logged 1 and 3 days ago but NOT 2 days ago — streak is consecutive from today.
        let entries = [
            WeightEntry(weight: 150.0, timestamp: daysAgo(1)),
            WeightEntry(weight: 149.0, timestamp: daysAgo(3))
        ]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        // Only yesterday is consecutive with today → 2
        #expect(streak == 2)
    }

    // -- Multiple entries on the same day --

    @Test func multipleEntriesSameDayCountAsOne() {
        // Two entries yesterday should still only add one day to the streak.
        let entries = [
            WeightEntry(weight: 149.5, timestamp: daysAgo(1).addingTimeInterval(3600)),
            WeightEntry(weight: 149.0, timestamp: daysAgo(1))
        ]
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        #expect(streak == 2)
    }
}

// MARK: - Notification Streak Threshold Tests
//
// Verify the ≥ 2 threshold that separates the generic body ("Tap to log your weight.")
// from the personalized streak body ("Keep your N-day streak going…").

struct NotificationStreakThresholdTests {

    private var calendar: Calendar { Calendar.current }

    private func potentialStreak(daysBack: [Int]) -> Int {
        let entries = daysBack.map {
            WeightEntry(weight: 150.0, timestamp: calendar.date(byAdding: .day, value: -$0, to: Date())!)
        }
        return WeightCalculations.currentStreak(from: entries, includingToday: true)
    }

    @Test func newUserBelowThresholdForPersonalizedMessage() {
        // No prior days → potential streak 1 → generic message territory.
        let streak = WeightCalculations.currentStreak(from: [], includingToday: true)
        #expect(streak < 2)
    }

    @Test func oneDayHistoryMeetsThresholdForPersonalizedMessage() {
        // Yesterday logged → potential streak 2 → meets the ≥ 2 threshold.
        let streak = potentialStreak(daysBack: [1])
        #expect(streak >= 2)
    }

    @Test func twoDayHistoryStreakIsThree() {
        let streak = potentialStreak(daysBack: [1, 2])
        #expect(streak == 3)
    }

    @Test func nineDayHistoryStreakIsTen() {
        let streak = potentialStreak(daysBack: Array(1...9))
        #expect(streak == 10)
    }

    @Test func brokenStreakDropsBelowThreshold() {
        // Only entry is 2 days ago (no yesterday) → potential streak 1 → generic message.
        let streak = potentialStreak(daysBack: [2])
        #expect(streak < 2)
    }
}

// MARK: - NotificationManager ModelContext Tests

struct NotificationManagerModelContextTests {

    @Test func modelContextIsNilByDefault() {
        let manager = NotificationManager()
        #expect(manager.modelContext == nil)
    }

    @Test func modelContextCanBeAssigned() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let manager = NotificationManager()
        manager.modelContext = ModelContext(container)
        #expect(manager.modelContext != nil)
    }

    @Test func rescheduleRemindersWithoutContextDoesNotCrash() {
        // If modelContext is nil, rescheduleReminders should silently use the generic body.
        let manager = NotificationManager()
        manager.rescheduleReminders() // should not throw or crash
    }

    @Test func rescheduleRemindersWithContextAndNoEntriesDoesNotCrash() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let manager = NotificationManager()
        manager.modelContext = ModelContext(container)
        manager.rescheduleReminders() // should not throw or crash
    }
}

// MARK: - App Tint Tests

struct AppTintTests {

    @Test func allCasesCount() {
        #expect(AppTint.allCases.count == 6)
    }

    @Test func defaultValueIsBlue() {
        #expect(AppTint.defaultValue == .blue)
    }

    @Test func rawValueLookupFindsSavedTint() {
        #expect(AppTint(rawValue: "green") == .green)
    }

    @Test func rawValueLookupFindsLavenderTint() {
        #expect(AppTint(rawValue: "lavender") == .lavender)
    }
}
