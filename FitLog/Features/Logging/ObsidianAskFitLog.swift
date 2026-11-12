//
//  ObsidianAskFitLog.swift
//  FitLog
//
//  Subtract 30 seconds from a live rest countdown from Siri / Shortcuts,
//  plus next-exercise-target and next-exercise-last-working queries, so a
//  mid-session "less rest" / "what's next" / "what did I last hit on
//  next" check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing
//  sessions, idle rest timers, open placeholders, and rest days are not
//  turned into a rest skip, a set, or a start. Distinct from
//  RestTimerIntent (starts rest), Zircon (add rest / this-exercise
//  target / prescribed rest), Aquamarine (skip rest / rest remaining),
//  Alexandrite (go to next / remaining / current workout), Jasper
//  (next-exercise name query), Spinel (previous / this-exercise sets),
//  Moonstone (skip remaining / next set / ready-to-finish), Tanzanite
//  (undo / sets logged / elapsed), Tourmaline (last cardio / last-set /
//  current-exercise), Citrine (last-load query), the Siri start series
//  (Onyx → Topaz), and 999e (in-app finish-ready banner). Does not
//  change freemium rules.
//

import Foundation

enum ObsidianAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let restAlreadyMinimumDialog = "Rest already at 1 second."
    static let noNextExerciseDialog = "No next exercise."
    static let subtractRestSeconds = 30
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        displayUnit: WeightDisplayUnit = .pounds,
        now: Date = Date()
    ) -> FitLogIntentBridge.ObsidianSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.ObsidianSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let next = nextIncompleteExercise(in: live, displayUnit: displayUnit)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.ObsidianSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            nextExerciseName: next?.exerciseName,
            nextIsCardio: next?.isCardio ?? false,
            nextTargetCaption: next?.targetCaption,
            nextLastWorkingCaption: next?.lastWorkingCaption,
            canSubtractRest: canSubtract(remaining: remaining),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canSubtractRest(
        snapshot: FitLogIntentBridge.ObsidianSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canSubtract(remaining: remainingRestSeconds(snapshot: snapshot, now: now))
            && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func subtractedRestSeconds(
        snapshot: FitLogIntentBridge.ObsidianSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now),
              canSubtract(remaining: remaining)
        else { return nil }
        return max(minRestSeconds, remaining - subtractRestSeconds)
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.ObsidianSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func subtractRestDialog(
        snapshot: FitLogIntentBridge.ObsidianSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now) else {
            return noRestTimerDialog
        }
        guard let subtracted = subtractedRestSeconds(snapshot: snapshot, now: now) else {
            return remaining == minRestSeconds ? restAlreadyMinimumDialog : noRestTimerDialog
        }
        return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: subtracted))."
    }

    static func nextExerciseTargetDialog(
        snapshot: FitLogIntentBridge.ObsidianSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let next = cleanedName(snapshot?.nextExerciseName) {
            if let caption = cleanedName(snapshot?.nextTargetCaption) {
                return "Next is \(next): \(caption)."
            }
            if snapshot?.nextIsCardio == true {
                return "Next is \(next). It is cardio."
            }
            return "Next is \(next). No target."
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

    static func nextExerciseLastWorkingDialog(
        snapshot: FitLogIntentBridge.ObsidianSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let next = cleanedName(snapshot?.nextExerciseName) {
            if let caption = cleanedName(snapshot?.nextLastWorkingCaption) {
                return "Next is \(next). Last was \(caption)."
            }
            return "Next is \(next). No working set logged yet."
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

    private struct NextExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var targetCaption: String?
        var lastWorkingCaption: String?
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canSubtract(remaining: Int?) -> Bool {
        guard let remaining else { return false }
        return remaining > minRestSeconds
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

    private static func focusedExercise(in session: WorkoutSession) -> FocusedExercise? {
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
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> NextExercise? {
        guard let nextIndex = nextIncompleteIndex(in: session) else { return nil }
        let log = session.exerciseLogs[nextIndex]
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        let cardio = isCardioRow(log)
        return NextExercise(
            exerciseName: name,
            isCardio: cardio,
            targetCaption: targetCaption(in: log, isCardio: cardio),
            lastWorkingCaption: lastWorkCaption(in: log, displayUnit: displayUnit)
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

    private static func hasCompletedCardioWork(_ log: ExerciseLog) -> Bool {
        log.loggedSets.contains { set in
            set.countsTowardCardioTotals && (set.cardioMetrics?.durationSec ?? 0) > 0
        }
    }

    private static func isCardioRow(_ log: ExerciseLog) -> Bool {
        log.workoutExercise.effectiveCardioPrescription != nil
            || log.loggedSets.contains(where: \.isCardioEntry)
    }

    private static func targetCaption(in log: ExerciseLog, isCardio: Bool) -> String? {
        if isCardio {
            return cardioTargetCaption(log.workoutExercise.effectiveCardioPrescription)
        }
        let sets = max(1, log.workoutExercise.recommendedSets)
        let setWord = sets == 1 ? "set" : "sets"
        if let reps = cleanedName(log.workoutExercise.recommendedReps) {
            return "\(sets) \(setWord) of \(reps)"
        }
        return "\(sets) \(setWord)"
    }

    private static func cardioTargetCaption(_ prescription: CardioPrescription?) -> String? {
        guard let prescription else { return nil }
        if let seconds = prescription.targetDurationSec, seconds > 0 {
            return CardioMetricsCalculator.spokenDuration(seconds: seconds)
        }
        if let meters = prescription.targetDistanceM, meters > 0 {
            return CardioMetricsCalculator.formatDistance(meters: meters)
        }
        return cleanedName(CardioMetricsCalculator.prescriptionSummary(prescription))
    }

    private static func lastWorkCaption(in log: ExerciseLog, displayUnit: WeightDisplayUnit) -> String? {
        if isCardioRow(log) {
            for set in log.loggedSets.reversed() {
                if let caption = cardioCaption(for: set) { return caption }
            }
            return nil
        }
        for set in log.loggedSets.reversed() where set.countsTowardRecommendedSets && set.reps > 0 {
            if let caption = cleanedName(set.weightRepsDisplaySummary(displayUnit: displayUnit)) {
                return caption
            }
        }
        return nil
    }

    private static func cardioCaption(for set: LoggedSet) -> String? {
        guard set.isCardioEntry else { return nil }
        if let seconds = set.cardioMetrics?.durationSec, seconds > 0 {
            return CardioMetricsCalculator.spokenDuration(seconds: seconds)
        }
        return nil
    }
}

extension FitLogIntentBridge.ObsidianSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
