//
//  CardioSlotDetailEditorView.swift
//  FitLog
//
//  Rich editor for a cardio template slot in the program builder.
//

import SwiftUI

struct CardioSlotDetailEditorView: View {
    @Binding var slot: SplitBuilderEditableSlot
    @Environment(DataManager.self) private var dataManager
    @Environment(\.dismiss) private var dismiss

    @State private var showCardioLibrary = false
    @State private var draftSlot: SplitBuilderEditableSlot?
    @State private var prescription: CardioPrescription = CardioPrescription(
        kind: .steadyState,
        targetDurationSec: 30 * 60,
        targetZone: .zone2
    )

    private var workingSlot: SplitBuilderEditableSlot {
        draftSlot ?? slot
    }

    private var selectedExercise: Exercise? {
        guard let id = workingSlot.suggestedExerciseOverrideId else { return nil }
        return dataManager.globalExercises.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    Button {
                        showCardioLibrary = true
                    } label: {
                        Label(
                            workingSlot.suggestedExerciseName ?? "Pick cardio exercise",
                            systemImage: "figure.run"
                        )
                        .foregroundStyle(FitlogPalette.chartSecondary)
                    }
                    .accessibilityHint("Opens cardio and hybrid exercises from your library.")

                    if let ex = selectedExercise {
                        Text(ex.cardioMetadata?.activityKind.displayName ?? "Cardio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Prescription") {
                    CardioIntervalEditorView(prescription: $prescription, embedInParentForm: true)
                }
            }
            .navigationTitle("Cardio slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyPrescriptionToDraft()
                        if let draftSlot {
                            slot = draftSlot
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draftSlot = slot
                var loaded = slot.cardioPrescription ?? CardioProgramTemplates.defaultCardioSlot(
                    library: dataManager.globalExercises
                ).cardioPrescription ?? prescription
                if loaded.notes == nil, let slotNotes = slot.notes, !slotNotes.isEmpty {
                    loaded.notes = slotNotes
                }
                prescription = loaded
            }
            .sheet(isPresented: $showCardioLibrary) {
                CardioExercisePickerSheet { exercise in
                    var s = workingSlot
                    s.suggestedExerciseName = exercise.name
                    s.suggestedExerciseOverrideId = exercise.id
                    s.targetMuscleNames = exercise.targetedMuscles.map(\.rawValue)
                    if s.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        s.label = exercise.name
                    }
                    draftSlot = s
                    showCardioLibrary = false
                }
                .environment(dataManager)
            }
        }
    }

    private func applyPrescriptionToDraft() {
        var s = workingSlot
        s.cardioPrescription = prescription
        s.modality = .cardio
        s.notes = prescription.notes?.isEmpty == false ? prescription.notes : workingSlot.notes
        switch prescription.kind {
        case .intervals:
            let count = max(1, prescription.intervals.reduce(0) { $0 + max(1, $1.repeatCount) })
            s.sets = count
            s.reps = "intervals"
        case .steadyState:
            s.sets = 1
            s.reps = "steady"
        case .circuit:
            s.sets = 1
            s.reps = "circuit"
        case .custom:
            s.sets = 1
            s.reps = "cardio"
        }
        draftSlot = s
    }
}
