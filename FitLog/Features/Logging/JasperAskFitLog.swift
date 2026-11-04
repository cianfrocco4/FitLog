//
//  JasperAskFitLog.swift
//  FitLog
//
//  Repeat the last working set from Siri / Shortcuts, plus read-only
//  sets-remaining and next-exercise queries, so log → next set does
//  not require opening the sheet or typing weight/reps
//  (`improve.history.quick_log` / `improve.home.last_weight` /
//  `like.history.logged`). Empty / missing sessions and warm-ups-only
//  are not turned into a new set or a start (`like.rest.no_nag`).
//  Distinct from Log Set (requires weight/reps), Lapis (resume /
//  last-session / days-since), Peridot (finish / in-progress /
//  last-finished), the Siri start series (Onyx → Topaz), and 999e
//  (in-app finish-ready banner). Does not change freemium rules.
//

import Foundation

enum JasperAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRepeatableDialog = "Nothing to repeat. Log a working set first."
    static let allSetsLoggedDialog = "All prescribed sets are logged."

    struct RepeatableWorkingSet {
        var exerciseIndex: Int
        var exerciseName: String
        var set: LoggedSet
    }

    static func querySnapshot(
        inProgress: WorkoutSession?,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.JasperSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.JasperSessionSnapshot()
        }
        let remaining = remainingWork(in: live, displayUnit: displayUnit)
        let repeatable = lastRepeatableWorkingSet(in: live)
        return FitLogIntentBridge.JasperSessionSnapshot(
            inProgressWorkoutName: cleanedWorkoutName(live.workout.name),
            lastRepeatableExerciseName: repeatable?.exerciseName,
            lastRepeatableCaption: repeatable.map {
                $0.set.weightRepsDisplaySummary(displayUnit: displayUnit)
            },
            remainingSetCount: remaining.setCount,
            remainingExerciseCount: remaining.exerciseCount,
            nextExerciseName: remaining.nextName,
            nextExerciseRemainingSets: remaining.nextRemaining,
            nextExerciseCaption: remaining.nextCaption
        )
    }

    static func canRepeatLastSet(snapshot: FitLogIntentBridge.JasperSessionSnapshot?) -> Bool {
        cleanedWorkoutName(snapshot?.lastRepeatableExerciseName) != nil
    }

    static func lastRepeatableWorkingSet(in session: WorkoutSession) -> RepeatableWorkingSet? {
        if let activeId = session.activeExerciseIds.first,
           let index = session.exerciseLogs.firstIndex(where: {
               $0.workoutExercise.exerciseId == activeId
           }),
           let match = repeatableWorkingSet(at: index, in: session) {
            return match
        }

        var best: RepeatableWorkingSet?
        for index in session.exerciseLogs.indices {
            guard let match = repeatableWorkingSet(at: index, in: session) else { continue }
            if let currentBest = best, match.set.timestamp <= currentBest.set.timestamp {
                continue
            }
            best = match
        }
        return best
    }

    static func remainingWork(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> (setCount: Int, exerciseCount: Int, nextName: String?, nextRemaining: Int, nextCaption: String?) {
        var setCount = 0
        var exerciseCount = 0
        var firstRemaining: (name: String, remaining: Int, caption: String?)?
        var activeRemaining: (name: String, remaining: Int, caption: String?)?

        for log in session.exerciseLogs {
            guard !log.workoutExercise.isSlotPlaceholder else { continue }
            let remaining = remainingSets(in: log)
            guard remaining > 0, let name = exerciseName(from: log) else { continue }
            setCount += remaining
            exerciseCount += 1
            let row = (name, remaining, exerciseCaption(from: log, displayUnit: displayUnit))
            if firstRemaining == nil {
                firstRemaining = row
            }
            if let activeId = session.activeExerciseIds.first,
               log.workoutExercise.exerciseId == activeId {
                activeRemaining = row
            }
        }

        let next = activeRemaining ?? firstRemaining
        return (
            setCount,
            exerciseCount,
            next?.name,
            next?.remaining ?? 0,
            next?.caption
        )
    }

    static func repeatLastSetDialog(
        snapshot: FitLogIntentBridge.JasperSessionSnapshot?
    ) -> String {
        guard cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let name = cleanedWorkoutName(snapshot?.lastRepeatableExerciseName) else {
            return noRepeatableDialog
        }
        if let caption = cleanedCaption(snapshot?.lastRepeatableCaption) {
            return "Logged \(name) again. \(caption)."
        }
        return "Logged \(name) again."
    }

    static func setsRemainingDialog(
        snapshot: FitLogIntentBridge.JasperSessionSnapshot?
    ) -> String {
        guard cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        let remaining = max(0, snapshot?.remainingSetCount ?? 0)
        let exercises = max(0, snapshot?.remainingExerciseCount ?? 0)
        if remaining == 0 || exercises == 0 {
            return allSetsLoggedDialog
        }
        if exercises == 1, let name = cleanedWorkoutName(snapshot?.nextExerciseName) {
            return "\(setCountPhrase(remaining)) left on \(name)."
        }
        return "\(setCountPhrase(remaining)) left across \(exerciseCountPhrase(exercises))."
    }

    static func nextExerciseDialog(
        snapshot: FitLogIntentBridge.JasperSessionSnapshot?
    ) -> String {
        guard cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let name = cleanedWorkoutName(snapshot?.nextExerciseName),
              (snapshot?.remainingSetCount ?? 0) > 0
        else {
            return allSetsLoggedDialog
        }
        let left = max(0, snapshot?.nextExerciseRemainingSets ?? 0)
        var message = "Next up: \(name)."
        if left > 0 {
            message += " \(setCountPhrase(left)) left."
        }
        if let caption = cleanedCaption(snapshot?.nextExerciseCaption) {
            message += " \(caption)."
        }
        return message
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

    private static func setCountPhrase(_ count: Int) -> String {
        count == 1 ? "1 set" : "\(count) sets"
    }

    private static func exerciseCountPhrase(_ count: Int) -> String {
        count == 1 ? "1 exercise" : "\(count) exercises"
    }

    private static func repeatableWorkingSet(
        at index: Int,
        in session: WorkoutSession
    ) -> RepeatableWorkingSet? {
        guard session.exerciseLogs.indices.contains(index) else { return nil }
        let log = session.exerciseLogs[index]
        guard !log.workoutExercise.isSlotPlaceholder else { return nil }
        guard let name = exerciseName(from: log) else { return nil }
        guard let set = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) else {
            return nil
        }
        return RepeatableWorkingSet(exerciseIndex: index, exerciseName: name, set: set)
    }

    private static func remainingSets(in log: ExerciseLog) -> Int {
        guard !log.workoutExercise.isSlotPlaceholder else { return 0 }
        if isCardioRow(log) {
            return lastCardioDurationSec(in: log) != nil ? 0 : 1
        }
        return max(0, max(1, log.workoutExercise.recommendedSets) - log.workingSetCount)
    }

    private static func isCardioRow(_ log: ExerciseLog) -> Bool {
        log.workoutExercise.effectiveCardioPrescription != nil
            || log.loggedSets.contains(where: \.isCardioEntry)
    }

    private static func exerciseName(from log: ExerciseLog) -> String? {
        if log.workoutExercise.isSlotPlaceholder { return nil }
        return cleanedWorkoutName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
    }

    private static func exerciseCaption(
        from log: ExerciseLog,
        displayUnit: WeightDisplayUnit
    ) -> String? {
        if let working = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) {
            return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
        }
        if let sec = lastCardioDurationSec(in: log) {
            return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
        }
        return nil
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.last(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
