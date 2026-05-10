//
//  DataAndIntegrationsView.swift
//  FitLog
//
//  Settings for Apple Health sync and data export/import.
//

import SwiftUI
import UniformTypeIdentifiers

struct DataAndIntegrationsView: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var showArchiveImporter = false
    @State private var archiveExportURL: URL?
    @State private var csvExportURL: URL?
    @State private var alertMessage: String?

    var body: some View {
        @Bindable var dm = dataVM
        return Form {
            Section("Units") {
                Picker("Weight display", selection: $userPreferences.weightDisplayUnit) {
                    ForEach(WeightDisplayUnit.allCases) { u in
                        Text(u == .pounds ? "Pounds (lb)" : "Kilograms (kg)").tag(u)
                    }
                }
                Text("Workout weights are stored consistently; this only changes labels and step size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Health") {
                Toggle("Sync completed workouts to Apple Health", isOn: $dm.healthSyncEnabled)
                    .onChange(of: dataVM.healthSyncEnabled) { _, enabled in
                        dataVM.setHealthSyncEnabled(enabled)
                    }
                if let msg = dataVM.healthSyncStatusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("When enabled, completed workouts are written to Apple Health.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Export") {
                if let archiveExportURL {
                    ShareLink(item: archiveExportURL) {
                        Label("Share full archive (.fitlog)", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        do {
                            archiveExportURL = try dataVM.dataTransferService.writeArchiveExportFile()
                        } catch {
                            alertMessage = "Could not build archive export: \(error.localizedDescription)"
                        }
                    } label: {
                        Label("Prepare full archive (.fitlog)", systemImage: "square.and.arrow.up")
                    }
                }

                if let csvExportURL {
                    ShareLink(item: csvExportURL) {
                        Label("Share sessions CSV", systemImage: "tablecells")
                    }
                } else {
                    Button {
                        do {
                            csvExportURL = try dataVM.dataTransferService.writeCSVExportFile()
                        } catch {
                            alertMessage = "Could not build CSV export: \(error.localizedDescription)"
                        }
                    } label: {
                        Label("Prepare sessions CSV", systemImage: "tablecells")
                    }
                }
            }

            Section("Import") {
                Button(role: .destructive) {
                    showArchiveImporter = true
                } label: {
                    Label("Import data file", systemImage: "square.and.arrow.down")
                }
                Text("Supports .fitlog/.json full restore and .csv session import. Import replaces current exercises, workouts, sessions, program, and display names.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Data & Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showArchiveImporter,
            allowedContentTypes: [.fitlogArchive, .json, .fitlogCSV, .commaSeparatedText]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    let access = url.startAccessingSecurityScopedResource()
                    defer {
                        if access { url.stopAccessingSecurityScopedResource() }
                    }
                    let data = try Data(contentsOf: url)
                    let format = DataTransferService.inferFormat(from: url) ?? .json
                    try dataVM.dataTransferService.importData(data, format: format)
                    alertMessage = "Import complete."
                } catch {
                    alertMessage = "Import failed: \(error.localizedDescription)"
                }
            case .failure(let error):
                alertMessage = "Import cancelled or failed: \(error.localizedDescription)"
            }
        }
        .alert(
            "Data & Integrations",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
}
