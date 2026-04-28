//
//  EntryView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct EntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Binding var historyScrollRequest: Int
    @Binding var historySelectedEntry: WeightEntry?
    var logDate: Date?
    var latestWeight: Double?
    var onDismiss: (() -> Void)?

    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @State private var currentWeight: Double = 142.5
    @State private var isEditingWeight = false
    @State private var weightText = ""
    @State private var saved = false
    @State private var pendingEntry: WeightEntry?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @FocusState private var weightFieldFocused: Bool

    private let step = 0.1
    private let weightDisplaySpacing: CGFloat = 16
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private var weightStatusText: String {
        if let logDate {
            return dayFormatter.string(from: logDate)
        }
        return "Log your weight"
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        weightDisplay
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.selection()
                        close()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                }
            }
            .onAppear {
                if let latestWeight {
                    currentWeight = latestWeight
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditingWeight {
                    weightEditControls
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    let newPhotoData = await loadPhotoData(from: newItems)
                    await MainActor.run {
                        photoData.append(contentsOf: newPhotoData)
                        saved = false
                        selectedPhotoItems = []
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: isEditingWeight) { _, new in new }
        }
    }

    // MARK: - Weight Display

    private var weightDisplay: some View {
        VStack(spacing: weightDisplaySpacing) {
            Text(weightStatusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            weightValue

            quickAdjustRow

            if !isEditingWeight {
                saveButton

                if !photos.isEmpty {
                    entryPhotoSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxHeight: .infinity)
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

            if !isEditingWeight {
                addPhotosButton
                    .padding(.leading, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            weightText = String(format: "%.1f", currentWeight)
            isEditingWeight = true
            weightFieldFocused = true
        }
    }

    private var weightEditControls: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                Haptics.selection()
                cancelWeightEdit()
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .buttonStyle(VisibleGlassButtonStyle(tint: .red))

            Button("Done") {
                Haptics.selection()
                commitWeightEdit(triggerHaptic: false)
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .buttonStyle(.glassProminent)
        }
    }

    private var saveButton: some View {
        Button {
            saveEntry()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.fill")
                Text("Save")
            }
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.glassProminent)
        .tint(tintColor)
    }

    @ViewBuilder
    private var entryPhotoSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 92, height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            photoData.remove(at: index)
                            saved = false
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
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private var photos: [UIImage] {
        photoData.compactMap(UIImage.init(data:))
    }

    private var addPhotosButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: nil,
            matching: .images
        ) {
            Image(systemName: "photo.badge.plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(tintColor.opacity(0.10))
                )
                .overlay {
                    Circle()
                        .strokeBorder(tintColor.opacity(0.24), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add photo")
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
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(width: 52, height: 44)
        }
        .buttonStyle(VisibleGlassButtonStyle(tint: tintColor))
    }

    // MARK: - Actions

    private func cancelWeightEdit() {
        isEditingWeight = false
        weightFieldFocused = false
    }

    private func commitWeightEdit(triggerHaptic: Bool = true) {
        if let value = WeightCalculations.parseWeight(from: weightText) {
            withAnimation(.snappy) {
                currentWeight = value
                saved = false
            }
            if triggerHaptic {
                Haptics.selection()
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
        let goal = WeightGoal(rawValue: weightGoal) ?? .defaultValue
        let reachedGoal = GoalProgressFeedback.didReachGoal(
            goal: goal,
            newWeight: currentWeight,
            cutTarget: cutTargetWeight,
            bulkTarget: bulkTargetWeight
        )
        let movedCloserToGoal = GoalProgressFeedback.isCloserToGoal(
            goal: goal,
            previousWeight: latestWeight,
            newWeight: currentWeight,
            cutTarget: cutTargetWeight,
            bulkTarget: bulkTargetWeight
        )
        let timestamp = logDate ?? Date()
        let entry = WeightEntry(
            weight: currentWeight,
            timestamp: timestamp
        )
        entry.photosData = photoData
        modelContext.insert(entry)

        // Fetch existing entries for streak + widget refresh after insert.
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let allEntries = (try? modelContext.fetch(descriptor)) ?? []

        entry.streakCount = WeightCalculations.currentStreak(from: allEntries, includingToday: true)
        WeightWidgetSnapshotStore.refresh(using: allEntries)

        // Reschedule reminders so tomorrow's notification reflects the updated streak.
        notificationManager.rescheduleReminders()

        Task {
            let uuid = await healthManager.saveWeight(currentWeight, date: entry.timestamp)
            entry.healthKitUUID = uuid
        }

        resetDraftAfterSave()
        saved = true
        pendingEntry = entry
        Haptics.success()
        if reachedGoal {
            NotificationCenter.default.post(
                name: .didReachWeightGoal,
                object: GoalReachedPayload(goal: goal, weight: currentWeight)
            )
        } else if movedCloserToGoal {
            NotificationCenter.default.post(name: .didMoveCloserToGoal, object: nil)
        }
        close()
    }

    private func resetDraftAfterSave() {
        selectedPhotoItems = []
        photoData = []
    }

    private func close() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
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
}

private struct VisibleGlassButtonStyle: ButtonStyle {
    let tint: Color
    var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(minHeight: height)
            .padding(.horizontal, 14)
            .foregroundStyle(tint)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .background(
                tint.opacity(configuration.isPressed ? 0.24 : 0.14),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(configuration.isPressed ? 0.62 : 0.38), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
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
        historyScrollRequest: .constant(0),
        historySelectedEntry: .constant(nil),
        latestWeight: 142.5
    )
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
