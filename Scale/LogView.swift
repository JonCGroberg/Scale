//
//  LogView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import Charts

enum ChartRange: String, CaseIterable {
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"

    var calendarComponent: Calendar.Component {
        switch self {
        case .days: return .day
        case .weeks: return .weekOfYear
        case .months: return .month
        }
    }

    var dayCount: Int {
        switch self {
        case .days: return 7
        case .weeks: return 30
        case .months: return 365
        }
    }
}

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("showChangeGraph") private var showChangeGraph = true

    @AppStorage("showChangePill") private var showChangePill = true

    @State private var isScrolling = false
    @State private var visibleSection = ""
    @State private var hideYearTask: Task<Void, Never>?
    @State private var chartRange: ChartRange = .weeks

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        if showChangePill, !entries.isEmpty {
                            ChangeBadge(entries: entries)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        }

                        List {
                            if showChangeGraph && chartEntries.count >= 2 {
                            weightChart
                                .listRowBackground(Color(.systemBackground))
                                .listRowSeparator(.hidden)
                        }

                        ForEach(groupedEntries, id: \.key) { month, monthEntries in
                            Section {
                                ForEach(monthEntries) { entry in
                                    logRow(entry: entry)
                                        .listRowBackground(Color(.systemBackground))
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
                                    .padding(.top, 12)
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
                    .listStyle(.grouped)
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
                    } // end VStack

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
                        .padding(.top, showChangePill && !entries.isEmpty ? 56 : 4)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Data

    private var groupedEntries: [(key: String, value: [WeightEntry])] {
        WeightCalculations.groupedByMonth(entries)
    }

    // MARK: - Chart

    private var chartEntries: [WeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -chartRange.dayCount, to: Date()) ?? Date()
        return entries.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
    }

    private var weightChart: some View {
        let sorted = chartEntries
        let dates = sorted.map(\.timestamp)
        let weights = sorted.map(\.weight)

        return VStack(spacing: 8) {
            Picker("Range", selection: $chartRange) {
                ForEach(ChartRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            Chart {
                ForEach(Array(zip(dates, weights).enumerated()), id: \.offset) { index, pair in
                    let (date, weight) = pair

                    LineMark(
                        x: .value("Date", date),
                        y: .value("Weight", weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.accent)

                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Weight", weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.accent.opacity(0.1))

                    PointMark(
                        x: .value("Date", date),
                        y: .value("Weight", weight)
                    )
                    .symbolSize(20)
                    .foregroundStyle(.accent)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                switch chartRange {
                case .days:
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                case .weeks:
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                case .months:
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No entries yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Log Row

    private func logRow(entry: WeightEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f lbs", entry.weight))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.accent)
        }
        .padding(.vertical, 4)
    }

    private func deleteEntries(_ sectionEntries: [WeightEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sectionEntries[index])
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: WeightEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let calendar = Calendar.current
    let now = Date()
    let sampleWeights: [(Int, Double)] = [
        (0, 185.2), (1, 184.8), (3, 185.0), (7, 184.3),
        (14, 183.9), (21, 183.5), (30, 184.1), (45, 182.8),
        (60, 182.2), (75, 181.5), (90, 181.0), (120, 180.5),
        (150, 180.0), (180, 179.5), (210, 179.0), (240, 178.5),
        (300, 178.0), (365, 177.5)
    ]
    for (daysAgo, weight) in sampleWeights {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let entry = WeightEntry(weight: weight, timestamp: date)
        context.insert(entry)
    }

    return LogView()
        .modelContainer(container)
}
