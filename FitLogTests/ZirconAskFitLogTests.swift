//
//  ZirconAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ZirconAskFitLogTests {

    @Test func strengthTargetAndPrescribedRestUseFocusedRow() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
            activeExerciseIds: [inclineId],
            exercises: [
                ("Bench Press", benchId, 3, "8-12", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = ZirconAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.focusedIsCardio == false)
        #expect(snapshot.focusedTargetCaption == "4 sets of 10")
        #expect(snapshot.focusedPrescribedRestSeconds == 120)
        #expect(snapshot.canAddRest == false)
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == "Incline Press: 4 sets of 10."
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: snapshot)
                == "Rest 2 minutes on Incline Press."
        )
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: snapshot)
                == ZirconAskFitLog.noRestTimerDialog
        )
        #expect(ZirconAskFitLog.canAddRest(snapshot: snapshot) == false)
    }

    @Test func sessionRestOverrideBeatsPlanDefault() {
        let benchId = UUID()
        var live = session(
            name: "Push A",
            endedAt: nil,
            duration: 90,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        live.exerciseLogs[0].sessionRestOverrideSeconds = 45
        let snapshot = ZirconAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedPrescribedRestSeconds == 45)
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: snapshot)
                == "Rest 45 seconds on Bench Press."
        )
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == "Bench Press: 3 sets of 8."
        )
    }

    @Test func singularSetWordingAndEmptyReps() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 30,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 1, "   ", 0, nil, [])
            ]
        )
        let snapshot = ZirconAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedTargetCaption == "1 set")
        #expect(snapshot.focusedPrescribedRestSeconds == nil)
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == "Bench Press: 1 set."
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: snapshot)
                == "No rest prescription on Bench Press."
        )
    }

    @Test func cardioTargetSpeaksDurationAndSkipsStrengthRest() {
        let zone2Id = UUID()
        let live = session(
            name: "Zone 2",
            endedAt: nil,
            duration: 120,
            activeExerciseIds: [zone2Id],
            exercises: [
                (
                    "Zone 2",
                    zone2Id,
                    1,
                    "—",
                    90,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    []
                )
            ]
        )
        let snapshot = ZirconAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedIsCardio)
        #expect(snapshot.focusedTargetCaption == "45 minutes")
        #expect(snapshot.focusedPrescribedRestSeconds == nil)
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == "Zone 2: 45 minutes."
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: snapshot)
                == "Zone 2 is cardio."
        )
    }

    @Test func addRestWhenCountdownIsLive() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let restEndsAt = now.addingTimeInterval(90)
        let snapshot = ZirconAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(snapshot.canAddRest)
        #expect(ZirconAskFitLog.canAddRest(snapshot: snapshot, now: now))
        #expect(ZirconAskFitLog.remainingRestSeconds(snapshot: snapshot, now: now) == 90)
        #expect(ZirconAskFitLog.addedRestSeconds(snapshot: snapshot, now: now) == 120)
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes."
        )
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == "Bench Press: 3 sets of 8."
        )
    }

    @Test func addRestCapsAtTenMinutes() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let restEndsAt = now.addingTimeInterval(590)
        let snapshot = ZirconAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(ZirconAskFitLog.addedRestSeconds(snapshot: snapshot, now: now) == 600)
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
    }

    @Test func expiredRestDoesNotQueueMoreTime() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = ZirconAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-1),
            now: now
        )
        #expect(snapshot.canAddRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(ZirconAskFitLog.canAddRest(snapshot: snapshot, now: now) == false)
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: snapshot, now: now)
                == ZirconAskFitLog.noRestTimerDialog
        )
    }

    @Test func idleRestOnInProgressDoesNotInventAStart() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let snapshot = ZirconAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(ZirconAskFitLog.canAddRest(snapshot: snapshot) == false)
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: snapshot)
                == ZirconAskFitLog.noRestTimerDialog
        )
    }

    @Test func nothingFocusedKeepsTargetAndRestQuiet() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = ZirconAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.canAddRest)
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == ZirconAskFitLog.nothingFocusedDialog
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: snapshot)
                == ZirconAskFitLog.nothingFocusedDialog
        )
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 10 seconds."
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: nil)
                == ZirconAskFitLog.noInProgressDialog
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: nil)
                == ZirconAskFitLog.noInProgressDialog
        )
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: nil)
                == ZirconAskFitLog.noInProgressDialog
        )
        #expect(ZirconAskFitLog.canAddRest(snapshot: nil) == false)

        let empty = ZirconAskFitLog.querySnapshot(inProgress: nil, restEndsAt: Date().addingTimeInterval(90))
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canAddRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: empty)
                == ZirconAskFitLog.noInProgressDialog
        )

        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 3600,
            activeExerciseIds: [UUID()],
            exercises: [
                ("Bench Press", UUID(), 3, "8", 90, nil, [])
            ]
        )
        let finishedSnapshot = ZirconAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canAddRest == false)
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: finishedSnapshot)
                == ZirconAskFitLog.noInProgressDialog
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: finishedSnapshot)
                == ZirconAskFitLog.noInProgressDialog
        )
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: finishedSnapshot)
                == ZirconAskFitLog.noInProgressDialog
        )
    }

    @Test func openSlotPlaceholderCannotBecomeATarget() {
        let openSlot = WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    id: UUID(),
                    label: "Pick later",
                    targetedMuscles: [.chest],
                    defaultExerciseId: nil
                )
            ),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [openSlot]),
            startTime: Date().addingTimeInterval(-120),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: openSlot,
                    loggedSets: []
                )
            ]
        )
        let snapshot = ZirconAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            ZirconAskFitLog.addRestDialog(snapshot: snapshot)
                == ZirconAskFitLog.noRestTimerDialog
        )
    }

    @Test func warmupDoesNotChangePrescriptionTarget() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 180,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8-12",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 60,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let snapshot = ZirconAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedTargetCaption == "3 sets of 8-12")
        #expect(snapshot.focusedPrescribedRestSeconds == 90)
        #expect(
            ZirconAskFitLog.thisExerciseTargetDialog(snapshot: snapshot)
                == "Bench Press: 3 sets of 8-12."
        )
        #expect(
            ZirconAskFitLog.prescribedRestDialog(snapshot: snapshot)
                == "Rest 1 minute, 30 seconds on Bench Press."
        )
    }

    @Test func zirconSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.ZirconSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsCardio: false,
            focusedTargetCaption: "4 sets of 10",
            focusedPrescribedRestSeconds: 120,
            canAddRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false
        )
        FitLogIntentBridge.publishZirconSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadZirconSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishZirconRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadZirconRestEndsAt()
        #expect(loadedRest != nil)
        #expect(ZirconAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishZirconRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadZirconRestEndsAt() == nil)

        FitLogIntentBridge.queueAddRestTime()
        #expect(FitLogIntentBridge.consumePendingAddRestTime())
        #expect(FitLogIntentBridge.consumePendingAddRestTime() == false)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        activeExerciseIds: [UUID] = [],
        completedExerciseIds: [UUID] = [],
        exercises: [(String, UUID, Int, String, Int, CardioPrescription?, [LoggedSet])]
    ) -> WorkoutSession {
        let logs: [ExerciseLog] = exercises.map { exerciseName, exerciseId, recommendedSets, recommendedReps, rest, cardio, sets in
            let workoutExercise = WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: exerciseId,
                    nameAtTimeOfLog: exerciseName
                )),
                defaultRestTime: rest,
                recommendedSets: recommendedSets,
                recommendedReps: recommendedReps,
                cardioPrescription: cardio
            )
            return ExerciseLog(
                id: UUID(),
                workoutExercise: workoutExercise,
                loggedSets: sets
            )
        }
        let workout = Workout(id: UUID(), name: name, exercises: logs.map(\.workoutExercise))
        let end = endedAt
        let start: Date
        if let end {
            start = end.addingTimeInterval(TimeInterval(-duration))
        } else {
            start = Date().addingTimeInterval(TimeInterval(-duration))
        }
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: start,
            endTime: end,
            exerciseLogs: logs,
            activeExerciseIds: activeExerciseIds,
            completedExerciseIds: completedExerciseIds
        )
    }
}
