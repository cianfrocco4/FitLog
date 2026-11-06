//
//  AquamarineAskFitLog.swift
//  FitLog
//
//  Reuse last History working weight from Siri / Shortcuts, plus skip
//  rest and rest-remaining queries, so the first working set and rest
//  countdown do not require opening History or the sheet
//  (`improve.home.last_weight` / `like.history.logged` /
//  `like.rest.no_nag`). Empty / missing sessions, cardio-only rows,
//  already-logged working sets, and idle rest timers are not turned
//  into a set, a rest skip, or a start. Distinct from Tourmaline
//  (last cardio duration / last-set / current-exercise), Jasper
//  (repeat this-session working set / remaining / next incomplete),
//  Lapis (resume / last-session / days-since), Peridot (finish /
//  in-progress / last-finished), Citrine (last-load query), the Siri
//  start series (Onyx → Topaz), and 999e (in-app finish-ready
//  banner). Does not change freemium rules.
//

import Foundation

enum AquamarineAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noUnfinishedStrengthDialog = "No unfinished strength set to log."
    static let noPreviousWeightDialog = "No previous working weight to reuse."
    static let noRestTimerDialog = "No rest timer running."

    struct ApplyableLastWeight: Equatable {
        var exerciseIndex: Int
        var exerciseName: String
        var weight: Double
        var reps: Int
        var restTime: Int
        var caption: String
    }

    static func querySnapshot(
        inProgress: WorkoutSession?,
        completedSessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.AquamarineSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.AquamarineSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let unfinished = unfinishedStrengthRow(in: live)
        let applyable = applyableLastWeight(
            in: live,
            completedSessions: completedSessions,
            displayUnit: displayUnit
        )
        return FitLogIntentBridge.AquamarineSessionSnapshot(
            inProgressWorkoutName: cleanedWorkoutName(live.workout.name),
            lastWeightExerciseName: applyable?.exerciseName ?? unfinished?.name,
            lastWeightCaption: applyable?.caption,
            canApplyLastWeight: applyable != nil,
            restEndsAtEpoch: restEpoch(restEndsAt, now: now)
        )
    }

    static func canApplyLastWeight(snapshot: FitLogIntentBridge.AquamarineSessionSnapshot?) -> Bool {
        snapshot?.canApplyLastWeight == true
            && cleanedWorkoutName(snapshot?.lastWeightExerciseName) != nil
    }

    static func canSkipRest(
        snapshot: FitLogIntentBridge.AquamarineSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        remainingRestSeconds(snapshot: snapshot, now: now) != nil
    }

    static func applyableLastWeight(
        in session: WorkoutSession,
        completedSessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> ApplyableLastWeight? {
        guard let row = unfinishedStrengthRow(in: session) else { return nil }
        guard let last = lastHistoryWorkingSet(
            exerciseId: row.exerciseId,
            excludingSessionId: session.id,
            completedSessions: completedSessions
        ) else { return nil }
        return ApplyableLastWeight(
            exerciseIndex: row.index,
            exerciseName: row.name,
            weight: last.weight,
            reps: last.reps,
            restTime: row.restTime,
            caption: last.weightRepsDisplaySummary(displayUnit: displayUnit)
        )
    }

    static func useLastWeightDialog(
        snapshot: FitLogIntentBridge.AquamarineSessionSnapshot?
    ) -> String {
        guard cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let name = cleanedWorkoutName(snapshot?.lastWeightExerciseName) else {
            return noUnfinishedStrengthDialog
        }
        guard snapshot?.canApplyLastWeight == true else {
            return noPreviousWeightDialog
        }
        if let caption = cleanedCaption(snapshot?.lastWeightCaption) {
            return "Logged \(name). Last \(caption)."
        }
        return "Logged \(name)."
    }

    static func skipRestDialog(
        snapshot: FitLogIntentBridge.AquamarineSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now) else {
            return noRestTimerDialog
        }
        return "Skipping rest. \(CardioMetricsCalculator.spokenDuration(seconds: remaining)) remaining."
    }

    static func restRemainingDialog(
        snapshot: FitLogIntentBridge.AquamarineSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now) else {
            return noRestTimerDialog
        }
        return "Rest remaining: \(CardioMetricsCalculator.spokenDuration(seconds: remaining))."
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.AquamarineSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    // MARK: - Private

    private static func restEpoch(_ restEndsAt: Date?, now: Date) -> TimeInterval? {
        guard remainingRestSeconds(restEndsAt: restEndsAt, now: now) != nil else {
            return nil
        }
        return restEndsAt?.timeIntervalSince1970
    }

    private static func cleanedInProgress(_ session: WorkoutSession?) -> WorkoutSession? {
        guard let session, session.endTime == nil else { return nil }
        guard cleanedWorkoutName(session.workout.name) != nil else { return nil }
        return session
    }

    private static func cleanedWorkoutName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cleanedCaption(_ caption: String?) -> String? {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func unfinishedStrengthRow(
        in session: WorkoutSession
    ) -> (index: Int, exerciseId: UUID, name: String, restTime: Int)? {
        if let activeId = session.activeExerciseIds.first,
           let match = strengthRow(matching: activeId, in: session),
           !hasWorkingSet(session.exerciseLogs[match.index]) {
            return match
        }

        for index in session.exerciseLogs.indices {
            guard let match = strengthRow(at: index, in: session) else { continue }
            guard !hasWorkingSet(session.exerciseLogs[index]) else { continue }
            return match
        }
        return nil
    }

    private static func strengthRow(
        matching exerciseId: UUID,
        in session: WorkoutSession
    ) -> (index: Int, exerciseId: UUID, name: String, restTime: Int)? {
        guard let index = session.exerciseLogs.firstIndex(where: {
            $0.workoutExercise.exerciseId == exerciseId
        }) else { return nil }
        return strengthRow(at: index, in: session)
    }

    private static func strengthRow(
        at index: Int,
        in session: WorkoutSession
    ) -> (index: Int, exerciseId: UUID, name: String, restTime: Int)? {
        guard session.exerciseLogs.indices.contains(index) else { return nil }
        let log = session.exerciseLogs[index]
        guard !isCardioRow(log) else { return nil }
        guard !log.workoutExercise.isSlotPlaceholder else { return nil }
        guard let exerciseId = log.workoutExercise.exerciseId else { return nil }
        guard let name = exerciseName(from: log) else { return nil }
        let restTime = max(0, log.workoutExercise.defaultRestTime)
        return (index, exerciseId, name, restTime)
    }

    private static func lastHistoryWorkingSet(
        exerciseId: UUID,
        excludingSessionId: UUID,
        completedSessions: [WorkoutSession]
    ) -> LoggedSet? {
        let history = completedSessions
            .filter { $0.isCompleted && $0.id != excludingSessionId }
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
        for past in history {
            for log in past.exerciseLogs {
                let logId = log.workoutExercise.exerciseId
                    ?? log.workoutExercise.snapshot?.exerciseId
                guard logId == exerciseId else { continue }
                if let working = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) {
                    return working
                }
            }
        }
        return nil
    }

    private static func hasWorkingSet(_ log: ExerciseLog) -> Bool {
        log.loggedSets.contains(where: \.countsTowardLoadPRMetrics)
    }

    private static func isCardioRow(_ log: ExerciseLog) -> Bool {
        log.workoutExercise.effectiveCardioPrescription != nil
            || log.loggedSets.contains(where: \.isCardioEntry)
    }

    private static func exerciseName(from log: ExerciseLog) -> String? {
        if log.workoutExercise.isSlotPlaceholder { return nil }
        return cleanedWorkoutName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
    }
}
