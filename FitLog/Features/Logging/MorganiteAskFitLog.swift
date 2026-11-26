//
//  MorganiteAskFitLog.swift
//  FitLog
//
//  Apply the *next* exercise's most recently logged *working-set*
//  rest to a live rest countdown from Siri / Shortcuts, plus
//  next-exercise last-working-rest and next-exercise
//  working-sets logged queries, so a mid-session "use the rest I
//  last took on the lift after this one" / "how long was the
//  next exercise's last working rest" / "how many working sets
//  did I log on the next lift" check does not require hunting
//  through the sheet (`like.history.logged` / `like.rest.no_nag`).
//  Empty / missing sessions, idle rest timers, open placeholders,
//  and rest days are not turned into a rest start, a skip, a set,
//  or a start. Distinct from RestTimerIntent (starts rest),
//  Beryl (use *previous* exercise last working rest /
//  previous-exercise last working rest / previous-exercise
//  working sets), Kyanite (use this *focused* exercise last
//  working rest / this-exercise last working rest /
//  this-exercise working sets), Iolite (use this workout's last
//  working rest on *any* exercise / last completed strength),
//  Azurite (use last finished strength *prescribed* rest / last
//  cardio duration / last completed exercise including cardio),
//  Malachite (use next leftover prescribed rest / this-workout
//  last prescribed rest *query* / this-workout sets completed),
//  Hematite (use previous leftover prescribed rest /
//  this-exercise last rest including warm-ups / this-workout
//  exercises completed), Sunstone (use this-workout last
//  *logged* rest including warm-ups / remaining sets / last
//  working *load*), Larimar (use next last rest / previous
//  prescribed rest query / this-workout last rest), Turquoise
//  (use previous last rest including warm-ups / previous last
//  rest / next prescribed rest query), Coral (use focused last
//  rest including warm-ups / previous remaining / next last
//  rest), Amber (double rest / next remaining / this last rest),
//  Jade (halve rest / previous last working / this remaining
//  sets), Zircon (add rest / this-exercise target / prescribed
//  rest on the focused row), Obsidian (subtract 30s /
//  next-exercise target / next last working), Fluorite (reset
//  rest to focused prescribed / previous target / this last
//  working *load*), Alexandrite (go to next exercise /
//  remaining exercises / current workout), Spinel (go to
//  previous exercise / this-exercise sets including warm-ups),
//  Aquamarine (skip rest / rest remaining), Tourmaline (use last
//  cardio duration *action* / last-set / current-exercise),
//  Jasper (repeat / session remaining / next incomplete),
//  Moonstone (skip remaining / next set / ready-to-finish),
//  Tanzanite (undo / sets logged / elapsed), Citrine (last-load
//  query), the Siri start series (Onyx → Topaz), and 999e
//  (in-app finish-ready banner). Does not change freemium rules.
//

import Foundation

enum MorganiteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let noExerciseInFocusDialog = "No exercise in focus."
    static let noNextExerciseDialog = "No next exercise."
    static let noWorkingRestDialog = "No working rest next exercise."
    static let noWorkingSetsDialog = "No working sets next exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.MorganiteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.MorganiteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let next = nextExercise(in: live)
        let lastWorkingRest = nextLastWorkingRest(in: live)
        let workingSets = nextWorkingSetsLogged(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.MorganiteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedIsPlaceholder: focused?.isPlaceholder ?? false,
            nextExerciseName: next?.exerciseName,
            nextIsIncomplete: next?.isIncomplete ?? false,
            nextIsPlaceholder: next?.isPlaceholder ?? false,
            lastWorkingRestSeconds: lastWorkingRest?.seconds,
            lastWorkingRestExerciseName: lastWorkingRest?.exerciseName,
            workingSetsLogged: workingSets,
            canUseLastWorkingRest: canUseLastWorkingRest(
                remaining: remaining,
                workingRestSeconds: lastWorkingRest?.seconds,
                nextName: next?.exerciseName,
                nextIsPlaceholder: next?.isPlaceholder ?? false,
                hasFocus: focused != nil
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseLastWorkingRest(
        snapshot: FitLogIntentBridge.MorganiteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseLastWorkingRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            workingRestSeconds: snapshot?.lastWorkingRestSeconds,
            nextName: snapshot?.nextExerciseName,
            nextIsPlaceholder: snapshot?.nextIsPlaceholder ?? false,
            hasFocus: snapshot?.hasFocus == true
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func lastWorkingRestTargetSeconds(
        snapshot: FitLogIntentBridge.MorganiteSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.lastWorkingRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.MorganiteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useNextExerciseLastWorkingRestDialog(
        snapshot: FitLogIntentBridge.MorganiteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        guard snapshot?.hasFocus == true else {
            return noExerciseInFocusDialog
        }
        if snapshot?.nextIsPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        guard cleanedName(snapshot?.nextExerciseName) != nil else {
            return noNextExerciseDialog
        }
        if let target = lastWorkingRestTargetSeconds(snapshot: snapshot) {
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
        }
        return noWorkingRestDialog
    }

    static func nextExerciseLastWorkingRestDialog(
        snapshot: FitLogIntentBridge.MorganiteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard snapshot?.hasFocus == true else {
            return noExerciseInFocusDialog
        }
        if snapshot?.nextIsPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        guard let nextName = cleanedName(snapshot?.nextExerciseName) else {
            return noNextExerciseDialog
        }
        if let seconds = snapshot?.lastWorkingRestSeconds, seconds > 0 {
            let spoken = CardioMetricsCalculator.spokenDuration(seconds: seconds)
            return "Last working rest next exercise was \(spoken) on \(nextName)."
        }
        return noWorkingRestDialog
    }

    static func nextExerciseWorkingSetsLoggedDialog(
        snapshot: FitLogIntentBridge.MorganiteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard snapshot?.hasFocus == true else {
            return noExerciseInFocusDialog
        }
        if snapshot?.nextIsPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        guard let nextName = cleanedName(snapshot?.nextExerciseName) else {
            return noNextExerciseDialog
        }
        let count = snapshot?.workingSetsLogged ?? 0
        if count <= 0 {
            return noWorkingSetsDialog
        }
        let noun = count == 1 ? "set" : "sets"
        return "\(count) working \(noun) logged on \(nextName)."
    }

    // MARK: - Private

    private struct RowExercise: Equatable {
        var exerciseName: String?
        var isIncomplete: Bool
        var isPlaceholder: Bool
    }

    private struct NextLastWorkingRest: Equatable {
        var exerciseName: String
        var seconds: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseLastWorkingRest(
        remaining: Int?,
        workingRestSeconds: Int?,
        nextName: String?,
        nextIsPlaceholder: Bool,
        hasFocus: Bool
    ) -> Bool {
        guard hasFocus else { return false }
        guard !nextIsPlaceholder else { return false }
        guard cleanedName(nextName) != nil else { return false }
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

    private static func focusedLogIndex(in session: WorkoutSession) -> Int? {
        guard let activeId = session.activeExerciseIds.first else { return nil }
        return session.exerciseLogs.firstIndex {
            $0.workoutExercise.exerciseId == activeId
        }
    }

    private static func focusedLog(in session: WorkoutSession) -> ExerciseLog? {
        guard let index = focusedLogIndex(in: session) else { return nil }
        return session.exerciseLogs[index]
    }

    private static func nextLog(in session: WorkoutSession) -> ExerciseLog? {
        guard let index = focusedLogIndex(in: session) else { return nil }
        let nextIndex = index + 1
        guard nextIndex < session.exerciseLogs.count else { return nil }
        return session.exerciseLogs[nextIndex]
    }

    private static func rowExercise(
        _ log: ExerciseLog,
        completedExerciseIds: Set<UUID>
    ) -> RowExercise {
        if log.workoutExercise.isSlotPlaceholder {
            return RowExercise(
                exerciseName: nil,
                isIncomplete: true,
                isPlaceholder: true
            )
        }
        return RowExercise(
            exerciseName: cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog),
            isIncomplete: isIncomplete(log, completedExerciseIds: completedExerciseIds),
            isPlaceholder: false
        )
    }

    private static func focusedExercise(in session: WorkoutSession) -> RowExercise? {
        guard let log = focusedLog(in: session) else { return nil }
        return rowExercise(log, completedExerciseIds: Set(session.completedExerciseIds))
    }

    private static func nextExercise(in session: WorkoutSession) -> RowExercise? {
        guard let log = nextLog(in: session) else { return nil }
        return rowExercise(log, completedExerciseIds: Set(session.completedExerciseIds))
    }

    /// Most recently logged rest (`restTime > 0`) on a working set of the
    /// next row (the log immediately after the focused one). Warm-ups,
    /// cardio rows, interval rest, placeholders, the focused row, later
    /// rows beyond next, and nameless rows are skipped. Latest
    /// `timestamp` wins; ties go to later set index. Distinct from
    /// Beryl (previous last working rest), Kyanite (focused last
    /// working rest), Iolite (this workout last working rest, any
    /// exercise), Larimar (next last rest including warm-ups), and
    /// Malachite (next leftover prescribed rest).
    private static func nextLastWorkingRest(
        in session: WorkoutSession
    ) -> NextLastWorkingRest? {
        guard let log = nextLog(in: session) else { return nil }
        if log.workoutExercise.isSlotPlaceholder { return nil }
        if isCardioRow(log) { return nil }
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        var best: (timestamp: Date, setIndex: Int, seconds: Int)?
        for (setIndex, set) in log.loggedSets.enumerated() {
            guard set.countsTowardRecommendedSets, !set.isCardioEntry, set.restTime > 0 else {
                continue
            }
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
        return NextLastWorkingRest(exerciseName: name, seconds: best.seconds)
    }

    /// Working sets already logged on the next row
    /// (`countsTowardRecommendedSets`, cardio excluded). Zero-second
    /// rest still counts as a logged working set. Distinct from
    /// Beryl previous-exercise working sets, Kyanite this-exercise
    /// working sets, Spinel this-exercise sets (includes warm-ups),
    /// Jade this remaining sets, and Tanzanite session sets logged.
    private static func nextWorkingSetsLogged(in session: WorkoutSession) -> Int {
        guard let log = nextLog(in: session) else { return 0 }
        if log.workoutExercise.isSlotPlaceholder { return 0 }
        if isCardioRow(log) { return 0 }
        return log.loggedSets.filter { set in
            set.countsTowardRecommendedSets && !set.isCardioEntry
        }.count
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

extension FitLogIntentBridge.MorganiteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }

    var hasFocus: Bool {
        focusedIsPlaceholder || cleanedFocusName != nil
    }

    private var cleanedFocusName: String? {
        let trimmed = focusedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
