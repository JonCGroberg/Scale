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

    private var latestEntry: WeightEntry? { entries.first }

    private var weightStatusText: String {
        guard let latestEntry, Calendar.current.isDateInToday(latestEntry.timestamp) else {
            return "Log your weight today"
        }

        return "Last logged at \(timeFormatter.string(from: latestEntry.timestamp))"
    }

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
                        weightDisplay
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if let latest = latestEntry {
                    currentWeight = latest.weight
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
            .buttonStyle(.glass)

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
            if !saved {
                saveEntry()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(saved ? "Done" : "Save")
            }
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.glassProminent)
        .disabled(saved)
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
        .buttonStyle(.glass)
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
        // Compute the streak including today's new entry
        let streak = WeightCalculations.currentStreak(from: entries, includingToday: true)
        let entry = WeightEntry(
            weight: currentWeight,
            streakCount: streak
        )
        entry.photosData = photoData
        modelContext.insert(entry)
        WeightWidgetSnapshotStore.refresh(using: [entry] + entries)

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
    }

    private func resetDraftAfterSave() {
        selectedPhotoItems = []
        photoData = []
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
