//
//  NewWorkoutSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/25/26.
//

import SwiftUI

struct NewWorkoutSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var workoutName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Workout Details")) {
                    TextField("Workout Name (e.g. Push Day, Legs)", text: $workoutName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .navigationTitle("Create New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        if !workoutName.isEmpty {
                            dataVM.createWorkout(name: workoutName)
                            dismiss()
                        }
                    }
                    .disabled(workoutName.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
