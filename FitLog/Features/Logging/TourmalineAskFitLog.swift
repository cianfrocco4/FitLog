//
//  TourmalineAskFitLog.swift
//  FitLog
//
//  Reuse last cardio duration from Siri / Shortcuts, plus read-only
//  last-set and current-exercise queries, so cardio minutes and the
//  in-session last-load loop do not require opening History or the
//  sheet (`improve.cardio.home_duration` / `improve.home.last_weight`
//  / `like.history.logged`). Empty / missing sessions, already-logged
//  cardio, and strength-only rows are not turned into a duration or a
//  start (`like.rest.no_nag`). Distinct from Jasper (repeat working
//  set / remaining / next incomplete), Lapis (resume / last-session /
//  days-since), Peridot (finish / in-progress / last-finished), the
//  Siri start series (Onyx → Topaz), and 999e (in-app finish-ready
//  banner). Does not change freemium rules.
//

import Foundation

enum TourmalineAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noLastSetDialog = "Nothing logged yet."
    static let noCurrentExerciseDialog = "No current exercise."
    static let noUnfinishedCardioDialog = "No unfinished cardio to log."
    static let noPreviousCardioDialog = "No previous cardio duration to reuse."

    struct ApplyableLastCardio {
        var exerciseIndex: Int
        var exerciseName: String
        var durationSec: Int
    }

    struct SpokenSet {
        var exerciseName: String
        var caption: String
        var timestamp: Date
    }

    static func querySnapshot(
        inProgress: WorkoutSession?,
        completedSessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.TourmalineSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.TourmalineSessionSnapshot()
        }
        let lastSet = lastSpokenSet(in: live, displayUnit: displayUnit)
        let current = currentExercise(in: live, completedSessions: completedSessions, displayUnit: displayUnit)
        let unfinished = unfinishedCardioRow(in: live)
        let applyable = applyableLastCardio(in: live, completedSessions: completedSessions)
        return FitLogIntentBridge.TourmalineSessionSnapshot(
            inProgressWorkoutName: cleanedWorkoutName(live.workout.name),
            lastSetExerciseName: lastSet?.exerciseName,
            lastSetCaption: lastSet?.caption,
            currentExerciseName: current?.name,
            currentExerciseCaption: current?.caption,
            lastCardioExerciseName: applyable?.exerciseName ?? unfinished?.name,
            lastCardioCaption: applyable.map {
                CardioMetricsCalculator.formatDuration(seconds: $0.durationSec)
            },
            canApplyLastCardio: applyable != nil
        )
    }

    static func canApplyLastCardio(snapshot: FitLogIntentBridge.TourmalineSessionSnapshot?) -> Bool {
        snapshot?.canApplyLastCardio == true
            && cleanedWorkoutName(snapshot?.lastCardioExerciseName) != nil
    }

    static func applyableLastCardio(
        in session: WorkoutSession,
        completedSessions: [WorkoutSession]
    ) -> ApplyableLastCardio? {
        guard let row = unfinishedCardioRow(in: session) else { return nil }
        guard let durationSec = lastHistoryCardioDurationSec(
            exerciseId: row.exerciseId,
            excludingSessionId: session.id,
            completedSessions: completedSessions
        ) else { return nil }
        return ApplyableLastCardio(
            exerciseIndex: row.index,
            exerciseName: row.name,
            durationSec: durationSec
        )
    }

    static func useLastCardioDialog(
        snapshot: FitLogIntentBridge.TourmalineSessionSnapshot?
    ) -> String {
        guard cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let name = cleanedWorkoutName(snapshot?.lastCardioExerciseName) else {
            return noUnfinishedCardioDialog
        }
        guard snapshot?.canApplyLastCardio == true else {
            return noPreviousCardioDialog
        }
        if let caption = cleanedCaption(snapshot?.lastCardioCaption) {
            return "Logged \(name). Last \(caption)."
        }
        return "Logged \(name)."
    }

    static func lastSetDialog(
        snapshot: FitLogIntentBridge.TourmalineSessionSnapshot?
    ) -> String {
        guard cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let name = cleanedWorkoutName(snapshot?.lastSetExerciseName) else {
            return noLastSetDialog
        }
        if let caption = cleanedCaption(snapshot?.lastSetCaption) {
            return "Last set: \(name). \(caption)."
        }
        return "Last set: \(name)."
    }

    static func currentExerciseDialog(
        snapshot: FitLogIntentBridge.TourmalineSessionSnapshot?
    ) -> String {
        guard cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let name = cleanedWorkoutName(snapshot?.currentExerciseName) else {
            return noCurrentExerciseDialog
        }
        if let caption = cleanedCaption(snapshot?.currentExerciseCaption) {
            return "Current exercise: \(name). \(caption)."
        }
        return "Current exercise: \(name)."
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    // MARK: - Private

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

    private static func unfinishedCardioRow(
        in session: WorkoutSession
    ) -> (index: Int, exerciseId: UUID, name: String)? {
        if let activeId = session.activeExerciseIds.first,
           let match = cardioRow(matching: activeId, in: session),
           lastCardioDurationSec(in: session.exerciseLogs[match.index]) == nil {
            return match
        }

        for index in session.exerciseLogs.indices {
            guard let match = cardioRow(at: index, in: session) else { continue }
            guard lastCardioDurationSec(in: session.exerciseLogs[index]) == nil else { continue }
            return match
        }
        return nil
    }

    private static func cardioRow(
        matching exerciseId: UUID,
        in session: WorkoutSession
    ) -> (index: Int, exerciseId: UUID, name: String)? {
        guard let index = session.exerciseLogs.firstIndex(where: {
            $0.workoutExercise.exerciseId == exerciseId
        }) else { return nil }
        return cardioRow(at: index, in: session)
    }

    private static func cardioRow(
        at index: Int,
        in session: WorkoutSession
    ) -> (index: Int, exerciseId: UUID, name: String)? {
        guard session.exerciseLogs.indices.contains(index) else { return nil }
        let log = session.exerciseLogs[index]
        guard isCardioRow(log) else { return nil }
        guard !log.workoutExercise.isSlotPlaceholder else { return nil }
        guard let exerciseId = log.workoutExercise.exerciseId else { return nil }
        guard let name = exerciseName(from: log) else { return nil }
        return (index, exerciseId, name)
    }

    private static func lastHistoryCardioDurationSec(
        exerciseId: UUID,
        excludingSessionId: UUID,
        completedSessions: [WorkoutSession]
    ) -> Int? {
        let history = completedSessions
            .filter { $0.isCompleted && $0.id != excludingSessionId }
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
        for past in history {
            for log in past.exerciseLogs {
                let logId = log.workoutExercise.exerciseId
                    ?? log.workoutExercise.snapshot?.exerciseId
                guard logId == exerciseId else { continue }
                if let sec = lastCardioDurationSec(in: log) {
                    return sec
                }
            }
        }
        return nil
    }

    private static func lastSpokenSet(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> SpokenSet? {
        if let activeId = session.activeExerciseIds.first,
           let index = session.exerciseLogs.firstIndex(where: {
               $0.workoutExercise.exerciseId == activeId
           }),
           let match = spokenSet(from: session.exerciseLogs[index], displayUnit: displayUnit) {
            return match
        }

        var best: SpokenSet?
        for log in session.exerciseLogs {
            guard let match = spokenSet(from: log, displayUnit: displayUnit) else { continue }
            if let currentBest = best, match.timestamp <= currentBest.timestamp {
                continue
            }
            best = match
        }
        return best
    }

    private static func spokenSet(
        from log: ExerciseLog,
        displayUnit: WeightDisplayUnit
    ) -> SpokenSet? {
        guard let name = exerciseName(from: log) else { return nil }
        if let working = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) {
            return SpokenSet(
                exerciseName: name,
                caption: working.weightRepsDisplaySummary(displayUnit: displayUnit),
                timestamp: working.timestamp
            )
        }
        if let cardio = log.loggedSets.last(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        }), let sec = cardio.cardioMetrics?.durationSec {
            return SpokenSet(
                exerciseName: name,
                caption: CardioMetricsCalculator.formatDuration(seconds: sec),
                timestamp: cardio.timestamp
            )
        }
        return nil
    }

    private static func currentExercise(
        in session: WorkoutSession,
        completedSessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> (name: String, caption: String?)? {
        if let activeId = session.activeExerciseIds.first,
           let log = session.exerciseLogs.first(where: {
               $0.workoutExercise.exerciseId == activeId
           }),
           let name = exerciseName(from: log) {
            return (
                name,
                exerciseCaption(
                    from: log,
                    completedSessions: completedSessions,
                    excludingSessionId: session.id,
                    displayUnit: displayUnit
                )
            )
        }

        for log in session.exerciseLogs {
            guard let name = exerciseName(from: log) else { continue }
            return (
                name,
                exerciseCaption(
                    from: log,
                    completedSessions: completedSessions,
                    excludingSessionId: session.id,
                    displayUnit: displayUnit
                )
            )
        }
        return nil
    }

    private static func exerciseCaption(
        from log: ExerciseLog,
        completedSessions: [WorkoutSession],
        excludingSessionId: UUID,
        displayUnit: WeightDisplayUnit
    ) -> String? {
        if let working = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) {
            return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
        }
        if let sec = lastCardioDurationSec(in: log) {
            return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
        }
        if isCardioRow(log),
           let exerciseId = log.workoutExercise.exerciseId,
           let sec = lastHistoryCardioDurationSec(
               exerciseId: exerciseId,
               excludingSessionId: excludingSessionId,
               completedSessions: completedSessions
           ) {
            return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
        }
        return nil
    }

    private static func isCardioRow(_ log: ExerciseLog) -> Bool {
        log.workoutExercise.effectiveCardioPrescription != nil
            || log.loggedSets.contains(where: \.isCardioEntry)
    }

    private static func exerciseName(from log: ExerciseLog) -> String? {
        if log.workoutExercise.isSlotPlaceholder { return nil }
        return cleanedWorkoutName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.last(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
