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
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("showChangePill") private var showChangePill = true
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @State private var historyScrollRequest = 0
    @State private var historySelectedEntry: WeightEntry?
    @State private var journalScrollToBottomRequest = 0

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

    /// Whether the change pill should be visible for a given tab index.
    static func isPillVisible(selectedTab: Int, settingsTab: Int = 2) -> Bool {
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
        TabView(selection: tabSelection) {
            EntryView(
                selectedTab: $selectedTab,
                historyScrollRequest: $historyScrollRequest,
                historySelectedEntry: $historySelectedEntry
            )
                .tabItem { Label("Log", systemImage: "square.and.pencil") }
                .tag(0)

            JournalView(
                scrollToEntryTrigger: historyScrollRequest,
                focusedEntry: historySelectedEntry,
                scrollToBottomTrigger: journalScrollToBottomRequest
            )
                .tabItem { Label("Journal", systemImage: "calendar") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(selectedTint.color)
        .id(appTint)
        .safeAreaInset(edge: .top, spacing: 0) {
            topAccessoryRow
                .opacity(Self.isPillVisible(selectedTab: selectedTab) ? 1 : 0)
                .frame(height: Self.isPillVisible(selectedTab: selectedTab) ? nil : 0)
                .animation(.default, value: selectedTab)
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
        .background {
            TabBarControllerObserver { tappedIndex, wasReselected in
                guard Self.shouldScrollJournalToBottom(
                    tappedIndex: tappedIndex,
                    wasReselected: wasReselected
                ) else { return }
                Haptics.selection()
                journalScrollToBottomRequest += 1
            }
        }
    }

    private var widgetSnapshotSignature: [String] {
        entries.map { entry in
            "\(entry.timestamp.timeIntervalSinceReferenceDate)-\(entry.weight)"
        }
    }

    private var topAccessoryRow: some View {
        HStack {
            Spacer(minLength: 0)

            topAccessoryBadge

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    private var topAccessoryBadge: some View {
        Button {
            if selectedTab == 0 {
                Haptics.impact()
                selectedTab = 1
            }
        } label: {
            ChangeBadge(entries: entries)
        }
        .buttonStyle(.glass)
        .tint(.primary)
        .allowsHitTesting(selectedTab == 0)
    }
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
    RootView(selectedTab: .constant(0))
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
