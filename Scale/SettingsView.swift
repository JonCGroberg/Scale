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

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
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
                        healthImportRow
                    } header: {
                        Text("Data")
                    } footer: {
                        Text("Import weight entries recorded in Apple Health into this app.")
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
        case .success(let imported, let skipped):
            if imported == 0 && skipped > 0 {
                Text("All entries already imported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if imported == 0 && skipped == 0 {
                Text("No weight data found in Apple Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(imported) imported, \(skipped) skipped")
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
