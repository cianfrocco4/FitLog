//
//  SplitBuilderSupportViews.swift
//  FitLog
//
//  Shared picker/search views for split builders.
//

import SwiftUI

struct SplitMuscleMultiPickerView: View {
    let initial: [MuscleGroup]
    let onDone: ([MuscleGroup]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<MuscleGroup> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text("Choose 1–3 groups for this slot (first = primary emphasis in the app).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(MuscleGroup.displayOrder, id: \.self) { m in
                let on = selected.contains(m)
                Button {
                    if on {
                        selected.remove(m)
                    } else if selected.count < 3 {
                        selected.insert(m)
                    }
                } label: {
                    HStack {
                        Text(m.rawValue)
                        Spacer()
                        if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Target muscles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    let arr = MuscleGroup.displayOrder.filter { selected.contains($0) }
                    onDone(arr.isEmpty ? [.other] : arr)
                    dismiss()
                }
            }
        }
        .onAppear {
            selected = Set(initial.isEmpty ? [.other] : initial)
        }
    }
}

struct SplitExerciseSuggestSheet: View {
    let exercises: [Exercise]
    let initialQuery: String
    let onPick: (Exercise) -> Void
    let onCancel: () -> Void
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Injected per-exercise captions skip the live session store (previews / tests).
    var lastLoadCaptionsByExerciseId: [UUID: String] = [:]
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    private var sorted: [Exercise] {
        exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(sorted.prefix(80)) }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }.prefix(80).map { $0 }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return QuartzLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    private var resolvedCaptionsByExerciseId: [UUID: String] {
        if !lastLoadCaptionsByExerciseId.isEmpty { return lastLoadCaptionsByExerciseId }
        guard resolvesLastLoadFromEnvironment else { return [:] }
        return QuartzLastWorkingLoad.captionsByExerciseId(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    var body: some View {
        List {
            if let lastLoad = resolvedLastLoadCaption {
                Section {
                    Text(lastLoad)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(FitLogA11yID.splitSuggest.lastLoad)
                        .accessibilityLabel(lastLoad)
                        .accessibilityHint("Last working set or last cardio duration from a completed session")
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            ForEach(filtered) { ex in
                Button {
                    onPick(ex)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                        if let rowLoad = resolvedCaptionsByExerciseId[ex.id] {
                            Text(rowLoad)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel(splitSuggestRowLabel(ex))
                .accessibilityHint("Uses this exercise as the default for the slot")
                .accessibilityAddTraits(.isButton)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Default exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .accessibilityLabel("Cancel")
                .accessibilityHint("Closes the default exercise picker without changing the slot")
            }
        }
        .onAppear {
            searchText = initialQuery
        }
    }

    private func splitSuggestRowLabel(_ exercise: Exercise) -> String {
        if let rowLoad = resolvedCaptionsByExerciseId[exercise.id] {
            return "\(exercise.name), \(rowLoad)"
        }
        return exercise.name
    }
}

struct SplitLibraryPickerView: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Injected per-exercise captions skip the live session store (previews / tests).
    var lastLoadCaptionsByExerciseId: [UUID: String] = [:]
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences
    @State private var searchText = ""

    private var filtered: [Exercise] {
        let sorted = exercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return QuartzLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    private var resolvedCaptionsByExerciseId: [UUID: String] {
        if !lastLoadCaptionsByExerciseId.isEmpty { return lastLoadCaptionsByExerciseId }
        guard resolvesLastLoadFromEnvironment else { return [:] }
        return QuartzLastWorkingLoad.captionsByExerciseId(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    var body: some View {
        List {
            if let lastLoad = resolvedLastLoadCaption {
                Section {
                    Text(lastLoad)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(lastLoad)
                        .accessibilityHint("Last working set or last cardio duration from a completed session")
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            ForEach(filtered) { ex in
                Button {
                    onSelect(ex)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                        if let rowLoad = resolvedCaptionsByExerciseId[ex.id] {
                            Text(rowLoad)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel(splitLibraryRowLabel(ex))
                .accessibilityHint("Links this library exercise to the slot")
                .accessibilityAddTraits(.isButton)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Link exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Closes the exercise linker without changing the slot")
            }
        }
    }

    private func splitLibraryRowLabel(_ exercise: Exercise) -> String {
        if let rowLoad = resolvedCaptionsByExerciseId[exercise.id] {
            return "\(exercise.name), \(rowLoad)"
        }
        return exercise.name
    }
}

enum SplitBuilderSupportText {
    static func slotMuscleOutcomeLine(_ slot: SplitBuilderEditableSlot) -> String {
        let parsed = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
        if !parsed.isEmpty {
            return "Targets: \(parsed.map(\.rawValue).joined(separator: ", "))."
        }
        let tokens = slot.targetMuscleNames.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if tokens.isEmpty {
            return "Tap “Muscles” to pick target groups, or Other is used."
        }
        return "Some muscle labels didn’t match known groups; Other is used where needed."
    }

    static func slotSuggestedExerciseLine(_ slot: SplitBuilderEditableSlot, library: [Exercise]) -> String {
        if let oid = slot.suggestedExerciseOverrideId,
           let ex = library.first(where: { $0.id == oid }) {
            return "Default exercise: \(ex.name) (your pick)."
        }
        let raw = (slot.suggestedExerciseName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "Open slot — you’ll choose an exercise in this category each time you start the workout."
        }
        guard let r = ExerciseNameResolution.resolve(planName: raw, library: library) else {
            return ""
        }
        switch r {
        case .linked(let ex):
            if ExerciseNameResolution.normalizationKey(raw) != ExerciseNameResolution.normalizationKey(ex.name) {
                return "Default exercise: \(ex.name) (matched from your text)."
            }
            return "Default exercise: \(ex.name)."
        case .createCustom(let name):
            return "Adds “\(name)” as a custom exercise and uses it as the default."
        }
    }
}

#Preview("Suggest sheet last load · strength") {
    NavigationStack {
        SplitExerciseSuggestSheet(
            exercises: [
                Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
            ],
            initialQuery: "",
            onPick: { _ in },
            onCancel: {},
            lastLoadCaption: "Last 185 lb × 8 reps",
            lastLoadCaptionsByExerciseId: [:],
            resolvesLastLoadFromEnvironment: false
        )
    }
}

#Preview("Suggest sheet last load · dark cardio") {
    NavigationStack {
        SplitExerciseSuggestSheet(
            exercises: [
                Exercise(id: UUID(), name: "Zone 2", description: "", targetedMuscles: [.other])
            ],
            initialQuery: "",
            onPick: { _ in },
            onCancel: {},
            lastLoadCaption: "Last 45:00",
            lastLoadCaptionsByExerciseId: [:],
            resolvesLastLoadFromEnvironment: false
        )
    }
    .preferredColorScheme(.dark)
}
