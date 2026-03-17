//
//  LogView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import Charts

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("showChangePill") private var showChangePill = true

    @State private var isScrolling = false
    @State private var visibleSection = ""
    @State private var hideYearTask: Task<Void, Never>?
    @State private var chartPeriod: TimePeriod = .threeMonths

    /// Streaks computed dynamically from all entries.
    private var streaksByDay: [Date: Int] {
        WeightCalculations.streaksByDay(from: entries)
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
                            Section {
                                weightChart
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)

                            ForEach(groupedEntries, id: \.key) { month, monthEntries in
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
                                            if minY < 160 {
                                                visibleSection = month
                                            }
                                        }
                                }
                            }
                            .listSectionSpacing(0)
                        }
                        .listStyle(.insetGrouped)
                        .contentMargins(.top, 16)
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
                if showChangePill, !entries.isEmpty {
                    ChangeBadge(entries: entries)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 0)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Chart

    private var chartEntries: [WeightEntry] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(
            byAdding: chartPeriod.calendarComponent,
            value: -chartPeriod.componentValue,
            to: Date()
        ) else { return [] }

        return entries
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var weightChart: some View {
        VStack(spacing: 12) {
            Picker("Period", selection: $chartPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if chartEntries.count >= 2 {
                Chart(chartEntries) { entry in
                    LineMark(
                        x: .value("Date", entry.timestamp),
                        y: .value("Weight", entry.weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.accent)

                    AreaMark(
                        x: .value("Date", entry.timestamp),
                        yStart: .value("Min", chartYDomain.lowerBound),
                        yEnd: .value("Weight", entry.weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.accent.opacity(0.25), .accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: chartYDomain)
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
        .padding(16)
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartEntries.map(\.weight)
        let minW = (weights.min() ?? 0) - 1
        let maxW = (weights.max() ?? 0) + 1
        return minW...maxW
    }

    // MARK: - Data

    private var groupedEntries: [(key: String, value: [WeightEntry])] {
        WeightCalculations.groupedByMonth(entries)
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
        return streaksByDay[day] ?? 0
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
                            .foregroundStyle(.pink)
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

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", entry.weight))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.accent)

                Text("lbs")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteEntries(_ sectionEntries: [WeightEntry], at offsets: IndexSet) {
        for index in offsets {
            let entry = sectionEntries[index]
            if let hkUUID = entry.healthKitUUID {
                Task {
                    await healthManager.deleteWeight(sampleUUID: hkUUID)
                }
            }
            modelContext.delete(entry)
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
