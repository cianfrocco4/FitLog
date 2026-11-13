//
//  FluoriteAskFitLog.swift
//  FitLog
//
//  Reset a live rest countdown to the focused row's prescribed rest from
//  Siri / Shortcuts, plus previous-exercise-target and this-exercise
//  last-working queries, so a mid-session "restart rest" / "what was
//  before this" / "what did I last hit on this" check does not require
//  hunting through the sheet (`like.history.logged` / `like.rest.no_nag`).
//  Empty / missing sessions, idle rest timers, open placeholders, and
//  rest days are not turned into a rest start, a set, or a start.
//  Distinct from RestTimerIntent (starts rest), Zircon (add rest /
//  this-exercise target / prescribed rest query), Obsidian (subtract
//  rest / next-exercise target / next last working), Aquamarine (skip
//  rest / rest remaining), Spinel (go to previous / previous name /
//  this-exercise sets), Alexandrite (go to next), Jasper (next-exercise
//  name), Moonstone (skip remaining / next set / ready-to-finish),
//  Tanzanite (undo / sets logged / elapsed), Tourmaline (last cardio /
//  last-set / current-exercise), Citrine (last-load query), the Siri
//  start series (Onyx → Topaz), and 999e (in-app finish-ready banner).
//  Does not change freemium rules.
//

import Foundation

enum FluoriteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let nothingFocusedDialog = "Nothing is focused."
    static let noPreviousExerciseDialog = "No previous exercise."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        displayUnit: WeightDisplayUnit = .pounds,
        now: Date = Date()
    ) -> FitLogIntentBridge.FluoriteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.FluoriteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live, displayUnit: displayUnit)
        let previous = previousIncompleteExercise(in: live, displayUnit: displayUnit)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        let prescribed = focused?.prescribedRestSeconds
        return FitLogIntentBridge.FluoriteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsCardio: focused?.isCardio ?? false,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            focusedLastWorkingCaption: focused?.lastWorkingCaption,
            focusedPrescribedRestSeconds: prescribed,
            previousExerciseName: previous?.exerciseName,
            previousIsCardio: previous?.isCardio ?? false,
            previousTargetCaption: previous?.targetCaption,
            canResetRest: canReset(
                remaining: remaining,
                prescribed: prescribed,
                focusedIsCardio: focused?.isCardio ?? false
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canResetRest(
        snapshot: FitLogIntentBridge.FluoriteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canReset(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            prescribed: snapshot?.focusedPrescribedRestSeconds,
            focusedIsCardio: snapshot?.focusedIsCardio ?? false
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func resetRestSeconds(
        snapshot: FitLogIntentBridge.FluoriteSessionSnapshot?
    ) -> Int? {
        cappedPrescribedRest(snapshot?.focusedPrescribedRestSeconds)
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.FluoriteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func resetRestDialog(
        snapshot: FitLogIntentBridge.FluoriteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            if snapshot?.focusedIsCardio == true {
                return "\(focused) is cardio."
            }
            guard let target = resetRestSeconds(snapshot: snapshot) else {
                return "No rest prescription on \(focused)."
            }
            if let remaining = remainingRestSeconds(snapshot: snapshot, now: now),
               remaining == target {
                return "Rest already at prescribed \(CardioMetricsCalculator.spokenDuration(seconds: target))."
            }
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
        }
        if snapshot?.hasOpenPlaceholder == true,
           let workoutName = cleanedName(snapshot?.inProgressWorkoutName) {
            return "\(workoutName) still has an open slot."
        }
        return nothingFocusedDialog
    }

    static func previousExerciseTargetDialog(
        snapshot: FitLogIntentBridge.FluoriteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let previous = cleanedName(snapshot?.previousExerciseName) {
            if let caption = cleanedName(snapshot?.previousTargetCaption) {
                return "Previous is \(previous): \(caption)."
            }
            if snapshot?.previousIsCardio == true {
                return "Previous is \(previous). It is cardio."
            }
            return "Previous is \(previous). No target."
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

    static func thisExerciseLastWorkingDialog(
        snapshot: FitLogIntentBridge.FluoriteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let focused = cleanedName(snapshot?.focusedExerciseName) {
            if let caption = cleanedName(snapshot?.focusedLastWorkingCaption) {
                return "\(focused). Last was \(caption)."
            }
            return "\(focused). No working set logged yet."
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
        var lastWorkingCaption: String?
        var prescribedRestSeconds: Int?
    }

    private struct PreviousExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
        var targetCaption: String?
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canReset(
        remaining: Int?,
        prescribed: Int?,
        focusedIsCardio: Bool
    ) -> Bool {
        guard !focusedIsCardio else { return false }
        guard remainingRestSecondsIsLive(remaining) else { return false }
        guard let target = cappedPrescribedRest(prescribed) else { return false }
        return remaining != target
    }

    private static func remainingRestSecondsIsLive(_ remaining: Int?) -> Bool {
        guard let remaining else { return false }
        return remaining > 0
    }

    private static func cappedPrescribedRest(_ prescribed: Int?) -> Int? {
        guard let prescribed, prescribed > 0 else { return nil }
        return min(maxRestSeconds, max(minRestSeconds, prescribed))
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
        let cardio = isCardioRow(log)
        return FocusedExercise(
            exerciseName: name,
            isCardio: cardio,
            isIncomplete: isIncomplete(log, completedExerciseIds: completed),
            lastWorkingCaption: lastWorkCaption(in: log, displayUnit: displayUnit),
            prescribedRestSeconds: cardio ? nil : prescribedRestSeconds(in: log)
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
            targetCaption: targetCaption(in: log, isCardio: cardio)
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

    private static func prescribedRestSeconds(in log: ExerciseLog) -> Int? {
        if let override = log.sessionRestOverrideSeconds, override > 0 {
            return override
        }
        let planDefault = log.workoutExercise.defaultRestTime
        return planDefault > 0 ? planDefault : nil
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

extension FitLogIntentBridge.FluoriteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
