//
//  JadeAskFitLog.swift
//  FitLog
//
//  Halve a live rest countdown from Siri / Shortcuts, plus previous-exercise
//  last-working and this-exercise remaining-sets queries, so a mid-session
//  "cut rest in half" / "what did I last hit before this" / "how many
//  sets left on this" check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing sessions,
//  idle rest timers, open placeholders, and rest days are not turned into
//  a rest start, a skip, a set, or a start. Distinct from RestTimerIntent
//  (starts rest), Zircon (add rest / this-exercise target / prescribed
//  rest), Obsidian (subtract 30s / next-exercise target / next last
//  working), Fluorite (reset rest / previous-exercise target / this
//  last working), Aquamarine (skip rest / rest remaining), Spinel
//  (go to previous / previous name / this-exercise sets), Jasper
//  (repeat / session remaining / next incomplete), Moonstone (skip
//  remaining / next set / ready-to-finish), Tanzanite (undo / sets
//  logged / elapsed), Tourmaline (last cardio / last-set /
//  current-exercise), Citrine (last-load query), the Siri start series
//  (Onyx → Topaz), and 999e (in-app finish-ready banner). Does not
//  change freemium rules.
//

import Foundation

enum JadeAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let restAlreadyMinimumDialog = "Rest already at 1 second."
    static let nothingFocusedDialog = "Nothing is focused."
    static let noPreviousExerciseDialog = "No previous exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        displayUnit: WeightDisplayUnit = .pounds,
        now: Date = Date()
    ) -> FitLogIntentBridge.JadeSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.JadeSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let previous = previousIncompleteExercise(in: live, displayUnit: displayUnit)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.JadeSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsCardio: focused?.isCardio ?? false,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedRemainingSetCount: focused?.remainingSetCount ?? 0,
            previousExerciseName: previous?.exerciseName,
            previousIsCardio: previous?.isCardio ?? false,
            previousLastWorkingCaption: previous?.lastWorkingCaption,
            canHalveRest: canHalve(remaining: remaining),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canHalveRest(
        snapshot: FitLogIntentBridge.JadeSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canHalve(remaining: remainingRestSeconds(snapshot: snapshot, now: now))
            && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func halvedRestSeconds(
        snapshot: FitLogIntentBridge.JadeSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now),
              canHalve(remaining: remaining)
        else { return nil }
        return min(maxRestSeconds, max(minRestSeconds, remaining / 2))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.JadeSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func halveRestDialog(
        snapshot: FitLogIntentBridge.JadeSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let remaining = remainingRestSeconds(snapshot: snapshot, now: now) else {
            return noRestTimerDialog
        }
        guard let halved = halvedRestSeconds(snapshot: snapshot, now: now) else {
            return remaining == minRestSeconds ? restAlreadyMinimumDialog : noRestTimerDialog
        }
        return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: halved))."
    }

    static func previousExerciseLastWorkingDialog(
        snapshot: FitLogIntentBridge.JadeSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let previous = cleanedName(snapshot?.previousExerciseName) {
            if let caption = cleanedName(snapshot?.previousLastWorkingCaption) {
                return "Previous is \(previous). Last was \(caption)."
            }
            if snapshot?.previousIsCardio == true {
                return "Previous is \(previous). No duration logged yet."
            }
            return "Previous is \(previous). No working set logged yet."
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

    static func thisExerciseRemainingSetsDialog(
        snapshot: FitLogIntentBridge.JadeSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            if snapshot?.focusedIsCardio == true {
                if (snapshot?.focusedRemainingSetCount ?? 0) > 0 {
                    return "\(focused) still needs a duration."
                }
                return "No duration left on \(focused)."
            }
            let left = max(0, snapshot?.focusedRemainingSetCount ?? 0)
            if left == 0 {
                return "No sets left on \(focused)."
            }
            if left == 1 {
                return "1 set left on \(focused)."
            }
            return "\(left) sets left on \(focused)."
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
        var isCardio: Bool
        var isIncomplete: Bool
        var remainingSetCount: Int
    }

    private struct PreviousExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var lastWorkingCaption: String?
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canHalve(remaining: Int?) -> Bool {
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
        let cardio = isCardioRow(log)
        let incomplete = isIncomplete(log, completedExerciseIds: completed)
        return FocusedExercise(
            exerciseName: name,
            isCardio: cardio,
            isIncomplete: incomplete,
            remainingSetCount: remainingSets(in: log, completedExerciseIds: completed)
        )
    }

    private static func previousIncompleteExercise(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> PreviousExercise? {
        guard let previousIndex = previousIncompleteIndex(in: session) else { return nil }
        let log = session.exerciseLogs[previousIndex]
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        let cardio = isCardioRow(log)
        return PreviousExercise(
            exerciseName: name,
            isCardio: cardio,
            lastWorkingCaption: lastWorkCaption(in: log, displayUnit: displayUnit)
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

extension FitLogIntentBridge.JadeSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
