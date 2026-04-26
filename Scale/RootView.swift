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
    @State private var historyScrollRequest = 0
    @State private var historySelectedEntry: WeightEntry?
    @State private var journalScrollToBottomRequest = 0
    @State private var logDate: Date?
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
        TabView(selection: tabSelection) {
            Tab(value: 1) {
                JournalView(
                    scrollToEntryTrigger: historyScrollRequest,
                    focusedEntry: historySelectedEntry,
                    scrollToBottomTrigger: journalScrollToBottomRequest,
                    showLog: $showLog,
                    logDate: $logDate
                )
            } label: {
                Label("Journal", systemImage: "calendar")
            }

            Tab(value: 3) {
                OverviewView()
            } label: {
                Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
            }

            Tab(value: 4) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(selectedTint.color)
        .id(appTint)
        .overlay(alignment: .bottomTrailing) {
            logButton
                .padding(.trailing, 16)
                .padding(.bottom, 52)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topAccessoryRow
                .opacity(Self.isPillVisible(selectedTab: selectedTab) ? 1 : 0)
                .frame(height: Self.isPillVisible(selectedTab: selectedTab) ? nil : 0)
                .animation(.default, value: selectedTab)
        }
        .sheet(isPresented: $showLog, onDismiss: { logDate = nil }) {
            EntryView(
                historyScrollRequest: $historyScrollRequest,
                historySelectedEntry: $historySelectedEntry,
                logDate: logDate,
                latestWeight: entries.first?.weight
            )
            .liquidGlassSheetPresentation()
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

    private var widgetSnapshotSignature: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        hasher.combine(entries.first?.timestamp.timeIntervalSinceReferenceDate ?? 0)
        hasher.combine(entries.first?.weight ?? 0)
        return hasher.finalize()
    }

    private var topAccessoryRow: some View {
        HStack {
            Spacer(minLength: 0)

            topAccessoryBadge

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.horizontal, 12)
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
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.glassProminent)
        .clipShape(Circle())
        .tint(selectedTint.color)
        .accessibilityLabel("Log")
        .help("Log")
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
    RootView(selectedTab: .constant(1), showLog: .constant(false))
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}

extension View {
    func liquidGlassSheetPresentation(cornerRadius: CGFloat = 36) -> some View {
        self
    }
}
