//
//  RootView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @State private var selectedTab = 0

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
        .tint(.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
}
