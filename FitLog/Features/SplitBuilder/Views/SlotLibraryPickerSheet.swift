//
//  SlotLibraryPickerSheet.swift
//  FitLog
//
//  Library-search slot picker scored by role/pattern/muscles for manual + AI parity (Task 20).
//

import SwiftUI

struct SlotLibraryPickerSheet: View {
    @Environment(DataManager.self) var dataVM
    @Environment(\.dismiss) private var dismiss

    let slot: SplitBuilderEditableSlot
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""

    private var scoredExercises: [(exercise: Exercise, score: Int)] {
        let slotMuscles = Set(slot.targetMuscleNames.compactMap { MuscleGroup(rawValue: $0) })
        let allExercises = dataVM.globalExercises

        let scored = allExercises.map { ex -> (exercise: Exercise, score: Int) in
            var score = 0

            // Match targeted muscles (highest priority)
            let exMuscles = Set(ex.targetedMuscles)
            let overlap = slotMuscles.intersection(exMuscles)
            score += overlap.count * 10

            // Match movement pattern
            if let slotLabel = slot.label.lowercased() as String? {
                if let exPattern = ex.movementPattern {
                    let patternName = String(describing: exPattern).lowercased()
                    if slotLabel.contains(patternName) || patternName.contains(slotLabel) {
                        score += 5
                    }
                }
            }

            // Prefer similar role
            // (No direct role in slot, but we can infer from sets/reps)
            if slot.sets >= 5 {
                // High volume suggests accessory
                if ex.exerciseRole == .accessory {
                    score += 2
                }
            } else if slot.sets <= 3 {
                // Low volume suggests compound
                if ex.exerciseRole == .compound {
                    score += 3
                }
            }

            // Boost if name contains slot label
            if ex.name.localizedCaseInsensitiveContains(slot.label) || slot.label.localizedCaseInsensitiveContains(ex.name) {
                score += 8
            }

            return (ex, score)
        }

        return scored.sorted { $0.score > $1.score || ($0.score == $1.score && $0.exercise.name < $1.exercise.name) }
    }

    private var filteredExercises: [(exercise: Exercise, score: Int)] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return scoredExercises }
        return scoredExercises.filter { item in
            item.exercise.matchesExerciseSearch(query: q, resolvedDisplayName: dataVM.resolvedDisplayName(for: item.exercise))
        }
    }

    private var bestMatches: [(exercise: Exercise, score: Int)] {
        Array(filteredExercises.prefix(5))
    }

    private var otherResults: [(exercise: Exercise, score: Int)] {
        Array(filteredExercises.dropFirst(5))
    }

    var body: some View {
        NavigationStack {
            List {
                if !bestMatches.isEmpty {
                    Section("Best Matches") {
                        ForEach(bestMatches, id: \.exercise.id) { item in
                            exerciseRow(item.exercise)
                        }
                    }
                }

                if !otherResults.isEmpty {
                    Section("Other Results") {
                        ForEach(otherResults, id: \.exercise.id) { item in
                            exerciseRow(item.exercise)
                        }
                    }
                }

                Section {
                    Button {
                        // TODO: Open custom exercise creation flow
                        dismiss()
                    } label: {
                        Label("Create new exercise", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(dataVM.resolvedDisplayName(for: exercise))
                    .font(.body)

                if !exercise.targetedMuscles.isEmpty {
                    Text(exercise.targetedMuscles.map { $0.rawValue.capitalized }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    let dataVM = DataManager.preview
    SlotLibraryPickerSheet(
        slot: SplitBuilderEditableSlot(
            label: "Bench Press",
            targetMuscleNames: [MuscleGroup.chest.rawValue, MuscleGroup.triceps.rawValue],
            sets: 3,
            reps: "8-12"
        ),
        onSelect: { _ in }
    )
    .environment(dataVM)
}
