//
//  SettingsView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @State private var reminders: [Reminder] = []
    @State private var miniGoals: [MiniGoal] = []

    private var selectedTint: Binding<AppTint> {
        Binding(
            get: { AppTint(rawValue: appTint) ?? .defaultValue },
            set: { appTint = $0.rawValue }
        )
    }

    private var selectedWeightGoal: Binding<WeightGoal> {
        Binding(
            get: { WeightGoal(rawValue: weightGoal) ?? .defaultValue },
            set: { weightGoal = $0.rawValue }
        )
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var selectedTargetWeight: Binding<Double> {
        Binding(
            get: {
                switch selectedWeightGoal.wrappedValue {
                case .lose:
                    cutTargetWeight
                case .maintain:
                    cutTargetWeight
                case .gain:
                    bulkTargetWeight
                }
            },
            set: { newValue in
                switch selectedWeightGoal.wrappedValue {
                case .lose:
                    cutTargetWeight = newValue
                case .maintain:
                    break
                case .gain:
                    bulkTargetWeight = newValue
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GoalPicker(
                        selection: selectedWeightGoal,
                        tintColor: tintColor
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)

                    if selectedWeightGoal.wrappedValue.showsTarget {
                        VStack(spacing: 12) {
                            GoalSectionDivider()

                            TargetWeightRow(
                                goal: selectedWeightGoal.wrappedValue,
                                targetWeight: selectedTargetWeight,
                                tintColor: tintColor
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparator(.hidden)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                        ForEach($miniGoals) { $miniGoal in
                            VStack(spacing: 12) {
                                GoalSectionDivider()

                                MiniGoalRow(
                                    miniGoal: $miniGoal,
                                    goal: selectedWeightGoal.wrappedValue,
                                    mainTarget: selectedTargetWeight.wrappedValue,
                                    tintColor: tintColor
                                ) {
                                    saveMiniGoals()
                                }
                                .padding(.leading, 32)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { offsets in
                            withAnimation {
                                miniGoals.remove(atOffsets: offsets)
                            }
                            saveMiniGoals()
                        }

                        Button {
                            withAnimation {
                                miniGoals.append(
                                    MiniGoal(
                                        parentGoal: selectedWeightGoal.wrappedValue,
                                        targetWeight: MiniGoalStore.defaultTarget(
                                            for: selectedWeightGoal.wrappedValue,
                                            mainTarget: selectedTargetWeight.wrappedValue,
                                            existingGoals: miniGoals
                                        )
                                    )
                                )
                            }
                            saveMiniGoals()
                            Haptics.selection()
                        } label: {
                            VStack(spacing: 12) {
                                GoalSectionDivider()

                                Label("Add mini goal", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 32)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Goal")
                } footer: {
                    if selectedWeightGoal.wrappedValue.showsTarget {
                        Text("Mini goals stay attached to this \(selectedWeightGoal.wrappedValue.targetTitle).")
                    } else {
                        Text("Cut and bulk keep separate goal weights. Maintain does not use a goal weight.")
                    }
                }

                Section {
                    if healthManager.isAvailable {
                        Toggle("Import Apple Health updates automatically", isOn: $autoSyncHealthKit)
                    }
                    HealthImportRows(tintColor: tintColor)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Bring in weight entries, workouts, and daily activity summaries from Apple Health automatically when the app opens, or run an import whenever you want.")
                }

                Section {
                    Toggle("Daily Reminders", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await notificationManager.requestAuthorization()
                                    if !granted {
                                        remindersEnabled = false
                                    } else {
                                        if reminders.isEmpty {
                                            withAnimation {
                                                reminders.append(Reminder())
                                            }
                                            notificationManager.saveReminders(reminders)
                                        } else {
                                            notificationManager.rescheduleReminders()
                                        }
                                    }
                                }
                            } else {
                                notificationManager.rescheduleReminders()
                            }
                        }

                    if remindersEnabled {
                        ForEach($reminders) { $reminder in
                            ReminderRow(reminder: $reminder, tintColor: tintColor) {
                                notificationManager.saveReminders(reminders)
                            }
                        }
                        .onDelete { offsets in
                            withAnimation {
                                reminders.remove(atOffsets: offsets)
                            }
                            notificationManager.saveReminders(reminders)
                        }

                        Button {
                            let lastHour = reminders.last?.hour ?? 6
                            withAnimation {
                                reminders.append(Reminder(hour: min(lastHour + 2, 22)))
                            }
                            notificationManager.saveReminders(reminders)
                            Haptics.selection()
                        } label: {
                            Label("Add Reminder", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Get a notification to log your weight. Tapping the notification opens the entry screen.")
                }

                Section {
                    Picker(selection: selectedTint) {
                        ForEach(AppTint.allCases) { tint in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(tint.color)
                                    .frame(width: 12, height: 12)

                                Text(tint.title)
                                    .foregroundStyle(tint.color)
                            }
                            .tag(tint)
                        }
                    }
                    label: {
                        Text("Tint Color")
                            .foregroundStyle(tintColor)
                    }
                } header: {
                    Text("Display")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                reminders = notificationManager.loadReminders()
                miniGoals = MiniGoalStore.load(for: selectedWeightGoal.wrappedValue)
            }
            .onChange(of: weightGoal) { _, _ in
                miniGoals = MiniGoalStore.load(for: selectedWeightGoal.wrappedValue)
            }
            .onChange(of: cutTargetWeight) { _, _ in
                normalizeMiniGoalsForSelectedTarget()
            }
            .onChange(of: bulkTargetWeight) { _, _ in
                normalizeMiniGoalsForSelectedTarget()
            }
            .sensoryFeedback(.selection, trigger: reminders.count)
            .sensoryFeedback(.impact(weight: .medium), trigger: healthManager.isImporting) { _, new in new }
            .sensoryFeedback(.success, trigger: healthManager.importResult) { _, new in
                if case .success = new { return true }
                return false
            }
        }
    }

    private func saveMiniGoals() {
        MiniGoalStore.save(miniGoals, for: selectedWeightGoal.wrappedValue)
    }

    private func normalizeMiniGoalsForSelectedTarget() {
        let goal = selectedWeightGoal.wrappedValue
        guard goal.showsTarget else { return }

        var didChange = false
        miniGoals = miniGoals.map { miniGoal in
            var normalizedMiniGoal = miniGoal
            let clampedTarget = MiniGoalStore.clampedTarget(
                miniGoal.targetWeight,
                for: goal,
                mainTarget: selectedTargetWeight.wrappedValue
            )
            if clampedTarget != miniGoal.targetWeight {
                normalizedMiniGoal.targetWeight = clampedTarget
                didChange = true
            }
            return normalizedMiniGoal
        }

        if didChange {
            saveMiniGoals()
        }
    }

}

enum WeightGoal: String, CaseIterable, Identifiable {
    case lose
    case maintain
    case gain

    static let defaultValue: WeightGoal = .maintain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lose:
            "Lose"
        case .maintain:
            "Maintain"
        case .gain:
            "Gain"
        }
    }

    var subtitle: String {
        switch self {
        case .lose:
            "Cut"
        case .maintain:
            "Steady"
        case .gain:
            "Bulk"
        }
    }

    var systemImage: String {
        switch self {
        case .lose:
            "arrow.down.forward.circle.fill"
        case .maintain:
            "equal.circle.fill"
        case .gain:
            "arrow.up.forward.circle.fill"
        }
    }

    var targetTitle: String {
        switch self {
        case .lose:
            "Main Goal"
        case .maintain:
            "Goal"
        case .gain:
            "Main Goal"
        }
    }

    var showsTarget: Bool {
        self != .maintain
    }

    var targetStorageKey: String? {
        switch self {
        case .lose:
            "cutTargetWeight"
        case .maintain:
            nil
        case .gain:
            "bulkTargetWeight"
        }
    }
}

struct GoalPicker: View {
    @Binding var selection: WeightGoal
    let tintColor: Color

    @Namespace private var selectionNamespace
    private let cornerRadius: CGFloat = 14

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WeightGoal.allCases) { goal in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selection = goal
                    }
                    Haptics.selection()
                } label: {
                    ZStack {
                        if selection == goal {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tintColor.opacity(0.18))
                                .overlay {
                                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                        .stroke(.white.opacity(0.35), lineWidth: 1)
                                }
                                .matchedGeometryEffect(id: "selectedGoal", in: selectionNamespace)
                        }

                        VStack(spacing: 6) {
                            Image(systemName: goal.systemImage)
                                .font(.title3.weight(.semibold))

                            VStack(spacing: 1) {
                                Text(goal.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(goal.subtitle)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(selection == goal ? tintColor : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(goal.title) Weight")
                .accessibilityValue(goal.subtitle)
                .accessibilityAddTraits(selection == goal ? .isSelected : [])
            }
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.55))
        }
    }
}

private struct GoalSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.28))
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }
}

struct TargetWeightRow: View {
    let goal: WeightGoal
    @Binding var targetWeight: Double
    let tintColor: Color

    @State private var isEditingTarget = false
    @State private var targetText = ""
    @FocusState private var targetFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(goal.targetTitle)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            } icon: {
                Image(systemName: "flag.checkered")
                    .font(.title3)
                    .foregroundStyle(tintColor)
            }

            Spacer(minLength: 8)

            Button {
                beginEditingTarget()
            } label: {
                targetValue
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(goal.targetTitle) value")
            .accessibilityHint("Double tap to edit with the keyboard")
        }
        .animation(.snappy, value: targetWeight)
    }

    @ViewBuilder
    private var targetValue: some View {
        if isEditingTarget {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("Goal", text: $targetText)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tintColor)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($targetFieldFocused)
                    .frame(width: 76)
                    .onSubmit {
                        commitTargetEdit()
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("Cancel") {
                                cancelTargetEdit()
                            }
                            .foregroundStyle(.red)

                            Spacer()

                            Button("Done") {
                                commitTargetEdit()
                            }
                            .fontWeight(.semibold)
                        }
                    }

                Text("lbs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .onChange(of: targetFieldFocused) { _, focused in
                if !focused {
                    commitTargetEdit()
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(targetWeight, format: .number.precision(.fractionLength(1)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tintColor)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                Text("lbs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func beginEditingTarget() {
        targetText = String(format: "%.1f", targetWeight)
        isEditingTarget = true
        targetFieldFocused = true
        Haptics.selection()
    }

    private func commitTargetEdit() {
        guard isEditingTarget else { return }

        if let value = WeightCalculations.parseWeight(from: targetText) {
            targetWeight = min(max(value, 50), 700)
        }

        isEditingTarget = false
        targetFieldFocused = false
    }

    private func cancelTargetEdit() {
        isEditingTarget = false
        targetFieldFocused = false
    }
}

struct MiniGoalRow: View {
    @Binding var miniGoal: MiniGoal
    let goal: WeightGoal
    let mainTarget: Double
    let tintColor: Color
    let onChanged: () -> Void

    @State private var targetText = ""
    @FocusState private var targetFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.body)
                .foregroundStyle(tintColor)
                .frame(width: 24)

            TextField("Mini Goal", text: $miniGoal.name)
                .onChange(of: miniGoal.name) {
                    onChanged()
                }

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("Goal", text: $targetText)
                    .keyboardType(.decimalPad)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tintColor)
                    .multilineTextAlignment(.trailing)
                    .focused($targetFieldFocused)
                    .frame(width: 62)
                    .onAppear {
                        targetText = String(format: "%.1f", miniGoal.targetWeight)
                    }
                    .onChange(of: targetFieldFocused) { _, focused in
                        if !focused {
                            commitTarget()
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("Cancel") {
                                targetText = String(format: "%.1f", miniGoal.targetWeight)
                                targetFieldFocused = false
                            }
                            .foregroundStyle(.red)

                            Spacer()

                            Button("Done") {
                                commitTarget()
                            }
                            .fontWeight(.semibold)
                        }
                    }

                Text("lbs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commitTarget() {
        if let value = WeightCalculations.parseWeight(from: targetText) {
            miniGoal.targetWeight = MiniGoalStore.clampedTarget(value, for: goal, mainTarget: mainTarget)
            targetText = String(format: "%.1f", miniGoal.targetWeight)
            onChanged()
        }

        targetFieldFocused = false
    }
}

struct HealthImportRows: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    let tintColor: Color

    var body: some View {
        healthImportRow
        workoutImportRow
        dailyActivityImportRow
    }

    // MARK: - Health Import Row

    @ViewBuilder
    private var healthImportRow: some View {
        if !healthManager.isAvailable {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Health")
                        .font(.body)
                    Text("Apple Health isn't available on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(tintColor)
            }
        } else {
            Button {
                Haptics.selection()
                Task {
                    await healthManager.importWeightData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import weight history")
                            .font(.body)

                        if healthManager.isImporting {
                            Text("Reading your weight entries from Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.importResult {
                            resultText(result)
                        } else {
                            Text("Add weight entries from Apple Health to your log")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    if healthManager.isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(healthManager.isImporting)
        }
    }

    @ViewBuilder
    private var workoutImportRow: some View {
        if healthManager.isAvailable {
            Button {
                Haptics.selection()
                Task {
                    await healthManager.importWorkoutData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import workouts")
                            .font(.body)

                        if healthManager.isImportingWorkouts {
                            Text("Reading your workouts from Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.workoutImportResult {
                            resultText(result)
                        } else {
                            Text("Add Apple Health workout summaries to your journal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    if healthManager.isImportingWorkouts {
                        ProgressView()
                    } else {
                        Image(systemName: "figure.run")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(healthManager.isImportingWorkouts)
        }
    }

    @ViewBuilder
    private var dailyActivityImportRow: some View {
        if healthManager.isAvailable {
            Button {
                Haptics.selection()
                Task {
                    await healthManager.importDailyActivityData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import daily activity")
                            .font(.body)

                        if healthManager.isImportingDailyActivity {
                            Text("Reading steps and active energy from Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.dailyActivityImportResult {
                            resultText(result)
                        } else {
                            Text("Add daily step counts and active calories to your journal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    if healthManager.isImportingDailyActivity {
                        ProgressView()
                    } else {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(healthManager.isImportingDailyActivity)
        }
    }

    @ViewBuilder
    private func resultText(_ result: HealthKitManager.ImportResult) -> some View {
        switch result {
        case .success(let imported, let skipped, let removed):
            if imported == 0 && removed == 0 && skipped > 0 {
                Text("All entries already imported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if imported == 0 && removed == 0 && skipped == 0 {
                Text("No weight data found in Apple Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let parts = [
                    imported > 0 ? "\(imported) imported" : nil,
                    removed > 0 ? "\(removed) removed" : nil,
                    skipped > 0 ? "\(skipped) skipped" : nil,
                ].compactMap { $0 }.joined(separator: ", ")
                Text(parts)
                    .font(.caption)
                    .foregroundStyle(tintColor)
            }
        case .error(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
