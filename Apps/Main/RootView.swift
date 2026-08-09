//
//  RootView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit

private enum JournalSection: Hashable {
    case calendar
    case memories
}

struct RootView: View {
    enum TabTapAction: Equatable {
        case switchTab
        case scrollJournalToBottom
        case ignore
    }

    @Binding var selectedTab: Int
    @Binding var showLog: Bool
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("showChangePill") private var showChangePill = true
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("customTintHex") private var customTintHex = ""
    @AppStorage("journalTimelineFilter") private var journalTimelineFilterRaw = OverviewView.TimelineContentFilter.images.rawValue
    @State private var historyScrollRequest = 0
    @State private var historySelectedEntry: WeightEntry?
    @State private var journalScrollToBottomRequest = 0
    @State private var logDate: Date?
    @State private var initialEntryMode: EntryView.EntryMode?
    @State private var showGoalCelebration = false
    @State private var goalCelebrationID = 0
    @State private var goalCelebrationMessage: Text = Text("Closer to goal")
    @State private var goalCelebrationImage = "target"
    @State private var goalCelebrationType: CelebrationType = .confetti
    @State private var reachedGoalContext: ReachedGoalContext?
    @State private var celebrationQueue: [(message: Text, systemImage: String, type: CelebrationType)] = []
    @State private var isCelebrationRunning = false
    @State private var chartSelection: ChartDaySelection?
    @State private var overviewTimelineFocusRequest = 0
    @State private var journalSection: JournalSection = .calendar
    @State private var showSettings = false

    private var selectedTint: AppTint {
        AppTint(rawValue: appTint) ?? .defaultValue
    }

    private var weightEntries: [WeightEntry] {
        entries.filter(\.includesWeight)
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                guard newValue != selectedTab else { return }
                Haptics.selection()
                selectedTab = newValue
            }
        )
    }

    static func isPillVisible(selectedTab: Int, settingsTab: Int = 4) -> Bool {
        selectedTab != settingsTab
    }

    static func shouldUpdateSelectedTab(from currentTab: Int, to newTab: Int) -> Bool {
        currentTab != newTab
    }

    static func shouldScrollJournalToBottom(
        tappedIndex: Int,
        wasReselected: Bool,
        journalTabIndex: Int = 1
    ) -> Bool {
        wasReselected && tappedIndex == journalTabIndex
    }

    static func actionForTabTap(
        currentTab: Int,
        tappedTab: Int,
        journalTabIndex: Int = 1
    ) -> TabTapAction {
        if currentTab == tappedTab {
            return tappedTab == journalTabIndex ? .scrollJournalToBottom : .ignore
        }

        return .switchTab
    }

    var body: some View {
        NavigationStack {
            TabView(selection: tabSelection) {
                    OverviewView(
                        chartSelection: $chartSelection,
                        timelineFocusRequest: overviewTimelineFocusRequest,
                        onOpenSettings: {
                            openSettingsTab()
                        },
                        onOpenHistory: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selectedTab = 1
                            }
                            Haptics.selection()
                        },
                        onAddWeight: {
                            Haptics.impact()
                            initialEntryMode = .weight
                            logDate = nil
                            showLog = true
                        },
                        onAddMoment: {
                            Haptics.impact()
                            initialEntryMode = .moment
                            logDate = nil
                            showLog = true
                        },
                        showsCharts: true,
                        showsTimeline: false,
                        isMomentsTab: false
                    )
                    .tag(3)
                    .tabItem {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel("Home")

                    JournalHubView(
                        scrollToEntryTrigger: historyScrollRequest,
                        focusedEntry: historySelectedEntry,
                        scrollToBottomTrigger: journalScrollToBottomRequest,
                        showLog: $showLog,
                        logDate: $logDate,
                        chartSelection: $chartSelection,
                        timelineFocusRequest: overviewTimelineFocusRequest,
                        section: $journalSection,
                        onOpenSettings: {
                            openSettingsTab()
                        },
                        onAddMoment: {
                            Haptics.impact()
                            initialEntryMode = .moment
                            logDate = nil
                            showLog = true
                        }
                    )
                    .tag(1)
                    .tabItem {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Journal")

                    ProfileView()
                        .tag(4)
                        .tabItem {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("Profile")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationToolbar }
        }
        .tint(selectedTint.color)
        .id("\(appTint)-\(customTintHex)")
        .overlay {
            if showGoalCelebration {
                GoalCelebrationView(
                    tintColor: selectedTint.color,
                    message: goalCelebrationMessage,
                    systemImage: goalCelebrationImage,
                    type: goalCelebrationType
                )
                    .id(goalCelebrationID)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showLog, onDismiss: {
            logDate = nil
            initialEntryMode = nil
        }) {
            EntryView(
                historyScrollRequest: $historyScrollRequest,
                historySelectedEntry: $historySelectedEntry,
                logDate: logDate,
                latestWeight: weightEntries.first?.weight,
                initialEntryMode: initialEntryMode
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $reachedGoalContext) { context in
            GoalTargetUpdateSheet(
                goal: context.goal,
                reachedWeight: context.weight,
                tintColor: selectedTint.color
            )
        }
        .onAppear {
            WeightWidgetSnapshotStore.refresh(using: entries)
        }
        .onChange(of: widgetSnapshotSignature) { _, _ in
            WeightWidgetSnapshotStore.refresh(using: entries)
        }
        .onChange(of: appTint) { _, _ in
            WeightWidgetSnapshotStore.refresh(using: entries)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogFirstWeight)) { _ in
            enqueueCelebration(message: Text("One step closer to your goal"), systemImage: "figure.walk", type: .confetti)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didMoveCloserToGoal)) { notification in
            if let payload = notification.object as? CloserToGoalPayload,
               let miniGoal = payload.achievedMiniGoal {
                enqueueCelebration(message: Text("\(miniGoal.name) achieved!"), systemImage: "flag.fill", type: .fireworks)
            } else if let payload = notification.object as? CloserToGoalPayload {
                let formatted = String(format: "%.1f", payload.distanceCloser)
                let message = Text("\(Text(formatted).foregroundStyle(selectedTint.color)) lbs closer to goal")
                enqueueCelebration(message: message, systemImage: "target", type: .confetti)
            } else {
                enqueueCelebration(message: Text("Closer to goal"), systemImage: "target", type: .confetti)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReachWeightGoal)) { notification in
            guard let payload = notification.object as? GoalReachedPayload else { return }
            enqueueCelebration(message: Text("Goal reached"), systemImage: "party.popper.fill", type: .fireworks)
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                await MainActor.run {
                    reachedGoalContext = ReachedGoalContext(goal: payload.goal, weight: payload.weight)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSetNewMaxStreak)) { notification in
            let streak = notification.object as? Int ?? 0
            let message = Text("New best streak — \(Text("\(streak)").foregroundStyle(selectedTint.color)) days")
            enqueueCelebration(message: message, systemImage: "flame.fill")
        }
        .sensoryFeedback(.success, trigger: goalCelebrationID)
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        if selectedTab == 1 {
            ToolbarItem(placement: .principal) {
                JournalViewSwitcher(section: $journalSection)
                    .frame(width: 220)
            }

            if journalSection == .memories {
                ToolbarItem(placement: .topBarTrailing) {
                    journalFilterButton
                }
            }
        }

        if selectedTab == 3 {
            ToolbarItem(placement: .principal) {
                TimeRangePill()
            }

            ToolbarItem(placement: .topBarTrailing) {
                addButton
            }
        }

        if selectedTab == 4 {
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
        }
    }

    private func enqueueCelebration(message: Text, systemImage: String, type: CelebrationType = .confetti) {
        celebrationQueue.append((message: message, systemImage: systemImage, type: type))
        if !isCelebrationRunning {
            showNextCelebration()
        }
    }

    private func openSettingsTab() {
        Haptics.selection()
        withAnimation(.snappy) {
            selectedTab = 4
        }
    }

    private func showNextCelebration() {
        guard !celebrationQueue.isEmpty else {
            isCelebrationRunning = false
            return
        }
        isCelebrationRunning = true
        let next = celebrationQueue.removeFirst()
        goalCelebrationMessage = next.message
        goalCelebrationImage = next.systemImage
        goalCelebrationType = next.type
        goalCelebrationID += 1

        withAnimation(.easeOut(duration: 0.18)) {
            showGoalCelebration = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1.45))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.22)) {
                    showGoalCelebration = false
                }
            }
            try? await Task.sleep(for: .milliseconds(260))
            await MainActor.run {
                showNextCelebration()
            }
        }
    }

    private var addButton: some View {
        Button {
            Haptics.impact()
            initialEntryMode = nil
            logDate = nil
            showLog = true
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(.primary)
        }
        .tint(.primary)
        .accessibilityLabel("Log")
    }

    private var settingsButton: some View {
        Button {
            Haptics.selection()
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
    }

    private var journalFilterButton: some View {
        Menu {
            Picker("Show", selection: $journalTimelineFilterRaw) {
                ForEach(OverviewView.TimelineContentFilter.allCases) { filter in
                    Text(filter.title).tag(filter.rawValue)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Filter")
    }

    private var widgetSnapshotSignature: Int {
        var hasher = Hasher()
        hasher.combine(weightEntries.count)
        hasher.combine(weightEntries.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(weightEntries.first?.weight ?? 0)
        return hasher.finalize()
    }
}

private struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileCard
                ProfileGoalsView()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var profileCard: some View {
        HStack(spacing: 18) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Profile")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Your health and journal preferences")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

}

private struct ProfileGoalsView: View {
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("weightGoal") private var weightGoal = WeightGoal.defaultValue.rawValue
    @AppStorage("cutTargetWeight") private var cutTargetWeight = 180.0
    @AppStorage("bulkTargetWeight") private var bulkTargetWeight = 180.0
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @State private var bigGoals: [BigGoal] = []
    @State private var miniGoals: [MiniGoal] = []

    private var selectedGoal: Binding<WeightGoal> {
        Binding(get: { WeightGoal(rawValue: weightGoal) ?? .defaultValue }, set: { weightGoal = $0.rawValue })
    }

    private var targetWeight: Binding<Double> {
        Binding(
            get: { selectedGoal.wrappedValue == .gain ? bulkTargetWeight : cutTargetWeight },
            set: { newValue in
                if selectedGoal.wrappedValue == .gain { bulkTargetWeight = newValue }
                else if selectedGoal.wrappedValue == .lose { cutTargetWeight = newValue }
            }
        )
    }

    private var tintColor: Color { (AppTint(rawValue: appTint) ?? .defaultValue).color }
    private var currentWeight: Double? { entries.first(where: \.includesWeight)?.weight }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Goals", systemImage: "target")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tintColor)

            GoalPicker(selection: selectedGoal, tintColor: tintColor)

            if selectedGoal.wrappedValue.showsTarget {
                goalProgressSummary

                ForEach(bigGoals.indices, id: \.self) { index in
                    TargetWeightRow(
                        goal: selectedGoal.wrappedValue,
                        targetWeight: $bigGoals[index].targetWeight,
                        tintColor: tintColor,
                        currentWeight: currentWeight
                    )
                    .onChange(of: bigGoals[index].targetWeight) { _, _ in saveBigGoals() }

                    ForEach(miniGoals.indices.filter { miniGoals[$0].parentBigGoalID == bigGoals[index].id }, id: \.self) { miniIndex in
                        MiniGoalRow(
                            miniGoal: $miniGoals[miniIndex],
                            goal: selectedGoal.wrappedValue,
                            mainTarget: bigGoals[index].targetWeight,
                            tintColor: tintColor,
                            currentWeight: currentWeight,
                            onChanged: saveMiniGoals
                        )
                        .padding(.leading, 24)
                    }

                    Button { addSmallGoal(to: bigGoals[index]) } label: {
                        Label {
                            Text("Add small goal")
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(tintColor)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                        .padding(.leading, 24)
                }

                Button(action: addBigGoal) {
                    Label {
                        Text("Add big goal")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(tintColor)
                    }
                }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
            } else {
                Menu {
                    Button("Lose weight", systemImage: WeightGoal.lose.systemImage) { selectedGoal.wrappedValue = .lose }
                    Button("Gain weight", systemImage: WeightGoal.gain.systemImage) { selectedGoal.wrappedValue = .gain }
                } label: {
                    Label("Add goal", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .task { loadGoals() }
        .onChange(of: weightGoal) { _, _ in loadGoals() }
        .onChange(of: cutTargetWeight) { _, _ in normalizeMiniGoals() }
        .onChange(of: bulkTargetWeight) { _, _ in normalizeMiniGoals() }
    }

    private var goalTrackTargets: [Double] {
        var targets = Set(bigGoals.map(\.targetWeight) + miniGoals.map(\.targetWeight) + [targetWeight.wrappedValue])
        if let currentWeight {
            targets.insert(currentWeight)
        }

        switch selectedGoal.wrappedValue {
        case .lose:
            return targets.sorted(by: >)
        case .gain:
            return targets.sorted()
        case .maintain:
            return []
        }
    }

    private var goalProgressSummary: some View {
        let progress = WeightCalculations.goalProgress(
            from: entries,
            goal: selectedGoal.wrappedValue,
            targetWeight: targetWeight.wrappedValue,
            over: .year
        )
        let completion = progress.map { progress in
            guard progress.totalDistance > 0 else { return 0 }
            return min(max(progress.completedDistance / progress.totalDistance, 0), 1)
        } ?? 0
        let percentage = Int((completion * 100).rounded())

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tintColor)

                Spacer()

                Text("\(percentage)%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }

            GoalProgressTrack(
                goal: selectedGoal.wrappedValue,
                targets: goalTrackTargets,
                currentWeight: currentWeight,
                tintColor: tintColor
            )

            HStack {
                Text("\(currentWeight?.formatted(.number.precision(.fractionLength(1))) ?? "—") lbs now")
                Spacer()
                Text("Target \(targetWeight.wrappedValue.formatted(.number.precision(.fractionLength(1)))) lbs")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal progress, \(percentage) percent complete")
    }

    private func loadGoals() {
        let goal = selectedGoal.wrappedValue
        miniGoals = MiniGoalStore.load(for: goal)
        bigGoals = BigGoalStore.load(for: goal, fallbackTarget: targetWeight.wrappedValue)
        if let first = bigGoals.first, miniGoals.contains(where: { $0.parentBigGoalID == nil }) {
            miniGoals = miniGoals.map { var goal = $0; if goal.parentBigGoalID == nil { goal.parentBigGoalID = first.id }; return goal }
            saveMiniGoals()
        }
        syncActiveTarget()
    }

    private func addBigGoal() {
        let goal = selectedGoal.wrappedValue
        bigGoals.append(BigGoal(parentGoal: goal, targetWeight: BigGoalStore.defaultTarget(for: goal, existingGoals: bigGoals, fallbackTarget: targetWeight.wrappedValue)))
        saveBigGoals()
        Haptics.selection()
    }

    private func addSmallGoal(to bigGoal: BigGoal) {
        miniGoals.append(MiniGoal(parentGoal: selectedGoal.wrappedValue, parentBigGoalID: bigGoal.id, targetWeight: MiniGoalStore.defaultTarget(for: selectedGoal.wrappedValue, mainTarget: bigGoal.targetWeight, existingGoals: miniGoals.filter { $0.parentBigGoalID == bigGoal.id })))
        saveMiniGoals()
        Haptics.selection()
    }

    private func saveBigGoals() { BigGoalStore.save(bigGoals, for: selectedGoal.wrappedValue); syncActiveTarget() }
    private func saveMiniGoals() { MiniGoalStore.save(miniGoals, for: selectedGoal.wrappedValue) }

    private func syncActiveTarget() {
        guard let activeTarget = BigGoalStore.activeTarget(for: selectedGoal.wrappedValue, goals: bigGoals, currentWeight: currentWeight) else { return }
        targetWeight.wrappedValue = activeTarget
        normalizeMiniGoals()
    }

    private func normalizeMiniGoals() {
        let goal = selectedGoal.wrappedValue
        guard goal.showsTarget else { return }
        miniGoals = miniGoals.map { miniGoal in
            var normalized = miniGoal
            normalized.targetWeight = MiniGoalStore.clampedTarget(miniGoal.targetWeight, for: goal, mainTarget: targetWeight.wrappedValue)
            return normalized
        }
        saveMiniGoals()
    }
}

private struct JournalHubView: View {
    let scrollToEntryTrigger: Int
    let focusedEntry: WeightEntry?
    let scrollToBottomTrigger: Int
    @Binding var showLog: Bool
    @Binding var logDate: Date?
    @Binding var chartSelection: ChartDaySelection?
    let timelineFocusRequest: Int
    @Binding var section: JournalSection
    let onOpenSettings: () -> Void
    let onAddMoment: () -> Void

    var body: some View {
        Group {
            switch section {
            case .calendar:
                JournalView(
                    scrollToEntryTrigger: scrollToEntryTrigger,
                    focusedEntry: focusedEntry,
                    scrollToBottomTrigger: scrollToBottomTrigger,
                    showLog: $showLog,
                    logDate: $logDate
                )

            case .memories:
                OverviewView(
                    chartSelection: $chartSelection,
                    timelineFocusRequest: timelineFocusRequest,
                    onOpenSettings: onOpenSettings,
                    onOpenHistory: {},
                    onAddWeight: {},
                    onAddMoment: onAddMoment,
                    showsCharts: false,
                    showsTimeline: true,
                    isMomentsTab: true
                )
            }
        }
        .animation(.snappy, value: section)
    }
}

private struct JournalViewSwitcher: View {
    @Binding var section: JournalSection

    var body: some View {
        Picker("Journal view", selection: $section) {
            Text("Calendar").tag(JournalSection.calendar)
            Text("Moments").tag(JournalSection.memories)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Journal view")
        .accessibilityHint("Switches between the calendar and moments list")
        .onChange(of: section) { _, _ in Haptics.selection() }
    }
}

struct GoalReachedPayload {
    let goal: WeightGoal
    let weight: Double
}

struct ReachedGoalContext: Identifiable {
    let id = UUID()
    let goal: WeightGoal
    let weight: Double
}

struct TabBarControllerObserver: UIViewControllerRepresentable {
    let onTabInteraction: (_ tappedIndex: Int, _ wasReselected: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTabInteraction: onTabInteraction)
    }

    func makeUIViewController(context: Context) -> ObserverViewController {
        let viewController = ObserverViewController()
        viewController.coordinator = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.coordinator = context.coordinator
        uiViewController.attachIfNeeded()
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        private let onTabInteraction: (_ tappedIndex: Int, _ wasReselected: Bool) -> Void
        private var lastSelectedIndex: Int?

        init(onTabInteraction: @escaping (_ tappedIndex: Int, _ wasReselected: Bool) -> Void) {
            self.onTabInteraction = onTabInteraction
        }

        func attach(to tabBarController: UITabBarController) {
            tabBarController.delegate = self
            lastSelectedIndex = tabBarController.selectedIndex
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            let selectedIndex = tabBarController.selectedIndex
            let wasReselected = lastSelectedIndex == selectedIndex
            onTabInteraction(selectedIndex, wasReselected)
            lastSelectedIndex = selectedIndex
        }
    }

    final class ObserverViewController: UIViewController {
        weak var coordinator: Coordinator?
        private weak var observedTabBarController: UITabBarController?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfNeeded()
        }

        func attachIfNeeded() {
            guard let tabBarController, observedTabBarController !== tabBarController else { return }
            observedTabBarController = tabBarController
            coordinator?.attach(to: tabBarController)
        }
    }
}

#Preview {
    RootView(selectedTab: .constant(1), showLog: .constant(false))
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self, SleepEntry.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}

extension View {
    func liquidGlassSheetPresentation(cornerRadius: CGFloat = 36) -> some View {
        self
            .presentationBackground(.clear)
            .presentationCornerRadius(cornerRadius)
            .presentationDragIndicator(.visible)
    }

    func transparentLiquidGlassSheetPresentation(cornerRadius: CGFloat = 36) -> some View {
        self
            .presentationBackground(.clear)
            .presentationCornerRadius(cornerRadius)
            .presentationDragIndicator(.hidden)
    }
}
