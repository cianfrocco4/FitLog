//
//  InlineSwapSheet.swift
//  FitLog
//
//  Quick exercise swap sheet, accessible via long-press on an exercise card.
//  Filters the global library by matching muscles/movement pattern to preserve slot context.
//

import SwiftUI

struct InlineSwapSheet: View {
    /// The log being replaced.
    let exerciseLog: ExerciseLog
    /// Full exercise library to search.
    let allExercises: [Exercise]
    /// Display names map (exercise id → custom name).
    let displayNames: [UUID: String]
    /// Called with the chosen replacement exercise.
    let onConfirm: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if !topMatches.isEmpty {
                    Section("Best matches") {
                        ForEach(topMatches) { exercise in
                            ExerciseSwapRow(
                                exercise: exercise,
                                displayName: displayNames[exercise.id],
                                badge: matchBadge(for: exercise)
                            ) {
                                onConfirm(exercise)
                                dismiss()
                            }
                        }
                    }
                }

                if !otherResults.isEmpty {
                    Section("Other results") {
                        ForEach(otherResults) { exercise in
                            ExerciseSwapRow(
                                exercise: exercise,
                                displayName: displayNames[exercise.id],
                                badge: nil
                            ) {
                                onConfirm(exercise)
                                dismiss()
                            }
                        }
                    }
                }

                if topMatches.isEmpty && otherResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search exercises")
            .navigationTitle("Swap exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Filtering

    private var slotMuscles: Set<MuscleGroup> {
        guard case .flexible(let bp) = exerciseLog.workoutExercise.resolution else { return [] }
        return Set(bp.targetedMuscles)
    }

    private var slotPattern: MovementPattern? {
        guard case .flexible(let bp) = exerciseLog.workoutExercise.resolution else { return nil }
        return bp.movementPattern
    }

    private var slotRole: ExerciseRole? {
        guard case .flexible(let bp) = exerciseLog.workoutExercise.resolution else { return nil }
        return bp.exerciseRole
    }

    /// Current exercise id — excluded from results
    private var currentExerciseId: UUID? { exerciseLog.workoutExercise.exerciseId }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return allExercises.filter { ex in
            guard ex.id != currentExerciseId else { return false }
            if query.isEmpty { return true }
            let name = (displayNames[ex.id] ?? ex.name).lowercased()
            return name.contains(query)
        }
    }

    private func score(for exercise: Exercise) -> Int {
        var s = 0
        let muscles = slotMuscles
        if !muscles.isEmpty {
            let overlap = Set(exercise.targetedMuscles).intersection(muscles)
            s += overlap.count * 2
        }
        if let pattern = slotPattern, exercise.movementPattern == pattern { s += 3 }
        if let role = slotRole, exercise.exerciseRole == role { s += 2 }
        return s
    }

    private var topMatches: [Exercise] {
        guard !slotMuscles.isEmpty || slotPattern != nil else { return [] }
        return filteredExercises.filter { score(for: $0) > 0 }
            .sorted { score(for: $0) > score(for: $1) }
    }

    private var otherResults: [Exercise] {
        let topIds = Set(topMatches.map(\.id))
        return filteredExercises.filter { !topIds.contains($0.id) }
            .sorted { ($0.name) < ($1.name) }
    }

    private func matchBadge(for exercise: Exercise) -> String? {
        var tags: [String] = []
        let muscles = slotMuscles
        if !muscles.isEmpty {
            let overlap = Set(exercise.targetedMuscles).intersection(muscles)
            if !overlap.isEmpty { tags.append(overlap.map(\.rawValue).joined(separator: ", ")) }
        }
        if let pattern = slotPattern, exercise.movementPattern == pattern {
            tags.append(pattern.rawValue.capitalized)
        }
        return tags.isEmpty ? nil : tags.prefix(2).joined(separator: " · ")
    }
}

// MARK: - Row

private struct ExerciseSwapRow: View {
    let exercise: Exercise
    let displayName: String?
    let badge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName ?? exercise.name)
                        .fontWeight(.medium)
                    if let badge {
                        Text(badge)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.tint)
                    .imageScale(.small)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Swap to \(displayName ?? exercise.name)")
        .accessibilityHint("Replaces the current exercise in this set")
    }
}

#Preview {
    InlineSwapSheet(
        exerciseLog: ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .flexible(
                    SlotBlueprint(id: UUID(), label: "Main push",
                                  targetedMuscles: [.chest, .triceps],
                                  exerciseRole: .compound,
                                  movementPattern: .horizontalPush,
                                  defaultExerciseId: nil)
                )
            ),
            loggedSets: []
        ),
        allExercises: [],
        displayNames: [:],
        onConfirm: { _ in }
    )
}
