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
    enum Content {
        case settings
        case goals
    }

    var showsDoneButton = true
    var content: Content = .settings
    var isProfile = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @AppStorage("customTintHex") private var customTintHex = ""
    @AppStorage("calendarDayStat") private var calendarDayStat = CalendarDayStat.defaultValue.rawValue
    @State private var reminders: [Reminder] = []
    @State private var bigGoals: [BigGoal] = []
    @State private var miniGoals: [MiniGoal] = []
    @State private var showDeveloperTools = false
    @State private var hasLoadedDeferredContent = false

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

    private var selectedCalendarDayStat: Binding<CalendarDayStat> {
        Binding(
            get: { CalendarDayStat(rawValue: calendarDayStat) ?? .defaultValue },
            set: { calendarDayStat = $0.rawValue }
        )
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    private var weightEntries: [WeightEntry] {
        entries.filter(\.includesWeight)
    }

    private var customColor: Binding<Color> {
        Binding(
            get: {
                guard !customTintHex.isEmpty, let color = Color(hex: customTintHex) else {
                    return .blue
                }
                return color
            },
            set: { customTintHex = $0.toHex() }
        )
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

    private var goalProgress: WeightCalculations.GoalProgress? {
        guard selectedWeightGoal.wrappedValue.showsTarget else { return nil }
        return WeightCalculations.goalProgress(
            from: entries,
            goal: selectedWeightGoal.wrappedValue,
            targetWeight: selectedTargetWeight.wrappedValue,
            over: .year
        )
    }

    private var goalTrackTargets: [Double] {
        let targets = Set(bigGoals.map(\.targetWeight) + miniGoals.map(\.targetWeight) + [selectedTargetWeight.wrappedValue])

        switch selectedWeightGoal.wrappedValue {
        case .lose:
            return targets.sorted(by: >)
        case .gain:
            return targets.sorted()
        case .maintain:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if content == .goals {
                    goalSettingsSection
                } else {
                if isProfile {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Profile")
                                    .font(.headline)
                                Text("Your health and journal preferences")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    Picker(selection: selectedTint) {
                        ForEach(AppTint.presets) { tint in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(tint.color)
                                    .frame(width: 12, height: 12)

                                Text(tint.title)
                                    .foregroundStyle(tint.color)
                            }
                            .tag(tint)
                        }

                        HStack(spacing: 10) {
                            Circle()
                                .fill(selectedTint.wrappedValue == .custom ? tintColor : .gray.opacity(0.3))
                                .frame(width: 12, height: 12)

                            Text("Custom")
                                .foregroundStyle(selectedTint.wrappedValue == .custom ? tintColor : .primary)
                        }
                        .tag(AppTint.custom)
                    }
                    label: {
                        Text("Tint Color")
                            .foregroundStyle(tintColor)
                    }

                    if selectedTint.wrappedValue == .custom {
                        HStack {
                            ColorPicker("Custom Color",
                                        selection: customColor,
                                        supportsOpacity: false)
                        }
                    }

                    Menu {
                        Picker(selection: selectedCalendarDayStat) {
                            ForEach(CalendarDayStat.allCases) { stat in
                                Label(stat.title, systemImage: stat.systemImage)
                                    .tag(stat)
                            }
                        } label: {
                            EmptyView()
                        }
                    } label: {
                        HStack {
                            Text("Primary Stat")
                                .foregroundStyle(.primary)

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: selectedCalendarDayStat.wrappedValue.systemImage)
                                    .font(.system(size: 13))

                                Text(selectedCalendarDayStat.wrappedValue.title)

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12).weight(.semibold))
                            }
                            .foregroundStyle(tintColor)
                        }
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Choose the stat shown on logged days in the calendar view.")
                }

                if hasLoadedDeferredContent {
                if isProfile {
                    goalSettingsSection
                }

                Section {
                    if healthManager.isAvailable {
                        Toggle("Import Apple Health updates automatically", isOn: $autoSyncHealthKit)
                            .tint(tintColor)
                    }
                    HealthImportRows(tintColor: tintColor)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Bring in weight entries, workouts, and daily activity summaries from Apple Health automatically when the app opens, or run an import whenever you want.")
                }

                Section {
                    Toggle("Daily Reminders", isOn: $remindersEnabled)
                        .tint(tintColor)
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
                    Button {
                        Haptics.selection()
                        showDeveloperTools = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            
                            Text("Developer Testing Tools")
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Warning: These options are for developer testing only.")
                }
                } else {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading settings…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                }
            }
            .navigationTitle(isProfile ? "Profile" : (content == .goals ? "Goals" : "Settings"))
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            Haptics.selection()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .task {
                guard !hasLoadedDeferredContent else { return }

                // Let the sheet commit its first frame before loading and rendering
                // the less immediately useful settings sections.
                await Task.yield()
                guard !Task.isCancelled else { return }

                if content == .settings {
                    reminders = notificationManager.loadReminders()
                }
                loadGoals()
                withAnimation(.easeInOut(duration: 0.2)) {
                    hasLoadedDeferredContent = true
                }
            }
            .onChange(of: weightGoal) { _, _ in
                loadGoals()
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
        .tint(tintColor)
        .sheet(isPresented: $showDeveloperTools) {
            DeveloperView()
                .liquidGlassSheetPresentation()
        }
    }

    @ViewBuilder
    private var goalSettingsSection: some View {
        Section {
            GoalPicker(selection: selectedWeightGoal, tintColor: tintColor)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)

            if selectedWeightGoal.wrappedValue.showsTarget {
                goalProgressBreakdown
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)

                ForEach(bigGoals.indices, id: \.self) { bigIndex in
                    TargetWeightRow(
                            goal: selectedWeightGoal.wrappedValue,
                            targetWeight: $bigGoals[bigIndex].targetWeight,
                            tintColor: tintColor,
                            currentWeight: weightEntries.first?.weight
                        )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .onChange(of: bigGoals[bigIndex].targetWeight) { _, _ in
                        saveBigGoals()
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteBigGoal(bigGoals[bigIndex])
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    ForEach(miniGoals.indices.filter { miniGoals[$0].parentBigGoalID == bigGoals[bigIndex].id }, id: \.self) { miniIndex in
                        MiniGoalRow(
                            miniGoal: $miniGoals[miniIndex],
                            goal: selectedWeightGoal.wrappedValue,
                            mainTarget: bigGoals[bigIndex].targetWeight,
                            tintColor: tintColor,
                            currentWeight: weightEntries.first?.weight,
                            onChanged: saveMiniGoals
                        )
                        .padding(.leading, 32)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions {
                            Button(role: .destructive) {
                                deleteSmallGoal(miniGoals[miniIndex])
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button(action: { addSmallGoal(to: bigGoals[bigIndex]) }) {
                        Label("Add small goal", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 32)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                Button(action: addBigGoal) {
                    Label("Add big goal", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
            } else {
                Menu {
                    Button("Lose weight", systemImage: WeightGoal.lose.systemImage) {
                        startGoal(.lose)
                    }
                    Button("Gain weight", systemImage: WeightGoal.gain.systemImage) {
                        startGoal(.gain)
                    }
                } label: {
                    Label("Add goal", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparator(.hidden)
            }
        } header: {
            Text("Goals")
        } footer: {
            Text(selectedWeightGoal.wrappedValue.showsTarget
                 ? "Small goals support your big goals and are checked off when you reach their weight."
                 : "Add a lose or gain goal anytime.")
        }
    }

    private var goalProgressBreakdown: some View {
        let progress = goalProgress
        let completion = progress.map { progress in
            guard progress.totalDistance > 0 else { return 0 }
            return min(max(progress.completedDistance / progress.totalDistance, 0), 1)
        } ?? 0
        let percentage = Int((completion * 100).rounded())

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Progress", systemImage: selectedWeightGoal.wrappedValue.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tintColor)

                Spacer()

                Text("\(percentage)%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }

            GoalProgressTrack(
                goal: selectedWeightGoal.wrappedValue,
                targets: goalTrackTargets,
                currentWeight: weightEntries.first?.weight,
                tintColor: tintColor
            )

            HStack {
                Text("\(weightEntries.first?.weight.formatted(.number.precision(.fractionLength(1))) ?? "—") lbs now")
                Spacer()
                Text("Target \(selectedTargetWeight.wrappedValue.formatted(.number.precision(.fractionLength(1)))) lbs")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal progress, \(percentage) percent complete")
    }

    private func addSmallGoal(to bigGoal: BigGoal) {
        withAnimation {
            miniGoals.append(
                MiniGoal(
                    parentGoal: selectedWeightGoal.wrappedValue,
                    parentBigGoalID: bigGoal.id,
                    targetWeight: MiniGoalStore.defaultTarget(
                        for: selectedWeightGoal.wrappedValue,
                        mainTarget: bigGoal.targetWeight,
                        existingGoals: miniGoals.filter { $0.parentBigGoalID == bigGoal.id }
                    )
                )
            )
        }
        saveMiniGoals()
        Haptics.selection()
    }

    private func addBigGoal() {
        let goal = selectedWeightGoal.wrappedValue
        withAnimation {
            bigGoals.append(
                BigGoal(
                    parentGoal: goal,
                    targetWeight: BigGoalStore.defaultTarget(
                        for: goal,
                        existingGoals: bigGoals,
                        fallbackTarget: selectedTargetWeight.wrappedValue
                    )
                )
            )
        }
        saveBigGoals()
        Haptics.selection()
    }

    private func deleteBigGoal(_ bigGoal: BigGoal) {
        withAnimation {
            bigGoals.removeAll { $0.id == bigGoal.id }
            miniGoals.removeAll { $0.parentBigGoalID == bigGoal.id }
        }
        saveBigGoals()
        saveMiniGoals()
    }

    private func deleteSmallGoal(_ smallGoal: MiniGoal) {
        withAnimation {
            miniGoals.removeAll { $0.id == smallGoal.id }
        }
        saveMiniGoals()
    }

    private func startGoal(_ goal: WeightGoal) {
        weightGoal = goal.rawValue
        Haptics.selection()
    }

    private func loadGoals() {
        let goal = selectedWeightGoal.wrappedValue
        miniGoals = MiniGoalStore.load(for: goal)
        bigGoals = BigGoalStore.load(for: goal, fallbackTarget: selectedTargetWeight.wrappedValue)
        if let firstBigGoal = bigGoals.first, miniGoals.contains(where: { $0.parentBigGoalID == nil }) {
            miniGoals = miniGoals.map { miniGoal in
                var migrated = miniGoal
                if migrated.parentBigGoalID == nil { migrated.parentBigGoalID = firstBigGoal.id }
                return migrated
            }
            saveMiniGoals()
        }
        syncActiveBigGoal()
    }

    private func saveBigGoals() {
        BigGoalStore.save(bigGoals, for: selectedWeightGoal.wrappedValue)
        syncActiveBigGoal()
    }

    private func syncActiveBigGoal() {
        let goal = selectedWeightGoal.wrappedValue
        guard let target = BigGoalStore.activeTarget(
            for: goal,
            goals: bigGoals,
            currentWeight: weightEntries.first?.weight
        ) else { return }

        selectedTargetWeight.wrappedValue = target
        normalizeMiniGoalsForSelectedTarget()
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

    var body: some View {
        Picker("Goal", selection: $selection) {
            ForEach(WeightGoal.allCases) { goal in
                Text(goal.title).tag(goal)
            }
        }
        .pickerStyle(.segmented)
        .tint(tintColor)
        .labelsHidden()
        .accessibilityLabel("Weight goal")
        .onChange(of: selection) { _, _ in Haptics.selection() }
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

struct GoalProgressTrack: View {
    let goal: WeightGoal
    let targets: [Double]
    let currentWeight: Double?
    let tintColor: Color

    var body: some View {
        GeometryReader { proxy in
            let edgeInset: CGFloat = 0
            let gapWidth: CGFloat = 4
            let intervalCount = max(targets.count - 1, 0)
            let availableWidth = max(
                proxy.size.width - edgeInset * 2 - gapWidth * CGFloat(max(intervalCount - 1, 0)),
                0
            )

            ZStack(alignment: .topLeading) {
                HStack(spacing: gapWidth) {
                    ForEach(Array(targets.indices.dropLast()), id: \.self) { index in
                        Capsule()
                            .fill(hasReached(targets[index + 1]) ? tintColor : Color.secondary.opacity(0.32))
                            .frame(width: intervalWidth(at: index, availableWidth: availableWidth), height: 8)
                    }
                }
                .offset(x: edgeInset, y: 2)

            }
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func hasReached(_ target: Double) -> Bool {
        guard let currentWeight else { return false }

        switch goal {
        case .lose:
            return currentWeight <= target
        case .gain:
            return currentWeight >= target
        case .maintain:
            return false
        }
    }

    private var totalDistance: Double {
        zip(targets, targets.dropFirst()).reduce(0) { distance, pair in
            distance + abs(pair.0 - pair.1)
        }
    }

    private func intervalWidth(at index: Int, availableWidth: CGFloat) -> CGFloat {
        guard totalDistance > 0 else { return 0 }
        return availableWidth * CGFloat(abs(targets[index] - targets[index + 1])) / CGFloat(totalDistance)
    }

    private var accessibilityDescription: String {
        let formattedTargets = targets.map { String(format: "%.1f", $0) }.joined(separator: ", ")
        return "Proportional goal timeline at \(formattedTargets) pounds"
    }
}

struct TargetWeightRow: View {
    let goal: WeightGoal
    @Binding var targetWeight: Double
    let tintColor: Color
    let currentWeight: Double?

    @State private var isEditingTarget = false
    @State private var targetText = ""
    @FocusState private var targetFieldFocused: Bool

    init(
        goal: WeightGoal,
        targetWeight: Binding<Double>,
        tintColor: Color,
        currentWeight: Double? = nil
    ) {
        self.goal = goal
        _targetWeight = targetWeight
        self.tintColor = tintColor
        self.currentWeight = currentWeight
    }

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text("Big goal")
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            } icon: {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isComplete ? tintColor : .secondary)
            }

            Spacer(minLength: 8)

            Button {
                beginEditingTarget()
            } label: {
                targetValue
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Big goal value")
            .accessibilityHint("Double tap to edit with the keyboard")
        }
        .animation(.snappy, value: targetWeight)
    }

    private var isComplete: Bool {
        guard let currentWeight else { return false }
        switch goal {
        case .lose: return currentWeight <= targetWeight
        case .gain: return currentWeight >= targetWeight
        case .maintain: return false
        }
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
    let currentWeight: Double?
    let onChanged: () -> Void

    @State private var targetText = ""
    @FocusState private var targetFieldFocused: Bool

    init(
        miniGoal: Binding<MiniGoal>,
        goal: WeightGoal,
        mainTarget: Double,
        tintColor: Color,
        currentWeight: Double? = nil,
        onChanged: @escaping () -> Void
    ) {
        _miniGoal = miniGoal
        self.goal = goal
        self.mainTarget = mainTarget
        self.tintColor = tintColor
        self.currentWeight = currentWeight
        self.onChanged = onChanged
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(isComplete ? tintColor : .secondary)
                .frame(width: 24)

            TextField("Small goal", text: $miniGoal.name)
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

    private var isComplete: Bool {
        guard let currentWeight else { return false }
        switch goal {
        case .lose: return currentWeight <= miniGoal.targetWeight
        case .gain: return currentWeight >= miniGoal.targetWeight
        case .maintain: return false
        }
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
        sleepImportRow
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
            .contextMenu {
                Button {
                    Haptics.impact()
                    Task {
                        await healthManager.forceReimportWeightData(modelContext: modelContext)
                    }
                } label: {
                    Label("Force reimport all weight", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(healthManager.isImporting)
            }
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
            .contextMenu {
                Button {
                    Haptics.impact()
                    Task {
                        await healthManager.forceReimportWorkoutData(modelContext: modelContext)
                    }
                } label: {
                    Label("Force reimport all workouts", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(healthManager.isImportingWorkouts)
            }
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
            .contextMenu {
                Button {
                    Haptics.impact()
                    Task {
                        await healthManager.forceReimportDailyActivityData(modelContext: modelContext)
                    }
                } label: {
                    Label("Force reimport all activity", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(healthManager.isImportingDailyActivity)
            }
        }
    }

    @ViewBuilder
    private var sleepImportRow: some View {
        if healthManager.isAvailable {
            Button {
                Haptics.selection()
                Task {
                    await healthManager.importSleepData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import sleep")
                            .font(.body)

                        if healthManager.isImportingSleep {
                            Text("Reading sleep from Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.sleepImportResult {
                            resultText(result)
                        } else {
                            Text("Add Apple Health sleep summaries to your journal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    if healthManager.isImportingSleep {
                        ProgressView()
                    } else {
                        Image(systemName: "bed.double.fill")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(healthManager.isImportingSleep)
            .contextMenu {
                Button {
                    Haptics.impact()
                    Task {
                        await healthManager.forceReimportSleepData(modelContext: modelContext)
                    }
                } label: {
                    Label("Force reimport all sleep", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(healthManager.isImportingSleep)
            }
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
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self, SleepEntry.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}

// MARK: - Developer View
struct DeveloperView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding_v2") private var hasCompletedOnboarding = false
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @State private var isDeveloperResetting = false
    @State private var resetCompleted = false
    
    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.title3)
                            Text("WARNING: Developers Only")
                                .font(.headline)
                                .foregroundStyle(.red)
                                .fontWeight(.bold)
                        }
                        
                        Text("These actions will purge and reset the local persistent store. Do not use this in production as it will permanently delete your personal weight history and HealthKit mappings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.red.opacity(0.08))
                
                Section {
                    Button(role: .destructive) {
                        isDeveloperResetting = true
                        Haptics.impact(.heavy)
                        
                        ScaleApp.resetAndPopulateMockData(context: modelContext)
                        
                        isDeveloperResetting = false
                        resetCompleted = true
                        Haptics.success()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            resetCompleted = false
                        }
                    } label: {
                        HStack {
                            Label("Reset & Load Mock Data", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            if isDeveloperResetting {
                                ProgressView()
                            } else if resetCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(isDeveloperResetting)

                    Toggle("Bypass Onboarding", isOn: $hasCompletedOnboarding)
                        .tint(tintColor)
                } header: {
                    Text("Developer Actions")
                } footer: {
                    Text("Forces the app to load a mock 30-day weight database with workouts and sleep summaries, and lets you toggle the onboarding experience.")
                }
            }
            .navigationTitle("Developer Testing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.selection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(tintColor)
    }
}
