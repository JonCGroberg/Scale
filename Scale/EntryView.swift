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
    @Binding var selectedTab: Int

    @AppStorage("showChangePill") private var showChangePill = true
    @State private var currentWeight: Double = 142.5
    @State private var isEditingWeight = false
    @State private var weightText = ""
    @State private var showCamera = false
    @FocusState private var weightFieldFocused: Bool

    private let step: Double = 0.1

    private var latestEntry: WeightEntry? { entries.first }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showChangePill, !entries.isEmpty {
                    ChangeBadge(entries: entries)
                        .onTapGesture { selectedTab = 1 }
                        .padding(.top, 16)
                }

                Spacer()

                weightDisplay

                stepperRow
                    .padding(.top, 32)

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
        .fullScreenCover(isPresented: $showCamera) {
            ScaleScannerView { weight in
                withAnimation(.snappy) {
                    currentWeight = weight
                }
            }
        }
    }

    // MARK: - Weight Display

    private var weightDisplay: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isEditingWeight {
                    TextField("0.0", text: $weightText)
                        .font(.system(size: 72, weight: .light))
                        .tracking(-2)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
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
                        .font(.system(size: 72, weight: .light))
                        .tracking(-2)
                        .contentTransition(.numericText())
                }

                Text("lbs")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent.opacity(0.8))

                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title3)
                        .foregroundStyle(.accent.opacity(0.5))
                }
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

    // MARK: - Stepper Row

    private var stepperRow: some View {
        HStack(spacing: 40) {
            Button {
                withAnimation(.snappy) {
                    currentWeight = max(currentWeight - step, 0.1)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(.accent.opacity(0.1), in: Circle())
                    .overlay(Circle().stroke(.accent.opacity(0.2), lineWidth: 1))
            }

            Button {
                withAnimation(.snappy) {
                    currentWeight += step
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(.accent.opacity(0.1), in: Circle())
                    .overlay(Circle().stroke(.accent.opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button("Save Entry") {
            saveEntry()
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
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
        withAnimation {
            let entry = WeightEntry(weight: currentWeight)
            modelContext.insert(entry)
            selectedTab = 1
        }
    }
}



#Preview {
    EntryView(selectedTab: .constant(0))
        .modelContainer(for: WeightEntry.self, inMemory: true)
}
