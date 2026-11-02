//
//  InlineSwapSheet.swift
//  FitLog
//
//  Quick exercise swap sheet with muscle/pattern-aware ranking.
//

import SwiftUI

struct InlineSwapSheet: View {
    let exerciseLog: ExerciseLog
    let allExercises: [Exercise]
    let displayNames: [UUID: String]
    let baselineExercise: Exercise?
    /// Setup fields of the current exercise, so changing a grip is not mistaken for a swap.
    var setupFields: [ExerciseSetupField] = []
    var setupValues: [String: String] = [:]
    var onChangeSetup: ((String, String) -> Void)? = nil
    /// Exercise used instead of the plan the last time this workout was completed.
    var priorSubstitution: PriorWorkoutSubstitution? = nil
    let onConfirm: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataVM
    @State private var searchText = ""
    @State private var pendingSwapExercise: Exercise?
    @State private var showSwapClearsSetsConfirm = false
    @State private var showCreateCustom = false
    @State private var setupSelection: [String: String] = [:]

    private var hasLoggedSets: Bool { !exerciseLog.loggedSets.isEmpty }

    private var currentExerciseId: UUID? { exerciseLog.workoutExercise.exerciseId }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return allExercises.filter { ex in
            guard ex.id != currentExerciseId else { return false }
            if query.isEmpty { return true }
            let name = (displayNames[ex.id] ?? ex.name).lowercased()
            return name.contains(query) || ex.targetedMuscles.contains { $0.rawValue.lowercased().contains(query) }
        }
    }

    /// Pinned above the ranked list when search is empty, so it is not listed twice.
    private var exercisesForRanking: [Exercise] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let priorId = priorSubstitution?.exerciseId else {
            return filteredExercises
        }
        return filteredExercises.filter { $0.id != priorId }
    }

    private var priorSubstitutionExercise: Exercise? {
        guard let priorSubstitution else { return nil }
        return allExercises.first { $0.id == priorSubstitution.exerciseId }
    }

    private var rankedSections: [(tier: String, exercises: [Exercise])] {
        guard let baseline = baselineExercise else {
            let sorted = exercisesForRanking.sorted { ($0.name) < ($1.name) }
            return sorted.isEmpty ? [] : [("All exercises", sorted)]
        }
        let scored = exercisesForRanking.map { ex in
            (ex, ExerciseSwapSimilarity.score(candidate: ex, baseline: baseline, slotMuscleMatch: false))
        }
        let tiers = ["Strong matches", "Good matches", "Partial matches", "Weaker matches"]
        var sections: [(String, [Exercise])] = []
        for tier in tiers {
            let items = scored
                .filter { ExerciseSwapSimilarity.tierLabel(score: $0.1) == tier }
                .sorted { $0.1 > $1.1 }
                .map(\.0)
            if !items.isEmpty {
                sections.append((tier, items))
            }
        }
        return sections
    }

    var body: some View {
        NavigationStack {
            List {
                if !setupFields.isEmpty, let onChangeSetup {
                    Section {
                        WorkoutSetupPickerRow(
                            fields: setupFields,
                            values: setupSelection,
                            onSelect: { field, value in
                                setupSelection[field] = value
                                onChangeSetup(field, value)
                            }
                        )
                    } header: {
                        Text("Change setup")
                    } footer: {
                        Text("Same exercise, different grip or machine setting. Your logged sets stay.")
                    }
                }

                Section {
                    Button {
                        showCreateCustom = true
                    } label: {
                        Label("Create new exercise", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityHint("Adds a custom exercise and swaps it into this workout")
                } header: {
                    if !setupFields.isEmpty {
                        Text("Swap exercise")
                    }
                } footer: {
                    if !setupFields.isEmpty {
                        Text("Replaces the movement for this session.")
                    }
                }

                if let baseline = baselineExercise, searchText.isEmpty {
                    Section {
                        Text(ExerciseSwapSimilarity.matchSummary(
                            candidate: baseline,
                            baseline: baseline,
                            slot: nil,
                            slotMuscleMatch: false
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Replacing")
                    } footer: {
                        Text(dataVM.resolvedDisplayName(for: baseline))
                            .font(.subheadline.weight(.medium))
                    }
                }

                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let prior = priorSubstitution {
                    priorSubstitutionSection(prior)
                }

                ForEach(rankedSections, id: \.tier) { section in
                    Section(section.tier) {
                        ForEach(section.exercises) { exercise in
                            swapRow(
                                exercise: exercise,
                                showsLastSwap: exercise.id == priorSubstitution?.exerciseId
                            )
                        }
                    }
                }

                if rankedSections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search exercises")
            .onAppear {
                if setupSelection.isEmpty { setupSelection = setupValues }
            }
            .navigationTitle(setupFields.isEmpty ? "Swap exercise" : "Setup or swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCreateCustom) {
                InlineSwapCreateExerciseSheet(
                    baseline: baselineExercise,
                    onCreated: { created in
                        requestSwap(to: created)
                    }
                )
                .environment(dataVM)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Swap and clear logged sets?",
            isPresented: $showSwapClearsSetsConfirm,
            titleVisibility: .visible
        ) {
            Button("Swap and clear sets", role: .destructive) {
                if let pendingSwapExercise {
                    onConfirm(pendingSwapExercise)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSwapExercise = nil
            }
        } message: {
            Text("This exercise already has logged sets. Swapping replaces the movement and clears those sets so history stays accurate.")
        }
    }

    @ViewBuilder
    private func priorSubstitutionSection(_ prior: PriorWorkoutSubstitution) -> some View {
        let name = priorSubstitutionExercise.map { displayNames[$0.id] ?? $0.name } ?? prior.exerciseName
        Section {
            if let exercise = priorSubstitutionExercise {
                swapRow(exercise: exercise, showsLastSwap: true)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .fontWeight(.medium)
                    Text("No longer in your library, so it cannot be swapped in again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Last time in this workout")
        } footer: {
            Text("You swapped to \(name) the last time you completed this workout.")
        }
    }

    @ViewBuilder
    private func swapRow(exercise: Exercise, showsLastSwap: Bool = false) -> some View {
        let score = baselineExercise.map {
            ExerciseSwapSimilarity.score(candidate: exercise, baseline: $0, slotMuscleMatch: false)
        }
        Button {
            requestSwap(to: exercise)
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayNames[exercise.id] ?? exercise.name)
                        .fontWeight(.medium)
                    if let baseline = baselineExercise {
                        Text(ExerciseSwapSimilarity.matchSummary(
                            candidate: exercise,
                            baseline: baseline,
                            slot: nil,
                            slotMuscleMatch: false
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    } else if !exercise.targetedMuscles.isEmpty {
                        Text(exercise.targetedMuscles.map(\.rawValue).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if showsLastSwap {
                    LastSessionSwapBadge()
                }
                if let score, let badge = ExerciseSwapSimilarity.fitBadge(score: score) {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.tint)
                    .imageScale(.small)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(swapAccessibilityLabel(for: exercise, showsLastSwap: showsLastSwap))
        .accessibilityHint("Replaces the current exercise")
    }

    private func swapAccessibilityLabel(for exercise: Exercise, showsLastSwap: Bool) -> String {
        let name = displayNames[exercise.id] ?? exercise.name
        if showsLastSwap {
            return "Swap to \(name). Last time you completed this workout you swapped to this exercise."
        }
        return "Swap to \(name)"
    }

    private func requestSwap(to exercise: Exercise) {
        if hasLoggedSets {
            pendingSwapExercise = exercise
            showSwapClearsSetsConfirm = true
        } else {
            onConfirm(exercise)
            dismiss()
        }
    }
}

// MARK: - Inline custom exercise creation

private struct InlineSwapCreateExerciseSheet: View {
    let baseline: Exercise?
    let onCreated: (Exercise) -> Void

    @Environment(DataManager.self) private var dataVM
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedMuscles: [MuscleGroup] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise name") {
                    TextField("Name", text: $name)
                }
                Section("Muscles (up to 3)") {
                    ForEach(MuscleGroup.allCases) { muscle in
                        let isOn = selectedMuscles.contains(muscle)
                        Button {
                            toggleMuscle(muscle)
                        } label: {
                            HStack {
                                Text(muscle.rawValue)
                                Spacer()
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if let baseline {
                    Section("Fit vs current exercise") {
                        Text(ExerciseSwapSimilarity.matchSummary(
                            candidate: Exercise(
                                id: UUID(),
                                name: name.isEmpty ? "New exercise" : name,
                                description: "",
                                targetedMuscles: selectedMuscles,
                                isCustom: true
                            ),
                            baseline: baseline,
                            slot: nil,
                            slotMuscleMatch: false
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create & swap") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !selectedMuscles.isEmpty else { return }
                        let created = dataVM.addNewExercise(
                            name: trimmed,
                            description: "",
                            muscles: Array(selectedMuscles.prefix(3))
                        )
                        onCreated(created)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedMuscles.isEmpty)
                }
            }
            .onAppear {
                if selectedMuscles.isEmpty, let baseline {
                    selectedMuscles = Array(baseline.targetedMuscles.prefix(3))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleMuscle(_ muscle: MuscleGroup) {
        if let idx = selectedMuscles.firstIndex(of: muscle) {
            selectedMuscles.remove(at: idx)
        } else if selectedMuscles.count < 3 {
            selectedMuscles.append(muscle)
        }
    }
}
