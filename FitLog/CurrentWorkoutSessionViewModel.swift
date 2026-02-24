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
    
    func startWorkout(_ workout: Workout) { /* same as first */ }
    func stopWorkout() { /* same */ }
    func logSet(exerciseIndex: Int, weight: Double, reps: Int, restTime: Int) { /* same */ }
    private func scheduleRestNotification(seconds: Int) { /* same */ }
}
