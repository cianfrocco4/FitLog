//
//  DataManager.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//


import Foundation

final class DataManager: ObservableObject {
    @Published var userWorkouts: [Workout] = []
    @Published var globalExercises: [Exercise] = []
    @Published var completedSessions: [WorkoutSession] = []
    
    private let workoutsKey = "userWorkouts"
    private let exercisesKey = "globalExercises"
    private let sessionsKey = "completedSessions"
    private let exercisesPreloadedKey = "exercisesPreloaded"
    
    init() { loadAll() }
    
    func loadAll() {
        loadWorkouts()
        loadExercises()
        loadSessions()
        
        if !UserDefaults.standard.bool(forKey: exercisesPreloadedKey) {
            preloadFullExerciseLibrary()
            UserDefaults.standard.set(true, forKey: exercisesPreloadedKey)
        }
    }
    
    // MARK: - Workouts
    func createWorkout(name: String) {
        let newWorkout = Workout(id: UUID(), name: name, exercises: [])
        print("Creating workout: \(name) with ID \(newWorkout.id.uuidString)")
        
        userWorkouts.append(newWorkout)
        print("Workouts after append: \(userWorkouts.count)")
        
        saveWorkouts()
        print("saveWorkouts() called")
        
        // This line forces SwiftUI to re-render observers in almost all cases
        objectWillChange.send()
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
                print("✅ Loaded \(decoded.count) workouts from UserDefaults")
            } catch {
                // IMPORTANT: Do not wipe existing data on decode failure.
                // Keep the raw data in UserDefaults so a future migration can recover it.
                print("❌ Decoding workouts failed: \(error.localizedDescription)")
            }
        } else {
            print("No saved workouts data found in UserDefaults")
        }
    }
    
    func saveWorkouts() {
        do {
            let data = try JSONEncoder().encode(userWorkouts)
            UserDefaults.standard.set(data, forKey: workoutsKey)
            print("✅ Saved \(userWorkouts.count) workouts to UserDefaults")
        } catch {
            print("❌ Encoding failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Global Exercises (now 60+ default)
    func addNewExercise(name: String, description: String, muscles: [MuscleGroup]) {
        let new = Exercise(id: UUID(), name: name, description: description, targetedMuscles: muscles, isCustom: true, configurationOptions: [])
        globalExercises.append(new)
        saveExercises()
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
        globalExercises.removeAll { $0.id == exercise.id }
        for i in userWorkouts.indices {
            userWorkouts[i].exercises.removeAll { $0.exercise.id == exercise.id }
        }
        saveExercises()
        saveWorkouts()
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
                print("❌ Decoding exercises failed: \(error.localizedDescription)")
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
            } catch {
                print("❌ Decoding sessions failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Reload completed sessions from UserDefaults (e.g. when opening History so new completions are visible).
    func refreshCompletedSessions() {
        loadSessions()
    }
    
    func saveSessions() {
        if let data = try? JSONEncoder().encode(completedSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
    
    // MARK: - Past week summary
    var workoutsThisWeek: Int {
        let sevenDaysAgo = Date().addingTimeInterval(-7*24*60*60)
        return completedSessions.filter { ($0.endTime ?? Date()) > sevenDaysAgo }.count
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
}
