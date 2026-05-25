//
//  RootView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit

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
    @State private var historyScrollRequest = 0
    @State private var historySelectedEntry: WeightEntry?
    @State private var journalScrollToBottomRequest = 0
    @State private var logDate: Date?
    @State private var showGoalCelebration = false
    @State private var goalCelebrationID = 0
    @State private var goalCelebrationMessage: Text = Text("Closer to goal")
    @State private var goalCelebrationImage = "target"
    @State private var goalCelebrationType: CelebrationType = .confetti
    @State private var reachedGoalContext: ReachedGoalContext?
    @State private var celebrationQueue: [(message: Text, systemImage: String, type: CelebrationType)] = []
    @State private var isCelebrationRunning = false
    @State private var showSettings = false
    @Namespace private var tabNamespace
    private var selectedTint: AppTint {
        AppTint(rawValue: appTint) ?? .defaultValue
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                switch Self.actionForTabTap(currentTab: selectedTab, tappedTab: newValue) {
                case .switchTab:
                    Haptics.selection()
                    selectedTab = newValue
                case .scrollJournalToBottom:
                    Haptics.selection()
                    journalScrollToBottomRequest += 1
                case .ignore:
                    return
                }
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
        ZStack {
            JournalView(
                scrollToEntryTrigger: historyScrollRequest,
                focusedEntry: historySelectedEntry,
                scrollToBottomTrigger: journalScrollToBottomRequest,
                showLog: $showLog,
                logDate: $logDate
            )
            .opacity(selectedTab == 1 ? 1 : 0)
            .allowsHitTesting(selectedTab == 1)

            OverviewView()
                .opacity(selectedTab == 3 ? 1 : 0)
                .allowsHitTesting(selectedTab == 3)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            topAccessoryRow
                .opacity(Self.isPillVisible(selectedTab: selectedTab) ? 1 : 0)
                .frame(height: Self.isPillVisible(selectedTab: selectedTab) ? nil : 0)
                .animation(.default, value: selectedTab)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                customNavBar
                Spacer()
                logButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showLog, onDismiss: { logDate = nil }) {
            EntryView(
                historyScrollRequest: $historyScrollRequest,
                historySelectedEntry: $historySelectedEntry,
                logDate: logDate,
                latestWeight: entries.first?.weight
            )
            .presentationDetents([.height(430), .large])
            .liquidGlassSheetPresentation()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .liquidGlassSheetPresentation()
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

    private func enqueueCelebration(message: Text, systemImage: String, type: CelebrationType = .confetti) {
        celebrationQueue.append((message: message, systemImage: systemImage, type: type))
        if !isCelebrationRunning {
            showNextCelebration()
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

    private var widgetSnapshotSignature: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        hasher.combine(entries.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(entries.first?.weight ?? 0)
        return hasher.finalize()
    }

    private var topAccessoryRow: some View {
        HStack {
            Button { } label: {
                Image(systemName: "gearshape")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .opacity(0)
            .allowsHitTesting(false)

            Spacer()

            topAccessoryBadge

            Spacer()

            Button {
                Haptics.selection()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .tint(.primary)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 4)
        .padding(.horizontal, 16)
    }

    private var topAccessoryBadge: some View {
        Button {
            Haptics.selection()
            selectedTab = 3
        } label: {
            ChangeBadge(entries: entries)
        }
        .buttonStyle(.glass)
        .tint(.primary)
    }

    private var logButton: some View {
        Button {
            Haptics.impact()
            logDate = nil
            showLog = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.callout.weight(.semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glassProminent)
        .clipShape(Circle())
        .tint(selectedTint.color)
        .accessibilityLabel("Log")
        .help("Log")
    }

    private var customNavBar: some View {
        HStack(spacing: 6) {
            tabButton(title: "Journal", systemImage: "calendar", tabValue: 1)
            tabButton(title: "Overview", systemImage: "chart.line.uptrend.xyaxis", tabValue: 3)
        }
        .padding(6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
    }

    private func tabButton(title: String, systemImage: String, tabValue: Int) -> some View {
        Button {
            let action = Self.actionForTabTap(currentTab: selectedTab, tappedTab: tabValue)
            switch action {
            case .switchTab:
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    selectedTab = tabValue
                }
                Haptics.selection()
            case .scrollJournalToBottom:
                Haptics.selection()
                journalScrollToBottomRequest += 1
            case .ignore:
                break
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))

                if selectedTab == tabValue {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .foregroundStyle(selectedTab == tabValue ? selectedTint.color : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if selectedTab == tabValue {
                    Capsule(style: .continuous)
                        .fill(selectedTint.color.opacity(0.12))
                        .matchedGeometryEffect(id: "activeTabBackground", in: tabNamespace)
                }
            }
        }
        .buttonStyle(.plain)
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
