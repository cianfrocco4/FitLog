//
//  CurrentWorkoutSessionViewModel.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import UserNotifications

final class CurrentWorkoutSessionViewModel: ObservableObject {
    @Published var currentSession: WorkoutSession?
    
    var isInProgress: Bool { currentSession != nil && currentSession?.endTime == nil }
    
    func startWorkout(_ workout: Workout) {
        // TODO: Commenting out exercises temporarily
//        let logs = workout.exercises.map { ex in
//            ExerciseLog(id: UUID(), workoutExercise: ex, loggedSets: [])
//        }
//        currentSession = WorkoutSession(id: UUID(), workout: workout, startTime: Date(), endTime: nil, exerciseLogs: logs)
    }
    
    func stopWorkout() {
        guard var session = currentSession else  { return }
        
        session.endTime = Date()
        
        // Save to completed
        if let data = try? JSONEncoder().encode([session]), let existing = UserDefaults.standard.data(forKey: "completedSessions"),
           var all = try? JSONDecoder().decode([WorkoutSession].self, from: existing) {
            all.append(session)
            if let encoded = try? JSONEncoder().encode(all) {
                UserDefaults.standard.set(encoded, forKey: "completedSessions")
            }
        }
        currentSession = nil
    }
    
    func logSet(exerciseIndex: Int, weight: Double, reps: Int, restTime: Int) {
        guard var session = currentSession, exerciseIndex < session.exerciseLogs.count else { return }
        
        let set = LoggedSet(id: UUID(), weight: weight, reps: reps, restTime: restTime, timestamp: Date())
        session.exerciseLogs[exerciseIndex].loggedSets.append(set)
        currentSession = session
        
        if restTime > 0 {
            scheduleRestNotification(seconds: restTime)
        }
    }
    
    private func scheduleRestNotification(seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Over! 💪"
        content.body = "Time for the next set"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
