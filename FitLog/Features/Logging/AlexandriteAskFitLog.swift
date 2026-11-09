//
//  AlexandriteAskFitLog.swift
//  FitLog
//
//  Focus the next incomplete exercise from Siri / Shortcuts, plus
//  remaining-exercises and current-workout queries, so a mid-session
//  "next exercise" / "what's left" / "what am I doing" check does not
//  require hunting through the sheet (`like.history.logged` /
//  `like.rest.no_nag`). Empty / missing sessions, open placeholders,
//  already-focused last leftover rows, and rest days are not turned
//  into a skip, a set, or a start. Distinct from Moonstone (skip
//  remaining / next set / ready-to-finish), Tanzanite (undo / sets
//  logged / elapsed), Jasper (repeat this-session working set /
//  remaining / next incomplete query), Tourmaline (last cardio /
//  last-set / current-exercise query), Aquamarine (last History
//  weight / skip rest / rest remaining), Lapis (resume / last-session
//  / days-since), Peridot (finish / in-progress / last-finished),
//  Citrine (last-load query), the Siri start series (Onyx → Topaz),
//  and 999e (in-app finish-ready banner). Does not change freemium
//  rules.
//

import Foundation

enum AlexandriteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noNextExerciseDialog = "No next exercise."

    struct FocusNextTarget: Equatable {
        var exerciseIndex: Int
        var exerciseId: UUID
        var exerciseName: String
        var caption: String?
    }

    static func querySnapshot(
        inProgress: WorkoutSession?,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.AlexandriteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.AlexandriteSessionSnapshot()
        }
        let focused = focusedExercise(in: live, displayUnit: displayUnit)
        let next = focusNextTarget(in: live, displayUnit: displayUnit)
        let leftover = leftoverExercises(in: live, displayUnit: displayUnit)
        let finish = finishReadiness(in: live)
        return FitLogIntentBridge.AlexandriteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedCaption: focused?.caption,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            nextExerciseName: next?.exerciseName,
            nextExerciseCaption: next?.caption,
            canFocusNext: next != nil,
            remainingExerciseNames: leftover.names,
            remainingCount: leftover.count,
            firstRemainingCaption: leftover.firstCaption,
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canFocusNext(snapshot: FitLogIntentBridge.AlexandriteSessionSnapshot?) -> Bool {
        snapshot?.canFocusNext == true
            && cleanedName(snapshot?.nextExerciseName) != nil
    }

    static func focusNextTarget(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> FocusNextTarget? {
        guard cleanedInProgress(session) != nil else { return nil }
        guard let nextIndex = nextIncompleteIndex(in: session) else { return nil }
        let log = session.exerciseLogs[nextIndex]
        guard let exerciseId = log.workoutExercise.exerciseId,
              let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
        else { return nil }
        return FocusNextTarget(
            exerciseIndex: nextIndex,
            exerciseId: exerciseId,
            exerciseName: name,
            caption: lastWorkCaption(in: log, displayUnit: displayUnit)
        )
    }

    static func focusNextDialog(
        snapshot: FitLogIntentBridge.AlexandriteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if canFocusNext(snapshot: snapshot),
           let name = cleanedName(snapshot?.nextExerciseName) {
            if let caption = cleanedName(snapshot?.nextExerciseCaption) {
                return "Now on \(name). Last was \(caption)."
            }
            return "Now on \(name)."
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName),
           snapshot?.focusedIsIncomplete == true,
           (snapshot?.remainingCount ?? 0) <= 1 {
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

    static func remainingExercisesDialog(
        snapshot: FitLogIntentBridge.AlexandriteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let names = (snapshot?.remainingExerciseNames ?? []).compactMap(cleanedName)
        let leftover = max(names.count, snapshot?.remainingCount ?? 0)
        if leftover > 0 {
            let list = spokenNameList(names, total: leftover)
            var message = "\(list) still left on \(workoutName)."
            if leftover == 1, let caption = cleanedName(snapshot?.firstRemainingCaption) {
                message += " Last was \(caption)."
            }
            return message
        }
        if snapshot?.isReadyToFinish == true {
            return "\(workoutName) is ready to finish."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "Nothing left on \(workoutName)."
    }

    static func currentWorkoutDialog(
        snapshot: FitLogIntentBridge.AlexandriteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        var parts = ["\(workoutName) is in progress."]
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            parts.append("Focused on \(focused).")
            if let caption = cleanedName(snapshot?.focusedCaption) {
                parts.append("Last was \(caption).")
            }
        }
        if snapshot?.isReadyToFinish == true {
            parts.append("Ready to finish.")
        } else if snapshot?.hasOpenPlaceholder == true,
                  (snapshot?.remainingCount ?? 0) == 0 {
            parts.append("It still has an open slot.")
        }
        return parts.joined(separator: " ")
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
    }

    private struct LeftoverExercises: Equatable {
        var names: [String]
        var count: Int
        var firstCaption: String?
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
            isIncomplete: isIncomplete(log, completedExerciseIds: completed)
        )
    }

    /// Next incomplete startable row after the focused exercise, wrapping.
    /// Returns nil when the only leftover is already focused (does not wrap onto self).
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

    private static func leftoverExercises(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> LeftoverExercises {
        let completed = Set(session.completedExerciseIds)
        var names: [String] = []
        var firstCaption: String?
        for log in session.exerciseLogs where isIncomplete(log, completedExerciseIds: completed) {
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            if names.isEmpty {
                firstCaption = lastWorkCaption(in: log, displayUnit: displayUnit)
            }
            names.append(name)
        }
        return LeftoverExercises(
            names: names,
            count: names.count,
            firstCaption: firstCaption
        )
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

    private static func spokenNameList(_ names: [String], total: Int) -> String {
        let leftover = max(total, names.count)
        switch leftover {
        case 0:
            return ""
        case 1:
            return names.first ?? ""
        case 2:
            if names.count >= 2 {
                return "\(names[0]) and \(names[1])"
            }
            return names.first ?? ""
        case 3:
            if names.count >= 3 {
                return "\(names[0]), \(names[1]), and \(names[2])"
            }
            if names.count == 2 {
                return "\(names[0]), \(names[1]), and 1 more"
            }
            return names.first ?? ""
        default:
            if names.count >= 2 {
                return "\(names[0]), \(names[1]), and \(leftover - 2) more"
            }
            return names.first ?? ""
        }
    }
}
