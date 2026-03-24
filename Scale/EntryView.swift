//
//  EntryView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit

struct EntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @Binding var selectedTab: Int
    @Binding var historyScrollRequest: Int
    @Binding var historySelectedEntry: WeightEntry?

    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @State private var currentWeight: Double = 142.5
    @State private var isEditingWeight = false
    @State private var weightText = ""
    @State private var showCamera = false
    @State private var saved = false
    @FocusState private var weightFieldFocused: Bool

    private let step = 0.1
    private let bottomBarWidth: CGFloat = 320
    private let weightDisplaySpacing: CGFloat = 16

    private var latestEntry: WeightEntry? { entries.first }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            lastLoggedLabel
                        }

                        weightDisplay
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if !isEditingWeight {
                    VStack(spacing: 12) {
                        bottomActionRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                        saved = false
                    }
                }
            }
            .toolbar {
                if isEditingWeight {
                    ToolbarItem(placement: .keyboard) {
                        HStack {
                            Button("Cancel") {
                                cancelWeightEdit()
                            }
                            .foregroundStyle(.red)

                            Spacer()

                            Button("Done") {
                                commitWeightEdit()
                            }
                            .fontWeight(.semibold)
                        }
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
        VStack(spacing: weightDisplaySpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                weightValue

                scanCameraButton
            }

            quickAdjustRow
        }
        .onChange(of: weightFieldFocused) { _, focused in
            if !focused && isEditingWeight {
                commitWeightEdit()
            }
        }
    }

    private var weightValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if isEditingWeight {
                TextField("0.0", text: $weightText)
                    .font(.system(size: 68, weight: .regular, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($weightFieldFocused)
                    .fixedSize()
                    .onSubmit { commitWeightEdit() }
            } else {
                Text(String(format: "%.1f", currentWeight))
                    .font(.system(size: 68, weight: .regular, design: .rounded))
                    .contentTransition(.numericText())
            }

            Text("lbs")
                .font(.title2.weight(.medium))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            weightText = String(format: "%.1f", currentWeight)
            isEditingWeight = true
            weightFieldFocused = true
        }
    }

    private var bottomActionRow: some View {
        GlassEffectContainer(spacing: 18) {
            HStack {
                Button {
                    saveEntry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                            .contentTransition(.symbolEffect(.replace))
                        Text(saved ? "Saved" : "Save")
                    }
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.glassProminent)
                .disabled(saved)
            }
            .frame(maxWidth: 150)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .frame(width: bottomBarWidth)
    }

    private var scanCameraButton: some View {
        Button {
            showCamera = true
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private var quickAdjustRow: some View {
        HStack(spacing: 16) {
            quickAdjustButton(systemImage: "minus") {
                adjustWeight(by: -step)
            }

            quickAdjustButton(systemImage: "plus") {
                adjustWeight(by: step)
            }
        }
    }

    private func quickAdjustButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(width: 52, height: 44)
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
                saved = false
            }
        }
        isEditingWeight = false
        weightFieldFocused = false
    }

    private func adjustWeight(by delta: Double) {
        let nextWeight = max(currentWeight + delta, 0.1)
        let roundedWeight = (nextWeight * 10).rounded() / 10

        withAnimation(.snappy) {
            currentWeight = roundedWeight
            saved = false
        }
    }

    private func saveEntry() {
        // Compute the streak including today's new entry
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        let entry = WeightEntry(
            weight: currentWeight,
            streakCount: streak
        )
        modelContext.insert(entry)
        WeightWidgetSnapshotStore.refresh(using: [entry] + entries)

        // Reschedule reminders so tomorrow's notification reflects the updated streak.
        notificationManager.rescheduleReminders()

        Task {
            let uuid = await healthManager.saveWeight(currentWeight, date: entry.timestamp)
            entry.healthKitUUID = uuid
        }

        Task { @MainActor in
            saved = true
            historySelectedEntry = entry
            historyScrollRequest += 1
            selectedTab = 1
        }
    }
}

struct ProgressPhotoCameraView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onImagePicked(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            picker.dismiss(animated: true)
            onImagePicked(image)
        }
    }
}



#Preview {
    EntryView(
        selectedTab: .constant(0),
        historyScrollRequest: .constant(0),
        historySelectedEntry: .constant(nil)
    )
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
