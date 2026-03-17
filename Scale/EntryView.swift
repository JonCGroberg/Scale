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
    @Environment(HealthKitManager.self) private var healthManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @Binding var selectedTab: Int

    @AppStorage("showChangePill") private var showChangePill = true
    @State private var currentWeight: Double = 142.5
    @State private var isEditingWeight = false
    @State private var weightText = ""
    @State private var showCamera = false
    @State private var saved = false
    @FocusState private var weightFieldFocused: Bool

    private let step: Double = 0.1

    private var latestEntry: WeightEntry? { entries.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if showChangePill, !entries.isEmpty {
                        ChangeBadge(entries: entries)
                            .onTapGesture { selectedTab = 1 }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 16)
                    }

                    Spacer()

                    // Weight entry card
                    GlassEffectContainer {
                        VStack(spacing: 28) {
                            lastLoggedLabel

                            weightDisplay

                            stepperRow

                            saveButton
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal, 40)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .green.opacity(0),
                                            .mint.opacity(0),
                                            .green.opacity(0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .allowsHitTesting(false)
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.accent.opacity(0.12))
                    )
                    .padding(.horizontal, 24)

                    Spacer()

                    cameraButton
                        .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if let latest = latestEntry {
                    currentWeight = latest.weight
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ScaleScannerView { weight in
                    withAnimation(.snappy) {
                        currentWeight = weight
                    }
                }
            }
        }
    }

    // MARK: - Last Logged Label

    private var lastLoggedLabel: some View {
        Group {
            if let latest = latestEntry {
                Text("Last logged \(latest.timestamp, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Log your first weight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Weight Display

    private var weightDisplay: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if isEditingWeight {
                    TextField("0.0", text: $weightText)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .focused($weightFieldFocused)
                        .fixedSize()
                        .onSubmit { commitWeightEdit() }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Button("Cancel") {
                                    cancelWeightEdit()
                                }
                                Spacer()
                                Button("Done") {
                                    commitWeightEdit()
                                }
                                .fontWeight(.semibold)
                            }
                        }
                } else {
                    Text(String(format: "%.1f", currentWeight))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }

                Text("lbs")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            .onTapGesture {
                weightText = String(format: "%.1f", currentWeight)
                isEditingWeight = true
                weightFieldFocused = true
            }
        }
        .onChange(of: weightFieldFocused) { _, focused in
            if !focused && isEditingWeight {
                commitWeightEdit()
            }
        }
    }

    // MARK: - Stepper

    private var stepperRow: some View {
        Stepper("Weight") {
            withAnimation(.snappy) {
                currentWeight += step
            }
        } onDecrement: {
            withAnimation(.snappy) {
                currentWeight -= step
            }
        }
        .labelsHidden()
        .onChange(of: currentWeight) {
            saved = false
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveEntry()
        } label: {
            Text(saved ? "Saved" : "Save")
                .contentTransition(.interpolate)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .disabled(saved)
    }

    // MARK: - Camera Button

    private var cameraButton: some View {
        Button {
            showCamera = true
        } label: {
            Label("Scan Scale", systemImage: "camera.viewfinder")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
    }

    // MARK: - Actions

    private func cancelWeightEdit() {
        isEditingWeight = false
        weightFieldFocused = false
    }

    private func commitWeightEdit() {
        if let value = WeightCalculations.parseWeight(from: weightText) {
            withAnimation(.snappy) {
                currentWeight = value
            }
        }
        isEditingWeight = false
    }

    private func saveEntry() {
        // Compute the streak including today's new entry
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        let entry = WeightEntry(weight: currentWeight, streakCount: streak)
        modelContext.insert(entry)

        Task {
            let uuid = await healthManager.saveWeight(currentWeight, date: entry.timestamp)
            entry.healthKitUUID = uuid
        }

        Task { @MainActor in
            saved = true
            selectedTab = 1
        }
    }
}



#Preview {
    EntryView(selectedTab: .constant(0))
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
}
