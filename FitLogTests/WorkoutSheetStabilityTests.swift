//
//  WorkoutSheetStabilityTests.swift
//  FitLogTests
//

import SwiftUI
import Testing
@testable import FitLog

struct WorkoutSheetStabilityTests {
    @Test func collapsedDetentDismissesPullUp() {
        #expect(WorkoutSheetCollapsePolicy.shouldDismissPullUp(for: FitlogWorkoutSheetDetent.collapsed))
        #expect(!WorkoutSheetCollapsePolicy.shouldDismissPullUp(for: FitlogWorkoutSheetDetent.medium))
        #expect(!WorkoutSheetCollapsePolicy.shouldDismissPullUp(for: FitlogWorkoutSheetDetent.expanded))
    }

    @Test func restStepsFromActualSecondsAndClampsTheResult() {
        #expect(SessionRestOverrideBounds.range == 0...600)
        #expect(SessionRestOverrideBounds.stepped(100, by: 1) == 115)
        #expect(SessionRestOverrideBounds.stepped(100, by: -1) == 85)
        #expect(SessionRestOverrideBounds.stepped(90, by: 1) == 105)
        #expect(SessionRestOverrideBounds.stepped(0, by: -1) == 0)
        #expect(SessionRestOverrideBounds.stepped(300, by: 1) == 315)
        #expect(SessionRestOverrideBounds.stepped(590, by: 1) == 600)
        #expect(SessionRestOverrideBounds.stepped(600, by: 1) == 600)
        #expect(SessionRestOverrideBounds.stepped(600, by: -1) == 585)
        #expect(SessionRestOverrideBounds.stepped(1_000, by: -1) == 600)
        #expect(SessionRestOverrideBounds.stepped(-15, by: 1) == 0)
        #expect(SessionRestOverrideBounds.stepped(1_000, by: 1) == 600)
        #expect(SessionRestOverrideBounds.clamped(1_000) == 600)
        #expect(SessionRestOverrideBounds.clamped(-4) == 0)
        #expect(SessionRestOverrideBounds.clamped(90) == 90)
        for sample in [0, 1, 14, 15, 90, 100, 300, 585, 590, 600] {
            let up = SessionRestOverrideBounds.stepped(sample, by: 1)
            let down = SessionRestOverrideBounds.stepped(sample, by: -1)
            #expect(up >= sample)
            #expect(up - sample <= SessionRestOverrideBounds.step)
            #expect(down <= sample)
            #expect(sample - down <= SessionRestOverrideBounds.step)
        }
    }

    @Test func dismissSettleDelayIsPositiveButShort() {
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds > 0)
        #expect(WorkoutSheetCollapsePolicy.dismissSettleNanoseconds <= 500_000_000)
    }

    @Test func sheetBackgroundIsOpaqueSystemFill() {
        #expect(WorkoutSheetPresentationStyle.background == Color(.systemBackground))
    }

    @Test func finishReady_requiresEveryStartableRow() {
        let logs = [
            workingLog(sets: 3, recommended: 3),
            workingLog(sets: 1, recommended: 3)
        ]
        #expect(
            WorkoutFinishReadyPolicy.shouldOfferFinish(logs: logs, completedExerciseIds: []) == false
        )
    }

    @Test func finishReady_whenAllPrescribedWorkIsIn() {
        let logs = [
            workingLog(sets: 3, recommended: 3),
            workingLog(sets: 4, recommended: 3)
        ]
        #expect(WorkoutFinishReadyPolicy.shouldOfferFinish(logs: logs, completedExerciseIds: []))
    }

    @Test func finishReady_blockedByOpenPlaceholder() {
        let logs = [workingLog(sets: 3, recommended: 3), placeholderLog()]
        #expect(
            WorkoutFinishReadyPolicy.shouldOfferFinish(logs: logs, completedExerciseIds: []) == false
        )
    }

    @Test func finishReady_emptySessionIsNotReady() {
        #expect(WorkoutFinishReadyPolicy.shouldOfferFinish(logs: [], completedExerciseIds: []) == false)
    }

    @Test func finishReady_warmupsAloneDoNotCount() {
        let log = log(setTypes: [.warmup, .warmup], recommended: 3)
        #expect(WorkoutFinishReadyPolicy.isRowReady(log, completedExerciseIds: []) == false)
        #expect(
            WorkoutFinishReadyPolicy.shouldOfferFinish(logs: [log], completedExerciseIds: []) == false
        )
    }

    @Test func finishReady_acceptsManuallyMarkedExercise() {
        let log = workingLog(sets: 0, recommended: 3)
        let id = log.workoutExercise.exerciseId!
        #expect(
            WorkoutFinishReadyPolicy.shouldOfferFinish(logs: [log], completedExerciseIds: [id])
        )
    }

    @Test func finishReady_cardioDurationCountsAsComplete() {
        let log = cardioLog(durationSec: 2_700)
        #expect(WorkoutFinishReadyPolicy.hasCompletedCardioWork(log))
        #expect(WorkoutFinishReadyPolicy.shouldOfferFinish(logs: [log], completedExerciseIds: []))
    }

    @Test func finishReady_zeroDurationCardioIsNotComplete() {
        let log = cardioLog(durationSec: 0)
        #expect(WorkoutFinishReadyPolicy.hasCompletedCardioWork(log) == false)
        #expect(
            WorkoutFinishReadyPolicy.shouldOfferFinish(logs: [log], completedExerciseIds: []) == false
        )
    }

    @Test func finishReadyCopyIsStable() {
        #expect(WorkoutFinishReadyPolicy.bannerTitle == "All sets logged")
        #expect(WorkoutFinishReadyPolicy.bannerSubtitle.contains("History"))
        #expect(WorkoutFinishReadyPolicy.bannerAccessibilityLabel.contains("Finish"))
    }

    private func workingLog(sets: Int, recommended: Int) -> ExerciseLog {
        log(setTypes: Array(repeating: .working, count: sets), recommended: recommended)
    }

    private func log(setTypes: [ExerciseSetType], recommended: Int) -> ExerciseLog {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let logged: [LoggedSet] = setTypes.map { type in
            LoggedSet(
                id: UUID(),
                weight: 135,
                reps: 8,
                restTime: 0,
                timestamp: Date(),
                setType: type
            )
        }
        return ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: recommended,
                recommendedReps: "8"
            ),
            loggedSets: logged
        )
    }

    private func placeholderLog() -> ExerciseLog {
        ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .flexible(
                    SlotBlueprint(
                        id: UUID(),
                        label: "Open",
                        targetedMuscles: [.chest]
                    )
                ),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: []
        )
    }

    private func cardioLog(durationSec: Int) -> ExerciseLog {
        let exercise = Exercise(id: UUID(), name: "Zone 2", description: "", targetedMuscles: [.other])
        let set = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: durationSec)
        )
        return ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: 1,
                recommendedReps: "time",
                cardioPrescription: CardioPrescription(targetDurationSec: durationSec)
            ),
            loggedSets: [set]
        )
    }
}
