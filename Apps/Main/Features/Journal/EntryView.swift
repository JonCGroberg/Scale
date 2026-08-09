//
//  EntryView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit
import Photos
import PhotosUI
import AVFoundation

struct EntryView: View {
    enum EntryMode: String, CaseIterable, Identifiable {
        case moment = "Photo"
        case weight = "Weight"

        var id: Self { self }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Binding var historyScrollRequest: Int
    @Binding var historySelectedEntry: WeightEntry?
    var logDate: Date?
    var latestWeight: Double?
    var initialEntryMode: EntryMode? = nil
    var onDismiss: (() -> Void)?

    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @AppStorage("lastEntryMode") private var lastEntryMode = EntryMode.moment.rawValue

    private var effectiveDate: Date {
        logDate ?? Date()
    }

    private struct DayStats {
        var activitySummary: DailyActivitySummary?
        var sleepDuration: TimeInterval?
        var workoutCount = 0
    }

    private var statsDay: Date {
        Calendar.current.startOfDay(for: effectiveDate)
    }

    @State private var dayStats = DayStats()

    /// Fetch only the records displayed by this sheet. The task yields once so
    /// sheet presentation can commit its initial frame before the fetch begins.
    private func loadDayStats() {
        let calendar = Calendar.current
        let targetDay = statsDay
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!

        let activityDescriptor = FetchDescriptor<DailyActivitySummary>(
            predicate: #Predicate { $0.date >= targetDay && $0.date < nextDay }
        )
        let sleepDescriptor = FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.startDate >= targetDay && $0.startDate < nextDay }
        )
        let workoutDescriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { $0.timestamp >= targetDay && $0.timestamp < nextDay }
        )

        let activitySummary = try? modelContext.fetch(activityDescriptor).first
        let sleepEntries = (try? modelContext.fetch(sleepDescriptor)) ?? []
        let workoutCount = (try? modelContext.fetchCount(workoutDescriptor)) ?? 0

        dayStats = DayStats(
            activitySummary: activitySummary,
            sleepDuration: sleepEntries.isEmpty ? nil : sleepEntries.reduce(0) { $0 + $1.duration },
            workoutCount: workoutCount
        )
    }

    @State private var currentWeight: Double = 142.5
    @State private var isEditingWeight = false
    @State private var weightText = ""
    @State private var saved = false
    @State private var pendingEntry: WeightEntry?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var entryMode: EntryMode = .moment
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
                    if entryMode == .moment {
                        momentCapture
                    } else {
                        weightLogging
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            switchEntryMode(for: value)
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 0) {
                        Button {
                            Haptics.selection()
                            close()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        if entryMode == .moment {
                            toolbarAddPhotosButton
                        }
                    }
                    // This is one grouped control: its shared capsule is glass,
                    // while the contained actions deliberately remain plain.
                    .glassEffect(.regular.interactive(), in: Capsule())
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
                        .disabled(entryMode == .moment && photoData.isEmpty)
                    }
                }
            }
            .onAppear {
                if let latestWeight {
                    currentWeight = latestWeight
                }
                entryMode = initialEntryMode ?? EntryMode(rawValue: lastEntryMode) ?? .moment
            }
            .task(id: statsDay) {
                await Task.yield()
                loadDayStats()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if isEditingWeight {
                        weightEditControls
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    entryModePicker
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
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
            .onChange(of: entryMode) { _, newMode in
                lastEntryMode = newMode.rawValue
            }
            .sensoryFeedback(.selection, trigger: isEditingWeight) { _, new in new }
        }
    }

    // MARK: - Weight Display

    private var entryModePicker: some View {
        Picker("Entry type", selection: $entryMode) {
            ForEach(EntryMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private func switchEntryMode(for value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        guard abs(horizontal) > abs(vertical), abs(horizontal) > 56 else { return }

        let nextMode: EntryMode = horizontal < 0 ? .weight : .moment
        guard nextMode != entryMode else { return }

        withAnimation(.snappy) {
            entryMode = nextMode
        }
        Haptics.selection()
    }

    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }

    private var weightLogging: some View {
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

    @ViewBuilder
    private var momentCapture: some View {
        VStack(spacing: 14) {
            momentContext

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                ProgressPhotoCameraView { image in
                    guard let data = image?.jpegData(compressionQuality: 0.9) else { return }
                    photoData.append(data)
                    if let image {
                        saveToPhotoLibrary(image)
                    }
                    saved = false
                    Haptics.success()
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            } else {
                ContentUnavailableView {
                    Label("Camera unavailable", systemImage: "camera")
                } description: {
                    Text("Choose a photo from your library to add a moment.")
                } actions: {
                    addPhotosButton
                }
                .frame(maxHeight: .infinity)
            }

            if !photos.isEmpty {
                entryPhotoSection
                    .padding(.horizontal, 24)
            } else {
                Text("Take a progress photo, then save it as today’s moment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var momentContext: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "scalemass.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(currentWeight.formatted(.number.precision(.fractionLength(1)))) lbs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            dayStatsRow
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
    }

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
        let summary = dayStats.activitySummary
        let stepsText = summary.map { $0.stepCount.formatted() } ?? "—"
        let calText = summary.map { "\(Int($0.activeEnergyBurnedKilocalories.rounded())) cal" } ?? "—"
        let sleepHours = dayStats.sleepDuration.map { String(format: "%.1fh", $0 / 3600) } ?? "—"

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

            if dayStats.workoutCount > 0 {
                Label {
                    Text("\(dayStats.workoutCount)")
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

    private var toolbarAddPhotosButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: nil,
            matching: .images
        ) {
            Image(systemName: "photo.badge.plus")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
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
        if entryMode == .moment {
            savePhotoOnlyMoment()
            return
        }

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

        let existingEntriesDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let existingEntries = (try? modelContext.fetch(existingEntriesDescriptor)) ?? []
        let previousLongestStreak = WeightCalculations.longestStreak(from: existingEntries)

        modelContext.insert(entry)

        // Reuse the pre-insert history. The new entry is known locally, so a second
        // whole-history fetch during the Save tap is unnecessary.
        let allEntries = [entry] + existingEntries

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

    private func savePhotoOnlyMoment() {
        guard !photoData.isEmpty else { return }

        let entry = WeightEntry(
            weight: 0,
            includesWeight: false,
            timestamp: logDate ?? Date()
        )
        entry.photosData = photoData
        modelContext.insert(entry)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(entry)
            return
        }

        resetDraftAfterSave()
        Haptics.success()
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

    func makeUIViewController(context: Context) -> ProgressPhotoCameraController {
        ProgressPhotoCameraController(onImagePicked: onImagePicked)
    }

    func updateUIViewController(_ uiViewController: ProgressPhotoCameraController, context: Context) { }

    static func dismantleUIViewController(_ uiViewController: ProgressPhotoCameraController, coordinator: ()) {
        uiViewController.stopCaptureSession()
    }
}

final class ProgressPhotoCameraController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let onImagePicked: (UIImage?) -> Void
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.groberg.Scale.progress-photo-camera")
    private let photoOutput = AVCapturePhotoOutput()
    private let previewView = UIView()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoInput: AVCaptureDeviceInput?

    init(onImagePicked: @escaping (UIImage?) -> Void) {
        self.onImagePicked = onImagePicked
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureLayout()
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }

    func stopCaptureSession() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureLayout() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.backgroundColor = .black
        view.addSubview(previewView)

        let controls = UIStackView(arrangedSubviews: [cancelButton, shutterButton, switchCameraButton])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .horizontal
        controls.alignment = .center
        controls.distribution = .equalCentering
        controls.isLayoutMarginsRelativeArrangement = true
        controls.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28)
        controls.backgroundColor = .black
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controls.heightAnchor.constraint(equalToConstant: 88),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: controls.topAnchor)
        ])
    }

    private var cancelButton: UIButton {
        cameraButton(image: "xmark", action: #selector(cancelCapture))
    }

    private var switchCameraButton: UIButton {
        cameraButton(image: "arrow.triangle.2.circlepath.camera", action: #selector(switchCamera))
    }

    private var shutterButton: UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 31
        button.layer.borderWidth = 5
        button.layer.borderColor = UIColor(white: 0.2, alpha: 1).cgColor
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        button.accessibilityLabel = "Take photo"
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 62),
            button.heightAnchor.constraint(equalToConstant: 62)
        ])
        return button
    }

    private func cameraButton(image: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: image)
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor(white: 0.16, alpha: 1)
        configuration.cornerStyle = .capsule

        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])
        return button
    }

    private func configureCaptureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUpCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                self?.setUpCaptureSession()
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func setUpCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard let device = self.cameraDevice(position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input),
                  self.session.canAddOutput(self.photoOutput) else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)
            self.session.addOutput(self.photoOutput)
            self.videoInput = input

            DispatchQueue.main.async {
                let layer = AVCaptureVideoPreviewLayer(session: self.session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = self.previewView.bounds
                self.previewView.layer.addSublayer(layer)
                self.previewLayer = layer
            }
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    @objc private func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    @objc private func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self,
                  let currentInput = self.videoInput,
                  let nextPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back,
                  let device = self.cameraDevice(position: nextPosition),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoInput = newInput
            } else {
                self.session.addInput(currentInput)
            }
            self.session.commitConfiguration()
        }
    }

    @objc private func cancelCapture() {
        stopCaptureSession()
        onImagePicked(nil)
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onImagePicked(image)
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
