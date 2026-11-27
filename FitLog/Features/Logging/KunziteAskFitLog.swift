//
//  KunziteAskFitLog.swift
//  FitLog
//
//  Apply this workout's most recently logged *warm-up* rest to a
//  live rest countdown from Siri / Shortcuts, plus this-workout
//  last-warmup-rest and warmup-sets-logged queries, so a
//  mid-session "use the rest I last took after a warm-up" /
//  "how long was last warm-up rest" / "how many warm-up sets
//  have I logged" check does not require hunting through the
//  sheet (`like.history.logged` / `like.rest.no_nag`). Empty /
//  missing sessions, idle rest timers, open placeholders, and rest
//  days are not turned into a rest start, a skip, a set, or a
//  start. Distinct from RestTimerIntent (starts rest), Iolite
//  (use this-workout last *working* rest / last completed
//  strength), Kyanite (this-exercise last working rest), Beryl
//  (previous-exercise last working rest), Morganite (next-exercise
//  last working rest), Azurite (use last finished strength
//  *prescribed* rest / last cardio duration / last completed
//  exercise including cardio), Malachite (use next leftover
//  prescribed rest / this-workout last prescribed rest *query* /
//  this-workout sets completed), Hematite (use previous leftover
//  prescribed rest / this-exercise last rest / this-workout
//  exercises completed), Sunstone (use this-workout last *logged*
//  rest including warm-ups *and* working sets / remaining sets /
//  last working *load*), Larimar (use next last rest / previous
//  prescribed rest query / this-workout last rest), Turquoise
//  (use previous last rest), Coral (use focused last rest
//  including warm-ups), Amber (double rest), Jade (halve rest),
//  Zircon (add rest), Obsidian (subtract 30s), Fluorite (reset
//  rest to focused prescribed), Aquamarine (skip rest),
//  Tourmaline (use last cardio duration *action*), Spinel (go to
//  previous), Jasper (repeat), Moonstone (skip remaining),
//  Tanzanite (undo / sets logged / elapsed), Alexandrite
//  (remaining exercises row count), Citrine (last-load query),
//  the Siri start series (Onyx → Topaz), and 999e (in-app
//  finish-ready banner). Does not change freemium rules.
//

import Foundation

enum KunziteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let noWarmupRestDialog = "No warmup rest this workout."
    static let noWarmupSetsDialog = "No warmup sets this workout."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.KunziteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.KunziteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let lastWarmupRest = sessionLastWarmupRest(in: live)
        let warmupSets = sessionWarmupSetsLogged(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.KunziteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            lastWarmupRestSeconds: lastWarmupRest?.seconds,
            lastWarmupRestExerciseName: lastWarmupRest?.exerciseName,
            warmupSetsLogged: warmupSets,
            canUseLastWarmupRest: canUseLastWarmupRest(
                remaining: remaining,
                warmupRestSeconds: lastWarmupRest?.seconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseLastWarmupRest(
        snapshot: FitLogIntentBridge.KunziteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseLastWarmupRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            warmupRestSeconds: snapshot?.lastWarmupRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func lastWarmupRestTargetSeconds(
        snapshot: FitLogIntentBridge.KunziteSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.lastWarmupRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.KunziteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useThisWorkoutLastWarmupRestDialog(
        snapshot: FitLogIntentBridge.KunziteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let target = lastWarmupRestTargetSeconds(snapshot: snapshot) {
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noWarmupRestDialog
    }

    static func thisWorkoutLastWarmupRestDialog(
        snapshot: FitLogIntentBridge.KunziteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let seconds = snapshot?.lastWarmupRestSeconds, seconds > 0 {
            let spoken = CardioMetricsCalculator.spokenDuration(seconds: seconds)
            if let name = cleanedName(snapshot?.lastWarmupRestExerciseName) {
                return "Last warmup rest this workout was \(spoken) on \(name)."
            }
            return "Last warmup rest this workout was \(spoken)."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noWarmupRestDialog
    }

    static func thisWorkoutWarmupSetsLoggedDialog(
        snapshot: FitLogIntentBridge.KunziteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let count = snapshot?.warmupSetsLogged ?? 0
        if count > 0 {
            if count == 1 {
                return "1 warmup set logged this workout."
            }
            return "\(count) warmup sets logged this workout."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noWarmupSetsDialog
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isIncomplete: Bool
    }

    private struct SessionLastWarmupRest: Equatable {
        var exerciseName: String
        var seconds: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseLastWarmupRest(
        remaining: Int?,
        warmupRestSeconds: Int?
    ) -> Bool {
        guard let remaining, remaining >= minRestSeconds else { return false }
        guard let warmupRestSeconds, warmupRestSeconds > 0 else { return false }
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

    /// Most recently logged rest (`restTime > 0`) on a *warm-up* set.
    /// Working sets, cardio rows, interval rest, placeholders, and
    /// nameless rows are skipped. Latest `timestamp` wins; ties go
    /// to later row then later set. Distinct from Iolite (working-set
    /// rest only) and Sunstone (any last rest, including working).
    private static func sessionLastWarmupRest(
        in session: WorkoutSession
    ) -> SessionLastWarmupRest? {
        var best: (timestamp: Date, logIndex: Int, setIndex: Int, name: String, seconds: Int)?
        for (logIndex, log) in session.exerciseLogs.enumerated() {
            if log.workoutExercise.isSlotPlaceholder { continue }
            if isCardioRow(log) { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            for (setIndex, set) in log.loggedSets.enumerated() {
                guard isWarmupSet(set), set.restTime > 0 else { continue }
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
        return SessionLastWarmupRest(exerciseName: best.name, seconds: best.seconds)
    }

    /// Warm-up sets already logged this session. Working sets, cardio
    /// rows, placeholders, and nameless rows are skipped. Zero-second
    /// rest still counts as a logged warm-up set.
    private static func sessionWarmupSetsLogged(in session: WorkoutSession) -> Int {
        var count = 0
        for log in session.exerciseLogs {
            if log.workoutExercise.isSlotPlaceholder { continue }
            if isCardioRow(log) { continue }
            guard cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) != nil else {
                continue
            }
            count += log.loggedSets.filter(isWarmupSet).count
        }
        return count
    }

    private static func isWarmupSet(_ set: LoggedSet) -> Bool {
        set.setType == .warmup && !set.isCardioEntry
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

extension FitLogIntentBridge.KunziteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
