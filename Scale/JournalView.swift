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

struct JournalView: View {
    private final class PhotoThumbnailCache {
        static let shared = PhotoThumbnailCache()

        private let cache = NSCache<NSString, UIImage>()
        private let imageRendererFormat: UIGraphicsImageRendererFormat

        private init() {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            self.imageRendererFormat = format
            cache.countLimit = 256
        }

        func image(forKey key: String) -> UIImage? {
            cache.object(forKey: key as NSString)
        }

        func setImage(_ image: UIImage, forKey key: String) {
            cache.setObject(image, forKey: key as NSString)
        }

        func thumbnail(from data: Data, key: String, maxPixelSize: CGFloat = 160) -> UIImage? {
            if let cached = image(forKey: key) {
                return cached
            }

            guard let image = UIImage(data: data) else {
                return nil
            }

            let longestSide = max(image.size.width, image.size.height)
            let scale = min(maxPixelSize / max(longestSide, 1), 1)
            let size = CGSize(
                width: max(image.size.width * scale, 1),
                height: max(image.size.height * scale, 1)
            )
            let renderer = UIGraphicsImageRenderer(size: size, format: imageRendererFormat)
            let thumbnail = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            setImage(thumbnail, forKey: key)
            return thumbnail
        }
    }

    private struct PresentedDaySheet: Identifiable {
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

    private struct DayData {
        let weightText: String?
        let workoutCount: Int
        let primaryPhoto: UIImage?
        /// Position within a consecutive logging streak (0 = isolated day, 1+ = day N of a run).
        let streakDay: Int

        var isLogged: Bool {
            weightText != nil
        }
    }

    private struct MonthRenderData {
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
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue

    let scrollToEntryTrigger: Int
    let focusedEntry: WeightEntry?
    let scrollToBottomTrigger: Int

    @State private var monthLoader = CalendarMonthLoader(batchSize: 3)
    @State private var monthRenderDataByMonth: [Date: MonthRenderData] = [:]
    @State private var entryIDsByDay: [Date: [PersistentIdentifier]] = [:]
    @State private var workoutIDsByDay: [Date: [PersistentIdentifier]] = [:]
    @State private var presentedSheet: PresentedDaySheet?
    @State private var hasFinishedInitialMonthPositioning = false
    @State private var hasPerformedInitialScroll = false

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

    private var journalRenderSignature: [String] {
        var signature = entries.map { entry in
            [
                String(entry.timestamp.timeIntervalSinceReferenceDate),
                String(entry.weight),
                String(entry.photosFingerprint)
            ].joined(separator: "|")
        }
        signature.append(contentsOf: workouts.map { workout in
            String(workout.timestamp.timeIntervalSinceReferenceDate)
        })
        signature.append(contentsOf: dailyActivitySummaries.map { summary in
            [
                String(summary.date.timeIntervalSinceReferenceDate),
                String(summary.stepCount),
                String(summary.activeEnergyBurnedKilocalories)
            ].joined(separator: "|")
        })
        return signature
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
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(monthSections) { section in
                                monthSection(section)
                                    .id(section.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 56)
                        .padding(.bottom, 120)

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
                        loadEarlierMonthsIfNeeded()
                    }
                    .onAppear {
                        ensureInitialMonthsLoaded()
                        rebuildMonthRenderData()
                        if !hasPerformedInitialScroll {
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
                    .onChange(of: journalRenderSignature) { _, _ in
                        rebuildMonthRenderData()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $presentedSheet) { presentedSheet in
                switch presentedSheet.kind {
                case .detail:
                    LogDayDetailSheet(
                        title: dayTitleFormatter.string(from: presentedSheet.date),
                        entryIDs: entryIDs(for: presentedSheet.date),
                        workoutIDs: workoutIDs(for: presentedSheet.date),
                        dailyActivityDate: calendar.startOfDay(for: presentedSheet.date),
                        tintColor: tintColor
                    ) {
                        self.presentedSheet = nil
                    }
                case .create:
                    LogDayCreateSheet(
                        date: presentedSheet.date,
                        title: dayTitleFormatter.string(from: presentedSheet.date),
                        suggestedWeight: entries.first?.weight,
                        tintColor: tintColor
                    ) {
                        self.presentedSheet = nil
                    }
                }
            }
        }
    }

    private func monthSection(_ section: MonthSection) -> some View {
        let renderData = monthRenderDataByMonth[section.monthStart] ?? MonthRenderData(
            weeks: makeWeeks(for: section.monthStart),
            dayDataByDate: [:]
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            weekdayHeader

            VStack(spacing: dayRowSpacing) {
                ForEach(Array(renderData.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: dayColumnSpacing) {
                        ForEach(week, id: \.self) { date in
                            dayCell(
                                for: date,
                                in: section.monthStart,
                                dayData: renderData.dayDataByDate[calendar.startOfDay(for: date)]
                            )
                            .id(dayScrollID(for: date))
                        }
                    }
                }
            }
        }
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
    private func dayCell(for date: Date, in monthStart: Date, dayData: DayData?) -> some View {
        let workoutCount = dayData?.workoutCount ?? 0
        let isCurrentMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        let isLoggableDay = Self.isLoggableDay(date, calendar: calendar)
        let isLogged = dayData?.isLogged ?? false
        let hasWorkouts = workoutCount > 0
        let hasPhoto = dayData?.primaryPhoto != nil
        let streakDay = dayData?.streakDay ?? 0

        if !isCurrentMonth {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .allowsHitTesting(false)
        } else {
            Button {
                Haptics.selection()
                let day = calendar.startOfDay(for: date)
                let kind: PresentedDaySheet.Kind = Self.shouldPresentCreateSheet(
                    hasLoggedWeight: isLogged,
                    hasWorkouts: hasWorkouts
                ) ? .create : .detail
                presentedSheet = PresentedDaySheet(date: day, kind: kind)
            } label: {
                ZStack(alignment: .topLeading) {
                    cellBackground(
                        primaryPhoto: dayData?.primaryPhoto,
                        isLogged: isLogged,
                        isCurrentMonth: isCurrentMonth
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 2) {
                            Text(dayLabel(for: date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(
                                    hasPhoto
                                        ? Color.white.opacity(isCurrentMonth ? 0.98 : 0.72)
                                        : dayNumberColor(isCurrentMonth: isCurrentMonth)
                                )

                            Spacer(minLength: 0)

                            if streakDay >= 2 {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer(minLength: 0)

                        if let weightText = dayData?.weightText {
                            Text(weightText)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(isLogged ? tintColor.opacity(0.98) : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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
            }
            .buttonStyle(.plain)
            .allowsHitTesting(isLoggableDay)
        }
    }

    @ViewBuilder
    private func cellBackground(
        primaryPhoto: UIImage?,
        isLogged: Bool,
        isCurrentMonth: Bool
    ) -> some View {
        if let photo = primaryPhoto {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
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

    private func monthStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func dayScrollID(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func ensureInitialMonthsLoaded() {
        monthLoader.loadInitialMonths()
    }

    private func ensureMonthLoaded(_ month: Date) {
        let currentMonth = monthStart(for: .now)
        let clampedMonth = min(month, currentMonth)

        monthLoader.loadInitialMonths()
        var didChangeLoadedMonths = false

        while let earliest = monthLoader.earliest, clampedMonth < earliest {
            didChangeLoadedMonths = monthLoader.expandIfNeeded(for: earliest) || didChangeLoadedMonths
        }

        if didChangeLoadedMonths {
            rebuildMonthRenderData()
        }
    }

    private func loadEarlierMonthsIfNeeded() {
        guard hasFinishedInitialMonthPositioning else { return }
        guard let earliest = monthLoader.earliest else { return }
        if monthLoader.expandIfNeeded(for: earliest) {
            rebuildMonthRenderData()
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
        dailyActivityByDay: [Date: DailyActivitySummary],
        streaksByDay: [Date: Int]
    ) -> [Date: DayData] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
            return [:]
        }

        let allDays = Set(entriesByDay.keys.filter { monthInterval.contains($0) })
            .union(workoutsByDay.keys.filter { monthInterval.contains($0) })
            .union(dailyActivityByDay.keys.filter { monthInterval.contains($0) })

        return allDays.reduce(into: [:]) { result, day in
            let dayEntries = entriesByDay[day] ?? []
            result[day] = DayData(
                weightText: dayEntries.first.map { String(format: "%.1f", $0.weight) },
                workoutCount: workoutsByDay[day]?.count ?? 0,
                primaryPhoto: primaryPhoto(for: dayEntries),
                streakDay: streaksByDay[day] ?? 0
            )
        }
    }

    private func rebuildMonthRenderData() {
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
        let streaks = WeightCalculations.streaksByDay(from: entries)

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
        monthRenderDataByMonth = Dictionary(uniqueKeysWithValues: monthLoader.monthStarts.map { monthStart in
            (
                monthStart,
                MonthRenderData(
                    weeks: makeWeeks(for: monthStart),
                    dayDataByDate: makeDayDataByDate(
                        for: monthStart,
                        entriesByDay: groupedEntries,
                        workoutsByDay: groupedWorkouts,
                        dailyActivityByDay: groupedDailyActivity,
                        streaksByDay: streaks
                    )
                )
            )
        })
    }

    private func primaryPhoto(for entries: [WeightEntry]) -> UIImage? {
        for entry in entries {
            guard entry.hasPhotos else { continue }

            for (index, photoData) in entry.photosData.enumerated() {
                let cacheKey = "\(entry.persistentModelID)-\(index)-\(entry.photosFingerprint)"
                if let thumbnail = PhotoThumbnailCache.shared.thumbnail(from: photoData, key: cacheKey) {
                    return thumbnail
                }
            }
        }

        return nil
    }
}

#Preview {
    JournalView(scrollToEntryTrigger: 0, focusedEntry: nil, scrollToBottomTrigger: 0)
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
}

private struct LogDayDetailSheet: View {
    private struct PhotoItem {
        let image: UIImage
        let entryID: PersistentIdentifier
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

    let title: String
    let entryIDs: [PersistentIdentifier]
    let workoutIDs: [PersistentIdentifier]
    let dailyActivityDate: Date
    let tintColor: Color
    let onDismiss: () -> Void

    @State private var editingEntryIDs: Set<PersistentIdentifier> = []
    @State private var entryDrafts: [PersistentIdentifier: EntryDraft] = [:]
    @State private var pendingDeletionEntryID: PersistentIdentifier?
    @State private var selectedPhotoIndex = 0
    @State private var isPhotoCarouselPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingDayPhotoEntryID: PersistentIdentifier?

    private var entries: [WeightEntry] {
        let entryIDSet = Set(entryIDs)
        return allEntries.filter { entryIDSet.contains($0.persistentModelID) }
    }

    private var workouts: [WorkoutEntry] {
        let workoutIDSet = Set(workoutIDs)
        return allWorkouts.filter { workoutIDSet.contains($0.persistentModelID) }
    }

    private var dailyActivitySummary: DailyActivitySummary? {
        allDailyActivitySummaries.first { Calendar.current.isDate($0.date, inSameDayAs: dailyActivityDate) }
    }

    private var photoItems: [PhotoItem] {
        entries
            .flatMap { entry in
                entry.photosData.compactMap { data in
                    UIImage(data: data).map { image in
                        PhotoItem(image: image, entryID: entry.persistentModelID)
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

    private var displayedPhotos: [UIImage] {
        if isEditingEntry {
            if let dayPhotoEntry, let draft = entryDrafts[dayPhotoEntry.persistentModelID] {
                draft.photosData.compactMap(UIImage.init(data:))
            } else {
                []
            }
        } else {
            photos
        }
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

    private var logCardWidth: CGFloat {
        280
    }

    private var workoutCardWidth: CGFloat {
        240
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if isEditingEntry || !displayedPhotos.isEmpty {
                        photoStripSection
                    }

                    if let dailyActivitySummary, dailyActivitySummary.stepCount > 0 || dailyActivitySummary.activeEnergyBurnedKilocalories > 0 {
                        dailyActivityHighlights(summary: dailyActivitySummary)
                    }

                    if entries.isEmpty && workouts.isEmpty {
                        Text("No entry logged for this day.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    if !entries.isEmpty {
                        logCarouselSection
                    }

                    if !workouts.isEmpty {
                        workoutSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if isEditingEntry {
                        headerIconButton(
                            systemImage: "xmark",
                            tint: .primary
                        ) {
                            cancelEditing()
                        }

                        headerIconButton(
                            systemImage: "checkmark",
                            tint: .primary,
                            disabled: !canSaveDraft
                        ) {
                            saveChanges()
                        }
                    } else {
                        if let dayPhotoEntry {
                            toolbarPhotoPicker(for: dayPhotoEntry)
                        }

                        if let dayEditEntry {
                            editEntryButton(for: dayEditEntry)
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditingEntry {
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
                    photos: photos,
                    initialIndex: selectedPhotoIndex,
                    canEditCurrentPhoto: !photoItems.isEmpty,
                    onEditCurrentPhoto: editPhotoSourceEntry
                )
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    let newPhotoData = await loadPhotoData(from: newItems)
                    await MainActor.run {
                        if let pendingDayPhotoEntryID {
                            appendPhotos(newPhotoData, toEntryID: pendingDayPhotoEntryID)
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
            Text(entries.count > 1 ? "Logs" : "Log")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 4)

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

    private func logCard(for entry: WeightEntry, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            logSectionHeader(for: entry, index: index)

            if isEditingEntry, entryDrafts[entry.persistentModelID] != nil {
                TextField("Weight", text: draftWeightBinding(for: entry))
                    .keyboardType(.decimalPad)

                DatePicker(
                    "Date",
                    selection: draftDateBinding(for: entry),
                    displayedComponents: [.date]
                )

                DatePicker(
                    "Time",
                    selection: draftTimeBinding(for: entry),
                    displayedComponents: [.hourAndMinute]
                )

                TextField("Note", text: draftNoteBinding(for: entry), axis: .vertical)
                    .lineLimit(2...5)

                LabeledContent("Source") {
                    Text(entry.source == .appleHealth ? "Apple Health" : "Scale")
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", entry.weight))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tintColor)

                    Text("lbs")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(entry.timestamp, format: .dateTime.month(.wide).day().year().hour().minute())
                    .foregroundStyle(.secondary)

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                }

                LabeledContent("Source") {
                    Text(entry.source == .appleHealth ? "Apple Health" : "Scale")
                }
            }
        }
        .padding(18)
        .frame(width: logCardWidth, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workouts")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(workouts, id: \.persistentModelID) { workout in
                        WorkoutSummaryRow(workout: workout)
                            .padding(16)
                            .frame(width: workoutCardWidth, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
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
        cancelEditing()

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

    @ViewBuilder
    private var photoStripSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if isEditingEntry {
                    addPhotosButton
                }

                ForEach(Array(displayedPhotos.enumerated()), id: \.offset) { index, photo in
                    photoStripItem(photo, index: index)
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func photoStripItem(_ photo: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                selectedPhotoIndex = index
                isPhotoCarouselPresented = true
            } label: {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoThumbnailWidth, height: photoThumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: photoThumbnailCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            if isEditingEntry {
                Button {
                    guard let dayPhotoEntry else { return }
                    entryDrafts[dayPhotoEntry.persistentModelID]?.photosData.remove(at: index)
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

    private var addPhotosButton: some View {
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
            .frame(width: photoThumbnailWidth, height: photoThumbnailHeight)
            .background(
                RoundedRectangle(cornerRadius: photoThumbnailCornerRadius, style: .continuous)
                    .fill(tintColor.opacity(0.10))
            )
            .overlay {
                RoundedRectangle(cornerRadius: photoThumbnailCornerRadius, style: .continuous)
                    .strokeBorder(tintColor.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var photoThumbnailWidth: CGFloat {
        isEditingEntry ? 92 : 152
    }

    private var photoThumbnailHeight: CGFloat {
        isEditingEntry ? 118 : 188
    }

    private var photoThumbnailCornerRadius: CGFloat {
        isEditingEntry ? 14 : 16
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
    private func logSectionHeader(for entry: WeightEntry, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(entries.count > 1 ? "Log \(index + 1)" : "Log")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)

            Spacer(minLength: 0)

            if isEditingEntry {
                headerIconButton(
                    systemImage: "trash",
                    tint: .red
                ) {
                    pendingDeletionEntryID = entry.persistentModelID
                }
            } else if entries.count > 1 {
                editEntryButton(for: entry)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
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

    @ViewBuilder
    private func toolbarPhotoPicker(for entry: WeightEntry) -> some View {
        PhotosPicker(
            selection: toolbarPhotoSelectionBinding(for: entry),
            maxSelectionCount: nil,
            matching: .images
        ) {
            Image(systemName: "photo.badge.plus")
                .font(.headline.weight(.semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(tintColor)
        }
        .buttonStyle(.plain)
    }

    private func toolbarPhotoSelectionBinding(for entry: WeightEntry) -> Binding<[PhotosPickerItem]> {
        Binding(
            get: { selectedPhotoItems },
            set: { newItems in
                guard !newItems.isEmpty else {
                    pendingDayPhotoEntryID = nil
                    selectedPhotoItems = []
                    return
                }

                pendingDayPhotoEntryID = entry.persistentModelID
                selectedPhotoItems = newItems
            }
        )
    }

    private func photoSelectionBinding(for entry: WeightEntry) -> Binding<[PhotosPickerItem]> {
        Binding(
            get: { selectedPhotoItems },
            set: { newItems in
                guard !newItems.isEmpty else {
                    selectedPhotoItems = []
                    return
                }

                beginEditing(entry)
                selectedPhotoItems = newItems
            }
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

    private func dailyActivityHighlights(summary: DailyActivitySummary) -> some View {
        HStack(spacing: 12) {
            activityHighlightCard(
                systemImage: "shoeprints.fill",
                title: "Steps",
                value: summary.stepCount.formatted()
            )

            activityHighlightCard(
                systemImage: "flame.fill",
                title: "Active",
                value: "\(Int(summary.activeEnergyBurnedKilocalories.rounded())) cal"
            )
        }
        .padding(.vertical, 4)
    }

    private func activityHighlightCard(systemImage: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .font(.headline.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glassProminent)
            .tint(tint)
            .disabled(disabled)
        } else {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .disabled(disabled)
        }
    }
}

private struct LogPhotoCarouselView: View {
    let photos: [UIImage]
    let initialIndex: Int
    let canEditCurrentPhoto: Bool
    let onEditCurrentPhoto: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        GeometryReader { proxy in
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .background(Color.black)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedIndex = min(max(initialIndex, 0), max(photos.count - 1, 0))
        }
    }
}

private struct WorkoutSummaryRow: View {
    let workout: WorkoutEntry

    private var activityType: HKWorkoutActivityType {
        HKWorkoutActivityType(rawValue: workout.activityTypeRawValue) ?? .other
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(activityType.displayName, systemImage: "figure.run")
                    .font(.headline)

                Spacer(minLength: 12)

                Text(workout.timestamp, format: .dateTime.hour().minute())
                    .foregroundStyle(.secondary)
            }

            Text(durationText)
                .foregroundStyle(.secondary)

            if let metricText {
                Text(metricText)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }

    private var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = workout.duration >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: workout.duration) ?? "\(Int(workout.duration / 60)) min"
    }

    private var metricText: String? {
        var parts: [String] = []

        if let distanceMiles = workout.distanceMiles, distanceMiles > 0 {
            parts.append(String(format: "%.1f mi", distanceMiles))
        }

        if let energyBurnedKilocalories = workout.energyBurnedKilocalories, energyBurnedKilocalories > 0 {
            parts.append("\(Int(energyBurnedKilocalories.rounded())) cal")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
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
}

private struct LogDayCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var allEntries: [WeightEntry]

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
                    onEditCurrentPhoto: { _ in }
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
        dismissSheet()
    }

    private func dismissSheet() {
        dismiss()
        onDismiss()
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
