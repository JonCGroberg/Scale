//
//  ReminderSettingsContent.swift
//  Scale
//
//  Created by Codex on 4/14/26.
//

import SwiftUI

struct ReminderSettingsContent: View {
    @Binding var remindersEnabled: Bool
    @Binding var reminders: [Reminder]

    let tintColor: Color
    let notificationManager: NotificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Daily Reminders", isOn: $remindersEnabled)
                .onChange(of: remindersEnabled) { _, enabled in
                    updateReminderToggle(enabled: enabled)
                }

            if remindersEnabled {
                VStack(spacing: 12) {
                    ForEach($reminders) { $reminder in
                        ReminderRow(reminder: $reminder, tintColor: tintColor) {
                            notificationManager.saveReminders(reminders)
                        }
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
            }
        }
    }

    private func updateReminderToggle(enabled: Bool) {
        if enabled {
            Task {
                let granted = await notificationManager.requestAuthorization()
                if !granted {
                    await MainActor.run {
                        remindersEnabled = false
                    }
                } else if reminders.isEmpty {
                    await MainActor.run {
                        withAnimation {
                            reminders.append(Reminder())
                        }
                        notificationManager.saveReminders(reminders)
                    }
                } else {
                    notificationManager.rescheduleReminders()
                }
            }
        } else {
            notificationManager.rescheduleReminders()
        }
    }
}

struct ReminderRow: View {
    @Binding var reminder: Reminder
    let tintColor: Color
    let onChanged: () -> Void

    @State private var time: Date

    init(reminder: Binding<Reminder>, tintColor: Color, onChanged: @escaping () -> Void) {
        self._reminder = reminder
        self.tintColor = tintColor
        self.onChanged = onChanged

        var components = DateComponents()
        components.hour = reminder.wrappedValue.hour
        components.minute = reminder.wrappedValue.minute
        let date = Calendar.current.date(from: components) ?? .now
        _time = State(initialValue: date)
    }

    var body: some View {
        DatePicker(selection: $time, displayedComponents: .hourAndMinute) {
            TextField("Name", text: $reminder.name)
                .onChange(of: reminder.name) {
                    onChanged()
                }
        }
        .tint(tintColor)
        .onChange(of: time) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            reminder.hour = comps.hour ?? 8
            reminder.minute = comps.minute ?? 0
            onChanged()
        }
    }
}
