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
    
    init() { loadAll() }
    
    func loadAll() {
        loadWorkouts()
        loadExercises()
        loadSessions()
        if globalExercises.isEmpty { preloadSampleData() }
    }
    
    private func loadWorkouts() {
        if let data = UserDefaults.standard.data(forKey: workoutsKey),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            userWorkouts = decoded
        }
    }
    
    private func loadExercises() {
        if let data = UserDefaults.standard.data(forKey: exercisesKey),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            globalExercises = decoded
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            completedSessions = decoded
        }
    }
    
    func saveWorkouts() {
        if let data = try? JSONEncoder().encode(userWorkouts) {
            UserDefaults.standard.set(data, forKey: workoutsKey)
        }
    }
    
    func saveExercises() {
        if let data = try? JSONEncoder().encode(globalExercises) {
            UserDefaults.standard.set(data, forKey: exercisesKey)
        }
    }
    
    func saveSessions() {
        if let data = try? JSONEncoder().encode(completedSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
    
    // MARK: - Workout CRUD
    func createWorkout(name: String) {
        let newWorkout = Workout(id: UUID(), name: name, exercises: [])
        userWorkouts.append(newWorkout)
        saveWorkouts()
    }
    
    func deleteExercise(from workout: Workout, exerciseId: UUID) {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        userWorkouts[index].exercises.removeAll { $0.id == exerciseId }
        saveWorkouts()
    }
    
    func addExercise(to workout: Workout, exercise: Exercise) {
        guard let index = userWorkouts.firstIndex(where: { $0.id == workout.id }) else { return }
        let we = WorkoutExercise(id: UUID(), exercise: exercise)
        userWorkouts[index].exercises.append(we)
        saveWorkouts()
    }
    
    private func preloadSampleData() {
        globalExercises = [
            Exercise(id: UUID(), name: "Bench Press", description: "Classic chest builder", targetedMuscles: ["Chest", "Triceps"]),
            Exercise(id: UUID(), name: "Squat", description: "King of legs", targetedMuscles: ["Quads", "Glutes"]),
            Exercise(id: UUID(), name: "Pull-Up", description: "Ultimate back", targetedMuscles: ["Lats", "Biceps"])
        ]
        saveExercises()  // implement saveExercises similarly
        // Create 2 sample workouts as in original response
    }
    
    var workoutsThisWeek: Int {
        let sevenDaysAgo = Date().addingTimeInterval(-7*86400)
        return completedSessions.filter { ($0.endTime ?? Date()) > sevenDaysAgo }.count
    }
    
    // createWorkout, deleteExercise, addExercise methods exactly as in first response
}
