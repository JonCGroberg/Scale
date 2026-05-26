//
//  JournalView.swift
//  Scale
//
//  Created by Codex on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import HealthKit
import ImageIO
import QuickLook

struct JournalView: View {
    private final class PhotoThumbnailCache {
        nonisolated static let shared = PhotoThumbnailCache()

        nonisolated(unsafe) private let cache = NSCache<NSString, UIImage>()
        private init() {
            cache.countLimit = 256
        }

        nonisolated func image(forKey key: String) -> UIImage? {
            cache.object(forKey: key as NSString)
        }

        nonisolated func setImage(_ image: UIImage, forKey key: String) {
            cache.setObject(image, forKey: key as NSString)
        }

        nonisolated func thumbnail(from data: Data, key: String, maxPixelSize: CGFloat = 160) -> UIImage? {
            if let cached = image(forKey: key) {
                return cached
            }

            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }

            let thumbnail = UIImage(cgImage: cgImage)
            setImage(thumbnail, forKey: key)
            return thumbnail
        }
    }

    fileprivate struct PresentedDaySheet: Identifiable {
        enum Kind {
            case detail
            case create
        }

        let date: Date
        let kind: Kind

        var id: String {
            "\(date.timeIntervalSinceReferenceDate)-\(kindID)"
        }

        private var kindID: String {
            switch kind {
            case .detail:
                return "detail"
            case .create:
                return "create"
            }
        }
    }

    struct DayPreview: Identifiable {
        let date: Date
        let photos: [UIImage]
        let weightText: String?
        let entryCount: Int
        let workoutCount: Int
        let stepCount: Int
        let activeEnergyBurnedKilocalories: Double
        let sleepDuration: TimeInterval

        var id: Date { date }
    }

    fileprivate struct DayData {
        let weightText: String?
        let workoutCount: Int
        let sleepCount: Int
        let stepText: String?
        /// Cache key for lazy thumbnail loading – nil when the day has no photo.
        let photoCacheKey: String?
        /// Position within a consecutive logging streak (0 = isolated day, 1+ = day N of a run).
        let streakDay: Int
        /// True when this is today and logging would continue a streak (not yet logged).
        let isStreakPotential: Bool

        var isLogged: Bool {
            weightText != nil
        }

        var hasPhoto: Bool {
            photoCacheKey != nil
        }
    }

    /// Stores the raw photo data needed to generate a thumbnail on a background thread.
    struct PendingThumbnail {
        let photoData: Data
        let cacheKey: String
    }

    @Observable
    final class LazyThumbnailLoader {
        var thumbnails: [String: UIImage] = [:]
        private var loadedKeys: Set<String> = []
        private var loadingKeys: Set<String> = []

        @MainActor
        func loadIfNeeded(key: String, pending: PendingThumbnail?) {
            guard thumbnails[key] == nil, !loadedKeys.contains(key), !loadingKeys.contains(key) else { return }
            if let cached = PhotoThumbnailCache.shared.image(forKey: key) {
                thumbnails[key] = cached
                loadedKeys.insert(key)
                return
            }
            guard let pending else { return }
            loadingKeys.insert(key)
            Task.detached(priority: .utility) {
                let thumbnail = PhotoThumbnailCache.shared.thumbnail(
                    from: pending.photoData,
                    key: pending.cacheKey
                )
                await MainActor.run {
                    if let thumbnail {
                        self.thumbnails[key] = thumbnail
                    }
                    self.loadedKeys.insert(key)
                    self.loadingKeys.remove(key)
                }
            }
        }

        @MainActor
        func removeValue(forKey key: String) {
            thumbnails.removeValue(forKey: key)
            loadedKeys.remove(key)
            loadingKeys.remove(key)
        }
    }

    fileprivate struct MonthRenderData {
        let weeks: [[Date]]
        let dayDataByDate: [Date: DayData]
    }

    private struct MonthSection: Identifiable {
        let monthStart: Date
        let title: String

        var id: Date { monthStart }
    }

    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @Query(sort: \WorkoutEntry.timestamp, order: .reverse) private var workouts: [WorkoutEntry]
    @Query(sort: \DailyActivitySummary.date, order: .reverse) private var dailyActivitySummaries: [DailyActivitySummary]
    @Query(sort: \SleepEntry.endDate, order: .reverse) private var sleepEntries: [SleepEntry]
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue

    let scrollToEntryTrigger: Int
    let focusedEntry: WeightEntry?
    let scrollToBottomTrigger: Int
    @Binding var showLog: Bool
    @Binding var logDate: Date?

    @State private var monthLoader = CalendarMonthLoader(batchSize: 5)
    @State private var monthRenderDataByMonth: [Date: MonthRenderData] = [:]
    @State private var entryIDsByDay: [Date: [PersistentIdentifier]] = [:]
    @State private var workoutIDsByDay: [Date: [PersistentIdentifier]] = [:]
    @State private var sleepIDsByDay: [Date: [PersistentIdentifier]] = [:]
    @State private var presentedSheet: PresentedDaySheet?
    @State private var hasFinishedInitialMonthPositioning = false
    @State private var hasPerformedInitialScroll = false
    @State private var isDataReady = false
    @State private var thumbnailLoader = LazyThumbnailLoader()
    @State private var pendingThumbnails: [String: PendingThumbnail] = [:]
    @State private var dayPreview: DayPreview?
    @State private var suppressNextDayTap = false
    @State private var pressedPreviewDay: Date?
    @State private var showPhotoViewer = false
    @State private var selectedPhotoIndex = 0

    static func isNearTop(
        contentOffsetY: CGFloat,
        topInset: CGFloat,
        threshold: CGFloat = 80
    ) -> Bool {
        contentOffsetY <= topInset + threshold
    }

    static func targetDay(
        for focusedEntryDate: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        calendar.startOfDay(for: focusedEntryDate ?? now)
    }

    static func targetAnchor(hasFocusedEntry: Bool) -> UnitPoint {
        hasFocusedEntry ? .top : .bottom
    }

    static func isLoggableDay(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.compare(date, to: now, toGranularity: .day) != .orderedDescending
    }

    static func shouldPresentCreateSheet(
        hasLoggedWeight: Bool,
        hasWorkouts _: Bool
    ) -> Bool {
        !hasLoggedWeight
    }

    private let calendar = Calendar.current
    private let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    private let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    private let dayNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day,
           daysAgo >= 1 && daysAgo < 7 {
            return dayNameFormatter.string(from: date)
        }
        return dayTitleFormatter.string(from: date)
    }
    private let dayRowSpacing: CGFloat = 3
    private let dayColumnSpacing: CGFloat = 5
    private let dayCardCornerRadius: CGFloat = 12
    private let bottomScrollID = "journal-bottom"

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var backgroundColor: Color {
        Color(.systemGroupedBackground)
    }

    private var cardColor: Color {
        Color(.secondarySystemGroupedBackground)
    }

    private var secondaryTextColor: Color {
        .secondary
    }

    private var journalDataVersion: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        hasher.combine(entries.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(entries.first?.weight ?? 0)
        for entry in entries {
            hasher.combine(entry.photosFingerprint)
        }
        hasher.combine(workouts.count)
        hasher.combine(workouts.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(dailyActivitySummaries.count)
        hasher.combine(sleepEntries.count)
        hasher.combine(sleepEntries.first?.endDate.timeIntervalSinceReferenceDate ?? 0)
        return hasher.finalize()
    }

    private var monthSections: [MonthSection] {
        monthLoader.monthStarts
            .sorted()
            .map { monthStart in
                MonthSection(
                    monthStart: monthStart,
                    title: monthTitleFormatter.string(from: monthStart)
                )
            }
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(monthSections) { section in
                                if let renderData = monthRenderDataByMonth[section.monthStart] {
                                    MonthSectionView(
                                        monthStart: section.monthStart,
                                        title: section.title,
                                        renderData: renderData,
                                        tintColor: tintColor,
                                        calendar: calendar,
                                        dayRowSpacing: dayRowSpacing,
                                        dayColumnSpacing: dayColumnSpacing,
                                        dayCardCornerRadius: dayCardCornerRadius,
                                        weekdaySymbols: weekdaySymbols,
                                        secondaryTextColor: secondaryTextColor,
                                        cardColor: cardColor,
                                        suppressNextDayTap: $suppressNextDayTap,
                                        pressedPreviewDay: $pressedPreviewDay,
                                        logDate: $logDate,
                                        showLog: $showLog,
                                        presentedSheet: $presentedSheet,
                                        thumbnailLoader: thumbnailLoader,
                                        pendingThumbnails: pendingThumbnails,
                                        presentDayPreview: { date in
                                            self.presentDayPreview(for: date)
                                        }
                                    )
                                    .id(section.id)
                                } else {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(section.title)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 200)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Color.clear
                            .frame(height: 1)
                            .id(bottomScrollID)
                    }
                    .defaultScrollAnchor(.bottom)
                    .safeAreaPadding(.top, 32)
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        Self.isNearTop(
                            contentOffsetY: geometry.contentOffset.y,
                            topInset: geometry.contentInsets.top
                        )
                    } action: { wasNearTop, isNearTop in
                        guard !wasNearTop, isNearTop else { return }
                        loadEarlierMonthsIfNeeded(proxy: proxy)
                    }
                    .onAppear {
                        ensureInitialMonthsLoaded()
                        if !hasPerformedInitialScroll {
                            // Synchronous rebuild only on very first appear so scroll target exists.
                            if !isDataReady {
                                rebuildMonthRenderData(forceAll: true)
                                isDataReady = true
                            }
                            scrollToFocusedEntry(with: proxy, animated: false)
                            hasPerformedInitialScroll = true
                            Task { @MainActor in
                                hasFinishedInitialMonthPositioning = true
                            }
                        }
                    }
                    .onChange(of: scrollToEntryTrigger) { _, _ in
                        scrollToFocusedEntry(with: proxy, animated: true)
                    }
                    .onChange(of: scrollToBottomTrigger) { _, _ in
                        scrollToBottom(with: proxy, animated: true)
                    }
                    .onChange(of: journalDataVersion) { _, _ in
                        rebuildMonthRenderData(forceAll: true)
                    }
                }

            .sheet(item: $presentedSheet) { presentedSheet in
                LogDayDetailSheet(
                    initialDate: calendar.startOfDay(for: presentedSheet.date),
                    tintColor: tintColor
                ) {
                    self.presentedSheet = nil
                }
                .liquidGlassSheetPresentation()
            }
            .overlay {
                if let dayPreview {
                    DayPreviewPopup(
                        preview: dayPreview,
                        tintColor: tintColor,
                        title: dayTitle(for: dayPreview.date),
                        onDismiss: {
                            withAnimation(.snappy) {
                                self.dayPreview = nil
                            }
                        },
                        onPreviousDay: {
                            if let previousDay = calendar.date(byAdding: .day, value: -1, to: dayPreview.date) {
                                presentDayPreview(for: previousDay)
                            }
                        },
                        onNextDay: {
                            if let nextDay = calendar.date(byAdding: .day, value: 1, to: dayPreview.date) {
                                presentDayPreview(for: nextDay)
                            }
                        },
                        onTapPhoto: { index in
                            selectedPhotoIndex = index
                            showPhotoViewer = true
                        }
                    )
                    .id(dayPreview.date)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
                }
            }
            .fullScreenCover(isPresented: $showPhotoViewer) {
                if let dayPreview {
                    QuickLookPreview(
                        isPresented: $showPhotoViewer,
                        images: dayPreview.photos,
                        initialIndex: selectedPhotoIndex
                    )
                }
            }
        }
    }



    private func scrollToFocusedEntry(with proxy: ScrollViewProxy, animated: Bool) {
        let targetDate = focusedEntry?.timestamp
        let targetDay = Self.targetDay(for: targetDate, calendar: calendar)
        let targetMonth = monthStart(for: targetDay)
        let currentMonth = monthStart(for: .now)
        let clampedMonth = min(targetMonth, currentMonth)

        ensureMonthLoaded(clampedMonth)

        let anchor = Self.targetAnchor(hasFocusedEntry: focusedEntry != nil)
        let action = {
            proxy.scrollTo(targetDay, anchor: anchor)
        }

        if animated {
            withAnimation(.snappy) {
                action()
            }
        } else {
            action()
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo(bottomScrollID, anchor: .bottom)
        }

        if animated {
            withAnimation(.snappy) {
                action()
            }
        } else {
            action()
        }
    }

    private func entries(for date: Date) -> [WeightEntry] {
        let day = calendar.startOfDay(for: date)
        return entries
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .sorted(by: { $0.timestamp > $1.timestamp })
    }

    private func entryIDs(for date: Date) -> [PersistentIdentifier] {
        entryIDsByDay[calendar.startOfDay(for: date)] ?? []
    }

    private func workoutIDs(for date: Date) -> [PersistentIdentifier] {
        workoutIDsByDay[calendar.startOfDay(for: date)] ?? []
    }

    private func sleepIDs(for date: Date) -> [PersistentIdentifier] {
        sleepIDsByDay[calendar.startOfDay(for: date)] ?? []
    }

    private func presentDayPreview(for date: Date) {
        let day = calendar.startOfDay(for: date)
        let dayEntries = entries(for: day)
        let photos = dayEntries
            .flatMap(\.photosData)
            .compactMap(UIImage.init(data:))
        guard !photos.isEmpty else { return }

        let dayWorkouts = workouts.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
        let daySleep = sleepEntries.filter { calendar.isDate($0.endDate, inSameDayAs: day) }
        let activitySummary = dailyActivitySummaries.first { calendar.isDate($0.date, inSameDayAs: day) }

        suppressNextDayTap = true
        pressedPreviewDay = nil
        Haptics.selection()
        presentedSheet = nil
        withAnimation(.snappy) {
            dayPreview = DayPreview(
                date: day,
                photos: photos,
                weightText: dayEntries.first.map { String(format: "%.1f lbs", $0.weight) },
                entryCount: dayEntries.count,
                workoutCount: dayWorkouts.count,
                stepCount: activitySummary?.stepCount ?? 0,
                activeEnergyBurnedKilocalories: activitySummary?.activeEnergyBurnedKilocalories ?? 0,
                sleepDuration: daySleep.reduce(0) { $0 + $1.duration }
            )
        }
    }

    private func monthStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func dayScrollID(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func ensureInitialMonthsLoaded() {
        monthLoader.loadInitialMonths(count: 5)
    }

    private func ensureMonthLoaded(_ month: Date) {
        let currentMonth = monthStart(for: .now)
        let clampedMonth = min(month, currentMonth)

        monthLoader.loadInitialMonths(count: 5)
        var didChangeLoadedMonths = false

        while let earliest = monthLoader.earliest, clampedMonth < earliest {
            didChangeLoadedMonths = monthLoader.expandIfNeeded(for: earliest) || didChangeLoadedMonths
        }

        if didChangeLoadedMonths {
            rebuildMonthRenderData(forceAll: false)
        }
    }

    private func loadEarlierMonthsIfNeeded(proxy: ScrollViewProxy) {
        guard hasFinishedInitialMonthPositioning else { return }
        guard let earliest = monthLoader.earliest else { return }
        let anchorMonth = earliest
        if monthLoader.expandIfNeeded(for: earliest) {
            rebuildMonthRenderData(forceAll: false)
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.80)) {
                    proxy.scrollTo(anchorMonth, anchor: .top)
                }
            }
        }
    }

    private func makeWeeks(for monthStart: Date) -> [[Date]] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
            let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
            let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
            let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDayOfMonth)
        else {
            return []
        }

        var weeks: [[Date]] = []
        var weekStart = firstWeek.start

        while weekStart <= lastWeek.start {
            let week = (0..<7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
            }
            weeks.append(week)

            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
                break
            }
            weekStart = nextWeek
        }

        return weeks
    }

    private func makeDayDataByDate(
        for monthStart: Date,
        entriesByDay: [Date: [WeightEntry]],
        workoutsByDay: [Date: [WorkoutEntry]],
        sleepByDay: [Date: [SleepEntry]],
        dailyActivityByDay: [Date: DailyActivitySummary],
        streaksByDay: [Date: Int],
        todayPotentialStreak: Int
    ) -> [Date: DayData] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
            return [:]
        }

        let today = calendar.startOfDay(for: Date())
        let todayHasEntry = entriesByDay[today] != nil

        // Efficiently iterate only through the 28-31 days of this specific month
        // instead of filtering all historical database keys. This reduces the complexity
        // from O(N + W + S) history scans down to O(31) = O(1) constant time lookup.
        var allDays = Set<Date>()
        var date = monthInterval.start
        while date < monthInterval.end {
            let day = calendar.startOfDay(for: date)
            if entriesByDay[day] != nil || workoutsByDay[day] != nil || sleepByDay[day] != nil {
                allDays.insert(day)
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        
        if todayPotentialStreak > 0 && monthInterval.contains(today) {
            allDays.insert(today)
        }

        return allDays.reduce(into: [:]) { result, day in
            let dayEntries = entriesByDay[day] ?? []
            let isToday = day == today
            let isPotential = isToday && !todayHasEntry && todayPotentialStreak > 0
            let streakValue: Int
            if isPotential {
                streakValue = todayPotentialStreak
            } else {
                streakValue = streaksByDay[day] ?? 0
            }
            result[day] = DayData(
                weightText: dayEntries.first.map { String(format: "%.1f", $0.weight) },
                workoutCount: workoutsByDay[day]?.count ?? 0,
                sleepCount: sleepByDay[day]?.count ?? 0,
                stepText: stepText(for: dailyActivityByDay[day]?.stepCount ?? 0),
                photoCacheKey: photoCacheKey(for: dayEntries),
                streakDay: streakValue,
                isStreakPotential: isPotential
            )
        }
    }

    private func stepText(for steps: Int) -> String? {
        guard steps > 0 else { return nil }
        if steps >= 10_000 {
            return "\(steps / 1000)k"
        }
        if steps >= 1_000 {
            let value = Double(steps) / 1000
            return String(format: "%.1fk", value)
        }
        return steps.formatted()
    }

    private func rebuildMonthRenderData(forceAll: Bool = false) {
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        let groupedWorkouts = Dictionary(grouping: workouts) { workout in
            calendar.startOfDay(for: workout.timestamp)
        }
        let groupedDailyActivity = Dictionary(
            uniqueKeysWithValues: dailyActivitySummaries.map { summary in
                (calendar.startOfDay(for: summary.date), summary)
            }
        )
        let groupedSleep = Dictionary(grouping: sleepEntries) { sleep in
            calendar.startOfDay(for: sleep.endDate)
        }
        let streaks = WeightCalculations.streaksByDay(from: entries)

        // If today is not yet logged but yesterday was, compute the potential streak number.
        let today = calendar.startOfDay(for: Date())
        let todayHasEntry = groupedEntries[today] != nil
        let todayPotentialStreak: Int
        if !todayHasEntry, let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let yesterdayStreak = streaks[yesterday] {
            // yesterdayStreak == 0 means yesterday was isolated; logging today makes a 2-day run
            todayPotentialStreak = yesterdayStreak == 0 ? 2 : yesterdayStreak + 1
        } else {
            todayPotentialStreak = 0
        }

        entryIDsByDay = groupedEntries.mapValues { dayEntries in
            dayEntries
                .sorted(by: { $0.timestamp > $1.timestamp })
                .map(\.persistentModelID)
        }
        workoutIDsByDay = groupedWorkouts.mapValues { dayWorkouts in
            dayWorkouts
                .sorted(by: { $0.timestamp > $1.timestamp })
                .map(\.persistentModelID)
        }
        sleepIDsByDay = groupedSleep.mapValues { daySleep in
            daySleep
                .sorted(by: { $0.endDate > $1.endDate })
                .map(\.persistentModelID)
        }

        var newRenderData = monthRenderDataByMonth
        for monthStart in monthLoader.monthStarts {
            if forceAll || newRenderData[monthStart] == nil {
                newRenderData[monthStart] = MonthRenderData(
                    weeks: makeWeeks(for: monthStart),
                    dayDataByDate: makeDayDataByDate(
                        for: monthStart,
                        entriesByDay: groupedEntries,
                        workoutsByDay: groupedWorkouts,
                        sleepByDay: groupedSleep,
                        dailyActivityByDay: groupedDailyActivity,
                        streaksByDay: streaks,
                        todayPotentialStreak: todayPotentialStreak
                    )
                )
            }
        }

        let activeMonths = Set(monthLoader.monthStarts)
        newRenderData = newRenderData.filter { activeMonths.contains($0.key) }
        monthRenderDataByMonth = newRenderData

        // Build pending thumbnails for lazy loading and remove stale cached thumbnails.
        let newPending = buildPendingThumbnails(from: groupedEntries)
        let staleKeys = Set(pendingThumbnails.keys).subtracting(newPending.keys)
        for key in staleKeys {
            thumbnailLoader.removeValue(forKey: key)
        }
        pendingThumbnails = newPending

        for (key, pending) in newPending {
            thumbnailLoader.loadIfNeeded(key: key, pending: pending)
        }
    }

    /// Returns the cache key for the first available photo across the day's entries, or nil if none.
    private func photoCacheKey(for entries: [WeightEntry]) -> String? {
        for entry in entries {
            guard entry.hasPhotos else { continue }
            let cacheKey = "\(entry.persistentModelID)-0-\(entry.photosFingerprint)"
            return cacheKey
        }
        return nil
    }

    /// Builds the pending thumbnail map for lazy loading. Only decodes photo data
    /// for entries within the currently loaded months to avoid unnecessary work.
    private func buildPendingThumbnails(from groupedEntries: [Date: [WeightEntry]]) -> [String: PendingThumbnail] {
        let loadedMonthIntervals: [DateInterval] = monthLoader.monthStarts.compactMap { start in
            calendar.dateInterval(of: .month, for: start)
        }

        var result: [String: PendingThumbnail] = [:]
        for (day, dayEntries) in groupedEntries {
            // Skip entries outside loaded months — their thumbnails aren't needed yet.
            guard loadedMonthIntervals.contains(where: { $0.contains(day) }) else { continue }
            for entry in dayEntries {
                guard entry.hasPhotos else { continue }
                
                let cacheKey = "\(entry.persistentModelID)-0-\(entry.photosFingerprint)"

                let photosData = entry.photosData
                guard let firstPhoto = photosData.first else { continue }
                result[cacheKey] = PendingThumbnail(photoData: firstPhoto, cacheKey: cacheKey)
                break // Only need the first photo per day
            }
        }
        return result
    }
}

struct DayPreviewPopup: View {
    let preview: JournalView.DayPreview
    let tintColor: Color
    let title: String
    let onDismiss: () -> Void
    let onPreviousDay: (() -> Void)?
    let onNextDay: (() -> Void)?

    @State private var dragOffset: CGSize = .zero
    let onTapPhoto: ((Int) -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    if let weightText = preview.weightText {
                        Text(weightText)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tintColor)
                            .lineLimit(1)
                    }
                }

                photoStrip

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 10) {
                    statItem(value: "\(preview.photos.count)", label: preview.photos.count == 1 ? "Photo" : "Photos")
                    statItem(value: "\(preview.entryCount)", label: preview.entryCount == 1 ? "Log" : "Logs")

                    if preview.workoutCount > 0 {
                        statItem(value: "\(preview.workoutCount)", label: preview.workoutCount == 1 ? "Workout" : "Workouts")
                    }

                    if preview.stepCount > 0 {
                        statItem(value: preview.stepCount.formatted(), label: "Steps")
                    }

                    if preview.activeEnergyBurnedKilocalories > 0 {
                        statItem(value: Int(preview.activeEnergyBurnedKilocalories.rounded()).formatted(), label: "Active cal")
                    }

                    if preview.sleepDuration > 0 {
                        statItem(value: sleepText(preview.sleepDuration), label: "Sleep")
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
            .padding(.horizontal, 22)
            .offset(x: dragOffset.width)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    withAnimation(.interactiveSpring) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width > threshold {
                        onPreviousDay?()
                    } else if value.translation.width < -threshold {
                        onNextDay?()
                    }
                    withAnimation(.snappy) {
                        dragOffset = .zero
                    }
                }
        )
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(preview.photos.prefix(8).enumerated()), id: \.offset) { index, photo in
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture {
                            onTapPhoto?(index)
                        }
                }
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sleepText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let images: [UIImage]
    let initialIndex: Int

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.currentPreviewItemIndex = initialIndex
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.close)
        )
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(images: images, isPresented: $isPresented)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let images: [UIImage]
        var tempURLs: [URL] = []
        @Binding var isPresented: Bool

        init(images: [UIImage], isPresented: Binding<Bool>) {
            self.images = images
            self._isPresented = isPresented
            super.init()
            writeToTemp()
        }

        private func writeToTemp() {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (i, image) in images.enumerated() {
                let url = dir.appendingPathComponent("photo_\(i).jpg")
                if let data = image.jpegData(compressionQuality: 1.0) {
                    try? data.write(to: url)
                    tempURLs.append(url)
                }
            }
        }

        @objc func close() {
            isPresented = false
        }

        func numberOfPreviewItems(in _: QLPreviewController) -> Int {
            tempURLs.count
        }

        func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            tempURLs[index] as QLPreviewItem
        }

        deinit {
            for url in tempURLs {
                try? FileManager.default.removeItem(at: url)
            }
            if let dir = tempURLs.first?.deletingLastPathComponent() {
                try? FileManager.default.removeItem(at: dir)
            }
        }
    }
}

#Preview {
    JournalView(scrollToEntryTrigger: 0, focusedEntry: nil, scrollToBottomTrigger: 0, showLog: .constant(false), logDate: .constant(nil))
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self, SleepEntry.self], inMemory: true)
}

struct LogDayDetailSheet: View {
    private struct PhotoItem {
        let image: UIImage
        let entryID: PersistentIdentifier
        let photoIndex: Int
    }

    private struct EntryDraft {
        var weight: String
        var timestamp: Date
        var note: String
        var photosData: [Data]
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var allEntries: [WeightEntry]
    @Query(sort: \WorkoutEntry.timestamp, order: .reverse) private var allWorkouts: [WorkoutEntry]
    @Query(sort: \DailyActivitySummary.date, order: .reverse) private var allDailyActivitySummaries: [DailyActivitySummary]
    @Query(sort: \SleepEntry.endDate, order: .reverse) private var allSleepEntries: [SleepEntry]

    let initialDate: Date
    let tintColor: Color
    let onDismiss: () -> Void
    let calendar: Calendar = .current

    @State private var currentDate: Date
    @State private var editingEntryIDs: Set<PersistentIdentifier> = []
    @State private var entryDrafts: [PersistentIdentifier: EntryDraft] = [:]
    @State private var pendingDeletionEntryID: PersistentIdentifier?
    @State private var selectedPhotoIndex = 0
    @State private var isPhotoCarouselPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingDayPhotoEntryID: PersistentIdentifier?
    @State private var dragStartIndex: Int? = nil

    init(initialDate: Date, tintColor: Color, onDismiss: @escaping () -> Void) {
        self.initialDate = initialDate
        self.tintColor = tintColor
        self.onDismiss = onDismiss
        _currentDate = State(initialValue: initialDate)
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(currentDate) {
            return "Today"
        }
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        if let daysAgo = calendar.dateComponents([.day], from: currentDate, to: Date()).day,
           daysAgo >= 1 && daysAgo < 7 {
            return dayNameFormatter.string(from: currentDate)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: currentDate)
    }

    private var entries: [WeightEntry] {
        allEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: currentDate) }
    }

    private var workouts: [WorkoutEntry] {
        allWorkouts.filter { calendar.isDate($0.timestamp, inSameDayAs: currentDate) }
    }

    private var sleepEntries: [SleepEntry] {
        allSleepEntries
            .filter { calendar.isDate($0.startDate, inSameDayAs: currentDate) }
            .sorted(by: { $0.endDate > $1.endDate })
    }

    private var dailyActivitySummary: DailyActivitySummary? {
        allDailyActivitySummaries.first { Calendar.current.isDate($0.date, inSameDayAs: currentDate) }
    }

    private var datesWithPhotos: [Date] {
        let calendar = Calendar.current
        let uniqueDays = Set(allEntries.filter { $0.hasPhotos }.map { calendar.startOfDay(for: $0.timestamp) })
        return uniqueDays.sorted()
    }

    private var previousDateWithPhotos: Date? {
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: currentDate)
        return datesWithPhotos.last(where: { $0 < currentDay })
    }

    private var nextDateWithPhotos: Date? {
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: currentDate)
        return datesWithPhotos.first(where: { $0 > currentDay })
    }

    private var photoItems: [PhotoItem] {
        entries
            .flatMap { entry in
                entry.photosData.enumerated().compactMap { index, data in
                    UIImage(data: data).map { image in
                        PhotoItem(image: image, entryID: entry.persistentModelID, photoIndex: index)
                    }
                }
            }
    }

    private var photos: [UIImage] {
        photoItems.map(\.image)
    }

    private var isEditingEntry: Bool {
        !editingEntryIDs.isEmpty
    }

    private var displayedPhotoItems: [PhotoItem] {
        if isEditingEntry {
            return entries.flatMap { entry in
                guard let draft = entryDrafts[entry.persistentModelID] else { return [PhotoItem]() }
                return draft.photosData.enumerated().compactMap { index, data in
                    UIImage(data: data).map { image in
                        PhotoItem(image: image, entryID: entry.persistentModelID, photoIndex: index)
                    }
                }
            }
        }

        return photoItems
    }

    private var displayedPhotos: [UIImage] {
        displayedPhotoItems.map(\.image)
    }

    private var dayPhotoEntry: WeightEntry? {
        return entries.first
    }

    private var dayEditEntry: WeightEntry? {
        return entries.first
    }

    private var canSaveDraft: Bool {
        !entryDrafts.isEmpty && entryDrafts.values.allSatisfy { draft in
            WeightCalculations.parseWeight(from: draft.weight) != nil
        }
    }

    private var logCardMinWidth: CGFloat {
        isEditingEntry ? 280 : 190
    }

    private var logCardMaxWidth: CGFloat {
        isEditingEntry ? 280 : 230
    }


    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if !entries.isEmpty || dailyActivitySummary != nil || !workouts.isEmpty || !sleepEntries.isEmpty {
                        compactStatsRow(
                            weight: entries.sorted(by: { $0.timestamp > $1.timestamp }).first,
                            summary: dailyActivitySummary,
                            workouts: workouts,
                            sleepEntries: sleepEntries
                        )
                    }

                    if isEditingEntry {
                        logCarouselSection
                    }

                    if dayPhotoEntry != nil {
                        photoHeroSection
                    }

                    sleepSection

                    if entries.isEmpty && workouts.isEmpty && sleepEntries.isEmpty {
                        Text("No entry logged for this day.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    workoutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(.clear)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let threshold: CGFloat = 60
                        if value.translation.width > threshold {
                            withAnimation(.snappy) { goToPreviousDay() }
                        } else if value.translation.width < -threshold {
                            withAnimation(.snappy) { goToNextDay() }
                        }
                    }
            )
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if isEditingEntry {
                        headerIconButton(
                            systemImage: "xmark",
                            tint: .primary
                        ) {
                            cancelEditing()
                        }

                        if dayPhotoEntry != nil {
                            addPhotosToolbarButton
                        }
                    } else {
                        if let dayEditEntry {
                            editEntryButton(for: dayEditEntry)
                        }

                        if dayPhotoEntry != nil {
                            addPhotosToolbarButton
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.snappy) { goToPreviousDay() }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.footnote.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(previousDateWithPhotos == nil ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.5))
                        .disabled(previousDateWithPhotos == nil || editingEntryIDs.isEmpty == false)

                        Text(dayTitle)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)

                        Button {
                            withAnimation(.snappy) { goToNextDay() }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(nextDateWithPhotos == nil ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.5))
                        .disabled(nextDateWithPhotos == nil || editingEntryIDs.isEmpty == false)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isEditingEntry {
                        headerIconButton(
                            systemImage: "checkmark",
                            tint: .primary,
                            disabled: !canSaveDraft
                        ) {
                            saveChanges()
                        }
                    } else {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete this log?",
                isPresented: Binding(
                    get: { pendingDeletionEntryID != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeletionEntryID = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDeletionEntryID {
                        delete(entryID: pendingDeletionEntryID)
                    }
                }

                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $isPhotoCarouselPresented) {
                LogPhotoCarouselView(
                    photos: displayedPhotos,
                    initialIndex: selectedPhotoIndex,
                    canEditCurrentPhoto: !photoItems.isEmpty,
                    onEditCurrentPhoto: editPhotoSourceEntry,
                    canRemoveCurrentPhoto: isEditingEntry,
                    onRemoveCurrentPhoto: removeDisplayedPhoto,
                    weightEntry: entries.sorted(by: { $0.timestamp > $1.timestamp }).first,
                    activitySummary: dailyActivitySummary,
                    tintColor: tintColor,
                    date: currentDate
                )
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    let newPhotoData = await loadPhotoData(from: newItems)
                    await MainActor.run {
                        let targetID = pendingDayPhotoEntryID ?? dayPhotoEntry?.persistentModelID
                        if let targetID {
                            appendPhotos(newPhotoData, toEntryID: targetID)
                        }
                        pendingDayPhotoEntryID = nil
                        selectedPhotoItems = []
                    }
                }
            }
        }
    }

    private var logCarouselSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 4)

            if isEditingEntry {
                VStack(spacing: 10) {
                    ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                        editRow(for: entry, index: index)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                            logCard(for: entry, index: index)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func logCard(for entry: WeightEntry, index: Int) -> some View {
        let isEditing = isEditingEntry && entryDrafts[entry.persistentModelID] != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !isEditing {
                    Text(entry.timestamp, format: .dateTime.hour().minute())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if isEditing {
                            TextField("Weight", text: draftWeightBinding(for: entry))
                                .keyboardType(.decimalPad)
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .foregroundStyle(tintColor)
                                .frame(width: 96)
                        } else {
                            Text(String(format: "%.1f", entry.weight))
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .foregroundStyle(tintColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .contentTransition(.numericText())
                        }

                        Text("lbs")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    if isEditing {
                        HStack(spacing: 6) {
                            DatePicker(
                                "",
                                selection: draftDateBinding(for: entry),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .scaleEffect(0.8, anchor: .leading)
                            .frame(height: 28)

                            DatePicker(
                                "",
                                selection: draftTimeBinding(for: entry),
                                displayedComponents: [.hourAndMinute]
                            )
                            .labelsHidden()
                            .scaleEffect(0.8, anchor: .leading)
                            .frame(height: 28)
                        }
                    }
            }
            .layoutPriority(1)
        }
        .padding(18)
        .frame(minWidth: logCardMinWidth, maxWidth: logCardMaxWidth, alignment: .leading)
        .contextMenu {
            sourceContextMenuItem(sourceText: weightSourceText(entry.source))
        }
        .glassEffect(
            .regular.tint(tintColor.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            if isEditing {
                headerIconButton(systemImage: "trash", tint: .red) {
                    pendingDeletionEntryID = entry.persistentModelID
                }
                .padding(12)
            }
        }
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workouts")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 4)

            WorkoutSummaryCard(workouts: workouts, tintColor: tintColor)
                .padding(16)
                .glassEffect(
                    .regular.tint(tintColor.opacity(0.06)),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
        }
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 4)

            SleepSummaryCard(sleepEntries: sleepEntries, tintColor: tintColor)
                .padding(16)
                .glassEffect(
                    .regular.tint(tintColor.opacity(0.06)),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
        }
    }

    private func beginEditing(_ entry: WeightEntry) {
        editingEntryIDs = Set(entries.map(\.persistentModelID))
        entryDrafts = Dictionary(uniqueKeysWithValues: entries.map { currentEntry in
            (
                currentEntry.persistentModelID,
                EntryDraft(
                    weight: String(format: "%.1f", currentEntry.weight),
                    timestamp: currentEntry.timestamp,
                    note: currentEntry.note ?? "",
                    photosData: currentEntry.photosData
                )
            )
        })
    }

    private func cancelEditing() {
        editingEntryIDs = []
        entryDrafts = [:]
        pendingDayPhotoEntryID = nil
        selectedPhotoItems = []
    }

    private func appendPhotos(_ photos: [Data], toEntryID entryID: PersistentIdentifier) {
        guard !photos.isEmpty else { return }
        guard let entry = entries.first(where: { $0.persistentModelID == entryID }) else { return }

        if isEditingEntry {
            entryDrafts[entryID]?.photosData.append(contentsOf: photos)
            return
        }

        entry.photosData.append(contentsOf: photos)

        do {
            try modelContext.save()
            refreshDerivedState()
        } catch {
            return
        }
    }

    private func saveChanges() {
        let updates = entries.compactMap { entry -> (WeightEntry, EntryDraft)? in
            guard let draft = entryDrafts[entry.persistentModelID] else { return nil }
            return (entry, draft)
        }

        guard updates.count == entries.count else { return }

        let healthUpdates = updates.compactMap { entry, draft -> (WeightEntry, UUID?, Double, Date)? in
            guard let updatedWeight = WeightCalculations.parseWeight(from: draft.weight) else { return nil }
            let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let previousUUID = entry.healthKitUUID

            entry.weight = updatedWeight
            entry.timestamp = draft.timestamp
            entry.note = trimmedNote.isEmpty ? nil : trimmedNote
            entry.photosData = draft.photosData

            return (entry, previousUUID, updatedWeight, draft.timestamp)
        }

        cancelEditing()

        do {
            try modelContext.save()
            refreshDerivedState()
        } catch {
            return
        }

        Task {
            for (entry, previousUUID, updatedWeight, updatedTimestamp) in healthUpdates {
                if let previousUUID {
                    await healthManager.deleteWeight(sampleUUID: previousUUID)
                }

                let newUUID = await healthManager.saveWeight(updatedWeight, date: updatedTimestamp)
                await MainActor.run {
                    entry.healthKitUUID = newUUID
                    try? modelContext.save()
                    refreshDerivedState()
                }
            }
        }
    }

    private func delete(entryID: PersistentIdentifier) {
        guard let entry = entries.first(where: { $0.persistentModelID == entryID }) else {
            pendingDeletionEntryID = nil
            return
        }

        let sampleUUID = entry.healthKitUUID
        let remainingEntries = allEntries.filter { $0.persistentModelID != entryID }

        isPhotoCarouselPresented = false
        modelContext.delete(entry)
        pendingDeletionEntryID = nil
        entryDrafts.removeValue(forKey: entryID)
        editingEntryIDs.remove(entryID)

        do {
            try modelContext.save()
            WeightWidgetSnapshotStore.refresh(using: remainingEntries)
            notificationManager.rescheduleReminders()
        } catch {
            return
        }

        Task {
            if let sampleUUID {
                await healthManager.deleteWeight(sampleUUID: sampleUUID)
            }
        }
    }

    private func refreshDerivedState() {
        WeightWidgetSnapshotStore.refresh(using: allEntries)
        notificationManager.rescheduleReminders()
    }

    private func editPhotoSourceEntry(at index: Int) {
        guard photoItems.indices.contains(index) else { return }
        let entryID = photoItems[index].entryID
        guard let entry = entries.first(where: { $0.persistentModelID == entryID }) else { return }

        isPhotoCarouselPresented = false
        beginEditing(entry)
    }

    private func removeDisplayedPhoto(at index: Int) {
        guard displayedPhotoItems.indices.contains(index) else { return }
        let photoItem = displayedPhotoItems[index]

        removeDraftPhoto(entryID: photoItem.entryID, photoIndex: photoItem.photoIndex)

        if displayedPhotoItems.isEmpty {
            isPhotoCarouselPresented = false
        }
    }

    private func photosCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let dayEntries = allEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
        return dayEntries.flatMap(\.photosData).count
    }

    @ViewBuilder
    private var photoHeroSection: some View {
        if !displayedPhotos.isEmpty {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(displayedPhotoItems.enumerated()), id: \.offset) { index, photoItem in
                    photoHeroItem(photoItem.image, displayIndex: index)
                        .tag(index)
                }
            }
            .frame(height: photoHeroHeight)
            .tabViewStyle(.page(indexDisplayMode: displayedPhotos.count > 1 ? .always : .never))
            .id(currentDate)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartIndex == nil {
                            dragStartIndex = selectedPhotoIndex
                        }
                    }
                    .onEnded { value in
                        defer { dragStartIndex = nil }
                        guard let startIndex = dragStartIndex else { return }
                        let threshold: CGFloat = 50
                        
                        if startIndex == 0, value.translation.width > threshold {
                            if let prevDay = previousDateWithPhotos {
                                withAnimation(.snappy) {
                                    currentDate = prevDay
                                    let count = photosCount(for: prevDay)
                                    selectedPhotoIndex = max(count - 1, 0)
                                }
                            }
                        }
                        if startIndex == displayedPhotos.count - 1, value.translation.width < -threshold {
                            if let nextDay = nextDateWithPhotos {
                                withAnimation(.snappy) {
                                    currentDate = nextDay
                                    selectedPhotoIndex = 0
                                }
                            }
                        }
                    }
            )
            .overlay(alignment: .topTrailing) {
                if isEditingEntry && displayedPhotoItems.indices.contains(selectedPhotoIndex) {
                    Button {
                        removeDisplayedPhoto(at: selectedPhotoIndex)
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red.opacity(0.82))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .padding(.trailing, 14)
                    .accessibilityLabel("Remove photo")
                }
            }
        }
    }

    @ViewBuilder
    private func photoHeroItem(_ photo: UIImage, displayIndex: Int) -> some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: photoHeroHeight)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                selectedPhotoIndex = displayIndex
                isPhotoCarouselPresented = true
            }
    }

    private var addPhotosToolbarButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: nil,
            matching: .images
        ) {
            Image(systemName: "photo.badge.plus")
                .font(.headline.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }

    private var photoHeroHeight: CGFloat {
        170
    }

    private func removeDraftPhoto(entryID: PersistentIdentifier, photoIndex: Int) {
        guard var draft = entryDrafts[entryID] else { return }
        guard draft.photosData.indices.contains(photoIndex) else { return }

        draft.photosData.remove(at: photoIndex)
        entryDrafts[entryID] = draft
        selectedPhotoIndex = min(selectedPhotoIndex, max(displayedPhotoItems.count - 1, 0))
    }

    private func loadPhotoData(from items: [PhotosPickerItem]) async -> [Data] {
        var loadedData: [Data] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loadedData.append(data)
            }
        }

        return loadedData
    }

    @ViewBuilder
    private func editEntryButton(for entry: WeightEntry) -> some View {
        if !isEditingEntry {
            headerIconButton(
                systemImage: "pencil",
                tint: .primary
            ) {
                beginEditing(entry)
            }
        }
    }

    private func editRow(for entry: WeightEntry, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(entries.count > 1 ? "Weight \(index + 1)" : "Weight")
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)

                headerIconButton(systemImage: "trash", tint: .red) {
                    pendingDeletionEntryID = entry.persistentModelID
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("Weight", text: draftWeightBinding(for: entry))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(tintColor)
                    .frame(minWidth: 50)

                Text("lbs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 6) {
                DatePicker(
                    "",
                    selection: draftDateBinding(for: entry),
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .scaleEffect(0.8, anchor: .leading)
                .frame(height: 28)

                DatePicker(
                    "",
                    selection: draftTimeBinding(for: entry),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .scaleEffect(0.8, anchor: .leading)
                .frame(height: 28)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.tint(tintColor.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func draftWeightBinding(for entry: WeightEntry) -> Binding<String> {
        Binding(
            get: { entryDrafts[entry.persistentModelID]?.weight ?? "" },
            set: { entryDrafts[entry.persistentModelID]?.weight = $0 }
        )
    }

    private func draftNoteBinding(for entry: WeightEntry) -> Binding<String> {
        Binding(
            get: { entryDrafts[entry.persistentModelID]?.note ?? "" },
            set: { entryDrafts[entry.persistentModelID]?.note = $0 }
        )
    }

    private func draftDateBinding(for entry: WeightEntry) -> Binding<Date> {
        Binding(
            get: { entryDrafts[entry.persistentModelID]?.timestamp ?? entry.timestamp },
            set: { newDate in
                guard var draft = entryDrafts[entry.persistentModelID] else { return }
                draft.timestamp = combine(date: newDate, time: draft.timestamp)
                entryDrafts[entry.persistentModelID] = draft
            }
        )
    }

    private func draftTimeBinding(for entry: WeightEntry) -> Binding<Date> {
        Binding(
            get: { entryDrafts[entry.persistentModelID]?.timestamp ?? entry.timestamp },
            set: { newTime in
                guard var draft = entryDrafts[entry.persistentModelID] else { return }
                draft.timestamp = combine(date: draft.timestamp, time: newTime)
                entryDrafts[entry.persistentModelID] = draft
            }
        )
    }

    private func combine(date: Date, time: Date) -> Date {
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        return Calendar.current.date(from: combinedComponents) ?? date
    }

    private func compactStatsRow(
        weight: WeightEntry?,
        summary: DailyActivitySummary?,
        workouts: [WorkoutEntry],
        sleepEntries: [SleepEntry]
    ) -> some View {
        let editing = weight.map { isEditingEntry && entryDrafts[$0.persistentModelID] != nil } ?? false
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let weight {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass.fill")
                            .font(.caption2)

                        if editing {
                            TextField("Weight", text: draftWeightBinding(for: weight))
                                .keyboardType(.decimalPad)
                                .font(.subheadline.weight(.semibold))
                                .fixedSize()
                        } else {
                            Text(String(format: "%.1f", weight.weight))
                                .font(.subheadline.weight(.semibold))
                                .contentTransition(.numericText())
                        }

                        Text("lbs")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(tintColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                if let summary, summary.stepCount > 0 {
                    Label {
                        Text(summary.stepCount.formatted())
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "shoeprints.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                if let summary, summary.activeEnergyBurnedKilocalories > 0 {
                    Label {
                        Text("\(Int(summary.activeEnergyBurnedKilocalories.rounded())) cal")
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                if !workouts.isEmpty {
                    Label {
                        Text("\(workouts.count) " + (workouts.count == 1 ? "workout" : "workouts"))
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "figure.run")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                let sleepDuration = sleepEntries.map(\.duration).reduce(0, +)
                if sleepDuration > 0 {
                    Label {
                        Text(sleepText(sleepDuration))
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "bed.double.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sleepText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func activitySourceText(_ source: DailyActivitySource) -> String {
        switch source {
        case .appleHealth:
            return "Apple Health"
        }
    }

    private func weightSourceText(_ source: WeightSource) -> String {
        switch source {
        case .appleHealth:
            return "Apple Health"
        case .manual:
            return "Scale"
        }
    }

    private func sourceContextMenuItem(sourceText: String) -> some View {
        Button { } label: {
            Label("From \(sourceText)", systemImage: "info.circle")
        }
    }

    @ViewBuilder
    private func headerIconButton(
        systemImage: String,
        prominent: Bool = false,
        tint: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        if prominent {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glassProminent)
            .tint(tint)
            .disabled(disabled)
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .disabled(disabled)
        }
    }

    private func goToPreviousDay() {
        if let prevDay = previousDateWithPhotos {
            currentDate = prevDay
        }
    }

    private func goToNextDay() {
        if let nextDay = nextDateWithPhotos {
            currentDate = nextDay
        }
    }
}

struct LogPhotoCarouselView: View {
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var allEntries: [WeightEntry]
    @Query(sort: \DailyActivitySummary.date, order: .reverse) private var allDailyActivitySummaries: [DailyActivitySummary]
    @Query(sort: \WorkoutEntry.timestamp, order: .reverse) private var allWorkouts: [WorkoutEntry]
    @Query(sort: \SleepEntry.endDate, order: .reverse) private var allSleepEntries: [SleepEntry]

    let initialPhotos: [UIImage]
    let initialIndex: Int
    let canEditCurrentPhoto: Bool
    let onEditCurrentPhoto: (Int) -> Void
    var canRemoveCurrentPhoto = false
    var onRemoveCurrentPhoto: (Int) -> Void = { _ in }
    var weightEntry: WeightEntry?
    var activitySummary: DailyActivitySummary?
    let tintColor: Color
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0
    @State private var dateState: Date
    @State private var photosState: [UIImage]
    @State private var dragStartIndex: Int? = nil

    init(
        photos: [UIImage],
        initialIndex: Int,
        canEditCurrentPhoto: Bool,
        onEditCurrentPhoto: @escaping (Int) -> Void,
        canRemoveCurrentPhoto: Bool = false,
        onRemoveCurrentPhoto: @escaping (Int) -> Void = { _ in },
        weightEntry: WeightEntry? = nil,
        activitySummary: DailyActivitySummary? = nil,
        tintColor: Color = .blue,
        date: Date = Date()
    ) {
        self.initialPhotos = photos
        self.initialIndex = initialIndex
        self.canEditCurrentPhoto = canEditCurrentPhoto
        self.onEditCurrentPhoto = onEditCurrentPhoto
        self.canRemoveCurrentPhoto = canRemoveCurrentPhoto
        self.onRemoveCurrentPhoto = onRemoveCurrentPhoto
        self.weightEntry = weightEntry
        self.activitySummary = activitySummary
        self.tintColor = tintColor
        self.date = date
        _dateState = State(initialValue: date)
        _photosState = State(initialValue: photos)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(dateState) {
            return "Today"
        }
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        if let daysAgo = calendar.dateComponents([.day], from: dateState, to: Date()).day,
           daysAgo >= 1 && daysAgo < 7 {
            return dayNameFormatter.string(from: dateState)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: dateState)
    }

    private var datesWithPhotos: [Date] {
        let calendar = Calendar.current
        let uniqueDays = Set(allEntries.filter { $0.hasPhotos }.map { calendar.startOfDay(for: $0.timestamp) })
        return uniqueDays.sorted()
    }

    private var previousDateWithPhotos: Date? {
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: dateState)
        return datesWithPhotos.last(where: { $0 < currentDay })
    }

    private var nextDateWithPhotos: Date? {
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: dateState)
        return datesWithPhotos.first(where: { $0 > currentDay })
    }

    private var currentWeightEntry: WeightEntry? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: dateState)
        let initialDay = calendar.startOfDay(for: date)
        if calendar.isDate(targetDay, inSameDayAs: initialDay) {
            return weightEntry
        }
        return allEntries.first { calendar.isDate($0.timestamp, inSameDayAs: targetDay) }
    }

    private var currentActivitySummary: DailyActivitySummary? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: dateState)
        let initialDay = calendar.startOfDay(for: date)
        if calendar.isDate(targetDay, inSameDayAs: initialDay) {
            return activitySummary
        }
        return allDailyActivitySummaries.first { calendar.isDate($0.date, inSameDayAs: targetDay) }
    }

    private var currentWorkouts: [WorkoutEntry] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: dateState)
        return allWorkouts.filter { calendar.isDate($0.timestamp, inSameDayAs: targetDay) }
    }

    private var currentSleepEntries: [SleepEntry] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: dateState)
        return allSleepEntries.filter { calendar.isDate($0.startDate, inSameDayAs: targetDay) }
    }

    private func sleepText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func navigateTo(newDate: Date, landingAtRightmost: Bool = false) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: newDate)
        let initialDay = calendar.startOfDay(for: date)
        
        dateState = newDate
        
        if calendar.isDate(targetDay, inSameDayAs: initialDay) {
            photosState = initialPhotos
        } else {
            let dayEntries = allEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: targetDay) }
            photosState = dayEntries
                .sorted(by: { $0.timestamp > $1.timestamp })
                .flatMap(\.photosData)
                .compactMap(UIImage.init(data:))
        }
        
        selectedIndex = landingAtRightmost ? max(photosState.count - 1, 0) : 0
    }

    @ViewBuilder
    private func photoTabView(photo: UIImage, index: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ZoomableScrollView {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .background(Color(uiColor: .systemBackground))

                if canRemoveCurrentPhoto {
                    fullScreenRemoveButton(for: index)
                        .position(fullScreenRemoveButtonPosition(for: photo, in: proxy.size))
                }
            }
        }
    }

    private var carouselPhotosTab: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(photosState.enumerated()), id: \.offset) { index, photo in
                photoTabView(photo: photo, index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .id(dateState)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if dragStartIndex == nil {
                        dragStartIndex = selectedIndex
                    }
                }
                .onEnded { value in
                    defer { dragStartIndex = nil }
                    guard let startIndex = dragStartIndex else { return }
                    let threshold: CGFloat = 50
                    if startIndex == 0, value.translation.width > threshold {
                        if let prevDay = previousDateWithPhotos {
                            withAnimation(.snappy) { navigateTo(newDate: prevDay, landingAtRightmost: true) }
                        }
                    }
                    if startIndex == photosState.count - 1, value.translation.width < -threshold {
                        if let nextDay = nextDateWithPhotos {
                            withAnimation(.snappy) { navigateTo(newDate: nextDay, landingAtRightmost: false) }
                        }
                    }
                }
        )
    }

    private var toolbarPrincipalView: some View {
        HStack(spacing: 8) {
            Button {
                if let prevDay = previousDateWithPhotos {
                    withAnimation(.snappy) { navigateTo(newDate: prevDay, landingAtRightmost: true) }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.footnote.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(previousDateWithPhotos == nil ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.5))
            .disabled(previousDateWithPhotos == nil)

            Text(formattedDate)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Button {
                if let nextDay = nextDateWithPhotos {
                    withAnimation(.snappy) { navigateTo(newDate: nextDay, landingAtRightmost: false) }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(nextDateWithPhotos == nil ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.5))
            .disabled(nextDateWithPhotos == nil)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                carouselPhotosTab

                if currentWeightEntry != nil || currentActivitySummary != nil || !currentWorkouts.isEmpty || !currentSleepEntries.isEmpty {
                    carouselStatsRow
                        .padding(.top, -2)
                }
            }
            .tint(tintColor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    toolbarPrincipalView
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedIndex = min(max(initialIndex, 0), max(photosState.count - 1, 0))
        }
        .onChange(of: photosState.count) { _, count in
            selectedIndex = min(selectedIndex, max(count - 1, 0))
        }
    }

    @ViewBuilder
    private var carouselStatsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let weightEntry = currentWeightEntry {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass.fill")
                            .font(.caption2)

                        Text(String(format: "%.1f", weightEntry.weight))
                            .font(.subheadline.weight(.semibold))

                        Text("lbs")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(tintColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                if let activitySummary = currentActivitySummary, activitySummary.stepCount > 0 {
                    Label {
                        Text(activitySummary.stepCount.formatted())
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "shoeprints.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                if let activitySummary = currentActivitySummary, activitySummary.activeEnergyBurnedKilocalories > 0 {
                    Label {
                        Text("\(Int(activitySummary.activeEnergyBurnedKilocalories.rounded())) cal")
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                if !currentWorkouts.isEmpty {
                    Label {
                        Text("\(currentWorkouts.count) " + (currentWorkouts.count == 1 ? "workout" : "workouts"))
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "figure.run")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                let sleepDuration = currentSleepEntries.map(\.duration).reduce(0, +)
                if sleepDuration > 0 {
                    Label {
                        Text(sleepText(sleepDuration))
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "bed.double.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .systemBackground).opacity(0.8),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fullScreenRemoveButton(for index: Int) -> some View {
        Button {
            onRemoveCurrentPhoto(index)
            selectedIndex = min(selectedIndex, max(photosState.count - 2, 0))
        } label: {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red.opacity(0.82))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove photo")
    }

    private func fullScreenRemoveButtonPosition(for photo: UIImage, in containerSize: CGSize) -> CGPoint {
        let imageSize = photo.size
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGPoint(x: containerSize.width - 40, y: 40)
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )

        return CGPoint(
            x: origin.x + fittedSize.width - 22,
            y: origin.y + 22
        )
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear

        let hostedController = UIHostingController(rootView: content)
        hostedController.view.translatesAutoresizingMaskIntoConstraints = false
        hostedController.view.backgroundColor = .clear
        scrollView.addSubview(hostedController.view)

        NSLayoutConstraint.activate([
            hostedController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hostedController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }
    }
}

struct WorkoutSummaryCard: View {
    let workouts: [WorkoutEntry]
    let tintColor: Color

    @State private var isExpanded = false

    private var sortedWorkouts: [WorkoutEntry] {
        workouts.sorted { $0.timestamp < $1.timestamp }
    }

    private var totalDuration: TimeInterval {
        workouts.reduce(0) { $0 + $1.duration }
    }

    private var totalCalories: Double {
        workouts.compactMap(\.energyBurnedKilocalories).reduce(0, +)
    }

    private var timelineBounds: (start: Date, end: Date)? {
        let sorted = sortedWorkouts
        guard let first = sorted.first,
              let last = sorted.last else { return nil }
        return (first.timestamp, last.timestamp.addingTimeInterval(last.duration))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(
                    workouts.count == 1 ? activityName(for: workouts[0]) : "\(workouts.count) Workouts",
                    systemImage: workouts.count == 1 ? activitySymbol(for: workouts[0]) : "figure.run"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                if !workouts.isEmpty {
                    Text(totalDurationText)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            if workouts.isEmpty {
                Text("No data")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    if workouts.count > 1 {
                        withAnimation(.snappy(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        if let bounds = timelineBounds {
                            workoutTimeline(bounds: bounds)
                        }

                        if totalCalories > 0 {
                            Text("\(Int(totalCalories.rounded())) cal burned")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sortedWorkouts, id: \.persistentModelID) { workout in
                                workoutDetailCard(workout)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button { } label: {
                Label("From Apple Health", systemImage: "info.circle")
            }
        }
    }

    private func workoutTimeline(bounds: (start: Date, end: Date)) -> some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let totalSpan = bounds.end.timeIntervalSince(bounds.start)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tintColor.opacity(0.08))

                    ForEach(sortedWorkouts, id: \.persistentModelID) { workout in
                        let activityType = HKWorkoutActivityType(rawValue: workout.activityTypeRawValue) ?? .other
                        let startFraction = totalSpan > 0
                            ? workout.timestamp.timeIntervalSince(bounds.start) / totalSpan
                            : 0
                        let widthFraction = totalSpan > 0
                            ? workout.duration / totalSpan
                            : 1
                        let barWidth = max(widthFraction * proxy.size.width, 4)

                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(tintColor.opacity(0.55))

                            if barWidth >= 20 {
                                Image(systemName: activityType.symbolName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .frame(width: barWidth)
                        .offset(x: startFraction * proxy.size.width)
                    }
                }
            }
            .frame(height: 28)

            HStack {
                Text(bounds.start, format: .dateTime.hour().minute())
                Spacer()
                Text(bounds.end, format: .dateTime.hour().minute())
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private func workoutDetailCard(_ workout: WorkoutEntry) -> some View {
        let activityType = HKWorkoutActivityType(rawValue: workout.activityTypeRawValue) ?? .other

        return VStack(alignment: .leading, spacing: 6) {
            Label(activityType.displayName, systemImage: activityType.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(workoutDurationText(workout.duration))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(workout.timestamp, format: .dateTime.hour().minute())

                if let cal = workout.energyBurnedKilocalories, cal > 0 {
                    Text("•")
                    Text("\(Int(cal.rounded())) cal")
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(12)
        .frame(minWidth: 120, alignment: .leading)
        .background(tintColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func activityName(for workout: WorkoutEntry) -> String {
        (HKWorkoutActivityType(rawValue: workout.activityTypeRawValue) ?? .other).displayName
    }

    private func activitySymbol(for workout: WorkoutEntry) -> String {
        (HKWorkoutActivityType(rawValue: workout.activityTypeRawValue) ?? .other).symbolName
    }

    private var totalDurationText: String {
        workoutDurationText(totalDuration)
    }

    private func workoutDurationText(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: duration) ?? "\(Int(duration / 60)) min"
    }
}

struct SleepSummaryCard: View {
    let sleepEntries: [SleepEntry]
    let tintColor: Color

    private var totalDuration: TimeInterval {
        sleepEntries.reduce(0) { $0 + $1.duration }
    }

    private var sortedEntries: [SleepEntry] {
        sleepEntries.sorted { $0.startDate < $1.startDate }
    }

    private var timelineBounds: (start: Date, end: Date)? {
        let sorted = sortedEntries
        guard let earliest = sorted.first?.startDate,
              let latest = sorted.last?.endDate else { return nil }
        return (earliest, latest)
    }

    private var hasStageData: Bool {
        sleepEntries.contains { $0.stage != .unspecified }
    }

    private var visibleStages: [SleepStage] {
        let present = Set(sleepEntries.map(\.stage))
        return [.deep, .core, .rem, .unspecified].filter { present.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Sleep", systemImage: "bed.double.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                if !sleepEntries.isEmpty {
                    Text(totalDurationText)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            if sleepEntries.isEmpty {
                Text("No data")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else if let bounds = timelineBounds {
                sleepTimeline(bounds: bounds)

                if hasStageData {
                    stageLegend
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button { } label: {
                Label("From Apple Health", systemImage: "info.circle")
            }
        }
    }

    private func sleepTimeline(bounds: (start: Date, end: Date)) -> some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let totalSpan = bounds.end.timeIntervalSince(bounds.start)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tintColor.opacity(0.08))

                    ForEach(sortedEntries, id: \.persistentModelID) { entry in
                        let startFraction = totalSpan > 0
                            ? entry.startDate.timeIntervalSince(bounds.start) / totalSpan
                            : 0
                        let widthFraction = totalSpan > 0
                            ? entry.endDate.timeIntervalSince(entry.startDate) / totalSpan
                            : 1

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(stageColor(entry.stage))
                            .frame(width: max(widthFraction * proxy.size.width, 4))
                            .offset(x: startFraction * proxy.size.width)
                    }
                }
            }
            .frame(height: 28)

            HStack {
                Text(bounds.start, format: .dateTime.hour().minute())
                Spacer()
                Text(bounds.end, format: .dateTime.hour().minute())
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private var stageLegend: some View {
        HStack(spacing: 12) {
            ForEach(visibleStages, id: \.self) { stage in
                HStack(spacing: 4) {
                    Circle()
                        .fill(stageColor(stage))
                        .frame(width: 8, height: 8)

                    Text(stageName(stage))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .deep:
            return tintColor.opacity(0.85)
        case .core:
            return tintColor.opacity(0.50)
        case .rem:
            return tintColor.opacity(0.35)
        case .unspecified:
            return tintColor.opacity(0.55)
        }
    }

    private func stageName(_ stage: SleepStage) -> String {
        switch stage {
        case .deep: return "Deep"
        case .core: return "Core"
        case .rem: return "REM"
        case .unspecified: return "Sleep"
        }
    }

    private var totalDurationText: String {
        let totalMinutes = max(Int(totalDuration / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running:
            return "Run"
        case .walking:
            return "Walk"
        case .cycling:
            return "Cycling"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .functionalStrengthTraining:
            return "Functional Strength"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .hiking:
            return "Hike"
        case .swimming:
            return "Swim"
        case .yoga:
            return "Yoga"
        case .mixedCardio:
            return "Cardio"
        case .cooldown:
            return "Cooldown"
        case .other:
            return "Workout"
        default:
            return "Workout"
        }
    }

    var symbolName: String {
        switch self {
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .cycling:
            return "figure.outdoor.cycle"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "figure.strengthtraining.traditional"
        case .highIntensityIntervalTraining:
            return "figure.highintensity.intervaltraining"
        case .hiking:
            return "figure.hiking"
        case .swimming:
            return "figure.pool.swim"
        case .yoga:
            return "figure.yoga"
        case .mixedCardio:
            return "figure.mixed.cardio"
        case .cooldown:
            return "figure.cooldown"
        default:
            return "figure.mixed.cardio"
        }
    }
}

#Preview("Workout Card – Multiple") {
    let now = Calendar.current.startOfDay(for: Date())
    let workouts: [WorkoutEntry] = [
        WorkoutEntry(
            timestamp: now.addingTimeInterval(6 * 3600),
            activityTypeRawValue: HKWorkoutActivityType.running.rawValue,
            duration: 35 * 60,
            energyBurnedKilocalories: 320,
            distanceMiles: 3.2
        ),
        WorkoutEntry(
            timestamp: now.addingTimeInterval(8 * 3600),
            activityTypeRawValue: HKWorkoutActivityType.traditionalStrengthTraining.rawValue,
            duration: 55 * 60,
            energyBurnedKilocalories: 210
        ),
        WorkoutEntry(
            timestamp: now.addingTimeInterval(17.5 * 3600),
            activityTypeRawValue: HKWorkoutActivityType.yoga.rawValue,
            duration: 30 * 60,
            energyBurnedKilocalories: 95
        ),
    ]

    WorkoutSummaryCard(workouts: workouts, tintColor: .blue)
        .padding(16)
        .glassEffect(
            .regular.tint(Color.blue.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .padding()
}

struct LogDayCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var allEntries: [WeightEntry]
    @Query(sort: \DailyActivitySummary.date, order: .reverse) private var allDailyActivitySummaries: [DailyActivitySummary]
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0

    private var dailyActivitySummary: DailyActivitySummary? {
        allDailyActivitySummaries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    let date: Date
    let title: String
    let suggestedWeight: Double?
    let tintColor: Color
    let onDismiss: () -> Void

    @State private var weightText: String
    @State private var timestamp: Date
    @State private var note = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var selectedPhotoIndex = 0
    @State private var isPhotoCarouselPresented = false

    init(
        date: Date,
        title: String,
        suggestedWeight: Double?,
        tintColor: Color,
        onDismiss: @escaping () -> Void
    ) {
        self.date = date
        self.title = title
        self.suggestedWeight = suggestedWeight
        self.tintColor = tintColor
        self.onDismiss = onDismiss
        _weightText = State(initialValue: suggestedWeight.map { String(format: "%.1f", $0) } ?? "")
        _timestamp = State(initialValue: date)
    }

    private var canSave: Bool {
        WeightCalculations.parseWeight(from: weightText) != nil
            && JournalView.isLoggableDay(timestamp)
    }

    var body: some View {
        NavigationStack {
            List {
                if dailyActivitySummary != nil {
                    Section {
                        createStatsRow
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    createPhotoSection

                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)

                    DatePicker(
                        "Time",
                        selection: $timestamp,
                        in: date...endOfDay(for: date),
                        displayedComponents: [.hourAndMinute]
                    )

                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("New Log")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.height(280), .medium])
            .liquidGlassSheetPresentation()
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    let newPhotoData = await loadPhotoData(from: newItems)
                    await MainActor.run {
                        photoData.append(contentsOf: newPhotoData)
                        selectedPhotoItems = []
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismissSheet()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $isPhotoCarouselPresented) {
                LogPhotoCarouselView(
                    photos: photos,
                    initialIndex: selectedPhotoIndex,
                    canEditCurrentPhoto: false,
                    onEditCurrentPhoto: { _ in },
                    tintColor: tintColor,
                    date: date
                )
            }
        }
    }

    private func saveEntry() {
        guard let weight = WeightCalculations.parseWeight(from: weightText) else {
            return
        }
        guard JournalView.isLoggableDay(timestamp) else {
            return
        }

        let goal = WeightGoal(rawValue: weightGoal) ?? .defaultValue
        let isFirstEverLog = allEntries.isEmpty
        let previousLongestStreak = WeightCalculations.longestStreak(from: allEntries)
        let reachedGoal = GoalProgressFeedback.didReachGoal(
            goal: goal,
            newWeight: weight,
            cutTarget: cutTargetWeight,
            bulkTarget: bulkTargetWeight
        )
        let movedCloserToGoal = GoalProgressFeedback.isCloserToGoal(
            goal: goal,
            previousWeight: allEntries.first?.weight,
            newWeight: weight,
            cutTarget: cutTargetWeight,
            bulkTarget: bulkTargetWeight
        )
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let streak = WeightCalculations.currentStreak(from: allEntries, includingToday: true)
        let entry = WeightEntry(
            weight: weight,
            timestamp: timestamp,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            streakCount: streak
        )
        entry.photosData = photoData

        modelContext.insert(entry)

        do {
            try modelContext.save()
            WeightWidgetSnapshotStore.refresh(using: [entry] + allEntries)
            notificationManager.rescheduleReminders()
        } catch {
            return
        }

        Task {
            let uuid = await healthManager.saveWeight(weight, date: timestamp)
            await MainActor.run {
                entry.healthKitUUID = uuid
                try? modelContext.save()
            }
        }

        Haptics.success()
        let isNewMaxStreak = streak > 1 && streak > previousLongestStreak
        if isFirstEverLog {
            NotificationCenter.default.post(name: .didLogFirstWeight, object: nil)
        } else if reachedGoal {
            NotificationCenter.default.post(
                name: .didReachWeightGoal,
                object: GoalReachedPayload(goal: goal, weight: weight)
            )
        } else if movedCloserToGoal {
            let distanceCloser = GoalProgressFeedback.distanceCloserToGoal(
                goal: goal,
                previousWeight: allEntries.first?.weight,
                newWeight: weight,
                cutTarget: cutTargetWeight,
                bulkTarget: bulkTargetWeight
            ) ?? 0
            let miniGoals = MiniGoalStore.load(for: goal)
            let achievedMiniGoal = GoalProgressFeedback.achievedMiniGoal(
                goal: goal,
                previousWeight: allEntries.first?.weight,
                newWeight: weight,
                miniGoals: miniGoals
            )
            NotificationCenter.default.post(
                name: .didMoveCloserToGoal,
                object: CloserToGoalPayload(distanceCloser: distanceCloser, achievedMiniGoal: achievedMiniGoal)
            )
        }
        if isNewMaxStreak {
            NotificationCenter.default.post(name: .didSetNewMaxStreak, object: streak)
        }
        dismissSheet()
    }

    private func dismissSheet() {
        dismiss()
        onDismiss()
    }

    @ViewBuilder
    private var createStatsRow: some View {
        let summary = dailyActivitySummary
        HStack(spacing: 16) {
            if let summary, summary.stepCount > 0 {
                Label {
                    Text(summary.stepCount.formatted())
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "shoeprints.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            if let summary, summary.activeEnergyBurnedKilocalories > 0 {
                Label {
                    Text("\(Int(summary.activeEnergyBurnedKilocalories.rounded())) cal")
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var createPhotoSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                createAddPhotosButton

                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            selectedPhotoIndex = index
                            isPhotoCarouselPresented = true
                        } label: {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 92, height: 118)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            photoData.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.7))
                        }
                        .padding(8)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var photos: [UIImage] {
        photoData.compactMap(UIImage.init(data:))
    }

    private var createAddPhotosButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: nil,
            matching: .images
        ) {
            VStack(spacing: 10) {
                Image(systemName: "photo.badge.plus")
                    .font(.title2.weight(.semibold))
                Text("Add")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tintColor)
            .frame(width: 92, height: 118)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tintColor.opacity(0.10))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tintColor.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadPhotoData(from items: [PhotosPickerItem]) async -> [Data] {
        var loadedData: [Data] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loadedData.append(data)
            }
        }

        return loadedData
    }

    private func endOfDay(for date: Date) -> Date {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        return nextDay.addingTimeInterval(-1)
    }
}

fileprivate struct MonthSectionView: View {
    let monthStart: Date
    let title: String
    let renderData: JournalView.MonthRenderData
    let tintColor: Color
    let calendar: Calendar
    let dayRowSpacing: CGFloat
    let dayColumnSpacing: CGFloat
    let dayCardCornerRadius: CGFloat
    let weekdaySymbols: [String]
    let secondaryTextColor: Color
    let cardColor: Color

    @Binding var suppressNextDayTap: Bool
    @Binding var pressedPreviewDay: Date?
    @Binding var logDate: Date?
    @Binding var showLog: Bool
    @Binding var presentedSheet: JournalView.PresentedDaySheet?
    let thumbnailLoader: JournalView.LazyThumbnailLoader
    let pendingThumbnails: [String: JournalView.PendingThumbnail]
    let presentDayPreview: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            weekdayHeader

            LazyVStack(spacing: dayRowSpacing) {
                ForEach(Array(renderData.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: dayColumnSpacing) {
                        ForEach(week, id: \.self) { date in
                            dayCell(
                                for: date,
                                in: monthStart,
                                dayData: renderData.dayDataByDate[calendar.startOfDay(for: date)]
                            )
                            .id(calendar.startOfDay(for: date))
                        }
                    }
                }
            }
            .frame(height: calendarGridHeight(weekCount: renderData.weeks.count))
        }
    }

    private func calendarGridHeight(weekCount: Int) -> CGFloat {
        CGFloat(weekCount) * 64 + CGFloat(max(weekCount - 1, 0)) * dayRowSpacing
    }

    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func dayCell(for date: Date, in monthStart: Date, dayData: JournalView.DayData?) -> some View {
        let workoutCount = dayData?.workoutCount ?? 0
        let isCurrentMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        let isLoggableDay = JournalView.isLoggableDay(date, calendar: calendar)
        let isLogged = dayData?.isLogged ?? false
        let hasWorkouts = workoutCount > 0
        let hasSleep = (dayData?.sleepCount ?? 0) > 0
        let photoCacheKey = dayData?.photoCacheKey
        let primaryPhoto = photoCacheKey.flatMap { thumbnailLoader.thumbnails[$0] }
        let hasVisiblePhoto = primaryPhoto != nil
        let streakDay = dayData?.streakDay ?? 0
        let isStreakPotential = dayData?.isStreakPotential ?? false

        if !isCurrentMonth {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .allowsHitTesting(false)
        } else {
            Button {
                if suppressNextDayTap {
                    suppressNextDayTap = false
                    return
                }

                Haptics.selection()
                let day = calendar.startOfDay(for: date)
                if JournalView.shouldPresentCreateSheet(hasLoggedWeight: isLogged, hasWorkouts: hasWorkouts || hasSleep) {
                    logDate = day
                    showLog = true
                } else {
                    presentedSheet = JournalView.PresentedDaySheet(date: day, kind: .detail)
                }
            } label: {
                ZStack(alignment: .topLeading) {
                    cellBackground(
                        primaryPhoto: primaryPhoto,
                        isLogged: isLogged,
                        isCurrentMonth: isCurrentMonth
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 2) {
                            Text(dayLabel(for: date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(
                                    hasVisiblePhoto
                                        ? Color.white.opacity(isCurrentMonth ? 0.98 : 0.72)
                                        : dayNumberColor(isCurrentMonth: isCurrentMonth)
                                )
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }

                        Spacer(minLength: 0)

                        if let weightText = dayData?.weightText {
                            HStack {
                                Spacer(minLength: 0)

                                Text(weightText)
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        hasVisiblePhoto
                                            ? .white.opacity(0.92)
                                            : (isLogged ? tintColor.opacity(0.82) : .primary.opacity(0.82))
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .shadow(
                                        color: hasVisiblePhoto ? .black.opacity(0.6) : .clear,
                                        radius: hasVisiblePhoto ? 3 : 0,
                                        x: 0,
                                        y: 1
                                    )

                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous)
                        .strokeBorder(
                            dayOutlineColor(isToday: isToday, isCurrentMonth: isCurrentMonth),
                            lineWidth: dayOutlineWidth(isToday: isToday)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if streakDay >= 1 && !isStreakPotential {
                        ZStack {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.orange)
                                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)

                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                                .offset(y: 2)

                            Text("\(streakDay)")
                                .font(.system(size: 7.5, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .offset(y: 2.2)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        .fixedSize()
                        .offset(x: 5, y: -5)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .scaleEffect(pressedPreviewDay == calendar.startOfDay(for: date) ? 0.96 : 1)
            .animation(.snappy(duration: 0.16), value: pressedPreviewDay)
            .onLongPressGesture(
                minimumDuration: 0.38,
                maximumDistance: 12,
                pressing: { isPressing in
                    withAnimation(.snappy(duration: 0.16)) {
                        pressedPreviewDay = isPressing ? calendar.startOfDay(for: date) : nil
                    }
                },
                perform: {
                    presentDayPreview(date)
                }
            )
            .allowsHitTesting(isLoggableDay)
            .onAppear {
                guard let photoCacheKey else { return }
                thumbnailLoader.loadIfNeeded(
                    key: photoCacheKey,
                    pending: pendingThumbnails[photoCacheKey]
                )
            }
        }
    }

    @ViewBuilder
    private func cellBackground(
        primaryPhoto: UIImage?,
        isLogged: Bool,
        isCurrentMonth: Bool
    ) -> some View {
        if let photo = primaryPhoto {
            GeometryReader { geometry in
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .frame(height: 64)
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.54),
                                    Color.black.opacity(0.12),
                                    Color.black.opacity(0.74)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.34)
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 68
                            )
                        )

                    RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous)
                        .fill(Color(.systemBackground).opacity(isCurrentMonth ? 0.10 : 0.16))

                    if isLogged {
                        RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous)
                            .fill(tintColor.opacity(isCurrentMonth ? 0.10 : 0.06))
                    }
                }
            }
        } else if isLogged {
            RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous)
                .fill(tintColor.opacity(isCurrentMonth ? 0.11 : 0.06))
        } else {
            RoundedRectangle(cornerRadius: dayCardCornerRadius, style: .continuous)
                .fill(unloggedBackgroundColor(isCurrentMonth: isCurrentMonth))
        }
    }

    private func unloggedBackgroundColor(isCurrentMonth: Bool) -> Color {
        isCurrentMonth ? cardColor.opacity(0.52) : cardColor.opacity(0.20)
    }

    private func dayNumberColor(isCurrentMonth: Bool) -> Color {
        return isCurrentMonth ? .primary : .secondary.opacity(0.45)
    }

    private func dayLabel(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    private func dayOutlineColor(isToday: Bool, isCurrentMonth: Bool) -> Color {
        if isToday {
            return tintColor
        }

        return Color.secondary.opacity(isCurrentMonth ? 0.14 : 0.08)
    }

    private func dayOutlineWidth(isToday: Bool) -> CGFloat {
        if isToday {
            return 2
        }

        return 1
    }
}
