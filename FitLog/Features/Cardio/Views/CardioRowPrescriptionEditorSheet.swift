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
            VStack(spacing: 0) {
                if let caption = lastLoadCaption {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(caption)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .accessibilityIdentifier(FitLogA11yID.cardioPrescription.lastLoad)
                            .accessibilityLabel(caption)
                        Spacer(minLength: 8)
                        if let sec = lastDurationSec, sec > 0 {
                            Button("Use last time") {
                                prescription.targetDurationSec = sec
                            }
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier(FitLogA11yID.cardioPrescription.useLastDuration)
                            .accessibilityLabel(
                                "Use last time, \(CardioMetricsCalculator.formatDuration(seconds: sec))"
                            )
                            .accessibilityHint("Fills duration from your last cardio session")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                CardioIntervalEditorView(prescription: $prescription)
            }
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
            .onAppear {
                if prescription.targetDurationSec == nil, let sec = lastDurationSec, sec > 0 {
                    prescription.targetDurationSec = sec
                }
            }
        }
    }

    private var exerciseId: UUID? {
        dataVM.userWorkouts
            .first(where: { $0.id == workoutId })?
            .exercises
            .first(where: { $0.id == rowId })?
            .exerciseId
    }

    private var lastDurationSec: Int? {
        guard let exerciseId else { return nil }
        return HemlockLastWorkingLoad.lastCardioDurationSec(
            for: exerciseId,
            from: dataVM.completedSessions
        )
    }

    private var lastLoadCaption: String? {
        guard let exerciseId else { return nil }
        return HemlockLastWorkingLoad.caption(
            for: exerciseId,
            from: dataVM.completedSessions,
            displayUnit: .pounds
        )
    }
}
