//
//  LogSetView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct LogSetView: View {
    let workout: Workout
    let exerciseIndex: Int
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var weight = 0.0
    @State private var reps = 0
    @State private var rest = 90
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Set") {
                    Stepper("Weight: \(weight, specifier: "%.1f") kg", value: $weight, in: 0...500, step: 0.5)
                    Stepper("Reps: \(reps)", value: $reps, in: 0...50)
                    Stepper("Rest: \(rest)s", value: $rest, in: 0...300, step: 15)
                }
            }
            .navigationTitle("Log Set")
            .toolbar { Button("Save") { currentVM.logSet(exerciseIndex: exerciseIndex, weight: weight, reps: reps, restTime: rest); dismiss() } }
        }
    }
}
