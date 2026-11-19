//
//  SunstoneAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct SunstoneAskFitLogTests {

    @Test func lastRestLastWorkingAndRemainingSetsUseWholeSession() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
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
                            weight: 185,
                            reps: 8,
                            restTime: 80,
                            timestamp: Date().addingTimeInterval(-120),
                            setType: .working
                        )
                    ]
                ),
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    120,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-40),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 155,
                            reps: 10,
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-10),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.sessionLastRestSeconds == 75)
        #expect(snapshot.sessionLastRestExerciseName == "Incline Press")
        #expect(snapshot.sessionLastWorkingCaption == "155 lb × 10 reps")
        #expect(snapshot.sessionLastWorkingExerciseName == "Incline Press")
        #expect(snapshot.remainingSetCount == 5)
        #expect(snapshot.canUseThisWorkoutLastRest)
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: snapshot)
                == "5 sets left this workout."
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: snapshot)
                == "Last working this workout was 155 lb × 10 reps on Incline Press."
        )
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
        #expect(SunstoneAskFitLog.thisWorkoutLastRestTargetSeconds(snapshot: snapshot) == 75)
    }

    @Test func warmupRestCountsButWarmupLoadIsNotLastWorking() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .working
                        )
                    ]
                ),
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    150,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 40,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let snapshot = SunstoneAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.sessionLastRestSeconds == 40)
        #expect(snapshot.sessionLastRestExerciseName == "Incline Press")
        #expect(snapshot.sessionLastWorkingCaption == "185 lb × 8 reps")
        #expect(snapshot.sessionLastWorkingExerciseName == "Bench Press")
        #expect(snapshot.remainingSetCount == 6)
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: snapshot)
                == "Last working this workout was 185 lb × 8 reps on Bench Press."
        )
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot)
                == SunstoneAskFitLog.noRestTimerDialog
        )
        #expect(SunstoneAskFitLog.canUseThisWorkoutLastRest(snapshot: snapshot) == false)
    }

    @Test func idleAndExpiredRestDoNotInventAStart() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let idle = SunstoneAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseThisWorkoutLastRest == false)
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: idle, now: now)
                == SunstoneAskFitLog.noRestTimerDialog
        )

        let expired = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseThisWorkoutLastRest == false)
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: expired, now: now)
                == SunstoneAskFitLog.noRestTimerDialog
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: expired)
                == "2 sets left this workout."
        )
    }

    @Test func missingLastRestDoesNotQueueARestChange() {
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
        let snapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(45),
            now: now
        )
        #expect(snapshot.canUseThisWorkoutLastRest == false)
        #expect(SunstoneAskFitLog.thisWorkoutLastRestTargetSeconds(snapshot: snapshot) == nil)
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot, now: now)
                == "No rest logged yet this workout."
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: snapshot)
                == "No working set logged yet this workout."
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left this workout."
        )
    }

    @Test func remainingOneSecondCanUseLastRestWithoutStartingRest() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseThisWorkoutLastRest)
        #expect(SunstoneAskFitLog.thisWorkoutLastRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func lastRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 720,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(90),
            now: now
        )
        #expect(SunstoneAskFitLog.thisWorkoutLastRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.sessionLastRestSeconds == 720)
    }

    @Test func zeroSecondRestDoesNotBecomeATarget() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.sessionLastRestSeconds == nil)
        #expect(snapshot.canUseThisWorkoutLastRest == false)
        #expect(snapshot.sessionLastWorkingCaption == "95 lb × 8 reps")
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot, now: now)
                == "No rest logged yet this workout."
        )
    }

    @Test func finishedAndMissingSessionsStayQuiet() {
        let benchId = UUID()
        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 600,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let finishedSnapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseThisWorkoutLastRest == false)
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: finishedSnapshot, now: now)
                == SunstoneAskFitLog.noInProgressDialog
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: finishedSnapshot)
                == SunstoneAskFitLog.noInProgressDialog
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: finishedSnapshot)
                == SunstoneAskFitLog.noInProgressDialog
        )

        let missing = SunstoneAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: missing)
                == SunstoneAskFitLog.noInProgressDialog
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
        let now = Date()
        let snapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.remainingSetCount == 0)
        #expect(snapshot.sessionLastRestSeconds == nil)
        #expect(snapshot.canUseThisWorkoutLastRest == false)
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: snapshot)
                == "No working set logged yet this workout."
        )
        #expect(
            SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot, now: now)
                == "No rest logged yet this workout."
        )
    }

    @Test func cardioLeftoverCountsAsOneSetAndLastWorkingUsesDuration() {
        let zone2Id = UUID()
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 400,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-80),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-40),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        )
                    ]
                ),
                (
                    "Zone 2",
                    zone2Id,
                    1,
                    "—",
                    90,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date().addingTimeInterval(-5),
                            setType: .working,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                )
            ]
        )
        let snapshot = SunstoneAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.remainingSetCount == 0)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.sessionLastWorkingCaption == "45 minutes")
        #expect(snapshot.sessionLastWorkingExerciseName == "Zone 2")
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: snapshot)
                == "No sets left this workout."
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: snapshot)
                == "Last working this workout was 45 minutes on Zone 2."
        )
        #expect(snapshot.sessionLastRestSeconds == 90)
        #expect(snapshot.sessionLastRestExerciseName == "Bench Press")
    }

    @Test func unfinishedCardioAddsOneRemainingSet() {
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
        let snapshot = SunstoneAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.remainingSetCount == 1)
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: snapshot)
                == "1 set left this workout."
        )
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: snapshot)
                == "No working set logged yet this workout."
        )
    }

    @Test func markedCompleteRowsDoNotCountTowardRemainingSets() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = SunstoneAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.remainingSetCount == 4)
        #expect(
            SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(snapshot: snapshot)
                == "4 sets left this workout."
        )
    }

    @Test func lastWorkingUsesKilogramsWhenDisplayUnitIsKilograms() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = SunstoneAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: nil,
            displayUnit: .kilograms
        )
        #expect(snapshot.sessionLastWorkingCaption == "83.9 kg × 8 reps")
        #expect(
            SunstoneAskFitLog.thisWorkoutLastWorkingDialog(snapshot: snapshot)
                == "Last working this workout was 83.9 kg × 8 reps on Bench Press."
        )
    }

    @Test func sunstoneSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.SunstoneSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedIsIncomplete: true,
            remainingSetCount: 5,
            sessionLastRestSeconds: 80,
            sessionLastRestExerciseName: "Flyes",
            sessionLastWorkingCaption: "185 lb × 8 reps",
            sessionLastWorkingExerciseName: "Bench Press",
            canUseThisWorkoutLastRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishSunstoneSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadSunstoneSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishSunstoneRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadSunstoneRestEndsAt()
        #expect(loadedRest != nil)
        #expect(SunstoneAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishSunstoneRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadSunstoneRestEndsAt() == nil)

        FitLogIntentBridge.queueUseThisWorkoutLastRestTime()
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastRestTime())
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastRestTime() == false)
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
