//
//  LarimarAskFitLog.swift
//  FitLog
//
//  Apply the next incomplete exercise's last logged rest to a live rest
//  countdown from Siri / Shortcuts, plus previous-exercise prescribed-rest
//  and this-workout last-rest queries, so a mid-session "use the rest I
//  took on the next one" / "how long should I rest on the previous one"
//  / "how long did I last rest this workout" check does not require
//  hunting through the sheet (`like.history.logged` / `like.rest.no_nag`).
//  Empty / missing sessions, idle rest timers, open placeholders, and
//  rest days are not turned into a rest start, a skip, a set, or a
//  start. Distinct from RestTimerIntent (starts rest), Turquoise (use
//  previous last rest / previous last rest / next prescribed rest),
//  Coral (use focused last rest / previous remaining / next last rest),
//  Amber (double rest / next remaining / this last rest), Jade (halve
//  rest / previous last working / this remaining sets), Zircon (add
//  rest / this-exercise target / prescribed rest on the focused row),
//  Obsidian (subtract 30s / next-exercise target / next last working),
//  Fluorite (reset rest / previous-exercise target / this last working),
//  Aquamarine (skip rest / rest remaining), Spinel (go to previous /
//  previous name / this-exercise sets), Jasper (repeat / session
//  remaining / next incomplete), Moonstone (skip remaining / next set /
//  ready-to-finish), Tanzanite (undo / sets logged / elapsed),
//  Tourmaline (last cardio / last-set / current-exercise), Citrine
//  (last-load query), the Siri start series (Onyx → Topaz), and 999e
//  (in-app finish-ready banner). Does not change freemium rules.
//

import Foundation

enum LarimarAskFitLog {
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
    ) -> FitLogIntentBridge.LarimarSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.LarimarSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let previous = previousIncompleteExercise(in: live)
        let next = nextIncompleteExercise(in: live)
        let sessionLast = sessionLastRest(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.LarimarSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsCardio: focused?.isCardio ?? false,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            previousExerciseName: previous?.exerciseName,
            previousIsCardio: previous?.isCardio ?? false,
            previousPrescribedRestSeconds: previous?.prescribedRestSeconds,
            nextExerciseName: next?.exerciseName,
            nextIsCardio: next?.isCardio ?? false,
            nextLastRestSeconds: next?.lastRestSeconds,
            sessionLastRestSeconds: sessionLast?.seconds,
            sessionLastRestExerciseName: sessionLast?.exerciseName,
            canUseNextLastRest: canUseNextLastRest(
                remaining: remaining,
                lastRestSeconds: next?.lastRestSeconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseNextLastRest(
        snapshot: FitLogIntentBridge.LarimarSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseNextLastRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            lastRestSeconds: snapshot?.nextLastRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func nextLastRestTargetSeconds(
        snapshot: FitLogIntentBridge.LarimarSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.nextLastRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.LarimarSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useNextLastRestDialog(
        snapshot: FitLogIntentBridge.LarimarSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let next = cleanedName(snapshot?.nextExerciseName) {
            guard let target = nextLastRestTargetSeconds(snapshot: snapshot) else {
                return "No rest logged yet on \(next)."
            }
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
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
        return nothingFocusedDialog
    }

    static func previousExercisePrescribedRestDialog(
        snapshot: FitLogIntentBridge.LarimarSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let previous = cleanedName(snapshot?.previousExerciseName) {
            if snapshot?.previousIsCardio == true {
                return "\(previous) is cardio."
            }
            if let seconds = snapshot?.previousPrescribedRestSeconds, seconds > 0 {
                return "Rest \(CardioMetricsCalculator.spokenDuration(seconds: seconds)) on \(previous)."
            }
            return "No rest prescription on \(previous)."
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

    static func thisWorkoutLastRestDialog(
        snapshot: FitLogIntentBridge.LarimarSessionSnapshot?
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        if let seconds = snapshot?.sessionLastRestSeconds, seconds > 0,
           let name = cleanedName(snapshot?.sessionLastRestExerciseName) {
            return "Last rest this workout was \(CardioMetricsCalculator.spokenDuration(seconds: seconds)) on \(name)."
        }
        return "No rest logged yet this workout."
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var isIncomplete: Bool
    }

    private struct NeighborExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var lastRestSeconds: Int?
        var prescribedRestSeconds: Int?
    }

    private struct SessionLastRest: Equatable {
        var exerciseName: String
        var seconds: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseNextLastRest(remaining: Int?, lastRestSeconds: Int?) -> Bool {
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
            isIncomplete: isIncomplete(log, completedExerciseIds: completed)
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
        let cardio = isCardioRow(log)
        return NeighborExercise(
            exerciseName: name,
            isCardio: cardio,
            lastRestSeconds: lastRestSeconds(in: log),
            prescribedRestSeconds: cardio ? nil : prescribedRestSeconds(in: log)
        )
    }

    /// Most recently logged rest (`restTime > 0`) anywhere in the session,
    /// including completed rows. Warm-ups count; placeholders and nameless
    /// rows are skipped. Latest `timestamp` wins; ties go to later row then
    /// later set. Distinct from Coral/Amber/Turquoise row-neighbor last rest.
    private static func sessionLastRest(in session: WorkoutSession) -> SessionLastRest? {
        var best: (timestamp: Date, logIndex: Int, setIndex: Int, name: String, seconds: Int)?
        for (logIndex, log) in session.exerciseLogs.enumerated() {
            if log.workoutExercise.isSlotPlaceholder { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            for (setIndex, set) in log.loggedSets.enumerated() where set.restTime > 0 {
                let candidate = (set.timestamp, logIndex, setIndex, name, set.restTime)
                if let current = best {
                    if candidate.0 > current.timestamp
                        || (candidate.0 == current.timestamp && candidate.1 > current.logIndex)
                        || (candidate.0 == current.timestamp
                            && candidate.1 == current.logIndex
                            && candidate.2 > current.setIndex) {
                        best = (
                            timestamp: candidate.0,
                            logIndex: candidate.1,
                            setIndex: candidate.2,
                            name: candidate.3,
                            seconds: candidate.4
                        )
                    }
                } else {
                    best = (
                        timestamp: candidate.0,
                        logIndex: candidate.1,
                        setIndex: candidate.2,
                        name: candidate.3,
                        seconds: candidate.4
                    )
                }
            }
        }
        guard let best else { return nil }
        return SessionLastRest(exerciseName: best.name, seconds: best.seconds)
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

extension FitLogIntentBridge.LarimarSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
