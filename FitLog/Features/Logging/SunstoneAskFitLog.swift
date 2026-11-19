//
//  SunstoneAskFitLog.swift
//  FitLog
//
//  Apply this workout's most recently logged rest to a live rest
//  countdown from Siri / Shortcuts, plus this-workout remaining-sets
//  and this-workout last-working queries, so a mid-session "use the
//  rest I last took" / "how many sets left" / "what did I last hit"
//  check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing
//  sessions, idle rest timers, open placeholders, and rest days are
//  not turned into a rest start, a skip, a set, or a start. Distinct
//  from RestTimerIntent (starts rest), Larimar (use next last rest /
//  previous prescribed rest / this-workout last rest query),
//  Turquoise (use previous last rest / previous last rest / next
//  prescribed rest), Coral (use focused last rest / previous
//  remaining / next last rest), Amber (double rest / next remaining /
//  this last rest), Jade (halve rest / previous last working / this
//  remaining sets), Zircon (add rest / this-exercise target /
//  prescribed rest), Obsidian (subtract 30s / next-exercise target /
//  next last working), Fluorite (reset rest / previous-exercise
//  target / this last working), Aquamarine (skip rest / rest
//  remaining), Spinel (go to previous / previous name / this-exercise
//  sets), Jasper (repeat / session remaining / next incomplete),
//  Moonstone (skip remaining / next set / ready-to-finish), Tanzanite
//  (undo / sets logged / elapsed), Tourmaline (last cardio / last-set
//  / current-exercise), Citrine (last-load query), the Siri start
//  series (Onyx → Topaz), and 999e (in-app finish-ready banner). Does
//  not change freemium rules.
//

import Foundation

enum SunstoneAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        displayUnit: WeightDisplayUnit = .pounds,
        now: Date = Date()
    ) -> FitLogIntentBridge.SunstoneSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.SunstoneSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let sessionLastRest = sessionLastRest(in: live)
        let sessionLastWorking = sessionLastWorking(in: live, displayUnit: displayUnit)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        let leftoverSets = remainingSetCount(in: live)
        return FitLogIntentBridge.SunstoneSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            remainingSetCount: leftoverSets,
            sessionLastRestSeconds: sessionLastRest?.seconds,
            sessionLastRestExerciseName: sessionLastRest?.exerciseName,
            sessionLastWorkingCaption: sessionLastWorking?.caption,
            sessionLastWorkingExerciseName: sessionLastWorking?.exerciseName,
            canUseThisWorkoutLastRest: canUseThisWorkoutLastRest(
                remaining: remaining,
                lastRestSeconds: sessionLastRest?.seconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseThisWorkoutLastRest(
        snapshot: FitLogIntentBridge.SunstoneSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseThisWorkoutLastRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            lastRestSeconds: snapshot?.sessionLastRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func thisWorkoutLastRestTargetSeconds(
        snapshot: FitLogIntentBridge.SunstoneSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.sessionLastRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.SunstoneSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useThisWorkoutLastRestDialog(
        snapshot: FitLogIntentBridge.SunstoneSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        guard let target = thisWorkoutLastRestTargetSeconds(snapshot: snapshot) else {
            return "No rest logged yet this workout."
        }
        return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
    }

    static func thisWorkoutRemainingSetsDialog(
        snapshot: FitLogIntentBridge.SunstoneSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let left = max(0, snapshot?.remainingSetCount ?? 0)
        if left > 0 {
            if left == 1 {
                return "1 set left this workout."
            }
            return "\(left) sets left this workout."
        }
        if snapshot?.isReadyToFinish == true {
            return "No sets left this workout."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "No sets left this workout."
    }

    static func thisWorkoutLastWorkingDialog(
        snapshot: FitLogIntentBridge.SunstoneSessionSnapshot?
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        if let caption = cleanedName(snapshot?.sessionLastWorkingCaption),
           let name = cleanedName(snapshot?.sessionLastWorkingExerciseName) {
            return "Last working this workout was \(caption) on \(name)."
        }
        return "No working set logged yet this workout."
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isIncomplete: Bool
    }

    private struct SessionLastRest: Equatable {
        var exerciseName: String
        var seconds: Int
    }

    private struct SessionLastWorking: Equatable {
        var exerciseName: String
        var caption: String
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseThisWorkoutLastRest(remaining: Int?, lastRestSeconds: Int?) -> Bool {
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
            isIncomplete: isIncomplete(log, completedExerciseIds: completed)
        )
    }

    /// Most recently logged rest (`restTime > 0`) anywhere in the session,
    /// including completed rows. Warm-ups count; placeholders and nameless
    /// rows are skipped. Latest `timestamp` wins; ties go to later row then
    /// later set. Distinct from Coral/Amber/Turquoise/Larimar row-neighbor
    /// last rest and from this helper's last-working load.
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

    /// Most recently logged working load (or cardio duration) anywhere in
    /// the session, including completed rows. Warm-ups and zero-second
    /// cardio do not invent a working set. Latest `timestamp` wins; ties
    /// go to later row then later set. Distinct from Jade previous last
    /// working, Fluorite this last working, and Obsidian next last working.
    private static func sessionLastWorking(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> SessionLastWorking? {
        var best: (timestamp: Date, logIndex: Int, setIndex: Int, name: String, caption: String)?
        for (logIndex, log) in session.exerciseLogs.enumerated() {
            if log.workoutExercise.isSlotPlaceholder { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            for (setIndex, set) in log.loggedSets.enumerated() {
                guard let caption = lastWorkCaption(for: set, in: log, displayUnit: displayUnit) else {
                    continue
                }
                let candidate = (set.timestamp, logIndex, setIndex, name, caption)
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
                            caption: candidate.4
                        )
                    }
                } else {
                    best = (
                        timestamp: candidate.0,
                        logIndex: candidate.1,
                        setIndex: candidate.2,
                        name: candidate.3,
                        caption: candidate.4
                    )
                }
            }
        }
        guard let best else { return nil }
        return SessionLastWorking(exerciseName: best.name, caption: best.caption)
    }

    private static func remainingSetCount(in session: WorkoutSession) -> Int {
        let completed = Set(session.completedExerciseIds)
        return session.exerciseLogs.reduce(0) { total, log in
            total + remainingSets(in: log, completedExerciseIds: completed)
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

    private static func lastWorkCaption(
        for set: LoggedSet,
        in log: ExerciseLog,
        displayUnit: WeightDisplayUnit
    ) -> String? {
        if isCardioRow(log) {
            return cardioCaption(for: set)
        }
        guard set.countsTowardRecommendedSets, set.reps > 0 else { return nil }
        return cleanedName(set.weightRepsDisplaySummary(displayUnit: displayUnit))
    }

    private static func cardioCaption(for set: LoggedSet) -> String? {
        guard set.isCardioEntry else { return nil }
        if let seconds = set.cardioMetrics?.durationSec, seconds > 0 {
            return CardioMetricsCalculator.spokenDuration(seconds: seconds)
        }
        return nil
    }
}

extension FitLogIntentBridge.SunstoneSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
