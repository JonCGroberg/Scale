//
//  SettingsView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(HealthKitManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false
    @AppStorage("appTint") private var appTint = AppTint.defaultValue.rawValue
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @State private var reminders: [Reminder] = []

    private var selectedTint: Binding<AppTint> {
        Binding(
            get: { AppTint(rawValue: appTint) ?? .defaultValue },
            set: { appTint = $0.rawValue }
        )
    }

    private var tintColor: Color {
        (AppTint(rawValue: appTint) ?? .defaultValue).color
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: selectedTint) {
                        ForEach(AppTint.allCases) { tint in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(tint.color)
                                    .frame(width: 12, height: 12)

                                Text(tint.title)
                                    .foregroundStyle(tint.color)
                            }
                            .tag(tint)
                        }
                    }
                    label: {
                        Text("Tint Color")
                            .foregroundStyle(tintColor)
                    }
                } header: {
                    Text("Display")
                }

                Section {
                    if healthManager.isAvailable {
                        Toggle("Import Apple Health updates automatically", isOn: $autoSyncHealthKit)
                    }
                    HealthImportRows(tintColor: tintColor)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Bring in weight entries, workouts, and daily activity summaries from Apple Health automatically when the app opens, or run an import whenever you want.")
                }

                Section {
                    Toggle("Daily Reminders", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await notificationManager.requestAuthorization()
                                    if !granted {
                                        remindersEnabled = false
                                    } else {
                                        if reminders.isEmpty {
                                            withAnimation {
                                                reminders.append(Reminder())
                                            }
                                            notificationManager.saveReminders(reminders)
                                        } else {
                                            notificationManager.rescheduleReminders()
                                        }
                                    }
                                }
                            } else {
                                notificationManager.rescheduleReminders()
                            }
                        }

                    if remindersEnabled {
                        ForEach($reminders) { $reminder in
                            ReminderRow(reminder: $reminder, tintColor: tintColor) {
                                notificationManager.saveReminders(reminders)
                            }
                        }
                        .onDelete { offsets in
                            withAnimation {
                                reminders.remove(atOffsets: offsets)
                            }
                            notificationManager.saveReminders(reminders)
                        }

                        Button {
                            let lastHour = reminders.last?.hour ?? 6
                            withAnimation {
                                reminders.append(Reminder(hour: min(lastHour + 2, 22)))
                            }
                            notificationManager.saveReminders(reminders)
                            Haptics.selection()
                        } label: {
                            Label("Add Reminder", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Get a notification to log your weight. Tapping the notification opens the entry screen.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                reminders = notificationManager.loadReminders()
            }
            .sensoryFeedback(.selection, trigger: reminders.count)
            .sensoryFeedback(.impact(weight: .medium), trigger: healthManager.isImporting) { _, new in new }
            .sensoryFeedback(.success, trigger: healthManager.importResult) { _, new in
                if case .success = new { return true }
                return false
            }
        }
    }

}

struct HealthImportRows: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    let tintColor: Color

    var body: some View {
        healthImportRow
        workoutImportRow
        dailyActivityImportRow
    }

    // MARK: - Health Import Row

    @ViewBuilder
    private var healthImportRow: some View {
        if !healthManager.isAvailable {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Health")
                        .font(.body)
                    Text("Apple Health isn't available on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(tintColor)
            }
        } else {
            Button {
                Haptics.selection()
                Task {
                    await healthManager.importWeightData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import weight history")
                            .font(.body)

                        if healthManager.isImporting {
                            Text("Reading your weight entries from Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.importResult {
                            resultText(result)
                        } else {
                            Text("Add weight entries from Apple Health to your log")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    if healthManager.isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(healthManager.isImporting)
        }
    }

    @ViewBuilder
    private var workoutImportRow: some View {
        if healthManager.isAvailable {
            Button {
                Haptics.selection()
                Task {
                    await healthManager.importWorkoutData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import workouts")
                            .font(.body)

                        if healthManager.isImportingWorkouts {
                            Text("Reading your workouts from Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.workoutImportResult {
                            resultText(result)
                        } else {
                            Text("Add Apple Health workout summaries to your journal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    if healthManager.isImportingWorkouts {
                        ProgressView()
                    } else {
                        Image(systemName: "figure.run")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(healthManager.isImportingWorkouts)
        }
    }

    @ViewBuilder
    private var dailyActivityImportRow: some View {
        if healthManager.isAvailable {
            Button {
                Haptics.selection()
                Task {
                    await healthManager.importDailyActivityData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import daily activity")
                            .font(.body)

                        if healthManager.isImportingDailyActivity {
                            Text("Reading steps and active energy from Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.dailyActivityImportResult {
                            resultText(result)
                        } else {
                            Text("Add daily step counts and active calories to your journal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    if healthManager.isImportingDailyActivity {
                        ProgressView()
                    } else {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(tintColor)
                    }
                }
            }
            .disabled(healthManager.isImportingDailyActivity)
        }
    }

    @ViewBuilder
    private func resultText(_ result: HealthKitManager.ImportResult) -> some View {
        switch result {
        case .success(let imported, let skipped, let removed):
            if imported == 0 && removed == 0 && skipped > 0 {
                Text("All entries already imported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if imported == 0 && removed == 0 && skipped == 0 {
                Text("No weight data found in Apple Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let parts = [
                    imported > 0 ? "\(imported) imported" : nil,
                    removed > 0 ? "\(removed) removed" : nil,
                    skipped > 0 ? "\(skipped) skipped" : nil,
                ].compactMap { $0 }.joined(separator: ", ")
                Text(parts)
                    .font(.caption)
                    .foregroundStyle(tintColor)
            }
        case .error(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [WeightEntry.self, WorkoutEntry.self, DailyActivitySummary.self], inMemory: true)
        .environment(HealthKitManager())
        .environment(NotificationManager())
}
