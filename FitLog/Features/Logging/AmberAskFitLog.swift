//
//  AmberAskFitLog.swift
//  FitLog
//
//  Double a live rest countdown from Siri / Shortcuts, plus next-exercise
//  remaining-sets and this-exercise last-rest queries, so a mid-session
//  "double rest" / "how many sets left on the next one" / "how long did
//  I just rest on this" check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing sessions,
//  idle rest timers, open placeholders, and rest days are not turned into
//  a rest start, a skip, a set, or a start. Distinct from RestTimerIntent
//  (starts rest), Jade (halve rest / previous last working / this remaining
//  sets), Zircon (add rest / this-exercise target / prescribed rest),
//  Obsidian (subtract 30s / next-exercise target / next last working),
//  Fluorite (reset rest / previous-exercise target / this last working),
//  Aquamarine (skip rest / rest remaining), Spinel (go to previous /
//  previous name / this-exercise sets), Jasper (repeat / session remaining
//  / next incomplete), Moonstone (skip remaining / next set /
//  ready-to-finish), Tanzanite (undo / sets logged / elapsed), Tourmaline
//  (last cardio / last-set / current-exercise), Citrine (last-load query),
//  the Siri start series (Onyx → Topaz), and 999e (in-app finish-ready
//  banner). Does not change freemium rules.
//

import Foundation

enum AmberAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let restAlreadyMaximumDialog = "Rest already at 10 minutes."
    static let nothingFocusedDialog = "Nothing is focused."
    static let noNextExerciseDialog = "No next exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.AmberSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.AmberSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let next = nextIncompleteExercise(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.AmberSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsCardio: focused?.isCardio ?? false,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedLastRestSeconds: focused?.lastRestSeconds,
            nextExerciseName: next?.exerciseName,
            nextIsCardio: next?.isCardio ?? false,
            nextRemainingSetCount: next?.remainingSetCount ?? 0,
            canDoubleRest: canDouble(remaining: remaining),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canDoubleRest(
        snapshot: FitLogIntentBridge.AmberSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canDouble(remaining: remainingRestSeconds(snapshot: snapshot, now: now))
            && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func doubledRestSeconds(
        snapshot: FitLogIntentBridge.AmberSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now),
              canDouble(remaining: remaining)
        else { return nil }
        return min(maxRestSeconds, max(minRestSeconds, remaining * 2))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.AmberSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func doubleRestDialog(
        snapshot: FitLogIntentBridge.AmberSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now) else {
            return noRestTimerDialog
        }
        guard let doubled = doubledRestSeconds(snapshot: snapshot, now: now) else {
            return remaining >= maxRestSeconds ? restAlreadyMaximumDialog : noRestTimerDialog
        }
        return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: doubled))."
    }

    static func nextExerciseRemainingSetsDialog(
        snapshot: FitLogIntentBridge.AmberSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let next = cleanedName(snapshot?.nextExerciseName) {
            if snapshot?.nextIsCardio == true {
                if (snapshot?.nextRemainingSetCount ?? 0) > 0 {
                    return "\(next) still needs a duration."
                }
                return "No duration left on \(next)."
            }
            let left = max(0, snapshot?.nextRemainingSetCount ?? 0)
            if left == 0 {
                return "No sets left on \(next)."
            }
            if left == 1 {
                return "1 set left on \(next)."
            }
            return "\(left) sets left on \(next)."
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName),
           snapshot?.focusedIsIncomplete == true {
            return "Already on \(focused)."
        }
        if snapshot?.isReadyToFinish == true {
            return "No next exercise. \(workoutName) is ready to finish."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noNextExerciseDialog
    }

    static func thisExerciseLastRestDialog(
        snapshot: FitLogIntentBridge.AmberSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            if let seconds = snapshot?.focusedLastRestSeconds, seconds > 0 {
                return "Last rest on \(focused) was \(CardioMetricsCalculator.spokenDuration(seconds: seconds))."
            }
            return "No rest logged yet on \(focused)."
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
        var isIncomplete: Bool
        var lastRestSeconds: Int?
    }

    private struct NextExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var remainingSetCount: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canDouble(remaining: Int?) -> Bool {
        guard let remaining else { return false }
        return remaining >= minRestSeconds && remaining < maxRestSeconds
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

    private static func focusedExercise(
        in session: WorkoutSession
    ) -> FocusedExercise? {
        guard let activeId = session.activeExerciseIds.first,
              let log = session.exerciseLogs.first(where: {
                  $0.workoutExercise.exerciseId == activeId
              }),
              let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
        else { return nil }
        let completed = Set(session.completedExerciseIds)
        return FocusedExercise(
            exerciseName: name,
            isCardio: isCardioRow(log),
            isIncomplete: isIncomplete(log, completedExerciseIds: completed),
            lastRestSeconds: lastRestSeconds(in: log)
        )
    }

    private static func nextIncompleteExercise(
        in session: WorkoutSession
    ) -> NextExercise? {
        guard let nextIndex = nextIncompleteIndex(in: session) else { return nil }
        let log = session.exerciseLogs[nextIndex]
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        let completed = Set(session.completedExerciseIds)
        return NextExercise(
            exerciseName: name,
            isCardio: isCardioRow(log),
            remainingSetCount: remainingSets(in: log, completedExerciseIds: completed)
        )
    }

    /// Next incomplete startable row after the focused exercise, wrapping.
    /// Returns nil when the only leftover is already focused (does not wrap onto self).
    /// When nothing is focused, falls through to the first incomplete.
    private static func nextIncompleteIndex(in session: WorkoutSession) -> Int? {
        let completed = Set(session.completedExerciseIds)
        let logs = session.exerciseLogs
        let incomplete = logs.indices.filter {
            isIncomplete(logs[$0], completedExerciseIds: completed)
        }
        guard !incomplete.isEmpty else { return nil }
        let focusedIndex = session.activeExerciseIds.first.flatMap { activeId in
            logs.firstIndex { $0.workoutExercise.exerciseId == activeId }
        }
        guard let focusedIndex else { return incomplete.first }
        if let next = incomplete.first(where: { $0 > focusedIndex }) {
            return next
        }
        if let first = incomplete.first, first != focusedIndex {
            return first
        }
        return nil
    }

    private static func finishReadiness(in session: WorkoutSession) -> FinishReadiness {
        let logs = session.exerciseLogs
        let hasOpenPlaceholder = logs.contains { $0.workoutExercise.isSlotPlaceholder }
        let completed = Set(session.completedExerciseIds)
        let incompleteCount = logs.filter { isIncomplete($0, completedExerciseIds: completed) }.count
        let hasStartable = logs.contains { !$0.workoutExercise.isSlotPlaceholder }
        let isReady = hasStartable && !hasOpenPlaceholder && incompleteCount == 0
        return FinishReadiness(
            hasOpenPlaceholder: hasOpenPlaceholder,
            isReady: isReady
        )
    }

    private static func isIncomplete(_ log: ExerciseLog, completedExerciseIds: Set<UUID>) -> Bool {
        !isRowReady(log, completedExerciseIds: completedExerciseIds)
    }

    /// Matches 999e finish-ready row rules without sharing `WorkoutFinishReadyPolicy`.
    private static func isRowReady(_ log: ExerciseLog, completedExerciseIds: Set<UUID>) -> Bool {
        if log.workoutExercise.isSlotPlaceholder { return false }
        guard cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) != nil else { return false }
        if let id = log.workoutExercise.exerciseId, completedExerciseIds.contains(id) {
            return true
        }
        if log.meetsRecommendedSets { return true }
        return hasCompletedCardioWork(log)
    }

    private static func remainingSets(in log: ExerciseLog, completedExerciseIds: Set<UUID>) -> Int {
        guard !log.workoutExercise.isSlotPlaceholder else { return 0 }
        if isRowReady(log, completedExerciseIds: completedExerciseIds) { return 0 }
        if isCardioRow(log) {
            return hasCompletedCardioWork(log) ? 0 : 1
        }
        return max(0, max(1, log.workoutExercise.recommendedSets) - log.workingSetCount)
    }

    private static func hasCompletedCardioWork(_ log: ExerciseLog) -> Bool {
        log.loggedSets.contains { set in
            set.countsTowardCardioTotals && (set.cardioMetrics?.durationSec ?? 0) > 0
        }
    }

    private static func isCardioRow(_ log: ExerciseLog) -> Bool {
        log.workoutExercise.effectiveCardioPrescription != nil
            || log.loggedSets.contains(where: \.isCardioEntry)
    }

    /// Most recently logged rest duration on this row (`restTime > 0`).
    /// Warm-ups count; zero-second cardio entries do not invent a rest.
    private static func lastRestSeconds(in log: ExerciseLog) -> Int? {
        for set in log.loggedSets.reversed() where set.restTime > 0 {
            return set.restTime
        }
        return nil
    }
}

extension FitLogIntentBridge.AmberSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
