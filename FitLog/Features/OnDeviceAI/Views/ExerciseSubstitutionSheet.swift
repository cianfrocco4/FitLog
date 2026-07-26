//
//  ExerciseSubstitutionSheet.swift
//  FitLog
//

import SwiftUI

struct ExerciseSubstitutionSheet: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) private var dismiss

    let source: Exercise
    var onSelect: (Exercise) -> Void

    @State private var candidates: [ExerciseSubstitutionCandidate] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Suggestions for \(source.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    if isLoading {
                        ProgressView()
                    } else if candidates.isEmpty {
                        Text("No close substitutes found in your library.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(candidates) { item in
                            Button {
                                if let exercise = dataVM.globalExercises.first(where: { $0.id == item.id })
                                    ?? dataVM.globalExercises.first(where: {
                                        $0.name.caseInsensitiveCompare(item.exerciseName) == .orderedSame
                                    }) {
                                    onSelect(exercise)
                                    dismiss()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.exerciseName)
                                        .font(.headline)
                                    Text(item.rationale)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityHint("Replaces \(source.name) with \(item.exerciseName)")
                        }
                    }
                }
            }
            .navigationTitle("Substitutions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        candidates = await ExerciseSubstitutionService.propose(
            source: source,
            library: dataVM.globalExercises,
            isPremium: entitlementStore.isPremium,
            router: .shared
        )
    }
}
