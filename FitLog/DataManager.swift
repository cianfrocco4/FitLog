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
        
        // TODO:
        UserDefaults.standard.removeObject(forKey: exercisesPreloadedKey)
        UserDefaults.standard.removeObject(forKey: workoutsKey)
        UserDefaults.standard.removeObject(forKey: exercisesKey)
        print("Cleared UserDefaults keys for testing")
        
        if !UserDefaults.standard.bool(forKey: exercisesPreloadedKey) {
            preloadFullExerciseLibrary()
            UserDefaults.standard.set(true, forKey: exercisesPreloadedKey)
        }
        
        if userWorkouts.isEmpty {
            userWorkouts = [
                Workout(id: UUID(), name: "Test 1"),
                Workout(id: UUID(), name: "Test 2")
            ]
            saveWorkouts()
        }
    }
    
    // MARK: - Workouts
    func createWorkout(name: String) {
        // TODO: Commenting out exercises temporarily
        let newWorkout = Workout(id: UUID(), name: name)//, exercises: [])
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
    
    private func loadWorkouts() {
        if let data = UserDefaults.standard.data(forKey: workoutsKey) {
            do {
                let decoded = try JSONDecoder().decode([Workout].self, from: data)
                userWorkouts = decoded
                print("✅ Loaded \(decoded.count) workouts from UserDefaults")
            } catch {
                print("❌ Decoding failed: \(error.localizedDescription)")
                userWorkouts = []
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
    func addNewExercise(name: String, description: String, muscles: [String]) {
        let new = Exercise(id: UUID(), name: name, description: description, targetedMuscles: muscles)
        globalExercises.append(new)
        saveExercises()
    }
    
    private func loadExercises() {
        if let data = UserDefaults.standard.data(forKey: exercisesKey),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            globalExercises = decoded
        }
    }
    
    private func saveExercises() {
        if let data = try? JSONEncoder().encode(globalExercises) {
            UserDefaults.standard.set(data, forKey: exercisesKey)
        }
    }
    
    private func preloadFullExerciseLibrary() {
        globalExercises = [
            // Push (Chest, Shoulders, Triceps)
            Exercise(id: UUID(), name: "Barbell Bench Press", description: "Flat barbell bench press", targetedMuscles: ["Chest", "Triceps", "Front Delts"]),
            Exercise(id: UUID(), name: "Incline Barbell Bench Press", description: "Incline barbell bench", targetedMuscles: ["Upper Chest", "Triceps", "Front Delts"]),
            Exercise(id: UUID(), name: "Decline Barbell Bench Press", description: "Decline barbell bench", targetedMuscles: ["Lower Chest", "Triceps"]),
            Exercise(id: UUID(), name: "Dumbbell Bench Press", description: "Flat dumbbell press", targetedMuscles: ["Chest", "Triceps"]),
            Exercise(id: UUID(), name: "Incline Dumbbell Press", description: "Incline dumbbell press", targetedMuscles: ["Upper Chest"]),
            Exercise(id: UUID(), name: "Dumbbell Flies", description: "Flat or incline flies", targetedMuscles: ["Chest"]),
            Exercise(id: UUID(), name: "Cable Crossover", description: "High-to-low cable fly", targetedMuscles: ["Chest"]),
            Exercise(id: UUID(), name: "Overhead Barbell Press", description: "Standing military press", targetedMuscles: ["Shoulders", "Triceps"]),
            Exercise(id: UUID(), name: "Seated Dumbbell Press", description: "Seated overhead press", targetedMuscles: ["Shoulders"]),
            Exercise(id: UUID(), name: "Arnold Press", description: "Rotating dumbbell press", targetedMuscles: ["Shoulders"]),
            Exercise(id: UUID(), name: "Lateral Raise", description: "Dumbbell side lateral raise", targetedMuscles: ["Side Delts"]),
            Exercise(id: UUID(), name: "Front Raise", description: "Dumbbell or plate front raise", targetedMuscles: ["Front Delts"]),
            Exercise(id: UUID(), name: "Rear Delt Fly", description: "Dumbbell or machine rear delt fly", targetedMuscles: ["Rear Delts"]),
            Exercise(id: UUID(), name: "Tricep Pushdown", description: "Cable rope or bar pushdown", targetedMuscles: ["Triceps"]),
            Exercise(id: UUID(), name: "Overhead Tricep Extension", description: "Cable or dumbbell overhead extension", targetedMuscles: ["Triceps"]),
            Exercise(id: UUID(), name: "Skull Crushers", description: "EZ-bar lying tricep extension", targetedMuscles: ["Triceps"]),
            Exercise(id: UUID(), name: "Close-Grip Bench Press", description: "Triceps-focused bench", targetedMuscles: ["Triceps", "Chest"]),
            Exercise(id: UUID(), name: "Dips (Chest/Triceps)", description: "Parallel bar dips", targetedMuscles: ["Chest", "Triceps", "Shoulders"]),

            // Pull (Back, Rear Delts, Biceps)
            Exercise(id: UUID(), name: "Pull-Up", description: "Strict wide-grip pull-up", targetedMuscles: ["Lats", "Biceps", "Rear Delts"]),
            Exercise(id: UUID(), name: "Chin-Up", description: "Supinated grip chin-up", targetedMuscles: ["Biceps", "Lats"]),
            Exercise(id: UUID(), name: "Lat Pulldown (Wide Grip)", description: "Wide-grip cable pulldown", targetedMuscles: ["Lats"]),
            Exercise(id: UUID(), name: "Lat Pulldown (Neutral Grip)", description: "Neutral or V-bar pulldown", targetedMuscles: ["Lats", "Biceps"]),
            Exercise(id: UUID(), name: "Bent-Over Barbell Row", description: "Barbell back row", targetedMuscles: ["Upper Back", "Lats", "Biceps"]),
            Exercise(id: UUID(), name: "Pendlay Row", description: "Explosive barbell row from floor", targetedMuscles: ["Upper Back", "Lats"]),
            Exercise(id: UUID(), name: "Seated Cable Row", description: "Mid-back cable row", targetedMuscles: ["Mid Back", "Rhomboids"]),
            Exercise(id: UUID(), name: "Single-Arm Dumbbell Row", description: "Supported DB row", targetedMuscles: ["Lats", "Upper Back"]),
            Exercise(id: UUID(), name: "T-Bar Row", description: "Chest-supported or landmine T-bar", targetedMuscles: ["Upper Back"]),
            Exercise(id: UUID(), name: "Face Pull", description: "Cable rear delt / external rotation", targetedMuscles: ["Rear Delts", "Traps", "Rotator Cuff"]),
            Exercise(id: UUID(), name: "Deadlift (Conventional)", description: "Classic barbell deadlift", targetedMuscles: ["Posterior Chain", "Back", "Glutes"]),
            Exercise(id: UUID(), name: "Romanian Deadlift", description: "Hamstring-focused RDL", targetedMuscles: ["Hamstrings", "Glutes", "Lower Back"]),
            Exercise(id: UUID(), name: "Barbell Shrug", description: "Trap shrug", targetedMuscles: ["Traps"]),

            // Legs
            Exercise(id: UUID(), name: "Back Squat (High Bar)", description: "High-bar barbell squat", targetedMuscles: ["Quads", "Glutes"]),
            Exercise(id: UUID(), name: "Low-Bar Back Squat", description: "Powerlifting-style squat", targetedMuscles: ["Glutes", "Hamstrings"]),
            Exercise(id: UUID(), name: "Front Squat", description: "Barbell front squat", targetedMuscles: ["Quads", "Core"]),
            Exercise(id: UUID(), name: "Leg Press", description: "45° or horizontal leg press", targetedMuscles: ["Quads", "Glutes"]),
            Exercise(id: UUID(), name: "Hack Squat", description: "Machine hack squat", targetedMuscles: ["Quads"]),
            Exercise(id: UUID(), name: "Bulgarian Split Squat", description: "Rear-foot-elevated split squat", targetedMuscles: ["Quads", "Glutes"]),
            Exercise(id: UUID(), name: "Walking Lunges", description: "Dumbbell walking lunges", targetedMuscles: ["Quads", "Glutes"]),
            Exercise(id: UUID(), name: "Leg Extension", description: "Quad isolation machine", targetedMuscles: ["Quads"]),
            Exercise(id: UUID(), name: "Lying Leg Curl", description: "Hamstring curl machine", targetedMuscles: ["Hamstrings"]),
            Exercise(id: UUID(), name: "Seated Leg Curl", description: "Seated hamstring curl", targetedMuscles: ["Hamstrings"]),
            Exercise(id: UUID(), name: "Standing Calf Raise", description: "Machine or smith standing calf", targetedMuscles: ["Calves"]),
            Exercise(id: UUID(), name: "Seated Calf Raise", description: "Seated calf machine", targetedMuscles: ["Soleus"]),

            // Arms & Core
            Exercise(id: UUID(), name: "Barbell Bicep Curl", description: "Standing barbell curl", targetedMuscles: ["Biceps"]),
            Exercise(id: UUID(), name: "EZ-Bar Curl", description: "EZ-bar bicep curl", targetedMuscles: ["Biceps"]),
            Exercise(id: UUID(), name: "Dumbbell Hammer Curl", description: "Neutral grip curl", targetedMuscles: ["Biceps", "Brachialis"]),
            Exercise(id: UUID(), name: "Concentration Curl", description: "Seated DB concentration curl", targetedMuscles: ["Biceps"]),
            Exercise(id: UUID(), name: "Cable Bicep Curl", description: "Low-cable bicep curl", targetedMuscles: ["Biceps"]),
            Exercise(id: UUID(), name: "Plank", description: "Forearm plank hold", targetedMuscles: ["Core"]),
            Exercise(id: UUID(), name: "Hanging Leg Raise", description: "Strict hanging leg raise", targetedMuscles: ["Lower Abs"]),
            Exercise(id: UUID(), name: "Ab Wheel Rollout", description: "Ab wheel from knees or standing", targetedMuscles: ["Core"]),
            Exercise(id: UUID(), name: "Russian Twist", description: "Weighted or bodyweight twist", targetedMuscles: ["Obliques"]),
            Exercise(id: UUID(), name: "Cable Crunch", description: "Kneeling cable crunch", targetedMuscles: ["Abs"])
        ]
        
        saveExercises()
    }
    
    // MARK: - Sessions & week summary (unchanged)
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            completedSessions = decoded
        }
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
        // TODO: Commenting out exercises temporarily
//        userWorkouts[wIndex].exercises.removeAll { $0.id == exerciseId }
        saveWorkouts()
    }
    
    func addExercise(to workout: Workout, exercise: Exercise) {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        let we = WorkoutExercise(id: UUID(), exercise: exercise)
        // TODO: Commenting out exercises temporarily
//        userWorkouts[index].exercises.append(we)
        saveWorkouts()
    }
}
