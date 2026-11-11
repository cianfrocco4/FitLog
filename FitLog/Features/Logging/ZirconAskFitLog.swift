//
//  ZirconAskFitLog.swift
//  FitLog
//
//  Add 30 seconds to a live rest countdown from Siri / Shortcuts, plus
//  this-exercise-target and prescribed-rest queries, so a mid-session
//  "give me more rest" / "what's the target" / "how long should I rest"
//  check does not require hunting through the sheet (`like.history.logged`
//  / `like.rest.no_nag`). Empty / missing sessions, idle rest timers,
//  open placeholders, and rest days are not turned into a rest start,
//  a set, or a start. Distinct from RestTimerIntent (starts rest),
//  Aquamarine (skip rest / rest remaining / last History weight),
//  Spinel (previous exercise / this-exercise set counts), Alexandrite
//  (next incomplete / remaining / current workout), Moonstone (skip
//  remaining / next set / ready-to-finish), Tanzanite (undo / sets
//  logged / elapsed), Jasper (repeat this-session working set),
//  Tourmaline (last cardio / last-set / current-exercise), Lapis
//  (resume / last-session / days-since), Peridot (finish /
//  in-progress / last-finished), Citrine (last-load query), the Siri
//  start series (Onyx → Topaz), and 999e (in-app finish-ready banner).
//  Does not change freemium rules.
//

import Foundation

enum ZirconAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let nothingFocusedDialog = "Nothing is focused."
    static let addRestSeconds = 30
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.ZirconSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.ZirconSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        return FitLogIntentBridge.ZirconSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsCardio: focused?.isCardio ?? false,
            focusedTargetCaption: focused?.targetCaption,
            focusedPrescribedRestSeconds: focused?.prescribedRestSeconds,
            canAddRest: remainingRestSeconds(restEndsAt: restEndsAt, now: now) != nil,
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: live.exerciseLogs.contains { $0.workoutExercise.isSlotPlaceholder }
        )
    }

    static func canAddRest(
        snapshot: FitLogIntentBridge.ZirconSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        remainingRestSeconds(snapshot: snapshot, now: now) != nil
            && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func addedRestSeconds(
        snapshot: FitLogIntentBridge.ZirconSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now) else {
            return nil
        }
        return min(maxRestSeconds, remaining + addRestSeconds)
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.ZirconSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func addRestDialog(
        snapshot: FitLogIntentBridge.ZirconSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let added = addedRestSeconds(snapshot: snapshot, now: now) else {
            return noRestTimerDialog
        }
        return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: added))."
    }

    static func thisExerciseTargetDialog(
        snapshot: FitLogIntentBridge.ZirconSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            if let caption = cleanedName(snapshot?.focusedTargetCaption) {
                return "\(focused): \(caption)."
            }
            if snapshot?.focusedIsCardio == true {
                return "\(focused) is cardio."
            }
            return "\(focused) has no target."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return nothingFocusedDialog
    }

    static func prescribedRestDialog(
        snapshot: FitLogIntentBridge.ZirconSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            if snapshot?.focusedIsCardio == true {
                return "\(focused) is cardio."
            }
            if let seconds = snapshot?.focusedPrescribedRestSeconds, seconds > 0 {
                return "Rest \(CardioMetricsCalculator.spokenDuration(seconds: seconds)) on \(focused)."
            }
            return "No rest prescription on \(focused)."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return nothingFocusedDialog
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var targetCaption: String?
        var prescribedRestSeconds: Int?
    }

    private static func restEpoch(_ restEndsAt: Date?, now: Date) -> TimeInterval? {
        guard remainingRestSeconds(restEndsAt: restEndsAt, now: now) != nil else {
            return nil
        }
        return restEndsAt?.timeIntervalSince1970
    }

    private static func cleanedInProgress(_ session: WorkoutSession?) -> WorkoutSession? {
        guard let session, session.endTime == nil else { return nil }
        guard cleanedName(session.workout.name) != nil else { return nil }
        return session
    }

    private static func cleanedName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func focusedExercise(in session: WorkoutSession) -> FocusedExercise? {
        guard let activeId = session.activeExerciseIds.first,
              let log = session.exerciseLogs.first(where: {
                  $0.workoutExercise.exerciseId == activeId
              }),
              let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
        else { return nil }
        let cardio = isCardioRow(log)
        return FocusedExercise(
            exerciseName: name,
            isCardio: cardio,
            targetCaption: targetCaption(in: log, isCardio: cardio),
            prescribedRestSeconds: cardio ? nil : prescribedRestSeconds(in: log)
        )
    }

    private static func isCardioRow(_ log: ExerciseLog) -> Bool {
        log.workoutExercise.effectiveCardioPrescription != nil
            || log.loggedSets.contains(where: \.isCardioEntry)
    }

    private static func targetCaption(in log: ExerciseLog, isCardio: Bool) -> String? {
        if isCardio {
            return cardioTargetCaption(log.workoutExercise.effectiveCardioPrescription)
        }
        let sets = max(1, log.workoutExercise.recommendedSets)
        let setWord = sets == 1 ? "set" : "sets"
        if let reps = cleanedName(log.workoutExercise.recommendedReps) {
            return "\(sets) \(setWord) of \(reps)"
        }
        return "\(sets) \(setWord)"
    }

    private static func cardioTargetCaption(_ prescription: CardioPrescription?) -> String? {
        guard let prescription else { return nil }
        if let seconds = prescription.targetDurationSec, seconds > 0 {
            return CardioMetricsCalculator.spokenDuration(seconds: seconds)
        }
        if let meters = prescription.targetDistanceM, meters > 0 {
            return CardioMetricsCalculator.formatDistance(meters: meters)
        }
        return cleanedName(CardioMetricsCalculator.prescriptionSummary(prescription))
    }

    private static func prescribedRestSeconds(in log: ExerciseLog) -> Int? {
        if let override = log.sessionRestOverrideSeconds, override > 0 {
            return override
        }
        let planDefault = log.workoutExercise.defaultRestTime
        return planDefault > 0 ? planDefault : nil
    }
}

extension FitLogIntentBridge.ZirconSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
