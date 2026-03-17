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
    @State private var showLogSheet = false
    @State private var selectedIndex: Int?
    @State private var showAddExercise = false
    @State private var showRenameAlert = false
    @State private var newWorkoutName = ""
    @State private var displayOrder: ExerciseDisplayOrder = .defaultOrder
    @State private var suggestionsResult: Result<[String], Error>?
    @State private var suggestionsLoading = false
    @State private var suggestionsExpanded = true
    
    /// Display list for default and alphabetical (flat). Order is view-only.
    private var displayedItems: [ExerciseDisplayItem] {
        let enumerated = workout.exercises.enumerated().map { ExerciseDisplayItem(workoutExercise: $0.element, sourceIndex: $0.offset) }
        switch displayOrder {
        case .defaultOrder:
            return enumerated
        case .alphabetical:
            return enumerated.sorted { $0.workoutExercise.exercise.name.localizedCaseInsensitiveCompare($1.workoutExercise.exercise.name) == .orderedAscending }
        case .byMuscleGroup:
            return enumerated
        }
    }
    
    /// Sections for "By muscle" view only. Order is view-only.
    private var displayedSections: [(String, [ExerciseDisplayItem])] {
        let enumerated = workout.exercises.enumerated().map { ExerciseDisplayItem(workoutExercise: $0.element, sourceIndex: $0.offset) }
        let grouped = Dictionary(grouping: enumerated) { item -> String in
            item.workoutExercise.exercise.targetedMuscles.first?.rawValue ?? MuscleGroup.other.rawValue
        }
        return grouped.keys.sorted().map { key in
            (key, (grouped[key] ?? []).sorted { $0.workoutExercise.exercise.name.localizedCaseInsensitiveCompare($1.workoutExercise.exercise.name) == .orderedAscending })
        }
    }
    
    /// Displayed suggestions: from AI when configured and successful, else heuristic.
    private var displayedSuggestions: [String] {
        switch suggestionsResult {
        case .success(let list): return list
        case .failure, .none: return heuristicImprovementSuggestions(for: workout)
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
                        currentVM.startWorkout(workout)
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
        .sheet(isPresented: $showLogSheet) {
            if let idx = selectedIndex {
                LogSetView(exerciseIndex: idx)
                    .environmentObject(currentVM)
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
            if currentVM.currentSession?.workout.id == workout.id {
                selectedIndex = item.sourceIndex
                showLogSheet = true
            }
        } label: {
            HStack {
                Text(we.exercise.name).font(.headline)
                Spacer()
                Text("Rec: \(we.recommendedSets) sets x \(we.recommendedReps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadSuggestions() async {
        guard aiService.isConfigured else {
            suggestionsResult = .success(heuristicImprovementSuggestions(for: workout))
            return
        }
        suggestionsLoading = true
        suggestionsResult = nil
        defer { suggestionsLoading = false }
        do {
            let list = try await aiService.fetchWorkoutSuggestions(for: workout)
            suggestionsResult = .success(list)
        } catch {
            suggestionsResult = .failure(error)
        }
    }
}

// MARK: - Heuristic fallback suggestions
private func heuristicImprovementSuggestions(for workout: Workout) -> [String] {
    guard !workout.exercises.isEmpty else {
        return ["Add 4–6 compound and accessory movements that cover all major muscle groups you want to train."]
    }
    var suggestions: [String] = []
    var setsByMuscle: [MuscleGroup: Int] = [:]
    for we in workout.exercises {
        let primary = we.exercise.targetedMuscles.first ?? .other
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

struct AddExerciseSheet: View {
    let workout: Workout
    /// Passed in so the sheet doesn't observe it; avoids timer-driven re-renders that reset scroll position.
    let currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedExercise: Exercise?
    @State private var recommendedSets = 3
    @State private var recommendedReps = "8-12"
    @State private var configFieldRows: [ConfigFieldRow] = []
    @State private var perSetConfig: [Int: [String: String]] = [:]
    @State private var autoPausedWorkout = false
    /// Snapshot so the Picker doesn't depend on dataVM and re-scroll when parent updates.
    @State private var exerciseList: [Exercise] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Exercise") {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(exerciseList) { ex in
                            Text(ex.name).tag(ex as Exercise?)
                        }
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

                            if let _ = dataVM.addExercise(to: workout,
                                                          exercise: ex,
                                                          recommendedSets: recommendedSets,
                                                          recommendedReps: recommendedReps,
                                                          configurationFields: fieldNames,
                                                          recommendedConfigBySet: recommendedConfigBySet) {
                                // If this workout is currently in progress, ensure the active session
                                // gains a corresponding ExerciseLog so it shows up immediately.
                                if let updatedWorkout = dataVM.userWorkouts.first(where: { $0.id == workout.id }) {
                                    currentVM.syncExercises(withUpdatedWorkout: updatedWorkout)
                                }
                            }
                            dismiss()
                        }
                    }
                    .disabled(selectedExercise == nil)
                }
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
