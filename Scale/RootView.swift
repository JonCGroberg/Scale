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
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue

    private var selectedTint: AppTint {
        AppTint(rawValue: appTint) ?? .defaultValue
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            EntryView(selectedTab: $selectedTab)
                .tabItem { Label("Log", systemImage: "square.and.pencil") }
                .tag(0)

            LogView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(selectedTint.color)
        .id(appTint)
    }
}

#Preview {
    RootView(selectedTab: .constant(0))
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
