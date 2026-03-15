//
//  EntryView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData

struct EntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]

    @State private var currentWeight: Double = 142.5

    private let step: Double = 0.1

    private var latestEntry: WeightEntry? { entries.first }

    private var weightChange: Double? {
        guard entries.count >= 2 else { return nil }
        return entries[0].weight - entries[1].weight
    }

    private var changeDate: Date? {
        guard entries.count >= 2 else { return nil }
        return entries[1].timestamp
    }

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                weightDisplay

                stepperButtons
                    .padding(.top, 32)

                if let change = weightChange, let date = changeDate {
                    changeBadge(change: change, since: date)
                        .padding(.top, 24)
                }

                Spacer()

                saveButton
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if let latest = latestEntry {
                currentWeight = latest.weight
            }
        }
    }

    // MARK: - Weight Display

    private var weightDisplay: some View {
        VStack(spacing: 4) {
            Text("Current Weight")
                .font(.subheadline)
                .fontWeight(.light)
                .tracking(0.5)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", currentWeight))
                    .font(.system(size: 72, weight: .light))
                    .tracking(-2)
                    .contentTransition(.numericText())

                Text("lbs")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent.opacity(0.8))
            }
        }
    }

    // MARK: - Stepper Buttons

    private var stepperButtons: some View {
        HStack(spacing: 48) {
            Button {
                withAnimation(.snappy) {
                    currentWeight = max(0, currentWeight - step)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.title2)
                    .fontWeight(.light)
                    .foregroundStyle(.accent)
                    .frame(width: 64, height: 64)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Button {
                withAnimation(.snappy) {
                    currentWeight += step
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.light)
                    .foregroundStyle(.accent)
                    .frame(width: 64, height: 64)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    // MARK: - Change Badge

    private func changeBadge(change: Double, since date: Date) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: change <= 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.accent)

                Text(String(format: "%+.1f lbs", change))
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Circle()
                .fill(.accent.opacity(0.4))
                .frame(width: 4, height: 4)

            Text("Since \(date, format: .dateTime.month(.abbreviated).day())")
                .font(.caption2)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.accent.opacity(0.1), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.accent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveEntry()
        } label: {
            Text("Save Entry")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 18)
                .background(.accent, in: Capsule())
                .shadow(color: .accent.opacity(0.3), radius: 20, y: 10)
        }
    }

    // MARK: - Actions

    private func saveEntry() {
        withAnimation {
            let entry = WeightEntry(weight: currentWeight)
            modelContext.insert(entry)
        }
    }
}

#Preview {
    EntryView()
        .modelContainer(for: WeightEntry.self, inMemory: true)
}
