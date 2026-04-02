//
//  DataManager.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//
//  Thin façade that composes focused stores (WorkoutStore, SessionStore,
//  ExerciseStore, TrainingProgramStore) while remaining the single
//  @EnvironmentObject injection point for all SwiftUI views.
//

import Foundation
import SwiftData

final class DataManager: ObservableObject {
    @Published var userWorkouts: [Workout] = []
    @Published var userWorkoutTemplates: [WorkoutTemplate] = []
    @Published var globalExercises: [Exercise] = []
    @Published private(set) var exerciseLocalDisplayNames: [UUID: String] = [:]
    @Published var completedSessions: [WorkoutSession] = []
    @Published var trainingProgram: TrainingProgramState = TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date()))

    let workoutStore: WorkoutStore
    let sessionStore: SessionStore
    let exerciseStore: ExerciseStore
    let programStore: TrainingProgramStore

    // MARK: - Lifecycle

    init(modelContainer: ModelContainer) {
        let ctx = ModelContext(modelContainer)
        self.workoutStore = WorkoutStore(modelContext: ctx)
        self.sessionStore = SessionStore(modelContext: ctx)
        self.exerciseStore = ExerciseStore(modelContext: ctx)
        self.programStore = TrainingProgramStore(modelContext: ctx)
        loadAll()
    }

    func loadAll() {
        globalExercises = exerciseStore.loadExercises()
        exerciseLocalDisplayNames = exerciseStore.loadDisplayNames()
        userWorkouts = workoutStore.loadWorkouts()
        userWorkoutTemplates = workoutStore.loadWorkoutTemplates()
        completedSessions = sessionStore.loadSessions()

        if let program = programStore.loadProgram() {
            trainingProgram = program
        }

        pruneStaleFrozenCalendarDays()

        if globalExercises.isEmpty {
            preloadFullExerciseLibrary()
        }

        migrateLegacyCustomExercises()
        rotateBackup()
        freezeYesterdayPlanAssignmentIfNeeded()
    }

    // MARK: - Rotating backups

    private static let maxBackups = 2

    func rotateBackup() {
        let dir = URL.applicationSupportDirectory.appending(path: "Backups", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let snapshot = BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: globalExercises,
            workouts: userWorkouts,
            templates: userWorkoutTemplates,
            sessions: completedSessions,
            program: trainingProgram,
            displayNames: exerciseLocalDisplayNames
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            #if DEBUG
            print("[Backup] Failed to encode snapshot")
            #endif
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let fileName = "backup_\(formatter.string(from: Date())).json"
        let fileURL = dir.appending(path: fileName)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[Backup] Write failed: \(error.localizedDescription)")
            #endif
        }

        let backups = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]))?.sorted {
                let da = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            } ?? []

        for old in backups.dropFirst(Self.maxBackups) {
            try? FileManager.default.removeItem(at: old)
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

    func uniqueWorkoutTemplateName(_ base: String) -> String {
        workoutStore.uniqueName(
            base,
            existingWorkoutNames: Set(userWorkouts.map(\.name)),
            existingTemplateNames: Set(userWorkoutTemplates.map(\.name))
        )
    }

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
                cycleEntries: newIds.map { .concreteWorkout($0) },
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

    func saveWorkouts() {
        workoutStore.saveWorkouts(userWorkouts)
    }

    // MARK: - Slot workout templates (blueprints)

    @discardableResult
    func createSlotTemplate(name: String) -> UUID {
        let template = WorkoutTemplate(id: UUID(), name: name, slots: [])
        userWorkoutTemplates.append(template)
        saveWorkoutTemplates()
        return template.id
    }

    @discardableResult
    func createSlotTemplate(name: String, slots: [TemplateSlot]) -> UUID {
        let template = WorkoutTemplate(id: UUID(), name: name, slots: slots)
        userWorkoutTemplates.append(template)
        saveWorkoutTemplates()
        return template.id
    }

    func applyWorkoutSplitProposal(
        _ proposal: WorkoutSplitProposal,
        updateTrainingProgram: Bool,
        anchorDate: Date = Date()
    ) {
        var createdByPlanKey: [String: Exercise] = [:]

        func resolveOrCreateExercise(
            planName: String,
            overrideId: UUID?,
            musclesIfCreatingCustom: [MuscleGroup]
        ) -> Exercise? {
            if let oid = overrideId,
               let ex = globalExercises.first(where: { $0.id == oid }) {
                return ex
            }
            let trimmed = planName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard let result = ExerciseNameResolution.resolve(planName: trimmed, library: globalExercises) else { return nil }
            switch result {
            case .linked(let ex):
                return ex
            case .createCustom(let displayName):
                let key = ExerciseNameResolution.dedupeKey(forPlanName: displayName)
                if let cached = createdByPlanKey[key] { return cached }
                let muscles = musclesIfCreatingCustom.isEmpty ? [MuscleGroup.other] : musclesIfCreatingCustom
                let new = addNewExercise(name: displayName, description: "", muscles: muscles)
                createdByPlanKey[key] = new
                return new
            }
        }

        var entries: [WorkoutPlanRef] = []
        for day in proposal.workouts {
            if day.isSlotTemplateDay {
                let templateSlots: [TemplateSlot] = day.slots.map { s in
                    let parsedMuscles = ExerciseNameResolution.resolveMuscleGroups(from: s.targetMuscleNames)
                    let matchedExercise: Exercise? = {
                        if let oid = s.suggestedExerciseOverrideId,
                           let ex = globalExercises.first(where: { $0.id == oid }) {
                            return ex
                        }
                        guard let raw = s.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                            return nil
                        }
                        let musclesForNew = parsedMuscles.isEmpty ? [MuscleGroup.other] : parsedMuscles
                        return resolveOrCreateExercise(
                            planName: raw,
                            overrideId: nil,
                            musclesIfCreatingCustom: musclesForNew
                        )
                    }()
                    let targetedMuscles: [MuscleGroup]
                    if !parsedMuscles.isEmpty {
                        targetedMuscles = parsedMuscles
                    } else if let ex = matchedExercise, !ex.targetedMuscles.isEmpty {
                        targetedMuscles = ex.targetedMuscles
                    } else {
                        targetedMuscles = [MuscleGroup.other]
                    }
                    let repsRaw = s.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsFinal = repsRaw.isEmpty ? "8-12" : repsRaw
                    return TemplateSlot(
                        label: s.label,
                        targetedMuscles: targetedMuscles,
                        exerciseRole: matchedExercise?.exerciseRole,
                        movementPattern: matchedExercise?.movementPattern,
                        defaultExerciseId: matchedExercise?.id,
                        recommendedSets: min(max(1, s.sets), 10),
                        recommendedReps: repsFinal
                    )
                }
                guard !templateSlots.isEmpty else { continue }
                let name = uniqueSlotTemplateName(day.name)
                let id = createSlotTemplate(name: name, slots: templateSlots)
                entries.append(.slotTemplate(id))
            } else {
                guard !day.exercises.isEmpty else { continue }
                let name = uniqueWorkoutTemplateName(day.name)
                let id = createWorkout(name: name)
                entries.append(.concreteWorkout(id))
                for exItem in day.exercises {
                    guard let fresh = userWorkouts.first(where: { $0.id == id }) else { break }
                    let sets = min(max(1, exItem.sets), 10)
                    let reps = exItem.reps.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsFinal = reps.isEmpty ? "8-12" : reps
                    guard let ex = resolveOrCreateExercise(
                        planName: exItem.name,
                        overrideId: exItem.libraryExerciseOverrideId,
                        musclesIfCreatingCustom: [MuscleGroup.other]
                    ) else { continue }
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
        mergeFrozenPastDays(from: p, into: &p.frozenCalendarDays, calendar: .current)
        p.cycleEntries.removeAll { $0 == .slotTemplate(template.id) }
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

    func instantiateWorkout(from template: WorkoutTemplate) -> Workout {
        workoutStore.instantiateWorkout(from: template, globalExercises: globalExercises)
    }

    func saveWorkoutTemplates() {
        workoutStore.saveWorkoutTemplates(userWorkoutTemplates)
    }

    func planLabel(for ref: WorkoutPlanRef) -> String {
        switch ref {
        case .concreteWorkout(let id):
            return userWorkouts.first(where: { $0.id == id })?.name ?? "Missing workout"
        case .slotTemplate(let id):
            return userWorkoutTemplates.first(where: { $0.id == id })?.name ?? "Missing template"
        }
    }

    /// Plan assignment shown on the calendar for `date`: frozen history before today (after rotation changes), else live engine resolution.
    /// Past days without a snapshot are unscheduled so the engine does not invent a split backward before you have any training history.
    func resolvedScheduleDay(for date: Date, calendar: Calendar = .current) -> ResolvedScheduleDay {
        let cal = calendar
        let todayStart = cal.startOfDay(for: Date())
        let dateStart = cal.startOfDay(for: date)
        if dateStart < todayStart {
            let key = TrainingProgramState.dayKey(for: date, calendar: cal)
            if let frozen = trainingProgram.frozenCalendarDays[key] {
                return frozen.asResolved()
            }
            return .unscheduled
        }
        return TrainingScheduleEngine(calendar: cal).resolve(date: date, program: trainingProgram)
    }

    /// Most recent completed session whose end (or start) falls on this local calendar day.
    func primaryCompletedSession(on date: Date, calendar: Calendar = .current) -> WorkoutSession? {
        let cal = calendar
        let key = TrainingProgramState.dayKey(for: date, calendar: cal)
        return completedSessions
            .filter(\.isCompleted)
            .filter { sessionDayKey($0, calendar: cal) == key }
            .max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    private func sessionDayKey(_ session: WorkoutSession, calendar: Calendar) -> String {
        let t = session.endTime ?? session.startTime
        return TrainingProgramState.dayKey(for: t, calendar: calendar)
    }

    /// For each local day strictly before today, records the current full resolution (including overrides) if not already frozen — so later split changes do not rewrite that day.
    /// Only days on or after the first completed workout are filled (or just yesterday when there are no logs) so we do not snapshot a fake cycle before you trained.
    private func mergeFrozenPastDays(from oldProgram: TrainingProgramState, into frozen: inout [String: FrozenPlanDay], calendar: Calendar = .current) {
        let engine = TrainingScheduleEngine(calendar: calendar)
        let todayStart = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return }

        let walkFrom: Date
        if let oldestLog = completedSessions.filter(\.isCompleted).map({ calendar.startOfDay(for: $0.endTime ?? $0.startTime) }).min() {
            walkFrom = oldestLog
        } else {
            walkFrom = yesterday
        }

        var walk = walkFrom
        if let cap = calendar.date(byAdding: .year, value: -3, to: todayStart) {
            let capStart = calendar.startOfDay(for: cap)
            if walk < capStart { walk = capStart }
        }
        if walk > yesterday { return }

        while walk <= yesterday {
            let key = TrainingProgramState.dayKey(for: walk, calendar: calendar)
            if frozen[key] == nil {
                let r = engine.resolve(date: walk, program: oldProgram)
                frozen[key] = FrozenPlanDay(resolved: r)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: walk) else { break }
            walk = next
        }
    }

    /// Drops frozen snapshots that predate any training evidence (or, with no logs, anything before yesterday) so older app versions cannot leave years of invented plan cells.
    private func pruneStaleFrozenCalendarDays(calendar: Calendar = .current) {
        let cal = calendar
        let todayStart = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) else { return }

        var p = trainingProgram
        let floorKey: String
        if let oldest = completedSessions.filter(\.isCompleted).map({ cal.startOfDay(for: $0.endTime ?? $0.startTime) }).min() {
            floorKey = TrainingProgramState.dayKey(for: oldest, calendar: cal)
        } else {
            floorKey = TrainingProgramState.dayKey(for: yesterday, calendar: cal)
        }

        let filtered = p.frozenCalendarDays.filter { $0.key >= floorKey }
        guard filtered.count != p.frozenCalendarDays.count else { return }
        p.frozenCalendarDays = filtered
        trainingProgram = p
        saveTrainingProgram()
    }

    private func applyTrainingProgramAfterFreezingPast(_ newProgram: TrainingProgramState) {
        var merged = newProgram
        mergeFrozenPastDays(from: trainingProgram, into: &merged.frozenCalendarDays, calendar: .current)
        trainingProgram = merged
        saveTrainingProgram()
    }

    /// Snapshots the previous local calendar day's plan (if not already frozen) using the current program. Call after the calendar day advances or on launch so "today" from yesterday does not remap when the split changes overnight.
    func freezeYesterdayPlanAssignmentIfNeeded(calendar: Calendar = .current) {
        guard completedSessions.contains(where: \.isCompleted) else { return }
        let cal = calendar
        let todayStart = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) else { return }
        let key = TrainingProgramState.dayKey(for: yesterday, calendar: cal)
        var p = trainingProgram
        guard p.frozenCalendarDays[key] == nil else { return }
        let r = TrainingScheduleEngine(calendar: cal).resolve(date: yesterday, program: p)
        p.frozenCalendarDays[key] = FrozenPlanDay(resolved: r)
        trainingProgram = p
        saveTrainingProgram()
    }

    // MARK: - Global exercises

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
        let snap = ExerciseSnapshot(from: exercise)
        for i in userWorkouts.indices {
            for j in userWorkouts[i].exercises.indices {
                if userWorkouts[i].exercises[j].exerciseId == exercise.id {
                    userWorkouts[i].exercises[j].resolution = .concrete(snap)
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
            userWorkouts[i].exercises.removeAll { $0.exerciseId == exercise.id }
        }
        saveExercises()
        saveWorkouts()
    }

    func saveExercises() {
        exerciseStore.saveExercises(globalExercises)
    }

    // MARK: - Local exercise display names

    func resolvedDisplayName(for exercise: Exercise) -> String {
        exerciseStore.resolvedDisplayName(for: exercise, globalExercises: globalExercises, localNames: exerciseLocalDisplayNames)
    }

    func displayName(for snapshot: ExerciseSnapshot) -> String {
        exerciseStore.displayName(for: snapshot, globalExercises: globalExercises, localNames: exerciseLocalDisplayNames)
    }

    func resolveExercise(for snapshot: ExerciseSnapshot) -> Exercise? {
        globalExercises.first { $0.id == snapshot.exerciseId }
    }

    func displayName(for we: WorkoutExercise) -> String {
        exerciseStore.displayName(for: we, globalExercises: globalExercises, localNames: exerciseLocalDisplayNames)
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

    private func saveExerciseLocalDisplayNames() {
        exerciseStore.saveDisplayNames(exerciseLocalDisplayNames)
    }

    // MARK: - Exercise library seeding

    private static let defaultExerciseNames: Set<String> = [
        "Barbell Bench Press", "Incline Barbell Bench Press", "Decline Barbell Bench Press",
        "Dumbbell Bench Press", "Incline Dumbbell Press", "Dumbbell Flies", "Cable Crossover",
        "Overhead Barbell Press", "Seated Dumbbell Press", "Arnold Press", "Lateral Raise",
        "Front Raise", "Rear Delt Fly", "Tricep Pushdown", "Overhead Tricep Extension",
        "Skull Crushers", "Close-Grip Bench Press", "Dips (Chest/Triceps)", "Pull-Up", "Chin-Up",
        "Lat Pulldown (Wide Grip)", "Lat Pulldown (Neutral Grip)", "Bent-Over Barbell Row",
        "Pendlay Row", "Seated Cable Row", "Single-Arm Dumbbell Row", "T-Bar Row", "Face Pull",
        "Deadlift (Conventional)", "Romanian Deadlift", "Barbell Shrug",
        "Back Squat (High Bar)", "Low-Bar Back Squat", "Front Squat", "Leg Press", "Hack Squat",
        "Bulgarian Split Squat", "Walking Lunges", "Leg Extension", "Lying Leg Curl",
        "Seated Leg Curl", "Standing Calf Raise", "Seated Calf Raise", "Barbell Bicep Curl",
        "EZ-Bar Curl", "Dumbbell Hammer Curl", "Concentration Curl", "Cable Bicep Curl",
        "Plank", "Hanging Leg Raise", "Ab Wheel Rollout", "Russian Twist", "Cable Crunch"
    ]

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

    private func preloadFullExerciseLibrary() {
        typealias MG = MuscleGroup
        globalExercises = [
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
            Exercise(id: UUID(), name: "Back Squat (High Bar)", description: "High-bar barbell squat", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Low-Bar Back Squat", description: "Powerlifting-style squat", targetedMuscles: [MG.glutes, .quads, .hamstrings]),
            Exercise(id: UUID(), name: "Front Squat", description: "Barbell front squat", targetedMuscles: [MG.quads, .core]),
            Exercise(id: UUID(), name: "Leg Press", description: "45\u{00b0} or horizontal leg press", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Hack Squat", description: "Machine hack squat", targetedMuscles: [MG.quads]),
            Exercise(id: UUID(), name: "Bulgarian Split Squat", description: "Rear-foot-elevated split squat", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Walking Lunges", description: "Dumbbell walking lunges", targetedMuscles: [MG.quads, .glutes]),
            Exercise(id: UUID(), name: "Leg Extension", description: "Quad isolation machine", targetedMuscles: [MG.quads]),
            Exercise(id: UUID(), name: "Lying Leg Curl", description: "Hamstring curl machine", targetedMuscles: [MG.hamstrings]),
            Exercise(id: UUID(), name: "Seated Leg Curl", description: "Seated hamstring curl", targetedMuscles: [MG.hamstrings]),
            Exercise(id: UUID(), name: "Standing Calf Raise", description: "Machine or smith standing calf", targetedMuscles: [MG.calves]),
            Exercise(id: UUID(), name: "Seated Calf Raise", description: "Seated calf machine", targetedMuscles: [MG.soleus]),
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

    // MARK: - Sessions

    func refreshCompletedSessions() {
        completedSessions = sessionStore.loadSessions()
    }

    func appendCompletedSession(_ session: WorkoutSession) {
        completedSessions.append(session)
        sessionStore.appendSession(session)
    }

    func saveSessions() {
        sessionStore.saveSessions(completedSessions)
    }

    // MARK: - Week summary / analytics

    var workoutsThisWeek: Int {
        let sevenDaysAgo = Date().addingTimeInterval(-7*24*60*60)
        return completedSessions.filter { ($0.endTime ?? Date()) > sevenDaysAgo }.count
    }

    struct WeekAtAGlance: Equatable {
        let isoWeekKey: String
        let days: [(date: Date, weekday: Int, hasWorkout: Bool)]
        let completedCount: Int
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
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let days: [(date: Date, weekday: Int, hasWorkout: Bool)] = dayStarts.map { dayStart in
            let wd = calendar.component(.weekday, from: dayStart)
            let hasWorkout = completedSessions.contains { session in
                guard let end = session.endTime else { return false }
                return calendar.isDate(end, inSameDayAs: dayStart)
            }
            return (date: dayStart, weekday: wd, hasWorkout: hasWorkout)
        }
        let completed: Int
        if let weekInterval {
            completed = completedSessions.filter { session in
                guard let end = session.endTime else { return false }
                return end >= weekInterval.start && end < weekInterval.end
            }.count
        } else {
            completed = 0
        }
        let goal: Int? = trainingProgram.cycleEntries.isEmpty
            ? nil
            : min(max(1, trainingProgram.sessionsPerWeek), 7)
        return WeekAtAGlance(isoWeekKey: weekKey, days: days, completedCount: completed, weeklyGoal: goal)
    }

    // MARK: - Exercise CRUD on workouts

    func deleteExercise(from workout: Workout, exerciseId: UUID) {
        guard let wIndex = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        userWorkouts[wIndex].exercises.removeAll { $0.id == exerciseId }
        userWorkouts[wIndex].templateSlotIdByWorkoutExerciseId.removeValue(forKey: exerciseId)
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

    // MARK: - Training program

    func saveTrainingProgram() {
        programStore.saveProgram(trainingProgram)
    }

    func applyTrainingProgramSuggestion(
        cycleWorkoutIds: [UUID],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        anchorDate: Date = Date()
    ) {
        applyTrainingProgramSuggestion(
            cycleEntries: cycleWorkoutIds.map { .concreteWorkout($0) },
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            anchorDate: anchorDate
        )
    }

    func applyTrainingProgramSuggestion(
        cycleEntries: [WorkoutPlanRef],
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        anchorDate: Date = Date()
    ) {
        var p = trainingProgram
        p.cycleEntries = cycleEntries
        p.sessionsPerWeek = min(max(1, sessionsPerWeek), 7)
        p.preferredWeekdays = preferredWeekdays
        p.anchorDayKey = TrainingProgramState.dayKey(for: anchorDate)
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingCycleWorkoutIds(_ ids: [UUID]) {
        setTrainingCycleEntries(ids.map { .concreteWorkout($0) })
    }

    func setTrainingCycleEntries(_ entries: [WorkoutPlanRef]) {
        var p = trainingProgram
        p.cycleEntries = entries
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingSessionsPerWeek(_ n: Int) {
        var p = trainingProgram
        p.sessionsPerWeek = min(max(1, n), 7)
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingPreferredWeekdays(_ days: [Int]) {
        var p = trainingProgram
        p.preferredWeekdays = days
        applyTrainingProgramAfterFreezingPast(p)
    }

    func setTrainingAnchorDate(_ date: Date) {
        var p = trainingProgram
        p.anchorDayKey = TrainingProgramState.dayKey(for: date)
        applyTrainingProgramAfterFreezingPast(p)
    }

    func clearTrainingDayOverride(dayKey: String) {
        var p = trainingProgram
        p.dayOverrides.removeValue(forKey: dayKey)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setTrainingDayOverride(dayKey: String, intent: ScheduleDayIntent, planRef: WorkoutPlanRef? = nil) {
        var p = trainingProgram
        p.dayOverrides[dayKey] = ScheduleDayOverride(intent: intent, planRef: planRef)
        trainingProgram = p
        saveTrainingProgram()
    }

    func clearWeekOverride(weekKey: String) {
        var p = trainingProgram
        p.weekOverrides.removeValue(forKey: weekKey)
        trainingProgram = p
        saveTrainingProgram()
    }

    func setWeekDayOverride(weekKey: String, weekday: Int, intent: ScheduleDayIntent, planRef: WorkoutPlanRef? = nil) {
        var p = trainingProgram
        var w = p.weekOverrides[weekKey] ?? ScheduleWeekOverride()
        if intent == .inherit {
            w.weekdayOverrides.removeValue(forKey: String(weekday))
        } else {
            w.weekdayOverrides[String(weekday)] = ScheduleDayOverride(intent: intent, planRef: planRef)
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
