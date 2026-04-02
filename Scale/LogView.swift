//
//  LogView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData

struct LogView: View {
    let scrollToLogsTrigger: Int
    let focusedEntry: WeightEntry?

    var body: some View {
        JournalView(
            scrollToEntryTrigger: scrollToLogsTrigger,
            focusedEntry: focusedEntry,
            scrollToBottomTrigger: 0
        )
    }
}

#Preview {
    LogView(
        scrollToLogsTrigger: 0,
        focusedEntry: nil
    )
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
