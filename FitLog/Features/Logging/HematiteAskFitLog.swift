//
//  HematiteAskFitLog.swift
//  FitLog
//
//  Apply the previous incomplete exercise's prescribed rest to a live
//  rest countdown from Siri / Shortcuts, plus this-exercise last-rest
//  and this-workout exercises-completed queries, so a mid-session
//  "use the rest the previous one calls for" / "how long did I last
//  rest on this one" / "how many exercises am I done with" check does
//  not require hunting through the sheet (`like.history.logged` /
//  `like.rest.no_nag`). Empty / missing sessions, idle rest timers,
//  open placeholders, and rest days are not turned into a rest start,
//  a skip, a set, or a start. Distinct from RestTimerIntent (starts
//  rest), Sunstone (use this-workout last rest / remaining sets /
//  last working), Larimar (use next last rest / previous prescribed
//  rest query / this-workout last rest), Turquoise (use previous last
//  rest / previous last rest / next prescribed rest), Coral (use
//  focused last rest / previous remaining / next last rest), Amber
//  (double rest / next remaining / this last rest), Jade (halve rest
//  / previous last working / this remaining sets), Zircon (add rest /
//  this-exercise target / prescribed rest on the focused row),
//  Obsidian (subtract 30s / next-exercise target / next last
//  working), Fluorite (reset rest to focused prescribed / previous
//  target / this last working), Aquamarine (skip rest / rest
//  remaining), Spinel (go to previous / previous name /
//  this-exercise sets), Jasper (repeat / session remaining / next
//  incomplete), Moonstone (skip remaining / next set /
//  ready-to-finish), Tanzanite (undo / sets logged / elapsed),
//  Tourmaline (last cardio / last-set / current-exercise),
//  Alexandrite (remaining exercises row count), Citrine (last-load
//  query), the Siri start series (Onyx → Topaz), and 999e (in-app
//  finish-ready banner). Does not change freemium rules.
//

import Foundation

enum HematiteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let nothingFocusedDialog = "Nothing is focused."
    static let noPreviousExerciseDialog = "No previous exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.HematiteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.HematiteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let previous = previousIncompleteExercise(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.HematiteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedLastRestSeconds: focused?.lastRestSeconds,
            previousExerciseName: previous?.exerciseName,
            previousIsCardio: previous?.isCardio ?? false,
            previousPrescribedRestSeconds: previous?.prescribedRestSeconds,
            completedExerciseCount: finish.completedCount,
            canUsePreviousPrescribedRest: canUsePreviousPrescribedRest(
                remaining: remaining,
                prescribedSeconds: previous?.prescribedRestSeconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUsePreviousPrescribedRest(
        snapshot: FitLogIntentBridge.HematiteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUsePreviousPrescribedRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            prescribedSeconds: snapshot?.previousPrescribedRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func previousPrescribedRestTargetSeconds(
        snapshot: FitLogIntentBridge.HematiteSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.previousPrescribedRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.HematiteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func usePreviousPrescribedRestDialog(
        snapshot: FitLogIntentBridge.HematiteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let previous = cleanedName(snapshot?.previousExerciseName) {
            if snapshot?.previousIsCardio == true {
                return "\(previous) is cardio."
            }
            guard let target = previousPrescribedRestTargetSeconds(snapshot: snapshot) else {
                return "No rest prescription on \(previous)."
            }
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
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

    static func thisExerciseLastRestDialog(
        snapshot: FitLogIntentBridge.HematiteSessionSnapshot?
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let focused = cleanedName(snapshot?.focusedExerciseName) else {
            if snapshot?.hasOpenPlaceholder == true,
               let workoutName = cleanedName(snapshot?.inProgressWorkoutName) {
                return "\(workoutName) still has an open slot."
            }
            return nothingFocusedDialog
        }
        if let seconds = snapshot?.focusedLastRestSeconds, seconds > 0 {
            return "Last rest on \(focused) was \(CardioMetricsCalculator.spokenDuration(seconds: seconds))."
        }
        return "No rest logged yet on \(focused)."
    }

    static func thisWorkoutExercisesCompletedDialog(
        snapshot: FitLogIntentBridge.HematiteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let done = max(0, snapshot?.completedExerciseCount ?? 0)
        if snapshot?.isReadyToFinish == true {
            return "All exercises done this workout."
        }
        if done > 0 {
            if done == 1 {
                return "1 exercise done this workout."
            }
            return "\(done) exercises done this workout."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "No exercises done this workout."
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isIncomplete: Bool
        var lastRestSeconds: Int?
    }

    private struct NeighborExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var prescribedRestSeconds: Int?
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
        var completedCount: Int
    }

    private static func canUsePreviousPrescribedRest(
        remaining: Int?,
        prescribedSeconds: Int?
    ) -> Bool {
        guard let remaining, remaining >= minRestSeconds else { return false }
        guard let prescribedSeconds, prescribedSeconds > 0 else { return false }
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

    private static func neighbor(
        at index: Int,
        in session: WorkoutSession
    ) -> NeighborExercise? {
        let log = session.exerciseLogs[index]
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        let cardio = isCardioRow(log)
        return NeighborExercise(
            exerciseName: name,
            isCardio: cardio,
            prescribedRestSeconds: cardio ? nil : prescribedRestSeconds(in: log)
        )
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
        let completedCount = logs.filter { isRowReady($0, completedExerciseIds: completed) }.count
        let incompleteCount = logs.filter { isIncomplete($0, completedExerciseIds: completed) }.count
        let hasStartable = logs.contains { !$0.workoutExercise.isSlotPlaceholder }
        let isReady = hasStartable && !hasOpenPlaceholder && incompleteCount == 0
        return FinishReadiness(
            hasOpenPlaceholder: hasOpenPlaceholder,
            isReady: isReady,
            completedCount: completedCount
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

    /// Session rest override wins over the library default. Cardio rows skip this.
    private static func prescribedRestSeconds(in log: ExerciseLog) -> Int? {
        if let override = log.sessionRestOverrideSeconds, override > 0 {
            return override
        }
        let planDefault = log.workoutExercise.defaultRestTime
        return planDefault > 0 ? planDefault : nil
    }
}

extension FitLogIntentBridge.HematiteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
