//
//  IoliteAskFitLog.swift
//  FitLog
//
//  Apply this workout's most recently logged *working-set* rest to a
//  live rest countdown from Siri / Shortcuts, plus this-workout
//  last-working-rest and last-completed-strength-exercise queries,
//  so a mid-session "use the rest I last took between working sets"
//  / "how long was last working rest" / "which strength exercise
//  did I just finish" check does not require hunting through the
//  sheet (`like.history.logged` / `like.rest.no_nag`). Empty /
//  missing sessions, idle rest timers, open placeholders, and rest
//  days are not turned into a rest start, a skip, a set, or a
//  start. Distinct from RestTimerIntent (starts rest), Azurite
//  (use last finished strength *prescribed* rest / last cardio
//  duration / last completed exercise including cardio), Malachite
//  (use next leftover prescribed rest / this-workout last
//  prescribed rest *query* / this-workout sets completed),
//  Hematite (use previous leftover prescribed rest / this-exercise
//  last rest / this-workout exercises completed), Sunstone (use
//  this-workout last *logged* rest including warm-ups / remaining
//  sets / last working *load*), Larimar (use next last rest /
//  previous prescribed rest query / this-workout last rest),
//  Turquoise (use previous last rest / previous last rest / next
//  prescribed rest query), Coral (use focused last rest /
//  previous remaining / next last rest), Amber (double rest /
//  next remaining / this last rest), Jade (halve rest / previous
//  last working / this remaining sets), Zircon (add rest /
//  this-exercise target / prescribed rest on the focused row),
//  Obsidian (subtract 30s / next-exercise target / next last
//  working), Fluorite (reset rest to focused prescribed /
//  previous target / this last working), Aquamarine (skip rest /
//  rest remaining), Tourmaline (use last cardio duration *action*
//  / last-set / current-exercise), Spinel (go to previous /
//  previous name / this-exercise sets), Jasper (repeat / session
//  remaining / next incomplete), Moonstone (skip remaining /
//  next set / ready-to-finish), Tanzanite (undo / sets logged /
//  elapsed), Alexandrite (remaining exercises row count),
//  Citrine (last-load query), the Siri start series (Onyx →
//  Topaz), and 999e (in-app finish-ready banner). Does not change
//  freemium rules.
//

import Foundation

enum IoliteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let noWorkingRestDialog = "No working rest this workout."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.IoliteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.IoliteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let lastStrength = lastCompletedStrengthExercise(in: live)
        let lastWorkingRest = sessionLastWorkingRest(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.IoliteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            lastCompletedStrengthExerciseName: lastStrength?.exerciseName,
            lastWorkingRestSeconds: lastWorkingRest?.seconds,
            lastWorkingRestExerciseName: lastWorkingRest?.exerciseName,
            canUseLastWorkingRest: canUseLastWorkingRest(
                remaining: remaining,
                workingRestSeconds: lastWorkingRest?.seconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseLastWorkingRest(
        snapshot: FitLogIntentBridge.IoliteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseLastWorkingRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            workingRestSeconds: snapshot?.lastWorkingRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func lastWorkingRestTargetSeconds(
        snapshot: FitLogIntentBridge.IoliteSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.lastWorkingRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.IoliteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useThisWorkoutLastWorkingRestDialog(
        snapshot: FitLogIntentBridge.IoliteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let target = lastWorkingRestTargetSeconds(snapshot: snapshot) {
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noWorkingRestDialog
    }

    static func thisWorkoutLastWorkingRestDialog(
        snapshot: FitLogIntentBridge.IoliteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let seconds = snapshot?.lastWorkingRestSeconds, seconds > 0 {
            let spoken = CardioMetricsCalculator.spokenDuration(seconds: seconds)
            if let name = cleanedName(snapshot?.lastWorkingRestExerciseName) {
                return "Last working rest this workout was \(spoken) on \(name)."
            }
            return "Last working rest this workout was \(spoken)."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noWorkingRestDialog
    }

    static func thisWorkoutLastCompletedStrengthExerciseDialog(
        snapshot: FitLogIntentBridge.IoliteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let name = cleanedName(snapshot?.lastCompletedStrengthExerciseName) {
            return "Last finished strength exercise this workout was \(name)."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "No finished strength exercise this workout."
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isIncomplete: Bool
    }

    private struct CompletedStrength: Equatable {
        var exerciseName: String
    }

    private struct SessionLastWorkingRest: Equatable {
        var exerciseName: String
        var seconds: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseLastWorkingRest(
        remaining: Int?,
        workingRestSeconds: Int?
    ) -> Bool {
        guard let remaining, remaining >= minRestSeconds else { return false }
        guard let workingRestSeconds, workingRestSeconds > 0 else { return false }
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
            isIncomplete: isIncomplete(log, completedExerciseIds: completed)
        )
    }

    /// Most recently finished startable *strength* row. Cardio completed
    /// and placeholders are skipped. Distinct from Azurite last completed
    /// (any startable row, including cardio).
    private static func lastCompletedStrengthExercise(
        in session: WorkoutSession
    ) -> CompletedStrength? {
        let completed = Set(session.completedExerciseIds)
        for log in session.exerciseLogs.reversed() {
            guard isRowReady(log, completedExerciseIds: completed) else { continue }
            guard !isCardioRow(log) else { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            return CompletedStrength(exerciseName: name)
        }
        return nil
    }

    /// Most recently logged rest (`restTime > 0`) on a set that counts
    /// toward recommended sets. Warm-ups, cardio rows, interval rest,
    /// placeholders, and nameless rows are skipped. Latest `timestamp`
    /// wins; ties go to later row then later set. Distinct from
    /// Sunstone (any last rest, including warm-ups) and Azurite
    /// (prescribed rest of last finished strength).
    private static func sessionLastWorkingRest(
        in session: WorkoutSession
    ) -> SessionLastWorkingRest? {
        var best: (timestamp: Date, logIndex: Int, setIndex: Int, name: String, seconds: Int)?
        for (logIndex, log) in session.exerciseLogs.enumerated() {
            if log.workoutExercise.isSlotPlaceholder { continue }
            if isCardioRow(log) { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            for (setIndex, set) in log.loggedSets.enumerated() {
                guard set.countsTowardRecommendedSets, !set.isCardioEntry, set.restTime > 0 else {
                    continue
                }
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
        return SessionLastWorkingRest(exerciseName: best.name, seconds: best.seconds)
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
}

extension FitLogIntentBridge.IoliteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
