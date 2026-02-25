//
//  Models.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation

struct Exercise: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var targetedMuscles: [String]
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var exercise: Exercise
    var defaultRestTime: Int = 90
}

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    // TODO: Remove exercises temporarily
//    var exercises: [WorkoutExercise]
}

struct LoggedSet: Identifiable, Codable {
    let id: UUID
    var weight: Double
    var reps: Int
    var restTime: Int
    var timestamp: Date
}

struct ExerciseLog: Identifiable, Codable {
    let id: UUID
    var workoutExercise: WorkoutExercise
    var loggedSets: [LoggedSet]
}

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    var workout: Workout
    var startTime: Date
    var endTime: Date?
    var exerciseLogs: [ExerciseLog]
    var isCompleted: Bool { endTime != nil }
}
