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

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var sorted: [Exercise] {
        exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(sorted.prefix(80)) }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }.prefix(80).map { $0 }
    }

    var body: some View {
        List(filtered) { ex in
            Button {
                onPick(ex)
                dismiss()
            } label: {
                Text(ex.name)
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
            }
        }
        .onAppear {
            searchText = initialQuery
        }
    }
}

struct SplitLibraryPickerView: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Exercise] {
        let sorted = exercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List(filtered) { ex in
            Button(ex.name) {
                onSelect(ex)
                dismiss()
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Link exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
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
