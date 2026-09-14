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
    @State private var lastDurationSec: Int?
    @State private var editorResetToken = 0

    init(workoutId: UUID, rowId: UUID, exerciseName: String, prescription: CardioPrescription) {
        self.workoutId = workoutId
        self.rowId = rowId
        self.exerciseName = exerciseName
        _prescription = State(initialValue: prescription)
    }

    private var resolvedExerciseId: UUID? {
        dataVM.workout(id: workoutId)?.exercises.first(where: { $0.id == rowId })?.exerciseId
    }

    private var lastDurationCaption: String? {
        guard let lastDurationSec else { return nil }
        return "Last \(CardioMetricsCalculator.formatDuration(seconds: lastDurationSec))"
    }

    private var lastDurationMatchesPrescription: Bool {
        guard let lastDurationSec else { return false }
        return prescription.targetDurationSec == lastDurationSec
    }

    private var canApplyLastDuration: Bool {
        lastDurationSec != nil
            && prescription.kind != .intervals
            && !lastDurationMatchesPrescription
    }

    var body: some View {
        NavigationStack {
            Form {
                if let lastDurationCaption {
                    Section {
                        Text(lastDurationCaption)
                            .font(.body.weight(.medium))
                            .accessibilityIdentifier(FitLogA11yID.cardioPrescription.lastDuration)
                            .accessibilityLabel(lastDurationCaption)
                        if canApplyLastDuration {
                            Button("Use last duration") {
                                applyLastDuration()
                            }
                            .accessibilityIdentifier(FitLogA11yID.cardioPrescription.useLastDuration)
                            .accessibilityHint("Fills the duration target from your last logged cardio for this exercise.")
                        }
                    } header: {
                        Text("Last session")
                    } footer: {
                        Text("Duration from your last completed cardio log for this exercise.")
                    }
                }

                CardioIntervalEditorView(prescription: $prescription, embedInParentForm: true)
                    .id(editorResetToken)
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
                refreshLastDuration()
            }
        }
    }

    private func refreshLastDuration() {
        guard let resolvedExerciseId else {
            lastDurationSec = nil
            return
        }
        lastDurationSec = PickerLastWorkingLoad.lastCardioDurationSec(
            for: resolvedExerciseId,
            from: dataVM.completedSessions
        )
    }

    private func applyLastDuration() {
        guard let lastDurationSec else { return }
        prescription = PickerLastWorkingLoad.applyingLastDuration(lastDurationSec, to: prescription)
        editorResetToken += 1
    }
}
