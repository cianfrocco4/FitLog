//
//  CurrentWorkoutPullUpSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct CurrentWorkoutPullUpSheet: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(currentVM.currentSession?.exerciseLogs ?? []) { log in Text(log.workoutExercise.exercise.name) }
            .navigationTitle("Current Workout")
            .toolbar { Button("Finish") { currentVM.stopWorkout(); dismiss() }.foregroundStyle(.red) }
        }
    }
}
