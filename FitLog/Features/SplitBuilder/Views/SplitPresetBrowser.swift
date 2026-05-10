//
//  SplitPresetBrowser.swift
//  FitLog
//
//  Browse and select saved split presets (Task 26).
//

import SwiftUI
import SwiftData

struct SplitPresetBrowser: View {
    @Environment(DataManager.self) var dataVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onSelect: (_ name: String, _ days: [SplitBuilderEditableDay], _ sessionsPerWeek: Int, _ preferredWeekdays: [Int]) -> Void

    @Query(sort: \SDSplitPresetV2.createdAt, order: .reverse) private var presets: [SDSplitPresetV2]
    @State private var presetToDelete: SDSplitPresetV2?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            if presets.isEmpty {
                ContentUnavailableView(
                    "No Saved Presets",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("Save a split configuration from the Apply screen to reuse it later.")
                )
            } else {
                List {
                    ForEach(presets) { preset in
                        presetRow(preset)
                    }
                    .onDelete(perform: deletePresets)
                }
                .navigationTitle("Saved Presets")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
        }
        .confirmationDialog("Delete Preset", isPresented: $showDeleteConfirm, presenting: presetToDelete) { preset in
            Button("Delete", role: .destructive) {
                performDelete(preset)
            }
        } message: { preset in
            Text("Are you sure you want to delete '\(preset.name)'?")
        }
    }

    @ViewBuilder
    private func presetRow(_ preset: SDSplitPresetV2) -> some View {
        Button {
            selectPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(preset.days.count) days", systemImage: "calendar")
                    Label("\(preset.sessionsPerWeek)/wk", systemImage: "repeat")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !preset.notes.isEmpty {
                    Text(preset.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(preset.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .contextMenu {
            Button(role: .destructive) {
                presetToDelete = preset
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func selectPreset(_ preset: SDSplitPresetV2) {
        let store = SplitPresetStore(modelContext: modelContext)
        let domain = store.toDomain(preset)
        onSelect(domain.name, domain.days, domain.sessionsPerWeek, domain.preferredWeekdays)
        dismiss()
    }

    private func deletePresets(at offsets: IndexSet) {
        for index in offsets {
            let preset = presets[index]
            performDelete(preset)
        }
    }

    private func performDelete(_ preset: SDSplitPresetV2) {
        modelContext.delete(preset)
        try? modelContext.save()
    }
}

// Preview disabled - requires ModelContainer setup
