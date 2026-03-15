//
//  LogView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("showChangePill") private var showChangePill = true

    @State private var isScrolling = false
    @State private var visibleSection = ""
    @State private var hideYearTask: Task<Void, Never>?


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
                            ForEach(groupedEntries, id: \.key) { month, monthEntries in
                                Section {
                                    ForEach(monthEntries) { entry in
                                        logRow(entry: entry)
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
                        .padding(.bottom, 16)
                        .padding(.horizontal, 16)
                }
            }
        }
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

    // MARK: - Log Row

    private func logRow(entry: WeightEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(entry.timestamp, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.caption)
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
