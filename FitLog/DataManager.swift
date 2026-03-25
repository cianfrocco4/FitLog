//
//  DataManager.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//


import Foundation

final class DataManager: ObservableObject {
    @Published var userWorkouts: [Workout] = []
    /// Slot blueprints (Option A); separate from concrete `userWorkouts`.
    @Published var userWorkoutTemplates: [WorkoutTemplate] = []
    @Published var globalExercises: [Exercise] = []
    /// Per-exercise display name overrides (by exercise id). Does not change canonical `Exercise.name`.
    @Published private(set) var exerciseLocalDisplayNames: [UUID: String] = [:]
    @Published var completedSessions: [WorkoutSession] = []
    @Published var trainingProgram: TrainingProgramState = TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))

    private let workoutsKey = "userWorkouts"
    /// One-time backup of the raw workouts payload, used for recovery if a future schema change breaks decoding.
    private let workoutsBackupKey = "userWorkouts_backup_v1"
    private let workoutTemplatesKey = "userWorkoutTemplates_v1"
    private let workoutTemplatesBackupKey = "userWorkoutTemplates_backup_v1"
    private let exercisesKey = "globalExercises"
    private let exerciseLocalDisplayNamesKey = "exerciseLocalDisplayNames"
    private let sessionsKey = "completedSessions"
    private let sessionsBackupKey = "completedSessions_backup_v1"
    private let exercisesPreloadedKey = "exercisesPreloaded"
    private let trainingProgramKey = "trainingProgram_v1"
    /// One-time raw snapshot of workouts + sessions before the first training-program save (extra safety on top of `_backup_v1`).
    private let schedulePrecheckFlagKey = "fitlog_schedule_precheck_backup_v1"
    private let workoutsPrecheckSnapshotKey = "userWorkouts_precheck_schedule_v1"
    private let sessionsPrecheckSnapshotKey = "completedSessions_precheck_schedule_v1"

    init() { loadAll() }

    func loadAll() {
        loadWorkouts()
        loadWorkoutTemplates()
        loadExercises()
        loadExerciseLocalDisplayNames()
        loadSessions()
        loadTrainingProgram()
        
        if !UserDefaults.standard.bool(forKey: exercisesPreloadedKey) {
            preloadFullExerciseLibrary()
            UserDefaults.standard.set(true, forKey: exercisesPreloadedKey)
        }
    }
    
    // MARK: - Workouts
    @discardableResult
    func createWorkout(name: String) -> UUID {
        let newWorkout = Workout(id: UUID(), name: name, exercises: [])
        userWorkouts.append(newWorkout)
        saveWorkouts()
        objectWillChange.send()
        return newWorkout.id
    }

    /// Picks a template name that does not collide with existing workout names.
    func uniqueWorkoutTemplateName(_ base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let root = trimmed.isEmpty ? "Workout" : trimmed
        let existingW = Set(userWorkouts.map(\.name))
        let existingT = Set(userWorkoutTemplates.map(\.name))
        if !existingW.contains(root), !existingT.contains(root) { return root }
        var n = 2
        while existingW.contains("\(root) (\(n))") || existingT.contains("\(root) (\(n))") {
            n += 1
        }
        return "\(root) (\(n))"
    }

    /// Creates new workout templates with exercises, optionally sets the training program cycle and schedule.
    func applySplitBuilderTemplates(
        workouts: [(templateName: String, exercises: [(exercise: Exercise, sets: Int, reps: String)])],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        updateTrainingProgram: Bool,
        anchorDate: Date = Date()
    ) {
        var newIds: [UUID] = []
        for w in workouts {
            let name = uniqueWorkoutTemplateName(w.templateName)
            let id = createWorkout(name: name)
            newIds.append(id)
            for ex in w.exercises {
                guard let fresh = userWorkouts.first(where: { $0.id == id }) else { break }
                let sets = min(max(1, ex.sets), 10)
                let reps = ex.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                let repsFinal = reps.isEmpty ? "8-12" : reps
                _ = addExercise(
                    to: fresh,
                    exercise: ex.exercise,
                    recommendedSets: sets,
                    recommendedReps: repsFinal,
                    configurationFields: [],
                    recommendedConfigBySet: Array(repeating: [:], count: sets)
                )
            }
        }
        if updateTrainingProgram, !newIds.isEmpty {
            applyTrainingProgramSuggestion(
                cycleEntries: newIds.map { ProgramCycleEntry(kind: .concreteWorkout, id: $0) },
                sessionsPerWeek: sessionsPerWeek,
                preferredWeekdays: preferredWeekdays,
                anchorDate: anchorDate
            )
        }
    }
    
    func deleteWorkout(_ workout: Workout) {
        userWorkouts.removeAll { $0.id == workout.id }
        saveWorkouts()
    }
    
    func renameWorkout(_ workout: Workout, newName: String) {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        userWorkouts[index].name = newName
        saveWorkouts()
    }
    
    func moveWorkout(from source: IndexSet, to destination: Int) {
        userWorkouts.move(fromOffsets: source, toOffset: destination)
        saveWorkouts()
    }
    
    private func loadWorkouts() {
        if let data = UserDefaults.standard.data(forKey: workoutsKey) {
            do {
                let decoded = try JSONDecoder().decode([Workout].self, from: data)
                userWorkouts = decoded
                #if DEBUG
                print("✅ Loaded \(decoded.count) workouts from UserDefaults")
                #endif
            } catch {
                // IMPORTANT: Do not wipe existing data on decode failure.
                // Try to recover from a previous backup snapshot, if available.
                #if DEBUG
                print("❌ Decoding workouts failed: \(error.localizedDescription)")
                #endif
                if let backupData = UserDefaults.standard.data(forKey: workoutsBackupKey) {
                    do {
                        let recovered = try JSONDecoder().decode([Workout].self, from: backupData)
                        userWorkouts = recovered
                        #if DEBUG
                        print("✅ Recovered \(recovered.count) workouts from legacy backup snapshot")
                        #endif
                        // Re-save to the primary key so the app continues normally.
                        saveWorkouts()
                    } catch {
                        #if DEBUG
                        print("❌ Failed to recover workouts from backup: \(error.localizedDescription)")
                        #endif
                    }
                }
            }
        }
    }
    
    func saveWorkouts() {
        do {
            let data = try JSONEncoder().encode(userWorkouts)
            UserDefaults.standard.set(data, forKey: workoutsKey)
            #if DEBUG
            print("✅ Saved \(userWorkouts.count) workouts to UserDefaults")
            #endif
            // Create a one-time backup snapshot for recovery from future schema changes.
            if UserDefaults.standard.data(forKey: workoutsBackupKey) == nil {
                UserDefaults.standard.set(data, forKey: workoutsBackupKey)
                #if DEBUG
                print("💾 Created workouts backup snapshot")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Encoding failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Slot workout templates (blueprints)

    private func loadWorkoutTemplates() {
        guard let data = UserDefaults.standard.data(forKey: workoutTemplatesKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([WorkoutTemplate].self, from: data)
            userWorkoutTemplates = decoded
        } catch {
            #if DEBUG
            print("❌ Decoding workout templates failed: \(error.localizedDescription)")
            #endif
            if let backupData = UserDefaults.standard.data(forKey: workoutTemplatesBackupKey) {
                do {
                    let recovered = try JSONDecoder().decode([WorkoutTemplate].self, from: backupData)
                    userWorkoutTemplates = recovered
                    saveWorkoutTemplates()
                } catch {
                    #if DEBUG
                    print("❌ Failed to recover workout templates from backup")
                    #endif
                }
            }
        }
    }

    func saveWorkoutTemplates() {
        do {
            let data = try JSONEncoder().encode(userWorkoutTemplates)
            UserDefaults.standard.set(data, forKey: workoutTemplatesKey)
            if UserDefaults.standard.data(forKey: workoutTemplatesBackupKey) == nil {
                UserDefaults.standard.set(data, forKey: workoutTemplatesBackupKey)
            }
        } catch {
            #if DEBUG
            print("❌ Encoding workout templates failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Empty slot template; edit slots in a dedicated UI later.
    @discardableResult
    func createSlotTemplate(name: String) -> UUID {
        createSlotTemplate(name: name, slots: [])
    }

    /// Slot template with initial slots (e.g. from AI split builder).
    @discardableResult
    func createSlotTemplate(name: String, slots: [TemplateSlot]) -> UUID {
        let trimmed = uniqueSlotTemplateName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        let t = WorkoutTemplate(id: UUID(), name: trimmed, slots: slots)
        userWorkoutTemplates.append(t)
        saveWorkoutTemplates()
        objectWillChange.send()
        return t.id
    }

    /// Builds concrete workouts and/or slot templates from an AI proposal and optionally updates the training program cycle.
    func applyWorkoutSplitProposal(
        _ proposal: WorkoutSplitProposal,
        updateTrainingProgram: Bool,
        anchorDate: Date = Date()
    ) {
        var entries: [ProgramCycleEntry] = []
        for day in proposal.workouts {
            if day.isSlotTemplateDay {
                let templateSlots: [TemplateSlot] = day.slots.map { s in
                    let muscles = s.targetMuscleNames.compactMap { MuscleGroup(rawValue: $0) }
                    let muscleFinal = muscles.isEmpty ? [MuscleGroup.other] : muscles
                    let defId: UUID? = s.suggestedExerciseName.flatMap { name in
                        globalExercises.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.id
                    }
                    let repsRaw = s.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsFinal = repsRaw.isEmpty ? "8-12" : repsRaw
                    return TemplateSlot(
                        label: s.label,
                        targetedMuscles: muscleFinal,
                        defaultExerciseId: defId,
                        recommendedSets: min(max(1, s.sets), 10),
                        recommendedReps: repsFinal
                    )
                }
                guard !templateSlots.isEmpty else { continue }
                let id = createSlotTemplate(name: day.name, slots: templateSlots)
                entries.append(ProgramCycleEntry(kind: .slotTemplate, id: id))
            } else {
                guard !day.exercises.isEmpty else { continue }
                let name = uniqueWorkoutTemplateName(day.name)
                let id = createWorkout(name: name)
                entries.append(ProgramCycleEntry(kind: .concreteWorkout, id: id))
                for exItem in day.exercises {
                    guard let fresh = userWorkouts.first(where: { $0.id == id }) else { break }
                    let sets = min(max(1, exItem.sets), 10)
                    let reps = exItem.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsFinal = reps.isEmpty ? "8-12" : reps
                    guard let ex = globalExercises.first(where: { $0.name.caseInsensitiveCompare(exItem.name) == .orderedSame }) else { continue }
                    _ = addExercise(
                        to: fresh,
                        exercise: ex,
                        recommendedSets: sets,
                        recommendedReps: repsFinal,
                        configurationFields: [],
                        recommendedConfigBySet: Array(repeating: [:], count: sets)
                    )
                }
            }
        }
        if updateTrainingProgram, !entries.isEmpty {
            applyTrainingProgramSuggestion(
                cycleEntries: entries,
                sessionsPerWeek: proposal.sessionsPerWeek,
                preferredWeekdays: proposal.preferredWeekdays,
                anchorDate: anchorDate
            )
        }
    }

    func uniqueSlotTemplateName(_ base: String) -> String {
        let root = base.isEmpty ? "Template" : base
        let existingW = Set(userWorkouts.map(\.name))
        let existingT = Set(userWorkoutTemplates.map(\.name))
        if !existingW.contains(root), !existingT.contains(root) { return root }
        var n = 2
        while existingW.contains("\(root) (\(n))") || existingT.contains("\(root) (\(n))") {
            n += 1
        }
        return "\(root) (\(n))"
    }

    func deleteSlotTemplate(_ template: WorkoutTemplate) {
        userWorkoutTemplates.removeAll { $0.id == template.id }
        var p = trainingProgram
        p.cycleEntries.removeAll { $0.kind == .slotTemplate && $0.id == template.id }
        trainingProgram = p
        saveWorkoutTemplates()
        saveTrainingProgram()
    }

    func renameSlotTemplate(_ template: WorkoutTemplate, newName: String) {
        guard let idx = userWorkoutTemplates.firstIndex(where: { $0.id == template.id }) else { return }
        var t = userWorkoutTemplates[idx]
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            t.name = trimmed
        }
        userWorkoutTemplates[idx] = t
        saveWorkoutTemplates()
    }

    func updateSlotTemplate(_ template: WorkoutTemplate) {
        guard let idx = userWorkoutTemplates.firstIndex(where: { $0.id == template.id }) else { return }
        userWorkoutTemplates[idx] = template
        saveWorkoutTemplates()
    }

    func slotTemplate(id: UUID) -> WorkoutTemplate? {
        userWorkoutTemplates.first { $0.id == id }
    }

    /// Build a concrete session `Workout` from a blueprint (placeholders until the user resolves slots).
    func instantiateWorkout(from template: WorkoutTemplate) -> Workout {
        var exercises: [WorkoutExercise] = []
        for slot in template.slots {
            let weId = UUID()
            let resolvedFromDefault: Exercise? = {
                guard let defId = slot.defaultExerciseId else { return nil }
                return globalExercises.first { $0.id == defId }
            }()
            if let ex = resolvedFromDefault {
                exercises.append(
                    WorkoutExercise(
                        id: weId,
                        exercise: ex,
                        defaultRestTime: slot.defaultRestTime,
                        recommendedSets: slot.recommendedSets,
                        recommendedReps: slot.recommendedReps,
                        isSlotPlaceholder: false,
                        templateSlotId: slot.id,
                        slotLabel: slot.label
                    )
                )
            } else {
                let placeholder = Exercise.unfilledSlotPlaceholder(label: slot.label)
                exercises.append(
                    WorkoutExercise(
                        id: weId,
                        exercise: placeholder,
                        defaultRestTime: slot.defaultRestTime,
                        recommendedSets: slot.recommendedSets,
                        recommendedReps: slot.recommendedReps,
                        isSlotPlaceholder: true,
                        templateSlotId: slot.id,
                        slotLabel: slot.label
                    )
                )
            }
        }
        return Workout(id: UUID(), name: template.name, exercises: exercises)
    }

    func cycleEntryDisplayLabel(_ entry: ProgramCycleEntry) -> String {
        switch entry.kind {
        case .concreteWorkout:
            return workoutDisplayName(forWorkoutId: entry.id)
        case .slotTemplate:
            return userWorkoutTemplates.first(where: { $0.id == entry.id })?.name ?? "Missing template"
        }
    }

    func planLabel(for ref: WorkoutPlanRef) -> String {
        switch ref {
        case .concreteWorkout(let id):
            return workoutDisplayName(forWorkoutId: id)
        case .slotTemplate(let id):
            return userWorkoutTemplates.first(where: { $0.id == id })?.name ?? "Missing template"
        }
    }

    // MARK: - Global Exercises (now 60+ default)
    @discardableResult
    func addNewExercise(name: String, description: String, muscles: [MuscleGroup]) -> Exercise {
        let new = Exercise(id: UUID(), name: name, description: description, targetedMuscles: muscles, isCustom: true, configurationOptions: [])
        globalExercises.append(new)
        saveExercises()
        return new
    }
    
    func updateExercise(_ exercise: Exercise) {
        guard let idx = globalExercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        globalExercises[idx] = exercise
        for i in userWorkouts.indices {
            for j in userWorkouts[i].exercises.indices {
                if userWorkouts[i].exercises[j].exercise.id == exercise.id {
                    userWorkouts[i].exercises[j].exercise = exercise
                }
            }
        }
        saveExercises()
        saveWorkouts()
    }
    
    func deleteGlobalExercise(_ exercise: Exercise) {
        clearLocalExerciseDisplayName(for: exercise.id)
        globalExercises.removeAll { $0.id == exercise.id }
        for i in userWorkouts.indices {
            userWorkouts[i].exercises.removeAll { $0.exercise.id == exercise.id }
        }
        saveExercises()
        saveWorkouts()
    }

    // MARK: - Local exercise display names

    /// Name shown in the UI: custom local label if set, otherwise the canonical library name (from `globalExercises` when present).
    func resolvedDisplayName(for exercise: Exercise) -> String {
        let canonical = globalExercises.first(where: { $0.id == exercise.id })?.name ?? exercise.name
        if let custom = exerciseLocalDisplayNames[exercise.id] {
            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return canonical
    }

    func hasLocalDisplayName(for exerciseId: UUID) -> Bool {
        guard let s = exerciseLocalDisplayNames[exerciseId] else { return false }
        return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setLocalExerciseDisplayName(for exerciseId: UUID, customName: String?) {
        guard let ex = globalExercises.first(where: { $0.id == exerciseId }) else { return }
        let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var next = exerciseLocalDisplayNames
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare(ex.name) == .orderedSame {
            next.removeValue(forKey: exerciseId)
        } else {
            next[exerciseId] = trimmed
        }
        exerciseLocalDisplayNames = next
        saveExerciseLocalDisplayNames()
    }

    func clearLocalExerciseDisplayName(for exerciseId: UUID) {
        var next = exerciseLocalDisplayNames
        next.removeValue(forKey: exerciseId)
        exerciseLocalDisplayNames = next
        saveExerciseLocalDisplayNames()
    }

    private func loadExerciseLocalDisplayNames() {
        guard let data = UserDefaults.standard.data(forKey: exerciseLocalDisplayNamesKey),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            exerciseLocalDisplayNames = [:]
            return
        }
        var out: [UUID: String] = [:]
        for (key, value) in raw {
            guard let id = UUID(uuidString: key) else { continue }
            let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { out[id] = t }
        }
        exerciseLocalDisplayNames = out
    }

    private func saveExerciseLocalDisplayNames() {
        let raw = Dictionary(uniqueKeysWithValues: exerciseLocalDisplayNames.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: exerciseLocalDisplayNamesKey)
        }
    }
    
    /// Names of exercises in the built-in library. Used to treat legacy user-added exercises as custom (editable/deletable) after app update.
    private static let defaultExerciseNames: Set<String> = [
        "Barbell Bench Press", "Incline Barbell Bench Press", "Decline Barbell Bench Press", "Dumbbell Bench Press",
        "Incline Dumbbell Press", "Dumbbell Flies", "Cable Crossover", "Overhead Barbell Press", "Seated Dumbbell Press",
        "Arnold Press", "Lateral Raise", "Front Raise", "Rear Delt Fly", "Tricep Pushdown", "Overhead Tricep Extension",
        "Skull Crushers", "Close-Grip Bench Press", "Dips (Chest/Triceps)",
        "Pull-Up", "Chin-Up", "Lat Pulldown (Wide Grip)", "Lat Pulldown (Neutral Grip)", "Bent-Over Barbell Row",
        "Pendlay Row", "Seated Cable Row", "Single-Arm Dumbbell Row", "T-Bar Row", "Face Pull",
        "Deadlift (Conventional)", "Romanian Deadlift", "Barbell Shrug",
        "Back Squat (High Bar)", "Low-Bar Back Squat", "Front Squat", "Leg Press", "Hack Squat", "Bulgarian Split Squat",
        "Walking Lunges", "Leg Extension", "Lying Leg Curl", "Seated Leg Curl", "Standing Calf Raise", "Seated Calf Raise",
        "Barbell Bicep Curl", "EZ-Bar Curl", "Dumbbell Hammer Curl", "Concentration Curl", "Cable Bicep Curl",
        "Plank", "Hanging Leg Raise", "Ab Wheel Rollout", "Russian Twist", "Cable Crunch"
    ]

    private func loadExercises() {
        if let data = UserDefaults.standard.data(forKey: exercisesKey) {
            do {
                let decoded = try JSONDecoder().decode([Exercise].self, from: data)
                globalExercises = decoded
                migrateLegacyCustomExercises()
            } catch {
                // Do not clear existing data if decoding fails; keep raw bytes for potential future migration.
                #if DEBUG
                print("❌ Decoding exercises failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Mark any loaded exercise that isn’t in the default library as custom (so it can be edited/deleted). Runs once per load; persists when we save.
    private func migrateLegacyCustomExercises() {
        var changed = false
        for i in globalExercises.indices {
            if !globalExercises[i].isCustom && !Self.defaultExerciseNames.contains(globalExercises[i].name) {
                globalExercises[i].isCustom = true
                changed = true
            }
        }
        if changed { saveExercises() }
    }
    
    private func saveExercises() {
        if let data = try? JSONEncoder().encode(globalExercises) {
            UserDefaults.standard.set(data, forKey: exercisesKey)
        }
    }
    
    private func preloadFullExerciseLibrary() {
        typealias MG = MuscleGroup
        globalExercises = [
            // Push (Chest, Shoulders, Triceps)
            Exercise(id: UUID(), name: "Barbell Bench Press", description: "Flat barbell bench press", targetedMuscles: [MG.chest, .triceps, .frontDelts]),
            Exercise(id: UUID(), name: "Incline Barbell Bench Press", description: "Incline barbell bench", targetedMuscles: [MG.upperChest, .triceps, .frontDelts]),
            Exercise(id: UUID(), name: "Decline Barbell Bench Press", description: "Decline barbell bench", targetedMuscles: [MG.lowerChest, .triceps]),
            Exercise(id: UUID(), name: "Dumbbell Bench Press", description: "Flat dumbbell press", targetedMuscles: [MG.chest, .triceps]),
            Exercise(id: UUID(), name: "Incline Dumbbell Press", description: "Incline dumbbell press", targetedMuscles: [MG.upperChest, .frontDelts]),
            Exercise(id: UUID(), name: "Dumbbell Flies", description: "Flat or incline flies", targetedMuscles: [MG.chest]),
            Exercise(id: UUID(), name: "Cable Crossover", description: "High-to-low cable fly", targetedMuscles: [MG.chest]),
            Exercise(id: UUID(), name: "Overhead Barbell Press", description: "Standing military press", targetedMuscles: [MG.frontDelts, .sideDelts, .triceps]),
            Exercise(id: UUID(), name: "Seated Dumbbell Press", description: "Seated overhead press", targetedMuscles: [MG.frontDelts, .sideDelts]),
            Exercise(id: UUID(), name: "Arnold Press", description: "Rotating dumbbell press", targetedMuscles: [MG.frontDelts, .sideDelts]),
            Exercise(id: UUID(), name: "Lateral Raise", description: "Dumbbell side lateral raise", targetedMuscles: [MG.sideDelts]),
            Exercise(id: UUID(), name: "Front Raise", description: "Dumbbell or plate front raise", targetedMuscles: [MG.frontDelts]),
            Exercise(id: UUID(), name: "Rear Delt Fly", description: "Dumbbell or machine rear delt fly", targetedMuscles: [MG.rearDelts]),
            Exercise(id: UUID(), name: "Tricep Pushdown", description: "Cable rope or bar pushdown", targetedMuscles: [MG.triceps]),
            Exercise(id: UUID(), name: "Overhead Tricep Extension", description: "Cable or dumbbell overhead extension", targetedMuscles: [MG.triceps]),
            Exercise(id: UUID(), name: "Skull Crushers", description: "EZ-bar lying tricep extension", targetedMuscles: [MG.triceps]),
            Exercise(id: UUID(), name: "Close-Grip Bench Press", description: "Triceps-focused bench", targetedMuscles: [MG.triceps, .chest, .frontDelts]),
            Exercise(id: UUID(), name: "Dips (Chest/Triceps)", description: "Parallel bar dips", targetedMuscles: [MG.triceps, .chest, .frontDelts]),

            // Pull (Back, Rear Delts, Biceps)
            Exercise(id: UUID(), name: "Pull-Up", description: "Strict wide-grip pull-up", targetedMuscles: [MG.lats, .biceps, .rearDelts]),
            Exercise(id: UUID(), name: "Chin-Up", description: "Supinated grip chin-up", targetedMuscles: [MG.biceps, .lats]),
            Exercise(id: UUID(), name: "Lat Pulldown (Wide Grip)", description: "Wide-grip cable pulldown", targetedMuscles: [MG.lats]),
            Exercise(id: UUID(), name: "Lat Pulldown (Neutral Grip)", description: "Neutral or V-bar pulldown", targetedMuscles: [MG.lats, .biceps]),
            Exercise(id: UUID(), name: "Bent-Over Barbell Row", description: "Barbell back row", targetedMuscles: [MG.upperBack, .lats, .biceps]),
            Exercise(id: UUID(), name: "Pendlay Row", description: "Explosive barbell row from floor", targetedMuscles: [MG.upperBack, .lats]),
            Exercise(id: UUID(), name: "Seated Cable Row", description: "Mid-back cable row", targetedMuscles: [MG.midBack, .rhomboids]),
            Exercise(id: UUID(), name: "Single-Arm Dumbbell Row", description: "Supported DB row", targetedMuscles: [MG.lats, .upperBack]),
            Exercise(id: UUID(), name: "T-Bar Row", description: "Chest-supported or landmine T-bar", targetedMuscles: [MG.upperBack, .lats]),
            Exercise(id: UUID(), name: "Face Pull", description: "Cable rear delt / external rotation", targetedMuscles: [MG.rearDelts, .rotatorCuff, .traps]),
            Exercise(id: UUID(), name: "Deadlift (Conventional)", description: "Classic barbell deadlift", targetedMuscles: [MG.posteriorChain, .glutes, .lowerBack]),
            Exercise(id: UUID(), name: "Romanian Deadlift", description: "Hamstring-focused RDL", targetedMuscles: [MG.hamstrings, .glutes, .lowerBack]),
            Exercise(id: UUID(), name: "Barbell Shrug", description: "Trap shrug", targetedMuscles: [MG.traps]),

            // Legs
            Exercise(id: UUID(), name: "Back Squat (High Bar)", description: "High-bar barbell squat", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Low-Bar Back Squat", description: "Powerlifting-style squat", targetedMuscles: [MG.glutes, .quads, .hamstrings]),
            Exercise(id: UUID(), name: "Front Squat", description: "Barbell front squat", targetedMuscles: [MG.quads, .core]),
            Exercise(id: UUID(), name: "Leg Press", description: "45° or horizontal leg press", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Hack Squat", description: "Machine hack squat", targetedMuscles: [MG.quads]),
            Exercise(id: UUID(), name: "Bulgarian Split Squat", description: "Rear-foot-elevated split squat", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Walking Lunges", description: "Dumbbell walking lunges", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Leg Extension", description: "Quad isolation machine", targetedMuscles: [MG.quads]),
            Exercise(id: UUID(), name: "Lying Leg Curl", description: "Hamstring curl machine", targetedMuscles: [MG.hamstrings]),
            Exercise(id: UUID(), name: "Seated Leg Curl", description: "Seated hamstring curl", targetedMuscles: [MG.hamstrings]),
            Exercise(id: UUID(), name: "Standing Calf Raise", description: "Machine or smith standing calf", targetedMuscles: [MG.calves]),
            Exercise(id: UUID(), name: "Seated Calf Raise", description: "Seated calf machine", targetedMuscles: [MG.soleus]),

            // Arms & Core
            Exercise(id: UUID(), name: "Barbell Bicep Curl", description: "Standing barbell curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "EZ-Bar Curl", description: "EZ-bar bicep curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "Dumbbell Hammer Curl", description: "Neutral grip curl", targetedMuscles: [MG.brachialis, .biceps]),
            Exercise(id: UUID(), name: "Concentration Curl", description: "Seated DB concentration curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "Cable Bicep Curl", description: "Low-cable bicep curl", targetedMuscles: [MG.biceps]),
            Exercise(id: UUID(), name: "Plank", description: "Forearm plank hold", targetedMuscles: [MG.core]),
            Exercise(id: UUID(), name: "Hanging Leg Raise", description: "Strict hanging leg raise", targetedMuscles: [MG.lowerAbs]),
            Exercise(id: UUID(), name: "Ab Wheel Rollout", description: "Ab wheel from knees or standing", targetedMuscles: [MG.core]),
            Exercise(id: UUID(), name: "Russian Twist", description: "Weighted or bodyweight twist", targetedMuscles: [MG.obliques]),
            Exercise(id: UUID(), name: "Cable Crunch", description: "Kneeling cable crunch", targetedMuscles: [MG.abs])
        ]
        saveExercises()
    }
    
    // MARK: - Sessions & week summary
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey) {
            do {
                let decoded = try JSONDecoder().decode([WorkoutSession].self, from: data)
                completedSessions = decoded
                #if DEBUG
                print("✅ Loaded \(decoded.count) sessions from UserDefaults")
                #endif
            } catch {
                #if DEBUG
                print("❌ Decoding sessions failed: \(error.localizedDescription)")
                #endif
                // Attempt to recover from backup snapshot if it exists.
                if let backupData = UserDefaults.standard.data(forKey: sessionsBackupKey) {
                    do {
                        let recovered = try JSONDecoder().decode([WorkoutSession].self, from: backupData)
                        completedSessions = recovered
                        #if DEBUG
                        print("✅ Recovered \(recovered.count) sessions from legacy backup snapshot")
                        #endif
                        saveSessions()
                    } catch {
                        #if DEBUG
                        print("❌ Failed to recover sessions from backup: \(error.localizedDescription)")
                        #endif
                    }
                }
            }
        }
    }
    
    /// Reload completed sessions from UserDefaults (e.g. when opening History so new completions are visible).
    func refreshCompletedSessions() {
        loadSessions()
    }
    
    /// Appends a completed session and persists. Use this instead of writing `completedSessions` to UserDefaults directly.
    func appendCompletedSession(_ session: WorkoutSession) {
        refreshCompletedSessions()
        var next = completedSessions
        next.append(session)
        completedSessions = next
        saveSessions()
    }
    
    func saveSessions() {
        do {
            let data = try JSONEncoder().encode(completedSessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
            if UserDefaults.standard.data(forKey: sessionsBackupKey) == nil {
                UserDefaults.standard.set(data, forKey: sessionsBackupKey)
                #if DEBUG
                print("💾 Created sessions backup snapshot")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Encoding sessions failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Past week summary
    var workoutsThisWeek: Int {
        let sevenDaysAgo = Date().addingTimeInterval(-7*24*60*60)
        return completedSessions.filter { ($0.endTime ?? Date()) > sevenDaysAgo }.count
    }

    /// Snapshot for Home “This week” (calendar `weekOfYear`, aligned with Plan tab).
    struct WeekAtAGlance: Equatable {
        let isoWeekKey: String
        let days: [(date: Date, weekday: Int, hasWorkout: Bool)]
        let completedCount: Int
        /// When set, show “x of y” toward weekly target (requires a non-empty program cycle).
        let weeklyGoal: Int?

        static func == (lhs: WeekAtAGlance, rhs: WeekAtAGlance) -> Bool {
            lhs.isoWeekKey == rhs.isoWeekKey
                && lhs.completedCount == rhs.completedCount
                && lhs.weeklyGoal == rhs.weeklyGoal
                && lhs.days.elementsEqual(rhs.days) { a, b in
                    a.date == b.date && a.weekday == b.weekday && a.hasWorkout == b.hasWorkout
                }
        }
    }

    func weekAtAGlance(referenceDate: Date = Date(), calendar: Calendar = .current) -> WeekAtAGlance {
        let weekKey = TrainingProgramState.isoWeekKey(for: referenceDate, calendar: calendar)
        let dayStarts = TrainingProgramState.orderedCalendarDaysInWeek(containing: referenceDate, calendar: calendar)
        let days: [(date: Date, weekday: Int, hasWorkout: Bool)] = dayStarts.map { start in
            let wd = calendar.component(.weekday, from: start)
            return (date: start, weekday: wd, hasWorkout: hasCompletedSessionEnding(on: start, calendar: calendar))
        }
        let completed = completedSessionCount(inWeekContaining: referenceDate, calendar: calendar)
        let goal: Int? = trainingProgram.cycleEntries.isEmpty
            ? nil
            : min(max(1, trainingProgram.sessionsPerWeek), 7)
        return WeekAtAGlance(isoWeekKey: weekKey, days: days, completedCount: completed, weeklyGoal: goal)
    }

    private func completedSessionCount(inWeekContaining referenceDate: Date, calendar: Calendar) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        return completedSessions.filter { session in
            guard let end = session.endTime else { return false }
            return end >= interval.start && end < interval.end
        }.count
    }

    private func hasCompletedSessionEnding(on dayStart: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: dayStart)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        return completedSessions.contains { session in
            guard let end = session.endTime else { return false }
            return end >= start && end < dayEnd
        }
    }
    // Delete exercise from workout (already existed)
    func deleteExercise(from workout: Workout, exerciseId: UUID) {
        guard let wIndex = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        userWorkouts[wIndex].exercises.removeAll { $0.id == exerciseId }
        saveWorkouts()
    }
    
    func moveExercise(in workout: Workout, from source: IndexSet, to destination: Int) {
        guard let wIndex = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        userWorkouts[wIndex].exercises.move(fromOffsets: source, toOffset: destination)
        saveWorkouts()
    }
    
    @discardableResult
    func addExercise(
        to workout: Workout,
        exercise: Exercise,
        recommendedSets: Int,
        recommendedReps: String,
        configurationFields: [String],
        recommendedConfigBySet: [[String: String]]
    ) -> WorkoutExercise? {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return nil }
        var we = WorkoutExercise(id: UUID(), exercise: exercise)
        we.recommendedSets = recommendedSets
        we.recommendedReps = recommendedReps
        we.configurationFields = configurationFields
        we.recommendedConfigBySet = recommendedConfigBySet
        userWorkouts[index].exercises.append(we)
        saveWorkouts()
        return we
    }

    // MARK: - Training program (split + calendar)

    private func loadTrainingProgram() {
        guard let data = UserDefaults.standard.data(forKey: trainingProgramKey) else { return }
        do {
            trainingProgram = try JSONDecoder().decode(TrainingProgramState.self, from: data)
        } catch {
            #if DEBUG
            print("❌ Decoding training program failed: \(error.localizedDescription)")
            #endif
            trainingProgram = TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))
        }
    }

    private func ensureSchedulePrecheckBackupBeforeFirstScheduleWrite() {
        guard !UserDefaults.standard.bool(forKey: schedulePrecheckFlagKey) else { return }
        if let d = UserDefaults.standard.data(forKey: workoutsKey) {
            UserDefaults.standard.set(d, forKey: workoutsPrecheckSnapshotKey)
        }
        if let d = UserDefaults.standard.data(forKey: sessionsKey) {
            UserDefaults.standard.set(d, forKey: sessionsPrecheckSnapshotKey)
        }
        UserDefaults.standard.set(true, forKey: schedulePrecheckFlagKey)
        #if DEBUG
        print("💾 Precheck snapshots stored before first training program write")
        #endif
    }

    func saveTrainingProgram() {
        ensureSchedulePrecheckBackupBeforeFirstScheduleWrite()
        do {
            let data = try JSONEncoder().encode(trainingProgram)
            UserDefaults.standard.set(data, forKey: trainingProgramKey)
        } catch {
            #if DEBUG
            print("❌ Encoding training program failed: \(error.localizedDescription)")
            #endif
        }
    }

    func applyTrainingProgramSuggestion(
        cycleWorkoutIds: [UUID],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        anchorDate: Date = Date()
    ) {
        applyTrainingProgramSuggestion(
            cycleEntries: cycleWorkoutIds.map { ProgramCycleEntry(kind: .concreteWorkout, id: $0) },
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            anchorDate: anchorDate
        )
    }

    func applyTrainingProgramSuggestion(
        cycleEntries: [ProgramCycleEntry],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        anchorDate: Date = Date()
    ) {
        var p = trainingProgram
        p.cycleEntries = cycleEntries
        p.sessionsPerWeek = min(max(1, sessionsPerWeek), 7)
        p.preferredWeekdays = preferredWeekdays
        p.anchorDayKey = TrainingProgramState.dayKey(for: anchorDate)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setTrainingCycleWorkoutIds(_ ids: [UUID]) {
        setTrainingCycleEntries(ids.map { ProgramCycleEntry(kind: .concreteWorkout, id: $0) })
    }

    func setTrainingCycleEntries(_ entries: [ProgramCycleEntry]) {
        var p = trainingProgram
        p.cycleEntries = entries
        trainingProgram = p
        saveTrainingProgram()
    }

    func setTrainingSessionsPerWeek(_ n: Int) {
        var p = trainingProgram
        p.sessionsPerWeek = min(max(1, n), 7)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setTrainingPreferredWeekdays(_ days: [Int]) {
        var p = trainingProgram
        p.preferredWeekdays = days
        trainingProgram = p
        saveTrainingProgram()
    }

    func setTrainingAnchorDate(_ date: Date) {
        var p = trainingProgram
        p.anchorDayKey = TrainingProgramState.dayKey(for: date)
        trainingProgram = p
        saveTrainingProgram()
    }

    /// Persisted override removed ⇒ day/week fall through to defaults.
    func clearTrainingDayOverride(dayKey: String) {
        var p = trainingProgram
        p.dayOverrides.removeValue(forKey: dayKey)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setTrainingDayOverride(dayKey: String, intent: ScheduleDayIntent, workoutId: UUID? = nil) {
        var p = trainingProgram
        p.dayOverrides[dayKey] = ScheduleDayOverride(intent: intent, workoutId: workoutId)
        trainingProgram = p
        saveTrainingProgram()
    }

    func clearWeekOverride(weekKey: String) {
        var p = trainingProgram
        p.weekOverrides.removeValue(forKey: weekKey)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setWeekDayOverride(weekKey: String, weekday: Int, intent: ScheduleDayIntent, workoutId: UUID? = nil) {
        var p = trainingProgram
        var w = p.weekOverrides[weekKey] ?? ScheduleWeekOverride()
        if intent == .inherit {
            w.weekdayOverrides.removeValue(forKey: String(weekday))
        } else {
            w.weekdayOverrides[String(weekday)] = ScheduleDayOverride(intent: intent, workoutId: workoutId)
        }
        if w.weekdayOverrides.isEmpty {
            p.weekOverrides.removeValue(forKey: weekKey)
        } else {
            p.weekOverrides[weekKey] = w
        }
        trainingProgram = p
        saveTrainingProgram()
    }

    func workoutDisplayName(forWorkoutId id: UUID) -> String {
        userWorkouts.first(where: { $0.id == id })?.name ?? "Missing workout"
    }
}
