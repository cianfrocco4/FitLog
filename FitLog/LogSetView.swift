//
//  LogSetView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct LogSetView: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.dismiss) var dismiss
    
    let exerciseIndex: Int
    
    @State private var weight: Double = 0.0
    @State private var reps: Int = 0
    @State private var restTime: Int = 90
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Log Set") {
                    Stepper(
                        "Weight: \(weight, specifier: "%.1f") lbs",
                        value: $weight,
                        in: 0...1100,
                        step: 5
                    )
                    
                    Stepper(
                        "Reps: \(reps)",
                        value: $reps,
                        in: 0...50,
                        step: 1
                    )
                    
                    Stepper(
                        "Rest after set: \(restTime)s",
                        value: $restTime,
                        in: 0...300,
                        step: 15
                    )
                }
            }
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        currentVM.logSet(
                            exerciseIndex: exerciseIndex,
                            weight: weight,
                            reps: reps,
                            restTime: restTime
                        )
                        
                        // Small delay for UI updates before dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(weight <= 0 || reps <= 0)
                }
            }
        }
    }
}
