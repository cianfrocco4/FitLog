//
//  WorkoutPlanView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

/// View-only display order; persisted order is unchanged.
enum ExerciseDisplayOrder: String, CaseIterable {
    case defaultOrder = "Order"
    case alphabetical = "A–Z"
    case byMuscleGroup = "By muscle"
}

/// Wraps a workout exercise with its index in the persisted array (for tap/delete/move).
private struct ExerciseDisplayItem: Identifiable {
    let id: UUID
    let workoutExercise: WorkoutExercise
    let sourceIndex: Int
    
    init(workoutExercise: WorkoutExercise, sourceIndex: Int) {
        self.id = workoutExercise.id
        self.workoutExercise = workoutExercise
        self.sourceIndex = sourceIndex
    }
}

struct WorkoutPlanView: View {
    @Binding var workout: Workout
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var aiService: AIService
    @Environment(\.openPullUpToExerciseLogIndex) private var openPullUpToExerciseLogIndex
    @State private var showAddExercise = false
    @State private var showRenameAlert = false
    @State private var newWorkoutName = ""
    @State private var displayOrder: ExerciseDisplayOrder = .defaultOrder
    @State private var suggestionsResult: Result<[String], Error>?
    @State private var suggestionsLoading = false
    @State private var suggestionsExpanded = true
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?

    /// Display list for default and alphabetical (flat). Order is view-only.
    private var displayedItems: [ExerciseDisplayItem] {
        let enumerated = workout.exercises.enumerated().map { ExerciseDisplayItem(workoutExercise: $0.element, sourceIndex: $0.offset) }
        switch displayOrder {
        case .defaultOrder:
            return enumerated
        case .alphabetical:
            return enumerated.sorted {
                dataVM.displayName(for: $0.workoutExercise)
                    .localizedCaseInsensitiveCompare(dataVM.displayName(for: $1.workoutExercise)) == .orderedAscending
            }
        case .byMuscleGroup:
            return enumerated
        }
    }
    
    /// Sections for "By muscle" view only. Order is view-only.
    private var displayedSections: [(String, [ExerciseDisplayItem])] {
        let enumerated = workout.exercises.enumerated().map { ExerciseDisplayItem(workoutExercise: $0.element, sourceIndex: $0.offset) }
        let grouped = Dictionary(grouping: enumerated) { item -> String in
            if let snap = item.workoutExercise.snapshot,
               let ex = dataVM.resolveExercise(for: snap) {
                return ex.targetedMuscles.first?.rawValue ?? MuscleGroup.other.rawValue
            }
            return MuscleGroup.other.rawValue
        }
        return grouped.keys.sorted().map { key in
            (key, (grouped[key] ?? []).sorted {
                dataVM.displayName(for: $0.workoutExercise)
                    .localizedCaseInsensitiveCompare(dataVM.displayName(for: $1.workoutExercise)) == .orderedAscending
            })
        }
    }
    
    /// Displayed suggestions: from AI when configured and successful, else heuristic.
    private var displayedSuggestions: [String] {
        switch suggestionsResult {
        case .success(let list): return list
        case .failure, .none: return heuristicImprovementSuggestions(for: workout, dataVM: dataVM)
        }
    }

    var body: some View {
        Group {
            if displayOrder == .byMuscleGroup {
                listWithSections
            } else {
                listFlat
            }
        }
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(currentVM.currentSession?.workout.id == workout.id ? "Stop" : "Start") {
                    if currentVM.currentSession?.workout.id == workout.id {
                        currentVM.stopWorkout()
                    } else {
                        currentVM.startWorkoutResolvingConflict(workout, sessionPlanOrigin: .concreteWorkout(workout.id)) {
                            pendingWorkoutReplace = $0
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(currentVM.currentSession?.workout.id == workout.id ? .red : .green)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rename") {
                    newWorkoutName = workout.name
                    showRenameAlert = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("View", selection: $displayOrder) {
                        ForEach(ExerciseDisplayOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("View", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet(workout: workout, currentVM: currentVM)
        }
        .alert("Rename Workout", isPresented: $showRenameAlert) {
            TextField("New name", text: $newWorkoutName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                dataVM.renameWorkout(workout, newName: newWorkoutName)
            }
        }
        .workoutReplaceConflictConfirmation(currentVM: currentVM, pending: $pendingWorkoutReplace)
    }
    
    private var listFlat: some View {
        List {
            if displayOrder == .defaultOrder {
                ForEach(displayedItems) { item in
                    exerciseRow(item: item)
                }
                .onDelete { indexSet in
                    indexSet.map { displayedItems[$0] }.forEach { dataVM.deleteExercise(from: workout, exerciseId: $0.workoutExercise.id) }
                }
                .onMove { from, to in
                    dataVM.moveExercise(in: workout, from: from, to: to)
                    if let updatedWorkout = dataVM.userWorkouts.first(where: { $0.id == workout.id }) {
                        currentVM.syncExercises(withUpdatedWorkout: updatedWorkout)
                    }
                }
            } else {
                ForEach(displayedItems) { item in
                    exerciseRow(item: item)
                }
                .onDelete { indexSet in
                    indexSet.map { displayedItems[$0] }.forEach { dataVM.deleteExercise(from: workout, exerciseId: $0.workoutExercise.id) }
                }
            }
            suggestionsSection
            Button("Add Exercise") { showAddExercise = true }
        }
    }
    
    private var listWithSections: some View {
        List {
            ForEach(displayedSections, id: \.0) { sectionName, items in
                Section(header: Text(sectionName)) {
                    ForEach(items) { item in
                        exerciseRow(item: item)
                    }
                    .onDelete { indexSet in
                        indexSet.map { items[$0] }.forEach { dataVM.deleteExercise(from: workout, exerciseId: $0.workoutExercise.id) }
                    }
                }
            }
            suggestionsSection
            Button("Add Exercise") { showAddExercise = true }
        }
    }

    private var suggestionsSection: some View {
        Section("Suggestions") {
            Button {
                Task { await loadSuggestions() }
            } label: {
                Label("Get Suggestions", systemImage: "lightbulb")
            }
            .disabled(suggestionsLoading)
            if suggestionsLoading {
                HStack {
                    ProgressView()
                    Text("Loading…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if suggestionsResult != nil {
                DisclosureGroup(isExpanded: $suggestionsExpanded) {
                    if case .failure(let error) = suggestionsResult {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    ForEach(displayedSuggestions, id: \.self) { suggestion in
                        Text("• \(suggestion)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Text("Suggestions")
                }
            }
        }
    }
    
    private func exerciseRow(item: ExerciseDisplayItem) -> some View {
        let we = item.workoutExercise
        return Button {
            guard currentVM.currentSession?.workout.id == workout.id,
                  item.sourceIndex < workout.exercises.count
            else { return }
            let rowId = workout.exercises[item.sourceIndex].id
            guard let logIndex = currentVM.currentSession?.exerciseLogs.firstIndex(where: { $0.workoutExercise.id == rowId })
            else { return }
            openPullUpToExerciseLogIndex?(logIndex)
        } label: {
            HStack {
                Text(dataVM.displayName(for: we)).font(.headline)
                Spacer()
                Text("Rec: \(we.recommendedSets) sets x \(we.recommendedReps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadSuggestions() async {
        guard aiService.isConfigured else {
            suggestionsResult = .success(heuristicImprovementSuggestions(for: workout, dataVM: dataVM))
            return
        }
        suggestionsLoading = true
        suggestionsResult = nil
        defer { suggestionsLoading = false }
        do {
            let list = try await aiService.fetchWorkoutSuggestions(for: workout, globalExercises: dataVM.globalExercises)
            suggestionsResult = .success(list)
        } catch {
            suggestionsResult = .failure(error)
        }
    }
}

// MARK: - Heuristic fallback suggestions
private func heuristicImprovementSuggestions(for workout: Workout, dataVM: DataManager) -> [String] {
    guard !workout.exercises.isEmpty else {
        return ["Add 4–6 compound and accessory movements that cover all major muscle groups you want to train."]
    }
    var suggestions: [String] = []
    var setsByMuscle: [MuscleGroup: Int] = [:]
    for we in workout.exercises {
        let primary: MuscleGroup
        if let snap = we.snapshot, let ex = dataVM.resolveExercise(for: snap) {
            primary = ex.targetedMuscles.first ?? .other
        } else {
            primary = .other
        }
        setsByMuscle[primary, default: 0] += we.recommendedSets
    }
    let quadSets = (setsByMuscle[.quads] ?? 0)
    let hamSets = (setsByMuscle[.hamstrings] ?? 0)
    if quadSets > 0 && hamSets == 0 {
        suggestions.append("You have quad work but no direct hamstring work; consider adding a hinge or leg curl variation.")
    }
    let pushSets = (setsByMuscle[.chest] ?? 0) + (setsByMuscle[.frontDelts] ?? 0) + (setsByMuscle[.triceps] ?? 0)
    let pullSets = (setsByMuscle[.lats] ?? 0) + (setsByMuscle[.upperBack] ?? 0) + (setsByMuscle[.biceps] ?? 0)
    if pushSets >= pullSets * 2 && pullSets > 0 {
        suggestions.append("Push volume is much higher than pull; consider adding rowing or pulldown work to balance your upper body.")
    }
    if workout.exercises.count > 8 {
        suggestions.append("You have a lot of exercises in this workout; consider trimming to 4–6 key movements and adding sets instead.")
    }
    if suggestions.isEmpty {
        suggestions.append("Your workout looks reasonably balanced. Focus on adding small amounts of volume or load over time to progress.")
    }
    return suggestions
}

// MARK: - Exercise picker (search, favorites, recent, subgrouping, section index)
private struct ExercisePickerView: View {
    let exercises: [Exercise]
    @Binding var selection: Exercise?
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var favoriteIds: Set<UUID> = []
    @State private var recentIds: [UUID] = []

    /// Search by exercise name or primary muscle name.
    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return exercises }
        return exercises.filter { ex in
            dataVM.resolvedDisplayName(for: ex).localizedCaseInsensitiveContains(q)
            || ex.name.localizedCaseInsensitiveContains(q)
            || (ex.targetedMuscles.first ?? .other).rawValue.localizedCaseInsensitiveContains(q)
        }
    }

    private var favoriteExercises: [Exercise] {
        filtered.filter { favoriteIds.contains($0.id) }
            .sorted {
                dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
            }
    }

    private var recentExercises: [Exercise] {
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        return recentIds.compactMap { byId[$0] }
            .filter { filtered.contains($0) && !favoriteIds.contains($0.id) }
    }

    private var exercisesForBucketGrouping: [Exercise] {
        let pinned = Set(favoriteExercises.map(\.id)).union(Set(recentExercises.map(\.id)))
        return filtered.filter { !pinned.contains($0.id) }
    }

    /// Subgrouped: (bucketName, [(muscle, [Exercise])]) in bucket order.
    private var bucketedSections: [(String, [(MuscleGroup, [Exercise])])] {
        ExerciseCategoryGrouping.bucketedSections(exercises: exercisesForBucketGrouping) { dataVM.resolvedDisplayName(for: $0) }
    }

    /// Section IDs for scroll-to (section index).
    private var sectionIds: [String] {
        var ids: [String] = []
        if !favoriteExercises.isEmpty { ids.append("favorites") }
        if !recentExercises.isEmpty { ids.append("recent") }
        ids.append(contentsOf: bucketedSections.map { $0.0.lowercased() })
        return ids
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !favoriteExercises.isEmpty {
                    Section(header: Text("Favorites")) {
                        exerciseRows(favoriteExercises, showFavorite: true)
                    }
                    .id("favorites")
                }
                if !recentExercises.isEmpty {
                    Section(header: Text("Recent")) {
                        exerciseRows(recentExercises, showFavorite: true)
                    }
                    .id("recent")
                }
                ForEach(bucketedSections, id: \.0) { bucket, musclePairs in
                    Section(header: Text(bucket)) {
                        ForEach(musclePairs, id: \.0.id) { muscle, list in
                            Section(header: Text(muscle.rawValue)) {
                                exerciseRows(list, showFavorite: true)
                            }
                        }
                    }
                    .id(bucket.lowercased())
                }
            }
            .searchable(text: $searchText, prompt: "Search by name or muscle")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if sectionIds.count > 1 {
                    ExerciseSectionIndexStrip(proxy: proxy, ids: sectionIds)
                }
            }
            .onAppear {
                favoriteIds = ExercisePickerPersistence.loadFavorites()
                recentIds = ExercisePickerPersistence.loadRecent()
            }
        }
    }

    @ViewBuilder
    private func exerciseRows(_ list: [Exercise], showFavorite: Bool) -> some View {
        ForEach(list) { ex in
            Button {
                selection = ex
                dismiss()
            } label: {
                HStack {
                    Text(dataVM.resolvedDisplayName(for: ex))
                    Spacer()
                    if showFavorite {
                        Button {
                            toggleFavorite(ex.id)
                        } label: {
                            Image(systemName: favoriteIds.contains(ex.id) ? "heart.fill" : "heart")
                                .foregroundStyle(favoriteIds.contains(ex.id) ? .red : .secondary)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                    }
                    if selection?.id == ex.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    private func toggleFavorite(_ id: UUID) {
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
        } else {
            favoriteIds.insert(id)
        }
        ExercisePickerPersistence.saveFavorites(favoriteIds)
    }
}


struct AddExerciseSheet: View {
    let workout: Workout
    /// Passed in so the sheet doesn't observe it; avoids timer-driven re-renders that reset scroll position.
    let currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedExercise: Exercise?
    @State private var recommendedSets = 3
    @State private var recommendedReps = "8-12"
    @State private var configFieldRows: [ConfigFieldRow] = []
    @State private var perSetConfig: [Int: [String: String]] = [:]
    @State private var autoPausedWorkout = false
    /// Snapshot so the list doesn't depend on dataVM and re-scroll when parent updates.
    @State private var exerciseList: [Exercise] = []
    @State private var showCreateCustomExercise = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Exercise") {
                    NavigationLink {
                        ExercisePickerView(exercises: exerciseList, selection: $selectedExercise)
                            .environmentObject(dataVM)
                    } label: {
                        HStack {
                            Text("Exercise")
                            Spacer()
                            Text(selectedExercise.map { dataVM.resolvedDisplayName(for: $0) } ?? "Tap to choose")
                                .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                        }
                    }
                    Button {
                        showCreateCustomExercise = true
                    } label: {
                        Label("Create new custom exercise", systemImage: "plus.circle")
                    }
                }
                
                Section("Recommended") {
                    Stepper("Sets: \(recommendedSets)", value: $recommendedSets, in: 1...10)
                    TextField("Reps (e.g. 8-12)", text: $recommendedReps)
                }

                if selectedExercise != nil {
                    Section("Configuration fields (optional)") {
                        ForEach(configFieldRows.indices, id: \.self) { idx in
                            HStack {
                                TextField("Field name (e.g. Grip, Seat)", text: $configFieldRows[idx].name)
                                Button(role: .destructive) {
                                    configFieldRows.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                            }
                        }
                        Button {
                            configFieldRows.append(ConfigFieldRow())
                        } label: {
                            Label("Add field", systemImage: "plus.circle")
                        }
                    }

                    if !configFieldRows.isEmpty {
                        Section("Per-set recommended configuration") {
                            ForEach(0..<recommendedSets, id: \.self) { setIndex in
                                DisclosureGroup("Set \(setIndex + 1)") {
                                    ForEach(configFieldRows.indices, id: \.self) { idx in
                                        let fieldName = configFieldRows[idx].name.trimmingCharacters(in: .whitespaces)
                                        if !fieldName.isEmpty {
                                            TextField(fieldName, text: bindingForSetField(setIndex: setIndex, field: fieldName))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .onAppear {
                exerciseList = dataVM.globalExercises
                // Pause the workout while the sheet is open so timer-driven updates don't affect the parent.
                if currentVM.isInProgress,
                   currentVM.currentSession?.workout.id == workout.id,
                   !currentVM.isWorkoutPaused {
                    currentVM.pauseWorkout()
                    autoPausedWorkout = true
                }
            }
            .onDisappear {
                if autoPausedWorkout,
                   currentVM.isInProgress,
                   currentVM.currentSession?.workout.id == workout.id,
                   currentVM.isWorkoutPaused {
                    currentVM.resumeWorkout()
                }
                autoPausedWorkout = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if let ex = selectedExercise {
                            let fieldNames = configFieldRows
                                .map { $0.name.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            let recommendedConfigBySet: [[String: String]] = (0..<recommendedSets).map { idx in
                                let raw = perSetConfig[idx] ?? [:]
                                // Keep only known fields and non-empty values
                                var cleaned: [String: String] = [:]
                                for name in fieldNames {
                                    if let value = raw[name], !value.trimmingCharacters(in: .whitespaces).isEmpty {
                                        cleaned[name] = value.trimmingCharacters(in: .whitespaces)
                                    }
                                }
                                return cleaned
                            }

                            ExercisePickerPersistence.recordRecent(exerciseId: ex.id)
                            if dataVM.userWorkouts.contains(where: { $0.id == workout.id }) {
                                if let _ = dataVM.addExercise(to: workout,
                                                              exercise: ex,
                                                              recommendedSets: recommendedSets,
                                                              recommendedReps: recommendedReps,
                                                              configurationFields: fieldNames,
                                                              recommendedConfigBySet: recommendedConfigBySet),
                                   let updatedWorkout = dataVM.userWorkouts.first(where: { $0.id == workout.id }) {
                                    currentVM.syncExercises(withUpdatedWorkout: updatedWorkout)
                                }
                            } else if currentVM.isInProgress,
                                      currentVM.currentSession?.workout.id == workout.id {
                                currentVM.appendExerciseToSession(
                                    exercise: ex,
                                    recommendedSets: recommendedSets,
                                    recommendedReps: recommendedReps,
                                    configurationFields: fieldNames,
                                    recommendedConfigBySet: recommendedConfigBySet
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(selectedExercise == nil)
                }
            }
            .keyboardDismissToolbar()
            .sheet(isPresented: $showCreateCustomExercise) {
                NewExerciseSheet(onCreated: { created in
                    exerciseList = dataVM.globalExercises
                    selectedExercise = created
                })
                .environmentObject(dataVM)
                .environmentObject(aiService)
            }
        }
    }
}

private struct ConfigFieldRow: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
}

private extension AddExerciseSheet {
    func bindingForSetField(setIndex: Int, field: String) -> Binding<String> {
        Binding(
            get: {
                perSetConfig[setIndex]?[field] ?? ""
            },
            set: { newValue in
                var copy = perSetConfig[setIndex] ?? [:]
                copy[field] = newValue
               var all = perSetConfig
                all[setIndex] = copy
                perSetConfig = all
            }
        )
    }
}
