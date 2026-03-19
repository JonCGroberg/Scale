//
//  LogView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import Charts
import UIKit
import PhotosUI

struct LogView: View {
    private enum HeatmapLayout {
        static let cellSize: CGFloat = 10
        static let cellSpacing: CGFloat = 4
        static let weekdayColumnWidth: CGFloat = 16
        static let rowHeight: CGFloat = cellSize * 7 + cellSpacing * 6

        static var columnWidth: CGFloat {
            cellSize + cellSpacing
        }

        static var monthLeadingInset: CGFloat {
            weekdayColumnWidth + 8
        }
    }

    private enum HistoryWidget: String, CaseIterable, Identifiable {
        case overview
        case trend
        case consistency
        case logs

        static let defaultLayout: [HistoryWidget] = [.consistency, .trend, .logs]

        static var defaultStorageValue: String {
            defaultLayout.map(\.rawValue).joined(separator: ",")
        }

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview:
                "Overview"
            case .trend:
                "Trend"
            case .consistency:
                "Consistency"
            case .logs:
                "Logs"
            }
        }

        var subtitle: String {
            switch self {
            case .overview:
                "Latest weight, streak, and total logs"
            case .trend:
                "Chart and period controls"
            case .consistency:
                "Heatmap and active-day streaks"
            case .logs:
                "Your month-grouped weight history"
            }
        }

        var systemImage: String {
            switch self {
            case .overview:
                "square.grid.2x2.fill"
            case .trend:
                "chart.xyaxis.line"
            case .consistency:
                "calendar"
            case .logs:
                "list.bullet.rectangle"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("showChangePill") private var showChangePill = true
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("historyWidgetLayout") private var historyWidgetLayout = HistoryWidget.defaultStorageValue

    @State private var isScrolling = false
    @State private var visibleSection = ""
    @State private var hideYearTask: Task<Void, Never>?
    @State private var chartPeriod: TimePeriod = .threeMonths
    @State private var historyWidgets = HistoryWidget.defaultLayout
    @State private var isCustomizeHistoryPresented = false
    @State private var managedPhotoEntry: WeightEntry?

    private var snapshot: WeightCalculations.LogSnapshot {
        WeightCalculations.logSnapshot(from: entries, chartPeriod: chartPeriod)
    }

    private var heatmap: WeightCalculations.HeatmapSnapshot {
        WeightCalculations.heatmapSnapshot(from: entries)
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var activeHeatmapDays: Int {
        heatmap.weeks
            .flatMap(\.self)
            .filter { $0.entryCount > 0 }
            .count
    }

    private var currentLoggingStreak: Int {
        WeightCalculations.currentStreak(from: entries)
    }

    private var latestWeightText: String {
        guard let latest = entries.first else { return "--" }
        return String(format: "%.1f lbs", latest.weight)
    }

    private var hiddenHistoryWidgets: [HistoryWidget] {
        HistoryWidget.allCases.filter { !historyWidgets.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        List {
                            historyContent
                        }
                        .listStyle(.insetGrouped)
                        .contentMargins(.top, 32)
                        .contentMargins(.horizontal, 24)
                        .scrollContentBackground(.hidden)
                        .onScrollPhaseChange { _, newPhase in
                            switch newPhase {
                            case .idle:
                                hideYearTask?.cancel()
                                hideYearTask = Task {
                                    try? await Task.sleep(for: .seconds(0.8))
                                    guard !Task.isCancelled else { return }
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        isScrolling = false
                                    }
                                }
                            default:
                                hideYearTask?.cancel()
                                if !isScrolling {
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        isScrolling = true
                                    }
                                }
                            }
                        }
                    }

                    // Floating month overlay
                    if isScrolling && !visibleSection.isEmpty {
                        VStack {
                            Text(visibleSection)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                Group {
                    if !entries.isEmpty {
                        ZStack {
                            if showChangePill {
                                ChangeBadge(entries: entries)
                            }
                            
                            HStack {
                                Spacer(minLength: 0)
                                
                                Button {
                                    isCustomizeHistoryPresented = true
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
            }
            .sheet(isPresented: $isCustomizeHistoryPresented) {
                historyCustomizationSheet
            }
            .sheet(item: $managedPhotoEntry) { entry in
                PhotoManagementSheet(entry: entry) {
                    managedPhotoEntry = nil
                }
            }
            .task {
                loadHistoryWidgets()
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if historyWidgets.isEmpty {
            Section {
                ContentUnavailableView {
                    Label("No History Widgets", systemImage: "square.grid.2x2")
                } description: {
                    Text("Add widgets back to build the History page you want.")
                } actions: {
                    Button("Customize History") {
                        isCustomizeHistoryPresented = true
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        } else {
            ForEach(historyWidgets) { widget in
                historyWidgetContent(widget)
            }
        }
    }

    @ViewBuilder
    private func historyWidgetContent(_ widget: HistoryWidget) -> some View {
        switch widget {
        case .overview:
            Section {
                overviewWidget
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        case .trend:
            Section {
                weightChart
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        case .consistency:
            Section {
                contributionCalendar
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        case .logs:
            logSections
        }
    }

    @ViewBuilder
    private var logSections: some View {
        ForEach(snapshot.groupedEntries, id: \.key) { month, monthEntries in
            Section {
                ForEach(monthEntries) { entry in
                    logRow(entry: entry, streak: streakForEntry(entry))
                        .deleteDisabled(entry.source == .appleHealth)
                }
                .onDelete { offsets in
                    deleteEntries(monthEntries, at: offsets)
                }
            } header: {
                Text(month.uppercased())
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .global).minY
                    } action: { minY in
                        if minY < 160, visibleSection != month {
                            visibleSection = month
                        }
                    }
            }
        }
        .listSectionSpacing(0)
    }

    private var overviewWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Overview")
                    .font(.headline)

                Spacer()

                Text("\(entries.count) Logs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                statChip(title: "Latest", value: latestWeightText)
                statChip(title: "Total Entries", value: "\(entries.count)")
            }

            HStack(alignment: .center, spacing: 10) {
                currentStreakPill
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var weightChart: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Trend")
                        .font(.headline)

                    Spacer()

                    Text(chartPeriod.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("See how your weight has changed over the selected period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                statChip(title: "Current", value: latestWeightText)
                statChip(title: "Data Points", value: "\(snapshot.chart.entries.count)")
            }

            Picker("Period", selection: $chartPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if snapshot.chart.entries.count >= 2 {
                Chart(snapshot.chart.entries) { entry in
                    LineMark(
                        x: .value("Date", entry.timestamp),
                        y: .value("Weight", entry.weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tintColor)

                    AreaMark(
                        x: .value("Date", entry.timestamp),
                        yStart: .value("Min", snapshot.chart.yDomain.lowerBound),
                        yEnd: .value("Weight", entry.weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [tintColor.opacity(0.25), tintColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: snapshot.chart.yDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
            } else {
                Text("Not enough data for this period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var contributionCalendar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Consistency")
                        .font(.headline)

                    Spacer()

                    Text("Last 26 weeks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("A quick view of how regularly you’ve logged your weight.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if heatmap.weeks.isEmpty {
                Text("No activity yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center, spacing: 10) {
                    statChip(title: "Active Days", value: "\(activeHeatmapDays)")
                    currentStreakPill
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        monthLabels
                        HStack(alignment: .top, spacing: 8) {
                            weekdayLabels
                            heatmapGrid
                        }
                    }
                    .padding(.trailing, HeatmapLayout.cellSpacing)
                    .scrollTargetLayout()
                }
                .defaultScrollAnchor(.trailing, for: .initialOffset)
                .scrollTargetBehavior(.viewAligned)

                HStack(spacing: 8) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: HeatmapLayout.cellSpacing) {
                        ForEach(0..<5, id: \.self) { intensity in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: intensity))
                                .frame(width: HeatmapLayout.cellSize, height: HeatmapLayout.cellSize)
                        }
                    }

                    Text("More")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Entries Yet", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Log your first weight entry to start tracking your progress.")
        }
    }

    // MARK: - Streak Helpers

    private func streakForEntry(_ entry: WeightEntry) -> Int {
        let day = Calendar.current.startOfDay(for: entry.timestamp)
        return snapshot.streaksByDay[day] ?? 0
    }

    // MARK: - Log Row

    private func logRow(entry: WeightEntry, streak: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(streak)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.12), in: Capsule())
                    }
                }

                Text(entry.timestamp, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    if entry.source == .appleHealth {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(tintColor)
                        Text("Apple Health")
                    } else {
                        Image(systemName: "pencil.line")
                            .foregroundStyle(.secondary)
                        Text("Manual")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                managedPhotoEntry = entry
            } label: {
                if entry.photosData.isEmpty {
                    Image(systemName: "camera.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .frame(width: 52, height: 52)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if let uiImage = UIImage(data: entry.photosData[0]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            if entry.photosData.count > 1 {
                                Text("+\(entry.photosData.count - 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.6), in: Capsule())
                                    .padding(4)
                            } else {
                                Image(systemName: "photo.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(.black.opacity(0.55), in: Circle())
                                    .padding(4)
                            }
                        }
                }
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", entry.weight))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(tintColor)

                Text("lbs")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(tintColor.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
    }


    private var monthLabels: some View {
        HStack(alignment: .center, spacing: HeatmapLayout.cellSpacing) {
            ForEach(Array(heatmap.monthLabels.enumerated()), id: \.offset) { index, label in
                let nextWeekIndex = index + 1 < heatmap.monthLabels.count ? heatmap.monthLabels[index + 1].weekIndex : heatmap.weeks.count
                let span = max(nextWeekIndex - label.weekIndex, 1)

                Text(label.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: CGFloat(span) * HeatmapLayout.columnWidth - HeatmapLayout.cellSpacing, alignment: .leading)
            }
        }
        .padding(.leading, HeatmapLayout.monthLeadingInset)
    }

    private var weekdayLabels: some View {
        VStack(spacing: HeatmapLayout.cellSpacing) {
            weekdayLabel("M")
            weekdayLabel("")
            weekdayLabel("W")
            weekdayLabel("")
            weekdayLabel("F")
            weekdayLabel("")
            weekdayLabel("")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(width: HeatmapLayout.weekdayColumnWidth, height: HeatmapLayout.rowHeight)
    }

    private var heatmapGrid: some View {
        HStack(alignment: .top, spacing: HeatmapLayout.cellSpacing) {
            ForEach(Array(heatmap.weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: HeatmapLayout.cellSpacing) {
                    ForEach(week, id: \.date) { day in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(for: day))
                            .frame(width: HeatmapLayout.cellSize, height: HeatmapLayout.cellSize)
                            .overlay {
                                if Calendar.current.isDateInToday(day.date) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(tintColor.opacity(0.9), lineWidth: 1)
                                }
                            }
                            .accessibilityElement()
                            .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day().year()))
                            .accessibilityValue(day.entryCount == 0 ? "No entries" : "\(day.entryCount) entries")
                    }
                }
            }
        }
    }

    private func color(for day: WeightCalculations.HeatmapDay) -> Color {
        color(for: day.intensity)
    }

    private func color(for intensity: Int) -> Color {
        switch intensity {
        case 0:
            return Color.secondary.opacity(0.12)
        case 1:
            return tintColor.opacity(0.28)
        case 2:
            return tintColor.opacity(0.45)
        case 3:
            return tintColor.opacity(0.65)
        default:
            return tintColor.opacity(0.9)
        }
    }

    private func statChip(
        title: String,
        value: String,
        valueColor: Color = .primary,
        backgroundColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            (backgroundColor ?? tintColor.opacity(0.08)),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var currentStreakPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            Text("\(currentLoggingStreak)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.orange)

            Text("Current Streak")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.orange.opacity(0.12), in: Capsule())
    }

    private var historyCustomizationSheet: some View {
        NavigationStack {
            List {
                visibleHistoryWidgetSection

                if !hiddenHistoryWidgets.isEmpty {
                    hiddenHistoryWidgetSection
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isCustomizeHistoryPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var visibleHistoryWidgetSection: some View {
        Section {
            ForEach(Array(historyWidgets.enumerated()), id: \.element.id) { _, widget in
                visibleHistoryWidgetRow(widget)
            }
            .onMove(perform: moveHistoryWidgets)
        } header: {
            Text("Visible Widgets")
        } footer: {
            Text("Drag to reorder the History page.")
        }
    }

    private var hiddenHistoryWidgetSection: some View {
        Section("Add Widgets") {
            ForEach(Array(hiddenHistoryWidgets.enumerated()), id: \.element.id) { _, widget in
                hiddenHistoryWidgetRow(widget)
            }
        }
    }

    private func visibleHistoryWidgetRow(_ widget: HistoryWidget) -> some View {
        HStack(spacing: 12) {
            Label(widget.title, systemImage: widget.systemImage)
            Spacer()
            Button("Hide") {
                removeHistoryWidget(widget)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderless)
            .disabled(historyWidgets.count == 1)
            .foregroundStyle(historyWidgets.count == 1 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.red))
        }
    }

    private func hiddenHistoryWidgetRow(_ widget: HistoryWidget) -> some View {
        Button {
            addHistoryWidget(widget)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Label(widget.title, systemImage: widget.systemImage)
                Text(widget.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadHistoryWidgets() {
        historyWidgets = decodeHistoryWidgets(from: historyWidgetLayout)
    }

    private func moveHistoryWidgets(from source: IndexSet, to destination: Int) {
        historyWidgets.move(fromOffsets: source, toOffset: destination)
        saveHistoryWidgets()
    }

    private func addHistoryWidget(_ widget: HistoryWidget) {
        guard !historyWidgets.contains(widget) else { return }
        historyWidgets.append(widget)
        saveHistoryWidgets()
    }

    private func removeHistoryWidget(_ widget: HistoryWidget) {
        guard historyWidgets.count > 1 else { return }
        historyWidgets.removeAll { $0 == widget }
        saveHistoryWidgets()
    }

    private func saveHistoryWidgets() {
        historyWidgetLayout = historyWidgets.map(\.rawValue).joined(separator: ",")
    }

    private func decodeHistoryWidgets(from storage: String) -> [HistoryWidget] {
        if storage.isEmpty {
            return HistoryWidget.defaultLayout
        }

        let orderedWidgets = storage
            .split(separator: ",")
            .compactMap { HistoryWidget(rawValue: String($0)) }

        let deduplicatedWidgets = orderedWidgets.reduce(into: [HistoryWidget]()) { widgets, widget in
            if !widgets.contains(widget) {
                widgets.append(widget)
            }
        }

        if deduplicatedWidgets.isEmpty {
            return HistoryWidget.defaultLayout
        }

        return deduplicatedWidgets
    }

    private func weekdayLabel(_ text: String) -> some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private func deleteEntries(_ sectionEntries: [WeightEntry], at offsets: IndexSet) {
        let deletedEntries = offsets.map { sectionEntries[$0] }

        for index in offsets {
            let entry = sectionEntries[index]
            if let hkUUID = entry.healthKitUUID {
                Task {
                    await healthManager.deleteWeight(sampleUUID: hkUUID)
                }
            }
            modelContext.delete(entry)
        }

        let remainingEntries = entries.filter { candidate in
            !deletedEntries.contains { $0.persistentModelID == candidate.persistentModelID }
        }
        WeightWidgetSnapshotStore.refresh(using: remainingEntries)
    }
}

// MARK: - Photo Management Sheet

private struct PhotoManagementSheet: View {
    @Bindable var entry: WeightEntry
    let onDismiss: () -> Void

    @State private var currentPage = 0
    @State private var isPhotoPickerPresented = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isCameraPresented = false
    @State private var isLoadingPhotos = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if entry.photosData.isEmpty {
                    emptyState
                } else {
                    photoGallery
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    addPhotoMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle(
                entry.photosData.isEmpty
                    ? "Photos"
                    : "\(currentPage + 1) of \(entry.photosData.count)"
            )
            .navigationBarTitleDisplayMode(.inline)
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $photoPickerItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: photoPickerItems) { _, items in
            guard !items.isEmpty else { return }
            isLoadingPhotos = true
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        entry.photosData.append(data)
                    }
                }
                photoPickerItems = []
                isLoadingPhotos = false
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            ProgressPhotoCameraView { image in
                isCameraPresented = false
                guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                entry.photosData.append(data)
            }
            .ignoresSafeArea()
        }
    }

    private var photoGallery: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(entry.photosData.enumerated()), id: \.offset) { index, data in
                ZStack(alignment: .topTrailing) {
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    }

                    Button {
                        withAnimation {
                            entry.photosData.remove(at: index)
                            if currentPage >= entry.photosData.count && currentPage > 0 {
                                currentPage = entry.photosData.count - 1
                            }
                        }
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .padding(16)
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Photos", systemImage: "photo.on.rectangle.angled")
                .foregroundStyle(.white)
        } description: {
            Text("Attach progress photos to this entry.")
                .foregroundStyle(.secondary)
        } actions: {
            addPhotoMenu
        }
    }

    private var addPhotoMenu: some View {
        Menu {
            Button {
                isCameraPresented = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            if isLoadingPhotos {
                ProgressView()
            } else {
                Label("Add Photo", systemImage: "plus")
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: WeightEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let calendar = Calendar.current
    let now = Date()
    let sampleWeights: [(Int, Double)] = [
        (0, 185.2), (1, 184.8), (2, 185.0), (3, 184.5),
        (4, 184.3), (7, 183.9), (8, 183.5), (14, 184.1),
        (30, 182.8), (60, 182.2), (90, 181.5), (120, 181.0),
        (150, 180.5), (180, 180.0), (210, 179.5), (240, 179.0),
        (300, 178.5), (365, 178.0)
    ]
    for (daysAgo, weight) in sampleWeights {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let entry = WeightEntry(weight: weight, timestamp: date)
        context.insert(entry)
    }

    return LogView()
        .modelContainer(container)
        .environment(HealthKitManager())
}
