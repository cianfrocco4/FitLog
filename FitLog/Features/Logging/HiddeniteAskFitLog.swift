//
//  HiddeniteAskFitLog.swift
//  FitLog
//
//  Apply the *focused* exercise's most recently logged *warm-up*
//  rest to a live rest countdown from Siri / Shortcuts, plus
//  this-exercise last-warmup-rest and this-exercise warmup-sets
//  logged queries, so a mid-session "use the rest I last took
//  after a warm-up on this lift" / "how long was this exercise's
//  last warm-up rest" / "how many warm-up sets have I logged
//  here" check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing
//  sessions, idle rest timers, open placeholders, and rest days
//  are not turned into a rest start, a skip, a set, or a start.
//  Distinct from RestTimerIntent (starts rest), Kunzite (this
//  *workout* last warmup rest / warmup sets on any row), Kyanite
//  (this-exercise last *working* rest / working sets), Beryl
//  (previous-exercise last working rest), Morganite (next-exercise
//  last working rest), Iolite (this-workout last working rest /
//  last completed strength), Coral (focused last rest including
//  warm-ups *and* working), Sunstone (this-workout last *logged*
//  rest including working), Azurite (last finished strength
//  *prescribed* rest / last cardio duration / last completed
//  including cardio), Malachite (next leftover prescribed /
//  this-workout last prescribed *query* / sets completed),
//  Hematite (previous leftover prescribed / this-exercise last
//  rest including working / exercises completed), Larimar (use
//  next last rest), Turquoise (use previous last rest), Amber
//  (double rest), Jade (halve rest), Zircon (add rest), Obsidian
//  (subtract 30s), Fluorite (reset rest to focused prescribed),
//  Aquamarine (skip rest), Tourmaline (use last cardio duration
//  *action*), Spinel (this-exercise sets including warm-ups),
//  Jasper (repeat), Moonstone (skip remaining), Tanzanite (undo /
//  sets logged / elapsed), Alexandrite (remaining exercises row
//  count), Citrine (last-load query), the Siri start series
//  (Onyx → Topaz), and 999e (in-app finish-ready banner). Does
//  not change freemium rules.
//

import Foundation

enum HiddeniteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let noExerciseInFocusDialog = "No exercise in focus."
    static let noWarmupRestDialog = "No warmup rest this exercise."
    static let noWarmupSetsDialog = "No warmup sets this exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.HiddeniteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.HiddeniteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let lastWarmupRest = focusedLastWarmupRest(in: live)
        let warmupSets = focusedWarmupSetsLogged(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.HiddeniteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedIsPlaceholder: focused?.isPlaceholder ?? false,
            lastWarmupRestSeconds: lastWarmupRest?.seconds,
            lastWarmupRestExerciseName: lastWarmupRest?.exerciseName,
            warmupSetsLogged: warmupSets,
            canUseLastWarmupRest: canUseLastWarmupRest(
                remaining: remaining,
                warmupRestSeconds: lastWarmupRest?.seconds,
                focusedName: focused?.exerciseName,
                focusedIsPlaceholder: focused?.isPlaceholder ?? false
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseLastWarmupRest(
        snapshot: FitLogIntentBridge.HiddeniteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseLastWarmupRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            warmupRestSeconds: snapshot?.lastWarmupRestSeconds,
            focusedName: snapshot?.focusedExerciseName,
            focusedIsPlaceholder: snapshot?.focusedIsPlaceholder ?? false
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func lastWarmupRestTargetSeconds(
        snapshot: FitLogIntentBridge.HiddeniteSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.lastWarmupRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.HiddeniteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useThisExerciseLastWarmupRestDialog(
        snapshot: FitLogIntentBridge.HiddeniteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if snapshot?.focusedIsPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        guard cleanedName(snapshot?.focusedExerciseName) != nil else {
            return noExerciseInFocusDialog
        }
        if let target = lastWarmupRestTargetSeconds(snapshot: snapshot) {
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
        }
        return noWarmupRestDialog
    }

    static func thisExerciseLastWarmupRestDialog(
        snapshot: FitLogIntentBridge.HiddeniteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if snapshot?.focusedIsPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        guard let focusedName = cleanedName(snapshot?.focusedExerciseName) else {
            return noExerciseInFocusDialog
        }
        if let seconds = snapshot?.lastWarmupRestSeconds, seconds > 0 {
            let spoken = CardioMetricsCalculator.spokenDuration(seconds: seconds)
            return "Last warmup rest this exercise was \(spoken) on \(focusedName)."
        }
        return noWarmupRestDialog
    }

    static func thisExerciseWarmupSetsLoggedDialog(
        snapshot: FitLogIntentBridge.HiddeniteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if snapshot?.focusedIsPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        guard let focusedName = cleanedName(snapshot?.focusedExerciseName) else {
            return noExerciseInFocusDialog
        }
        let count = snapshot?.warmupSetsLogged ?? 0
        if count <= 0 {
            return noWarmupSetsDialog
        }
        let noun = count == 1 ? "set" : "sets"
        return "\(count) warmup \(noun) logged on \(focusedName)."
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String?
        var isIncomplete: Bool
        var isPlaceholder: Bool
    }

    private struct FocusedLastWarmupRest: Equatable {
        var exerciseName: String
        var seconds: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseLastWarmupRest(
        remaining: Int?,
        warmupRestSeconds: Int?,
        focusedName: String?,
        focusedIsPlaceholder: Bool
    ) -> Bool {
        guard !focusedIsPlaceholder else { return false }
        guard cleanedName(focusedName) != nil else { return false }
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

    private static func focusedLog(in session: WorkoutSession) -> ExerciseLog? {
        guard let activeId = session.activeExerciseIds.first else { return nil }
        return session.exerciseLogs.first(where: {
            $0.workoutExercise.exerciseId == activeId
        })
    }

    private static func focusedExercise(
        in session: WorkoutSession
    ) -> FocusedExercise? {
        guard let log = focusedLog(in: session) else { return nil }
        let completed = Set(session.completedExerciseIds)
        if log.workoutExercise.isSlotPlaceholder {
            return FocusedExercise(
                exerciseName: nil,
                isIncomplete: true,
                isPlaceholder: true
            )
        }
        return FocusedExercise(
            exerciseName: cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog),
            isIncomplete: isIncomplete(log, completedExerciseIds: completed),
            isPlaceholder: false
        )
    }

    /// Most recently logged rest (`restTime > 0`) on a *warm-up* set of
    /// the focused row. Working sets, cardio rows, interval rest,
    /// placeholders, other exercises, and nameless rows are skipped.
    /// Latest `timestamp` wins; ties go to later set index. Distinct
    /// from Kunzite (this workout last warmup rest, any exercise),
    /// Kyanite (this exercise last working rest), and Coral (focused
    /// last rest including working).
    private static func focusedLastWarmupRest(
        in session: WorkoutSession
    ) -> FocusedLastWarmupRest? {
        guard let log = focusedLog(in: session) else { return nil }
        if log.workoutExercise.isSlotPlaceholder { return nil }
        if isCardioRow(log) { return nil }
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        var best: (timestamp: Date, setIndex: Int, seconds: Int)?
        for (setIndex, set) in log.loggedSets.enumerated() {
            guard isWarmupSet(set), set.restTime > 0 else { continue }
            let candidate = (set.timestamp, setIndex, set.restTime)
            if let current = best {
                if candidate.0 > current.timestamp
                    || (candidate.0 == current.timestamp && candidate.1 > current.setIndex) {
                    best = (
                        timestamp: candidate.0,
                        setIndex: candidate.1,
                        seconds: candidate.2
                    )
                }
            } else {
                best = (
                    timestamp: candidate.0,
                    setIndex: candidate.1,
                    seconds: candidate.2
                )
            }
        }
        guard let best else { return nil }
        return FocusedLastWarmupRest(exerciseName: name, seconds: best.seconds)
    }

    /// Warm-up sets already logged on the focused row. Working sets,
    /// cardio, placeholders, other exercises, and nameless rows are
    /// skipped. Zero-second rest still counts as a logged warm-up
    /// set. Distinct from Kunzite this-workout warmup sets, Kyanite
    /// this-exercise working sets, and Spinel this-exercise sets
    /// (includes working).
    private static func focusedWarmupSetsLogged(in session: WorkoutSession) -> Int {
        guard let log = focusedLog(in: session) else { return 0 }
        if log.workoutExercise.isSlotPlaceholder { return 0 }
        if isCardioRow(log) { return 0 }
        return log.loggedSets.filter(isWarmupSet).count
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

extension FitLogIntentBridge.HiddeniteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
