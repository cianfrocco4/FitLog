//
//  CardioExercisePickerSheet.swift
//  FitLog
//

import SwiftUI

/// Picker limited to cardio and hybrid library exercises.
struct CardioExercisePickerSheet: View {
    @Environment(DataManager.self) var dataVM
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Exercise) -> Void

    @State private var searchText = ""

    private var cardioExercises: [Exercise] {
        dataVM.globalExercises
            .filter { $0.modality == .cardio || $0.modality == .hybrid }
            .sorted {
                dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
            }
    }

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return cardioExercises }
        return cardioExercises.filter { ex in
            dataVM.resolvedDisplayName(for: ex).localizedCaseInsensitiveContains(q)
                || ex.name.localizedCaseInsensitiveContains(q)
                || (ex.cardioMetadata?.activityKind.displayName.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(CardioExerciseCategoryGrouping.activitySections(exercises: filtered) { dataVM.resolvedDisplayName(for: $0) }, id: \.0) { activity, list in
                    Section {
                        ForEach(list) { ex in
                            Button {
                                onSelect(ex)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: activity.systemImage)
                                        .foregroundStyle(FitlogPalette.chartSecondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dataVM.resolvedDisplayName(for: ex))
                                            .foregroundStyle(.primary)
                                        if ex.modality == .hybrid {
                                            Text("Hybrid")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(activity.displayName)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search cardio exercises")
            .navigationTitle("Add Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
