//
//  SessionQuickAddExerciseSheet.swift
//  FitLog
//

import SwiftUI

/// Fast path to append an exercise to the active session with sensible defaults, prioritized by overlap with muscles already in the workout.
///
/// Uses `let` references to `CurrentWorkoutSessionViewModel` / `DataManager` (not `@EnvironmentObject`) so the per-second
/// workout timer does not re-run heavy list bucketing on the main thread.
struct SessionQuickAddExerciseSheet: View {
    let workout: Workout
    let currentVM: CurrentWorkoutSessionViewModel
    let dataVM: DataManager
    /// When true, shows “Add template slot” for flexible library sessions.
    var isFlexibleLibrarySession: Bool = false
    /// Dismiss quick-add first; parent should present full add (e.g. `AddExerciseSheet`).
    var onRequestCustomSetsAndFields: (() -> Void)? = nil
    /// Appends a flexible slot to the in-progress session / library.
    var onAddTemplateSlot: (() -> Void)? = nil
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var favoriteIds: Set<UUID> = []
    @State private var recentIds: [UUID] = []
    @State private var showCreateCustomExercise = false
    @State private var showCardioExercisePicker = false
    @State private var showCardioResolveFailureAlert = false

    @State private var suggestedExercises: [Exercise] = []
    @State private var favoriteExercises: [Exercise] = []
    @State private var recentExercises: [Exercise] = []
    @State private var searchResultExercises: [Exercise] = []
    @State private var workoutMuscleSet: Set<MuscleGroup> = []

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(CardioQuickAddTemplate.all) { template in
                                Button {
                                    addQuickCardio(template)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Image(systemName: template.systemImage)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(FitlogPalette.chartSecondary)
                                        Text(template.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(template.subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(width: 132, alignment: .leading)
                                    .padding(12)
                                    .background(FitlogPalette.chartSecondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(template.name), \(template.subtitle)")
                                .accessibilityHint("Adds this cardio template to your active workout.")
                            }
                            Button {
                                showCardioExercisePicker = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(FitlogPalette.chartSecondary)
                                    Text("Custom…")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Pick exercise")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 100, alignment: .leading)
                                .padding(12)
                                .background(Color.primary.opacity(0.045))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                } header: {
                    Text("Quick cardio")
                } footer: {
                    Text("Adds a cardio segment to this workout without leaving your session.")
                        .font(.caption)
                }

                if !suggestedExercises.isEmpty {
                    Section {
                        ForEach(suggestedExercises) { ex in
                            exerciseButton(ex, subtitle: suggestionSubtitle(for: ex))
                        }
                    } header: {
                        Text(workoutMuscleSet.isEmpty ? "All exercises" : "Suggested for this workout")
                    } footer: {
                        if !workoutMuscleSet.isEmpty {
                            Text("Ordered by how well each movement overlaps muscles you're already training today.")
                                .font(.caption)
                        }
                    }
                }

                if !favoriteExercises.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteExercises) { ex in
                            exerciseButton(ex, subtitle: nil)
                        }
                    }
                }

                if !recentExercises.isEmpty {
                    Section("Recent") {
                        ForEach(recentExercises) { ex in
                            exerciseButton(ex, subtitle: nil)
                        }
                    }
                }

                if !query.isEmpty {
                    Section {
                        ForEach(searchResultExercises) { ex in
                            exerciseButton(ex, subtitle: nil)
                        }
                    } header: {
                        Text("Search results")
                    } footer: {
                        if searchResultExercises.count >= SessionQuickAddExerciseSheet.searchResultsCap {
                            Text("Showing the first \(SessionQuickAddExerciseSheet.searchResultsCap) matches. Refine your search to narrow down.")
                                .font(.caption)
                        }
                    }
                } else if !suggestedExercises.isEmpty || !favoriteExercises.isEmpty || !recentExercises.isEmpty {
                    Section {
                        Text("Search by name or muscle to browse the rest of your library.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if suggestedExercises.isEmpty, favoriteExercises.isEmpty, recentExercises.isEmpty {
                    if query.isEmpty {
                        Section {
                            Text("Every exercise in your library is already in this session, or your library is empty.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if searchResultExercises.isEmpty {
                        Section {
                            Text("No exercises match your search.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if onRequestCustomSetsAndFields != nil || (isFlexibleLibrarySession && onAddTemplateSlot != nil) {
                    Section {
                        if onRequestCustomSetsAndFields != nil {
                            Button {
                                dismiss()
                                DispatchQueue.main.async {
                                    onRequestCustomSetsAndFields?()
                                }
                            } label: {
                                Label("Custom sets & fields…", systemImage: "slider.horizontal.3")
                            }
                        }
                        if isFlexibleLibrarySession, onAddTemplateSlot != nil {
                            Button {
                                onAddTemplateSlot?()
                                dismiss()
                            } label: {
                                Label("Add template slot", systemImage: "square.dashed")
                            }
                        }
                    } header: {
                        Text("More options")
                    } footer: {
                        if onRequestCustomSetsAndFields != nil {
                            Text("Use custom add when you need specific set counts, rep strings, or per-set configuration fields.")
                                .font(.caption)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateCustomExercise = true
                    } label: {
                        Label("New custom", systemImage: "plus.square.on.square")
                    }
                }
            }
            .onAppear {
                favoriteIds = ExercisePickerPersistence.loadFavorites()
                recentIds = ExercisePickerPersistence.loadRecent()
                if !currentVM.isInProgress || currentVM.currentSession?.workout.id != workout.id {
                    dismiss()
                    return
                }
                rebuildExerciseLists()
            }
            .onChange(of: searchText) { _, _ in
                rebuildExerciseLists()
            }
            .onChange(of: showCreateCustomExercise) { _, isPresented in
                if !isPresented {
                    rebuildExerciseLists()
                }
            }
            .sheet(isPresented: $showCreateCustomExercise) {
                NewExerciseSheet(onCreated: { created in
                    addExercise(created)
                })
                .environment(dataVM)
                .environmentObject(aiService)
            }
            .sheet(isPresented: $showCardioExercisePicker) {
                CardioExercisePickerSheet { exercise in
                    let prescription = CardioPrescription(
                        kind: .steadyState,
                        targetDurationSec: 20 * 60,
                        targetZone: .zone2
                    )
                    currentVM.appendCardioExerciseToSession(exercise: exercise, prescription: prescription)
                    dismiss()
                }
                .environment(dataVM)
            }
            .alert(
                "No cardio exercises",
                isPresented: $showCardioResolveFailureAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add a cardio exercise to your library first, then try again.")
            }
        }
    }

    private func addQuickCardio(_ template: CardioQuickAddTemplate) {
        guard let exercise = template.resolveExercise(in: dataVM.globalExercises) else {
            showCardioResolveFailureAlert = true
            return
        }
        guard currentVM.appendCardioExerciseToSession(exercise: exercise, prescription: template.prescription) else {
            showCardioResolveFailureAlert = true
            return
        }
        dismiss()
    }

    private static let searchResultsCap = 150
    private static let suggestedCap = 24

    private func rebuildExerciseLists() {
        guard let session = currentVM.currentSession, session.workout.id == workout.id else { return }

        let existingIds = Set(session.exerciseLogs.compactMap { $0.workoutExercise.exerciseId })
        var muscles = Set<MuscleGroup>()
        for log in session.exerciseLogs {
            guard !log.workoutExercise.isSlotPlaceholder,
                  let snap = log.workoutExercise.snapshot,
                  let ex = dataVM.resolveExercise(for: snap)
            else { continue }
            muscles.formUnion(ex.targetedMuscles)
        }
        workoutMuscleSet = muscles

        let globals = dataVM.globalExercises
        guard !globals.isEmpty else {
            suggestedExercises = []
            favoriteExercises = []
            recentExercises = []
            searchResultExercises = []
            return
        }

        let byId = Dictionary(uniqueKeysWithValues: globals.map { ($0.id, $0) })
        let q = query

        func matchesSearch(_ ex: Exercise) -> Bool {
            ex.matchesExerciseSearch(query: q, resolvedDisplayName: dataVM.resolvedDisplayName(for: ex))
        }

        func overlapScore(_ ex: Exercise) -> Int {
            guard !muscles.isEmpty else { return 0 }
            return ex.targetedMuscles.filter { muscles.contains($0) }.count
        }

        let suggested = globals
            .filter { !existingIds.contains($0.id) && matchesSearch($0) }
            .sorted {
                let s0 = overlapScore($0)
                let s1 = overlapScore($1)
                if s0 != s1 { return s0 > s1 }
                return dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
            }
            .prefix(Self.suggestedCap)
            .map { $0 }
        let suggestedIds = Set(suggested.map(\.id))

        let favorites = favoriteIds.compactMap { byId[$0] }
            .filter { !existingIds.contains($0.id) && matchesSearch($0) && !suggestedIds.contains($0.id) }
            .sorted {
                dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
            }

        let recent = recentIds.compactMap { byId[$0] }
            .filter { !existingIds.contains($0.id) && matchesSearch($0) && !suggestedIds.contains($0.id) }

        let favSet = Set(favorites.map(\.id))
        let recSet = Set(recent.map(\.id))

        var searchResults: [Exercise] = []
        if !q.isEmpty {
            searchResults = globals
                .filter { ex in
                    !existingIds.contains(ex.id)
                        && matchesSearch(ex)
                        && !suggestedIds.contains(ex.id)
                        && !favSet.contains(ex.id)
                        && !recSet.contains(ex.id)
                }
                .sorted {
                    dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
                }
            if searchResults.count > Self.searchResultsCap {
                searchResults = Array(searchResults.prefix(Self.searchResultsCap))
            }
        }

        suggestedExercises = suggested
        favoriteExercises = favorites
        recentExercises = recent
        searchResultExercises = searchResults
    }

    private func suggestionSubtitle(for ex: Exercise) -> String? {
        guard !ex.targetedMuscles.isEmpty else { return nil }
        return ex.targetedMuscles.map(\.rawValue).joined(separator: ", ")
    }

    @ViewBuilder
    private func exerciseButton(_ ex: Exercise, subtitle: String?) -> some View {
        Button {
            addExercise(ex)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(dataVM.resolvedDisplayName(for: ex))
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func addExercise(_ ex: Exercise) {
        ExercisePickerPersistence.recordRecent(exerciseId: ex.id)
        let remembered = ExercisePrescriptionMemory.rememberedSetsAndReps(for: ex.id)
        let recommendedSets = remembered?.sets ?? 3
        let recommendedReps = remembered?.reps ?? "8-12"
        let recommendedConfigBySet: [[String: String]] = Array(repeating: [:], count: recommendedSets)

        if dataVM.userWorkouts.contains(where: { $0.id == workout.id }) {
            if dataVM.addExercise(
                to: workout,
                exercise: ex,
                recommendedSets: recommendedSets,
                recommendedReps: recommendedReps,
                configurationFields: [],
                recommendedConfigBySet: recommendedConfigBySet
            ) != nil,
               let updated = dataVM.userWorkouts.first(where: { $0.id == workout.id }) {
                currentVM.syncExercises(withUpdatedWorkout: updated)
            }
        } else if currentVM.isInProgress, currentVM.currentSession?.workout.id == workout.id {
            currentVM.appendExerciseToSession(
                exercise: ex,
                recommendedSets: recommendedSets,
                recommendedReps: recommendedReps,
                configurationFields: [],
                recommendedConfigBySet: recommendedConfigBySet
            )
        }
        dismiss()
    }
}
