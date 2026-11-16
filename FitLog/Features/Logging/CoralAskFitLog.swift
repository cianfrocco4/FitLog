//
//  CoralAskFitLog.swift
//  FitLog
//
//  Apply the focused exercise's last logged rest to a live rest countdown
//  from Siri / Shortcuts, plus previous-exercise remaining-sets and
//  next-exercise last-rest queries, so a mid-session "use last rest" /
//  "how many sets left on the previous one" / "how long did I rest on
//  the next one" check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing sessions,
//  idle rest timers, open placeholders, and rest days are not turned into
//  a rest start, a skip, a set, or a start. Distinct from RestTimerIntent
//  (starts rest), Amber (double rest / next remaining / this last rest),
//  Jade (halve rest / previous last working / this remaining sets),
//  Zircon (add rest / this-exercise target / prescribed rest),
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

enum CoralAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let nothingFocusedDialog = "Nothing is focused."
    static let noPreviousExerciseDialog = "No previous exercise."
    static let noNextExerciseDialog = "No next exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.CoralSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.CoralSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let previous = previousIncompleteExercise(in: live)
        let next = nextIncompleteExercise(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.CoralSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsCardio: focused?.isCardio ?? false,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedLastRestSeconds: focused?.lastRestSeconds,
            previousExerciseName: previous?.exerciseName,
            previousIsCardio: previous?.isCardio ?? false,
            previousRemainingSetCount: previous?.remainingSetCount ?? 0,
            nextExerciseName: next?.exerciseName,
            nextIsCardio: next?.isCardio ?? false,
            nextLastRestSeconds: next?.lastRestSeconds,
            canUseLastRest: canUseLastRest(
                remaining: remaining,
                lastRestSeconds: focused?.lastRestSeconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseLastRest(
        snapshot: FitLogIntentBridge.CoralSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseLastRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            lastRestSeconds: snapshot?.focusedLastRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func lastRestTargetSeconds(
        snapshot: FitLogIntentBridge.CoralSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.focusedLastRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.CoralSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useLastRestDialog(
        snapshot: FitLogIntentBridge.CoralSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            guard let target = lastRestTargetSeconds(snapshot: snapshot) else {
                return "No rest logged yet on \(focused)."
            }
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return nothingFocusedDialog
    }

    static func previousExerciseRemainingSetsDialog(
        snapshot: FitLogIntentBridge.CoralSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let previous = cleanedName(snapshot?.previousExerciseName) {
            if snapshot?.previousIsCardio == true {
                if (snapshot?.previousRemainingSetCount ?? 0) > 0 {
                    return "\(previous) still needs a duration."
                }
                return "No duration left on \(previous)."
            }
            let left = max(0, snapshot?.previousRemainingSetCount ?? 0)
            if left == 0 {
                return "No sets left on \(previous)."
            }
            if left == 1 {
                return "1 set left on \(previous)."
            }
            return "\(left) sets left on \(previous)."
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName),
           snapshot?.focusedIsIncomplete == true {
            return "Already on \(focused)."
        }
        if snapshot?.isReadyToFinish == true {
            return "No previous exercise. \(workoutName) is ready to finish."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noPreviousExerciseDialog
    }

    static func nextExerciseLastRestDialog(
        snapshot: FitLogIntentBridge.CoralSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let next = cleanedName(snapshot?.nextExerciseName) {
            if let seconds = snapshot?.nextLastRestSeconds, seconds > 0 {
                return "Last rest on \(next) was \(CardioMetricsCalculator.spokenDuration(seconds: seconds))."
            }
            return "No rest logged yet on \(next)."
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

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var isIncomplete: Bool
        var lastRestSeconds: Int?
    }

    private struct NeighborExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var remainingSetCount: Int
        var lastRestSeconds: Int?
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseLastRest(remaining: Int?, lastRestSeconds: Int?) -> Bool {
        guard let remaining, remaining >= minRestSeconds else { return false }
        guard let lastRestSeconds, lastRestSeconds > 0 else { return false }
        return true
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

    private static func previousIncompleteExercise(
        in session: WorkoutSession
    ) -> NeighborExercise? {
        guard let previousIndex = previousIncompleteIndex(in: session) else { return nil }
        return neighbor(at: previousIndex, in: session)
    }

    private static func nextIncompleteExercise(
        in session: WorkoutSession
    ) -> NeighborExercise? {
        guard let nextIndex = nextIncompleteIndex(in: session) else { return nil }
        return neighbor(at: nextIndex, in: session)
    }

    private static func neighbor(
        at index: Int,
        in session: WorkoutSession
    ) -> NeighborExercise? {
        let log = session.exerciseLogs[index]
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        let completed = Set(session.completedExerciseIds)
        return NeighborExercise(
            exerciseName: name,
            isCardio: isCardioRow(log),
            remainingSetCount: remainingSets(in: log, completedExerciseIds: completed),
            lastRestSeconds: lastRestSeconds(in: log)
        )
    }

    /// Next incomplete startable row after the focused exercise, wrapping.
    /// Returns nil when the only leftover is already focused (does not wrap onto self).
    /// When nothing is focused, falls through to the first incomplete.
    private static func nextIncompleteIndex(in session: WorkoutSession) -> Int? {
        let incomplete = incompleteIndices(in: session)
        guard !incomplete.isEmpty else { return nil }
        guard let focusedIndex = focusedIndex(in: session) else { return incomplete.first }
        if let next = incomplete.first(where: { $0 > focusedIndex }) {
            return next
        }
        if let first = incomplete.first, first != focusedIndex {
            return first
        }
        return nil
    }

    /// Previous incomplete startable row before the focused exercise, wrapping.
    /// Returns nil when the only leftover is already focused (does not wrap onto self).
    /// When nothing is focused, falls through to the last incomplete.
    private static func previousIncompleteIndex(in session: WorkoutSession) -> Int? {
        let incomplete = incompleteIndices(in: session)
        guard !incomplete.isEmpty else { return nil }
        guard let focusedIndex = focusedIndex(in: session) else { return incomplete.last }
        if let previous = incomplete.last(where: { $0 < focusedIndex }) {
            return previous
        }
        if let last = incomplete.last, last != focusedIndex {
            return last
        }
        return nil
    }

    private static func incompleteIndices(in session: WorkoutSession) -> [Int] {
        let completed = Set(session.completedExerciseIds)
        let logs = session.exerciseLogs
        return logs.indices.filter {
            isIncomplete(logs[$0], completedExerciseIds: completed)
        }
    }

    private static func focusedIndex(in session: WorkoutSession) -> Int? {
        session.activeExerciseIds.first.flatMap { activeId in
            session.exerciseLogs.firstIndex { $0.workoutExercise.exerciseId == activeId }
        }
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

extension FitLogIntentBridge.CoralSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
