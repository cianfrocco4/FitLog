//
//  CardioRowPrescriptionEditorSheet.swift
//  FitLog
//

import SwiftUI

struct CardioRowPrescriptionEditorSheet: View {
    @Environment(DataManager.self) var dataVM
    @Environment(\.dismiss) private var dismiss

    let workoutId: UUID
    let rowId: UUID
    let exerciseName: String
    @State private var prescription: CardioPrescription

    init(workoutId: UUID, rowId: UUID, exerciseName: String, prescription: CardioPrescription) {
        self.workoutId = workoutId
        self.rowId = rowId
        self.exerciseName = exerciseName
        _prescription = State(initialValue: prescription)
    }

    var body: some View {
        NavigationStack {
            CardioIntervalEditorView(prescription: $prescription)
                .navigationTitle(exerciseName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            dataVM.updateCardioPrescription(
                                workoutId: workoutId,
                                workoutExerciseId: rowId,
                                prescription: prescription
                            )
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .keyboardDismissToolbar()
        }
    }
}
