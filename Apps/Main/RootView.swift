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
    @State private var tabDragOffset: CGFloat = 0
    @Namespace private var tabNamespace

    private var selectedTint: AppTint {
        AppTint(rawValue: appTint) ?? .defaultValue
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
        ZStack {
            NavigationStack {
                ZStack {
                    if selectedTab == 1 {
                        JournalView(
                            scrollToEntryTrigger: historyScrollRequest,
                            focusedEntry: historySelectedEntry,
                            scrollToBottomTrigger: journalScrollToBottomRequest,
                            showLog: $showLog,
                            logDate: $logDate
                        )
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                    } else if selectedTab == 3 {
                        OverviewView()
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            if abs(horizontal) > abs(vertical) && abs(horizontal) > 45 {
                                if horizontal < 0 {
                                    if selectedTab == 1 {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            selectedTab = 3
                                        }
                                    }
                                } else if selectedTab == 3 {
                                    Haptics.selection()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        selectedTab = 1
                                    }
                                }
                            }
                        }
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 76)
                }
            }

            edgeFadeLayer
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topAccessoryRow
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                floatingBottomBar
            }
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
        .sheet(isPresented: $showLog, onDismiss: { logDate = nil }) {
            EntryView(
                historyScrollRequest: $historyScrollRequest,
                historySelectedEntry: $historySelectedEntry,
                logDate: logDate,
                latestWeight: entries.first?.weight
            )
            .presentationDetents([.height(430), .large])
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

    private var edgeFadeLayer: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(uiColor: .systemBackground).opacity(0.88), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [.clear, Color(uiColor: .systemBackground).opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
        }
        .ignoresSafeArea()
    }

    private var floatingBottomBar: some View {
        GlassEffectContainer(spacing: 40) {
            HStack(spacing: 10) {
                tabPill
                Spacer()
                logButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var topAccessoryRow: some View {
        ZStack(alignment: .top) {
            ChangeBadge(entries: entries, showsRange: selectedTab == 3)
                .frame(width: 260, height: 94, alignment: .top)
                .onTapGesture {
                    guard selectedTab != 3 else { return }
                    Haptics.selection()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedTab = 3
                    }
                }

            HStack {
                Spacer()

                Button {
                    Haptics.selection()
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Settings")
            }
        }
        .frame(height: 94, alignment: .top)
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

    private var tabPill: some View {
        HStack(spacing: 4) {
            tabButton(title: "Journal", systemImage: "calendar", tabValue: 1)
            tabButton(title: "Overview", systemImage: "chart.xyaxis.line", tabValue: 3)
        }
        .padding(5)
        .glassEffect(.regular.interactive(), in: Capsule())
        .glassEffectID("tabPill", in: tabNamespace)
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
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(selectedTab == tabValue ? selectedTint.color : .secondary)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background {
                if selectedTab == tabValue {
                    Capsule(style: .continuous)
                        .fill(.primary.opacity(0.18))
                        .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                        .offset(x: tabDragOffset)
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    let translation = value.translation.width
                                    if selectedTab == 1 {
                                        tabDragOffset = max(0, min(110, translation))
                                    } else {
                                        tabDragOffset = min(0, max(-110, translation))
                                    }
                                }
                                .onEnded { value in
                                    let translation = value.translation.width
                                    let threshold: CGFloat = 50
                                    
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                        if selectedTab == 1 && translation > threshold {
                                            selectedTab = 3
                                            Haptics.selection()
                                        } else if selectedTab == 3 && translation < -threshold {
                                            selectedTab = 1
                                            Haptics.selection()
                                        }
                                        tabDragOffset = 0
                                    }
                                }
                        )
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button {
            Haptics.impact()
            logDate = nil
            showLog = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .glassEffectID("logButton", in: tabNamespace)
        .accessibilityLabel("Log")
    }

    private var widgetSnapshotSignature: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        hasher.combine(entries.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(entries.first?.weight ?? 0)
        return hasher.finalize()
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
