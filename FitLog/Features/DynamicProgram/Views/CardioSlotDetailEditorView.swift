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
    @State private var lastDurationSec: Int?
    @State private var editorResetToken = 0

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

                if let lastDurationCaption {
                    Section {
                        Text(lastDurationCaption)
                            .font(.body.weight(.medium))
                            .accessibilityIdentifier(FitLogA11yID.cardioSlotEditor.lastDuration)
                            .accessibilityLabel(lastDurationCaption)
                        if canApplyLastDuration {
                            Button("Use last duration") {
                                applyLastDuration()
                            }
                            .accessibilityIdentifier(FitLogA11yID.cardioSlotEditor.useLastDuration)
                            .accessibilityHint("Fills the duration target from your last logged cardio for this exercise.")
                        }
                    } header: {
                        Text("Last session")
                    } footer: {
                        Text("Duration from your last completed cardio log for this exercise.")
                    }
                }

                Section("Prescription") {
                    CardioIntervalEditorView(prescription: $prescription, embedInParentForm: true)
                        .id(editorResetToken)
                }
            }
            .navigationTitle("Cardio slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityHint("Closes without saving slot changes.")
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
                    .accessibilityHint("Saves the cardio prescription to this slot.")
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
                refreshLastDuration()
            }
            .onChange(of: workingSlot.suggestedExerciseOverrideId) { _, _ in
                refreshLastDuration()
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

    private func refreshLastDuration() {
        guard let id = workingSlot.suggestedExerciseOverrideId else {
            lastDurationSec = nil
            return
        }
        lastDurationSec = CedarLastWorkingLoad.lastCardioDurationSec(
            for: id,
            from: dataManager.completedSessions
        )
    }

    private func applyLastDuration() {
        guard let lastDurationSec else { return }
        prescription = CedarLastWorkingLoad.applyingLastDuration(lastDurationSec, to: prescription)
        editorResetToken += 1
    }
}
