//
//  CardioWorkoutBuilderViewModel.swift
//  FitLog
//

import Foundation
import Observation

@Observable
@MainActor
final class CardioWorkoutBuilderViewModel {
    let workoutId: UUID
    private let dataManager: DataManager

    var workoutName: String = ""
    var replaceTemplateWarning: String?
    private(set) var lastAppliedTemplateId: String?

    init(workoutId: UUID, dataManager: DataManager) {
        self.workoutId = workoutId
        self.dataManager = dataManager
        refreshName()
    }

    var workout: Workout? {
        dataManager.workout(id: workoutId)
    }

    var rows: [WorkoutExercise] {
        workout?.exercises ?? []
    }

    func refreshName() {
        workoutName = workout?.name ?? ""
    }

    func renameWorkout() {
        let trimmed = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let w = workout else { return }
        dataManager.renameWorkout(w, newName: trimmed)
        refreshName()
    }

    /// Replaces all rows with template content.
    func applyTemplate(_ template: CardioWorkoutTemplate, replaceExisting: Bool) {
        guard let w = workout else { return }
        if !replaceExisting, !w.exercises.isEmpty {
            replaceTemplateWarning = "This workout already has exercises. Apply template anyway to replace them?"
            return
        }
        replaceTemplateWarning = nil
        if replaceExisting {
            clearAllRows()
        }
        let resolved = CardioTemplateLibrary.resolveRows(template.rows, library: dataManager.globalExercises)
        for item in resolved {
            _ = dataManager.addCardioExercise(to: dataManager.workout(id: workoutId) ?? w, exercise: item.exercise, prescription: item.prescription)
        }
        if let fresh = dataManager.workout(id: workoutId) {
            dataManager.setWorkoutKind(fresh, kind: template.workoutKind)
        }
        lastAppliedTemplateId = template.id
    }

    func confirmReplaceAndApplyTemplate(_ template: CardioWorkoutTemplate) {
        applyTemplate(template, replaceExisting: true)
    }

    func addExercise(_ exercise: Exercise, prescription: CardioPrescription? = nil) {
        guard let w = workout else { return }
        let rx = prescription ?? defaultPrescription(for: exercise)
        _ = dataManager.addCardioExercise(to: w, exercise: exercise, prescription: rx)
        dataManager.refreshWorkoutKind(workoutId: workoutId)
    }

    func updatePrescription(rowId: UUID, prescription: CardioPrescription) {
        dataManager.updateCardioPrescription(workoutId: workoutId, workoutExerciseId: rowId, prescription: prescription)
    }

    func deleteRow(rowId: UUID) {
        guard let w = workout else { return }
        _ = dataManager.deleteExerciseReturningSnapshot(from: w, exerciseId: rowId)
        dataManager.refreshWorkoutKind(workoutId: workoutId)
    }

    func moveRow(from source: IndexSet, to destination: Int) {
        guard let w = workout else { return }
        dataManager.moveExercise(in: w, from: source, to: destination)
    }

    private func clearAllRows() {
        guard var w = workout else { return }
        let ids = w.exercises.map(\.id)
        for rowId in ids {
            _ = dataManager.deleteExerciseReturningSnapshot(from: w, exerciseId: rowId)
            w = dataManager.workout(id: workoutId) ?? w
        }
    }

    private func defaultPrescription(for exercise: Exercise) -> CardioPrescription {
        let metric = exercise.cardioMetadata?.primaryMetric ?? .time
        switch metric {
        case .distance:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 20 * 60, targetDistanceM: 3_000)
        case .calories:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 15 * 60)
        default:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 30 * 60, targetZone: .zone2)
        }
    }
}
