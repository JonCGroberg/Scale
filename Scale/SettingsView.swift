//
//  SettingsView.swift
//  Scale
//
//  Created by Jonathan Groberg on 3/15/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthManager
    @AppStorage("showChangePill") private var showChangePill = true
    @AppStorage("autoSyncHealthKit") private var autoSyncHealthKit = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                List {
                    Section {
                        Toggle("Last Change Badge", isOn: $showChangePill)
                    } header: {
                        Text("Display")
                    } footer: {
                        Text("The last change badge shows your most recent weight difference on the Log screen.")
                    }

                    Section {
                        if healthManager.isAvailable {
                            Toggle("Sync on App Launch", isOn: $autoSyncHealthKit)
                        }
                        healthImportRow
                    } header: {
                        Text("Apple Health")
                    } footer: {
                        Text("Automatically import new weight entries from Apple Health each time you open the app, or import manually.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Health Import Row

    @ViewBuilder
    private var healthImportRow: some View {
        if !healthManager.isAvailable {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Health")
                        .font(.body)
                    Text("Not available on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.accent)
            }
        } else {
            Button {
                Task {
                    await healthManager.importWeightData(modelContext: modelContext)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import from Apple Health")
                            .font(.body)

                        if healthManager.isImporting {
                            Text("Importing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let result = healthManager.importResult {
                            resultText(result)
                        }
                    }
                } icon: {
                    if healthManager.isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.accent)
                    }
                }
            }
            .disabled(healthManager.isImporting)
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
                    .foregroundStyle(.accent)
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
        .modelContainer(for: WeightEntry.self, inMemory: true)
        .environment(HealthKitManager())
}
