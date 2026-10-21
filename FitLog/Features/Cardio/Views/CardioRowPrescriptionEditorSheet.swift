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
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true
    @State private var prescription: CardioPrescription

    init(
        workoutId: UUID,
        rowId: UUID,
        exerciseName: String,
        prescription: CardioPrescription,
        lastLoadCaption: String? = nil,
        resolvesLastLoadFromEnvironment: Bool = true
    ) {
        self.workoutId = workoutId
        self.rowId = rowId
        self.exerciseName = exerciseName
        self.lastLoadCaption = lastLoadCaption
        self.resolvesLastLoadFromEnvironment = resolvesLastLoadFromEnvironment
        _prescription = State(initialValue: prescription)
    }

    var body: some View {
        NavigationStack {
            CardioIntervalEditorView(prescription: $prescription)
                .safeAreaInset(edge: .top) {
                    if let lastLoad = resolvedLastLoadCaption {
                        Text(lastLoad)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .accessibilityIdentifier(FitLogA11yID.cardioRowEditor.lastLoad)
                            .accessibilityLabel(lastLoad)
                            .accessibilityHint("Last cardio duration from a completed session")
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                .navigationTitle(exerciseName)
                .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Closes without saving this cardio prescription")
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
                    .accessibilityLabel("Save")
                    .accessibilityHint("Saves this cardio prescription to the workout")
                }
            }
            .keyboardDismissToolbar()
        }
    }

    /// Last cardio duration from a completed session. Strength last-load is left to other surfaces.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return PearlLastWorkingLoad.lastCardioDurationCaption(from: dataVM.completedSessions)
    }
}

#Preview("Cardio editor · last duration") {
    CardioRowPrescriptionEditorSheet(
        workoutId: UUID(),
        rowId: UUID(),
        exerciseName: "Zone 2",
        prescription: CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    )
}

#Preview("Cardio editor · dark duration") {
    CardioRowPrescriptionEditorSheet(
        workoutId: UUID(),
        rowId: UUID(),
        exerciseName: "Zone 2",
        prescription: CardioPrescription(kind: .steadyState, targetDurationSec: 30 * 60),
        lastLoadCaption: "Last 30:00",
        resolvesLastLoadFromEnvironment: false
    )
    .preferredColorScheme(.dark)
}
