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

    @AppStorage("showChangePill") private var showChangePill = true
    @State private var currentWeight: Double = 142.5
    @State private var isEditingWeight = false
    @State private var weightText = ""
    @State private var showCamera = false
    @State private var saved = false
    @State private var isSaveOptionsPresented = false
    @State private var isProgressPhotoCameraPresented = false
    @State private var isCameraUnavailableAlertPresented = false
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
                    GlassEffectContainer(spacing: 24) {
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
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    cameraButton
                        .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if isEditingWeight {
                    editActionsBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
            .onAppear {
                if let latest = latestEntry {
                    currentWeight = latest.weight
                }
            }
            .confirmationDialog(
                "Add a progress photo?",
                isPresented: $isSaveOptionsPresented,
                titleVisibility: .visible
            ) {
                Button("Take Progress Photo") {
                    presentProgressPhotoCamera()
                }

                Button("Save Without Photo") {
                    saveEntry(photoData: nil)
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Attach a fresh photo to this weigh-in or skip it.")
            }
            .alert("Camera Unavailable", isPresented: $isCameraUnavailableAlertPresented) {
                Button("Save Without Photo") {
                    saveEntry(photoData: nil)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This device can’t take a progress photo right now.")
            }
            .fullScreenCover(isPresented: $showCamera) {
                ScaleScannerView { weight in
                    withAnimation(.snappy) {
                        currentWeight = weight
                    }
                }
            }
            .fullScreenCover(isPresented: $isProgressPhotoCameraPresented) {
                ProgressPhotoCameraView { image in
                    isProgressPhotoCameraPresented = false
                    guard let image else { return }
                    let photoData = image.jpegData(compressionQuality: 0.85)
                    saveEntry(photoData: photoData)
                }
                .ignoresSafeArea()
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
            isSaveOptionsPresented = true
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

    private var editActionsBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                cancelWeightEdit()
            }

            Spacer()

            Button("Done") {
                commitWeightEdit()
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
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

    private func presentProgressPhotoCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isCameraUnavailableAlertPresented = true
            return
        }

        isProgressPhotoCameraPresented = true
    }

    private func saveEntry(photoData: Data?) {
        // Compute the streak including today's new entry
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        let entry = WeightEntry(weight: currentWeight, streakCount: streak, photoData: photoData)
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
    EntryView(selectedTab: .constant(0))
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
}
