//
//  MalachiteAskFitLog.swift
//  FitLog
//
//  Apply the next incomplete exercise's prescribed rest to a live
//  rest countdown from Siri / Shortcuts, plus this-workout last
//  prescribed-rest and this-workout sets-completed queries, so a
//  mid-session "use the rest the next one calls for" / "what rest
//  did the last finished exercise call for" / "how many sets am I
//  done with" check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing
//  sessions, idle rest timers, open placeholders, and rest days
//  are not turned into a rest start, a skip, a set, or a start.
//  Distinct from RestTimerIntent (starts rest), Hematite (use
//  previous leftover prescribed rest / this-exercise last rest /
//  this-workout exercises completed), Sunstone (use this-workout
//  last rest / remaining sets / last working), Larimar (use next
//  last rest / previous prescribed rest query / this-workout last
//  rest), Turquoise (use previous last rest / previous last rest /
//  next prescribed rest query), Coral (use focused last rest /
//  previous remaining / next last rest), Amber (double rest /
//  next remaining / this last rest), Jade (halve rest / previous
//  last working / this remaining sets), Zircon (add rest /
//  this-exercise target / prescribed rest on the focused row),
//  Obsidian (subtract 30s / next-exercise target / next last
//  working), Fluorite (reset rest to focused prescribed /
//  previous target / this last working), Aquamarine (skip rest /
//  rest remaining), Spinel (go to previous / previous name /
//  this-exercise sets), Jasper (repeat / session remaining / next
//  incomplete), Moonstone (skip remaining / next set /
//  ready-to-finish), Tanzanite (undo / sets logged / elapsed),
//  Tourmaline (last cardio / last-set / current-exercise),
//  Alexandrite (remaining exercises row count), Citrine
//  (last-load query), the Siri start series (Onyx → Topaz), and
//  999e (in-app finish-ready banner). Does not change freemium
//  rules.
//

import Foundation

enum MalachiteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let noNextExerciseDialog = "No next exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.MalachiteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.MalachiteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let next = nextIncompleteExercise(in: live)
        let lastCompleted = lastCompletedPrescribedRest(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.MalachiteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            nextExerciseName: next?.exerciseName,
            nextIsCardio: next?.isCardio ?? false,
            nextPrescribedRestSeconds: next?.prescribedRestSeconds,
            lastCompletedExerciseName: lastCompleted?.exerciseName,
            lastCompletedPrescribedRestSeconds: lastCompleted?.prescribedRestSeconds,
            completedSetCount: finish.completedSetCount,
            canUseNextPrescribedRest: canUseNextPrescribedRest(
                remaining: remaining,
                prescribedSeconds: next?.prescribedRestSeconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseNextPrescribedRest(
        snapshot: FitLogIntentBridge.MalachiteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseNextPrescribedRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            prescribedSeconds: snapshot?.nextPrescribedRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func nextPrescribedRestTargetSeconds(
        snapshot: FitLogIntentBridge.MalachiteSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.nextPrescribedRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.MalachiteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useNextPrescribedRestDialog(
        snapshot: FitLogIntentBridge.MalachiteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let next = cleanedName(snapshot?.nextExerciseName) {
            if snapshot?.nextIsCardio == true {
                return "\(next) is cardio."
            }
            guard let target = nextPrescribedRestTargetSeconds(snapshot: snapshot) else {
                return "No rest prescription on \(next)."
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
        return noNextExerciseDialog
    }

    static func thisWorkoutLastPrescribedRestDialog(
        snapshot: FitLogIntentBridge.MalachiteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let name = cleanedName(snapshot?.lastCompletedExerciseName),
           let seconds = snapshot?.lastCompletedPrescribedRestSeconds,
           seconds > 0 {
            return "Last prescribed rest this workout was \(CardioMetricsCalculator.spokenDuration(seconds: seconds)) on \(name)."
        }
        if snapshot?.isReadyToFinish == true {
            return "No rest prescription this workout."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "No rest prescription this workout."
    }

    static func thisWorkoutSetsCompletedDialog(
        snapshot: FitLogIntentBridge.MalachiteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let done = max(0, snapshot?.completedSetCount ?? 0)
        if done > 0 {
            if done == 1 {
                return "1 set done this workout."
            }
            return "\(done) sets done this workout."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "No sets done this workout."
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isIncomplete: Bool
    }

    private struct NeighborExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var prescribedRestSeconds: Int?
    }

    private struct CompletedPrescribedRest: Equatable {
        var exerciseName: String
        var prescribedRestSeconds: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
        var completedSetCount: Int
    }

    private static func canUseNextPrescribedRest(
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
            isIncomplete: isIncomplete(log, completedExerciseIds: completed)
        )
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
            prescribedRestSeconds: cardio ? nil : prescribedRestSeconds(in: log)
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

    private static func lastCompletedPrescribedRest(
        in session: WorkoutSession
    ) -> CompletedPrescribedRest? {
        let completed = Set(session.completedExerciseIds)
        for log in session.exerciseLogs.reversed() {
            guard isRowReady(log, completedExerciseIds: completed) else { continue }
            guard !isCardioRow(log) else { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            guard let seconds = prescribedRestSeconds(in: log), seconds > 0 else { continue }
            return CompletedPrescribedRest(
                exerciseName: name,
                prescribedRestSeconds: seconds
            )
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
            isReady: isReady,
            completedSetCount: completedSetCount(in: logs)
        )
    }

    /// Strength working sets (`countsTowardVolumeTotals`) plus cardio work
    /// with duration (`countsTowardCardioTotals` and `durationSec > 0`).
    /// Warm-ups, timed holds, interval rests, and zero-second cardio do not count.
    private static func completedSetCount(in logs: [ExerciseLog]) -> Int {
        logs.reduce(0) { total, log in
            guard !log.workoutExercise.isSlotPlaceholder else { return total }
            let strength = log.loggedSets.filter(\.countsTowardVolumeTotals).count
            let cardio = log.loggedSets.filter { set in
                set.countsTowardCardioTotals && (set.cardioMetrics?.durationSec ?? 0) > 0
            }.count
            return total + strength + cardio
        }
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

    /// Session rest override wins over the library default. Cardio rows skip this.
    private static func prescribedRestSeconds(in log: ExerciseLog) -> Int? {
        if let override = log.sessionRestOverrideSeconds, override > 0 {
            return override
        }
        let planDefault = log.workoutExercise.defaultRestTime
        return planDefault > 0 ? planDefault : nil
    }
}

extension FitLogIntentBridge.MalachiteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
