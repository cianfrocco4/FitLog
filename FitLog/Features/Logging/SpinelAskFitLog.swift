//
//  SpinelAskFitLog.swift
//  FitLog
//
//  Focus the previous incomplete exercise from Siri / Shortcuts, plus
//  previous-exercise and this-exercise-sets queries, so a mid-session
//  "go back" / "what was previous" / "how many sets on this one" check
//  does not require hunting through the sheet (`like.history.logged` /
//  `like.rest.no_nag`). Empty / missing sessions, open placeholders,
//  already-focused last leftover rows, and rest days are not turned
//  into a skip, a set, or a start. Distinct from Alexandrite (next
//  incomplete / remaining / current workout), Moonstone (skip remaining
//  / next set / ready-to-finish), Tanzanite (undo / sets logged /
//  elapsed), Jasper (repeat this-session working set / remaining /
//  next incomplete query), Tourmaline (last cardio / last-set /
//  current-exercise query), Aquamarine (last History weight / skip
//  rest / rest remaining), Lapis (resume / last-session / days-since),
//  Peridot (finish / in-progress / last-finished), Citrine (last-load
//  query), the Siri start series (Onyx → Topaz), and 999e (in-app
//  finish-ready banner). Does not change freemium rules.
//

import Foundation

enum SpinelAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noPreviousExerciseDialog = "No previous exercise."
    static let nothingFocusedDialog = "Nothing is focused."

    struct FocusPreviousTarget: Equatable {
        var exerciseIndex: Int
        var exerciseId: UUID
        var exerciseName: String
        var caption: String?
    }

    static func querySnapshot(
        inProgress: WorkoutSession?,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.SpinelSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.SpinelSessionSnapshot()
        }
        let focused = focusedExercise(in: live, displayUnit: displayUnit)
        let previous = focusPreviousTarget(in: live, displayUnit: displayUnit)
        let finish = finishReadiness(in: live)
        return FitLogIntentBridge.SpinelSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedCaption: focused?.caption,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedIsCardio: focused?.isCardio ?? false,
            focusedWorkingSetsLogged: focused?.workingSetsLogged ?? 0,
            focusedRecommendedSets: focused?.recommendedSets ?? 0,
            previousExerciseName: previous?.exerciseName,
            previousExerciseCaption: previous?.caption,
            canFocusPrevious: previous != nil,
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canFocusPrevious(snapshot: FitLogIntentBridge.SpinelSessionSnapshot?) -> Bool {
        snapshot?.canFocusPrevious == true
            && cleanedName(snapshot?.previousExerciseName) != nil
    }

    static func focusPreviousTarget(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> FocusPreviousTarget? {
        guard cleanedInProgress(session) != nil else { return nil }
        guard let previousIndex = previousIncompleteIndex(in: session) else { return nil }
        let log = session.exerciseLogs[previousIndex]
        guard let exerciseId = log.workoutExercise.exerciseId,
              let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
        else { return nil }
        return FocusPreviousTarget(
            exerciseIndex: previousIndex,
            exerciseId: exerciseId,
            exerciseName: name,
            caption: lastWorkCaption(in: log, displayUnit: displayUnit)
        )
    }

    static func focusPreviousDialog(
        snapshot: FitLogIntentBridge.SpinelSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if canFocusPrevious(snapshot: snapshot),
           let name = cleanedName(snapshot?.previousExerciseName) {
            if let caption = cleanedName(snapshot?.previousExerciseCaption) {
                return "Now on \(name). Last was \(caption)."
            }
            return "Now on \(name)."
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName),
           snapshot?.focusedIsIncomplete == true,
           !canFocusPrevious(snapshot: snapshot) {
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

    static func previousExerciseDialog(
        snapshot: FitLogIntentBridge.SpinelSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if canFocusPrevious(snapshot: snapshot),
           let name = cleanedName(snapshot?.previousExerciseName) {
            if let caption = cleanedName(snapshot?.previousExerciseCaption) {
                return "Previous is \(name). Last was \(caption)."
            }
            return "Previous is \(name)."
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName),
           snapshot?.focusedIsIncomplete == true,
           !canFocusPrevious(snapshot: snapshot) {
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

    static func thisExerciseSetsDialog(
        snapshot: FitLogIntentBridge.SpinelSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            if snapshot?.focusedIsCardio == true {
                if let caption = cleanedName(snapshot?.focusedCaption) {
                    return "\(focused): \(caption) logged."
                }
                return "\(focused) still needs a duration."
            }
            let logged = max(0, snapshot?.focusedWorkingSetsLogged ?? 0)
            let prescribed = max(1, snapshot?.focusedRecommendedSets ?? 1)
            var message = "\(focused): \(logged) of \(prescribed) working sets."
            if let caption = cleanedName(snapshot?.focusedCaption) {
                message += " Last was \(caption)."
            }
            return message
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return nothingFocusedDialog
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
        var caption: String?
        var isIncomplete: Bool
        var isCardio: Bool
        var workingSetsLogged: Int
        var recommendedSets: Int
    }

    private struct FinishReadiness: Equatable {
        var incompleteCount: Int
        var hasOpenPlaceholder: Bool
        var isReady: Bool
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
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
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
            caption: lastWorkCaption(in: log, displayUnit: displayUnit),
            isIncomplete: isIncomplete(log, completedExerciseIds: completed),
            isCardio: isCardioRow(log),
            workingSetsLogged: log.workingSetCount,
            recommendedSets: max(1, log.workoutExercise.recommendedSets)
        )
    }

    /// Previous incomplete startable row before the focused exercise, wrapping.
    /// Returns nil when the only leftover is already focused (does not wrap onto self).
    /// When nothing is focused, falls through to the last incomplete.
    private static func previousIncompleteIndex(in session: WorkoutSession) -> Int? {
        let completed = Set(session.completedExerciseIds)
        let logs = session.exerciseLogs
        let incomplete = logs.indices.filter {
            isIncomplete(logs[$0], completedExerciseIds: completed)
        }
        guard !incomplete.isEmpty else { return nil }
        let focusedIndex = session.activeExerciseIds.first.flatMap { activeId in
            logs.firstIndex { $0.workoutExercise.exerciseId == activeId }
        }
        guard let focusedIndex else { return incomplete.last }
        if let previous = incomplete.last(where: { $0 < focusedIndex }) {
            return previous
        }
        if let last = incomplete.last, last != focusedIndex {
            return last
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
            incompleteCount: incompleteCount,
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
