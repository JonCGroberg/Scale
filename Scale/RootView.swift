//
//  RootView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Binding var selectedTab: Int
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    @AppStorage("showChangePill") private var showChangePill = true
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @State private var historyScrollRequest = 0
    @State private var historySelectedEntry: WeightEntry?

    private var selectedTint: AppTint {
        AppTint(rawValue: appTint) ?? .defaultValue
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            EntryView(
                selectedTab: $selectedTab,
                historyScrollRequest: $historyScrollRequest,
                historySelectedEntry: $historySelectedEntry
            )
                .tabItem { Label("Log", systemImage: "square.and.pencil") }
                .tag(0)

            LogView(
                scrollToLogsTrigger: historyScrollRequest,
                focusedEntry: historySelectedEntry
            )
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(selectedTint.color)
        .id(appTint)
        .safeAreaInset(edge: .top, spacing: 0) {
            topAccessoryRow
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
    }

    private var widgetSnapshotSignature: [String] {
        entries.map { entry in
            "\(entry.timestamp.timeIntervalSinceReferenceDate)-\(entry.weight)"
        }
    }

    @ViewBuilder
    private var topAccessoryRow: some View {
        if showChangePill, !entries.isEmpty, selectedTab != 2 {
            HStack {
                Spacer(minLength: 0)

                ChangeBadge(entries: entries)
                    .onTapGesture {
                        guard selectedTab == 0 else { return }
                        selectedTab = 1
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: selectedTab) { old, new in old == 0 && new == 1 }

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    RootView(selectedTab: .constant(0))
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
