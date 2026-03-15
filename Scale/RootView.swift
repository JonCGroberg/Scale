//
//  RootView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            EntryView()
                .tabItem { Label("Log", systemImage: "scalemass") }

            LogView()
                .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .tint(.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(for: WeightEntry.self, inMemory: true)
}
