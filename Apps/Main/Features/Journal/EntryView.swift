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
    @Query(sort: \DailyActivitySummary.date, order: .reverse) private var allDailyActivitySummaries: [DailyActivitySummary]
    @Query(sort: \SleepEntry.startDate, order: .reverse) private var allSleepEntries: [SleepEntry]
    @Query(sort: \WorkoutEntry.timestamp, order: .reverse) private var allWorkouts: [WorkoutEntry]
    @Binding var historyScrollRequest: Int
    @Binding var historySelectedEntry: WeightEntry?
    var logDate: Date?
    var latestWeight: Double?
    var onDismiss: (() -> Void)?

    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0

    private var effectiveDate: Date {
        logDate ?? Date()
    }

    private var dailyActivitySummary: DailyActivitySummary? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: effectiveDate)
        return allDailyActivitySummaries.first { calendar.startOfDay(for: $0.date) == targetDay }
    }

    private var sleepDurationForDay: TimeInterval? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: effectiveDate)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!
        let dayEntries = allSleepEntries.filter {
            $0.startDate >= targetDay && $0.startDate < nextDay
        }
        guard !dayEntries.isEmpty else { return nil }
        return dayEntries.reduce(0) { $0 + $1.duration }
    }

    private var workoutCountForDay: Int {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: effectiveDate)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!
        return allWorkouts.filter {
            $0.timestamp >= targetDay && $0.timestamp < nextDay
        }.count
    }

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

    private let dayNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private var weightStatusText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(effectiveDate) {
            return "Today"
        }
        if let daysAgo = calendar.dateComponents([.day], from: effectiveDate, to: Date()).day,
           daysAgo >= 1 && daysAgo < 7 {
            return dayNameFormatter.string(from: effectiveDate)
        }
        return dayFormatter.string(from: effectiveDate)
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
                    dayStatsRow
                        .padding(.horizontal, 46)
                        .padding(.top, 8)

                    Spacer()

                    VStack(spacing: 16) {
                        weightDisplay
                    }
                    .padding(.horizontal, 46)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Button {
                            Haptics.selection()
                            close()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.glass)

                        addPhotosButton
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(weightStatusText)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditingWeight {
                        Button("Save") {
                            saveEntry()
                        }
                    }
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
            weightValue

            quickAdjustRow

            if !isEditingWeight, !photos.isEmpty {
                entryPhotoSection
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var dayStatsRow: some View {
        let summary = dailyActivitySummary
        let stepsText = summary.map { $0.stepCount.formatted() } ?? "—"
        let calText = summary.map { "\(Int($0.activeEnergyBurnedKilocalories.rounded())) cal" } ?? "—"
        let sleepHours = sleepDurationForDay.map { String(format: "%.1fh", $0 / 3600) } ?? "—"

        HStack(spacing: 12) {
            Label {
                Text(stepsText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: "shoeprints.fill")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Label {
                Text(calText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: "flame.fill")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Label {
                Text(sleepHours)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: "bed.double.fill")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            if workoutCountForDay > 0 {
                Label {
                    Text("\(workoutCountForDay)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "figure.run")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
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
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tintColor)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Add photos")
    }

    private var quickAdjustRow: some View {
        HStack(spacing: 16) {
            RepeatingWeightAdjustButton(systemImage: "minus", tint: tintColor) {
                adjustWeight(by: -step)
            }

            RepeatingWeightAdjustButton(systemImage: "plus", tint: tintColor) {
                adjustWeight(by: step)
            }
        }
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
        let isFirstEverLog = latestWeight == nil
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

        let preInsertDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let preInsertEntries = (try? modelContext.fetch(preInsertDescriptor)) ?? []
        let previousLongestStreak = WeightCalculations.longestStreak(from: preInsertEntries)

        modelContext.insert(entry)

        // Fetch existing entries for streak + widget refresh after insert.
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let allEntries = (try? modelContext.fetch(descriptor)) ?? []

        let streak = WeightCalculations.currentStreak(from: allEntries, includingToday: true)
        entry.streakCount = streak
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
        let isNewMaxStreak = streak > 1 && streak > previousLongestStreak
        if isFirstEverLog {
            NotificationCenter.default.post(name: .didLogFirstWeight, object: nil)
        } else if reachedGoal {
            NotificationCenter.default.post(
                name: .didReachWeightGoal,
                object: GoalReachedPayload(goal: goal, weight: currentWeight)
            )
        } else if movedCloserToGoal {
            let distanceCloser = GoalProgressFeedback.distanceCloserToGoal(
                goal: goal,
                previousWeight: latestWeight,
                newWeight: currentWeight,
                cutTarget: cutTargetWeight,
                bulkTarget: bulkTargetWeight
            ) ?? 0
            let miniGoals = MiniGoalStore.load(for: goal)
            let achievedMiniGoal = GoalProgressFeedback.achievedMiniGoal(
                goal: goal,
                previousWeight: latestWeight,
                newWeight: currentWeight,
                miniGoals: miniGoals
            )
            NotificationCenter.default.post(
                name: .didMoveCloserToGoal,
                object: CloserToGoalPayload(distanceCloser: distanceCloser, achievedMiniGoal: achievedMiniGoal)
            )
        }
        if isNewMaxStreak {
            NotificationCenter.default.post(name: .didSetNewMaxStreak, object: streak)
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

private struct RepeatingWeightAdjustButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    @State private var isPressed = false
    @State private var didRepeat = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 52, height: 44)
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .background(
                tint.opacity(isPressed ? 0.24 : 0.14),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(isPressed ? 0.62 : 0.38), lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.97 : 1)
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        beginPress()
                    }
                    .onEnded { _ in
                        endPress()
                    }
            )
            .accessibilityLabel(systemImage == "minus" ? "Decrease weight" : "Increase weight")
            .accessibilityAddTraits(.isButton)
            .onDisappear {
                cancelRepeat()
            }
            .animation(.snappy(duration: 0.16), value: isPressed)
    }

    private func beginPress() {
        isPressed = true
        didRepeat = false

        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }

            let startedAt = Date()
            while !Task.isCancelled {
                didRepeat = true
                Haptics.selection()
                action()

                let elapsed = Date().timeIntervalSince(startedAt)
                let delay: Duration = if elapsed < 1.0 {
                    .milliseconds(180)
                } else if elapsed < 2.0 {
                    .milliseconds(110)
                } else {
                    .milliseconds(65)
                }
                try? await Task.sleep(for: delay)
            }
        }
    }

    private func endPress() {
        let shouldHandleAsTap = !didRepeat
        cancelRepeat()

        if shouldHandleAsTap {
            Haptics.selection()
            action()
        }
    }

    private func cancelRepeat() {
        repeatTask?.cancel()
        repeatTask = nil
        isPressed = false
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
