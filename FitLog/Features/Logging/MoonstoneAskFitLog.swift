//
//  MoonstoneAskFitLog.swift
//  FitLog
//
//  Skip remaining sets on the focused incomplete exercise from Siri /
//  Shortcuts, plus next-set and ready-to-finish queries, so a mid-set
//  "I'm done with this one" / "what set am I on" / "can I finish"
//  check does not require opening the sheet (`like.history.logged` /
//  `like.rest.no_nag`). Empty / missing sessions, open placeholders,
//  already-complete rows, and rest days are not turned into a skip, a
//  set, or a start. Distinct from Tanzanite (undo last set / sets
//  logged / elapsed), Jasper (repeat this-session working set /
//  remaining / next incomplete), Tourmaline (last cardio duration /
//  last-set / current-exercise), Aquamarine (last History weight /
//  skip rest / rest remaining), Lapis (resume / last-session /
//  days-since), Peridot (finish / in-progress / last-finished),
//  Citrine (last-load query), the Siri start series (Onyx → Topaz),
//  and 999e (in-app finish-ready banner). Does not change freemium
//  rules.
//

import Foundation

enum MoonstoneAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let nothingToSkipDialog = "Nothing to skip."
    static let noNextSetDialog = "No next set."

    struct SkipRemainingTarget: Equatable {
        var exerciseIndex: Int
        var exerciseId: UUID
        var exerciseName: String
        var caption: String?
        var nextExerciseId: UUID?
        var nextExerciseName: String?
        var nextCaption: String?
    }

    static func querySnapshot(
        inProgress: WorkoutSession?,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.MoonstoneSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.MoonstoneSessionSnapshot()
        }
        let skip = skipRemainingTarget(in: live, displayUnit: displayUnit)
        let next = nextSetTarget(in: live, displayUnit: displayUnit)
        let finish = finishReadiness(in: live)
        return FitLogIntentBridge.MoonstoneSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            skipExerciseName: skip?.exerciseName,
            skipCaption: skip?.caption,
            nextAfterSkipName: skip?.nextExerciseName,
            nextAfterSkipCaption: skip?.nextCaption,
            canSkipRemaining: skip != nil,
            nextSetExerciseName: next?.exerciseName,
            nextSetNumber: next?.setNumber ?? 0,
            nextSetOf: next?.setOf ?? 0,
            nextSetLastCaption: next?.lastCaption,
            isCardioNextSet: next?.isCardio ?? false,
            remainingIncompleteCount: finish.incompleteCount,
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canSkipRemaining(snapshot: FitLogIntentBridge.MoonstoneSessionSnapshot?) -> Bool {
        snapshot?.canSkipRemaining == true
            && cleanedName(snapshot?.skipExerciseName) != nil
    }

    static func skipRemainingTarget(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> SkipRemainingTarget? {
        guard cleanedInProgress(session) != nil else { return nil }
        guard let skipIndex = skippableExerciseIndex(in: session) else { return nil }
        let log = session.exerciseLogs[skipIndex]
        guard let exerciseId = log.workoutExercise.exerciseId,
              let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
        else { return nil }

        let nextIndex = nextIncompleteIndex(in: session, after: skipIndex, excludingExerciseId: exerciseId)
        var nextId: UUID?
        var nextName: String?
        var nextCaption: String?
        if let nextIndex {
            let nextLog = session.exerciseLogs[nextIndex]
            nextId = nextLog.workoutExercise.exerciseId
            nextName = cleanedName(nextLog.workoutExercise.snapshot?.nameAtTimeOfLog)
            nextCaption = lastWorkCaption(in: nextLog, displayUnit: displayUnit)
        }

        return SkipRemainingTarget(
            exerciseIndex: skipIndex,
            exerciseId: exerciseId,
            exerciseName: name,
            caption: lastWorkCaption(in: log, displayUnit: displayUnit),
            nextExerciseId: nextId,
            nextExerciseName: nextName,
            nextCaption: nextCaption
        )
    }

    static func skipRemainingDialog(
        snapshot: FitLogIntentBridge.MoonstoneSessionSnapshot?
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard canSkipRemaining(snapshot: snapshot),
              let name = cleanedName(snapshot?.skipExerciseName)
        else {
            return nothingToSkipDialog
        }
        var parts = ["Skipped remaining on \(name)."]
        if let caption = cleanedName(snapshot?.skipCaption) {
            parts.append("Last was \(caption).")
        }
        if let nextName = cleanedName(snapshot?.nextAfterSkipName) {
            if let nextCaption = cleanedName(snapshot?.nextAfterSkipCaption) {
                parts.append("Next up: \(nextName), last \(nextCaption).")
            } else {
                parts.append("Next up: \(nextName).")
            }
        } else if snapshot?.hasOpenPlaceholder != true,
                  (snapshot?.remainingIncompleteCount ?? 1) <= 1 {
            parts.append("Ready to finish.")
        }
        return parts.joined(separator: " ")
    }

    static func nextSetDialog(
        snapshot: FitLogIntentBridge.MoonstoneSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if snapshot?.isReadyToFinish == true {
            return "No next set. \(workoutName) is ready to finish."
        }
        guard let name = cleanedName(snapshot?.nextSetExerciseName) else {
            if snapshot?.hasOpenPlaceholder == true {
                return "\(workoutName) still has an open slot."
            }
            return noNextSetDialog
        }
        if snapshot?.isCardioNextSet == true {
            if let caption = cleanedName(snapshot?.nextSetLastCaption) {
                return "\(name) still needs a duration. Last was \(caption)."
            }
            return "\(name) still needs a duration."
        }
        let number = max(1, snapshot?.nextSetNumber ?? 1)
        let of = max(number, snapshot?.nextSetOf ?? 1)
        var message = "\(name), set \(number) of \(of)."
        if let caption = cleanedName(snapshot?.nextSetLastCaption) {
            message += " Last was \(caption)."
        }
        return message
    }

    static func readyToFinishDialog(
        snapshot: FitLogIntentBridge.MoonstoneSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if snapshot?.isReadyToFinish == true {
            return "\(workoutName) is ready to finish."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        let leftover = max(0, snapshot?.remainingIncompleteCount ?? 0)
        if leftover == 1 {
            return "1 exercise still left on \(workoutName)."
        }
        if leftover > 1 {
            return "\(leftover) exercises still left on \(workoutName)."
        }
        return "\(workoutName) is not ready to finish."
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    // MARK: - Private

    private struct NextSetTarget: Equatable {
        var exerciseName: String
        var setNumber: Int
        var setOf: Int
        var lastCaption: String?
        var isCardio: Bool
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

    private static func skippableExerciseIndex(in session: WorkoutSession) -> Int? {
        let completed = Set(session.completedExerciseIds)
        if let activeId = session.activeExerciseIds.first,
           let activeIndex = session.exerciseLogs.firstIndex(where: {
               $0.workoutExercise.exerciseId == activeId
           }) {
            return isIncomplete(session.exerciseLogs[activeIndex], completedExerciseIds: completed)
                ? activeIndex
                : nil
        }
        return session.exerciseLogs.indices.first {
            isIncomplete(session.exerciseLogs[$0], completedExerciseIds: completed)
        }
    }

    private static func nextIncompleteIndex(
        in session: WorkoutSession,
        after skipIndex: Int,
        excludingExerciseId: UUID
    ) -> Int? {
        let completed = Set(session.completedExerciseIds)
        let logs = session.exerciseLogs
        let order = Array((skipIndex + 1)..<logs.count) + Array(0..<skipIndex)
        return order.first { index in
            let log = logs[index]
            guard log.workoutExercise.exerciseId != excludingExerciseId else { return false }
            return isIncomplete(log, completedExerciseIds: completed)
        }
    }

    private static func nextSetTarget(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> NextSetTarget? {
        let completed = Set(session.completedExerciseIds)
        let logs = session.exerciseLogs
        let preferredIndex: Int?
        if let activeId = session.activeExerciseIds.first,
           let activeIndex = logs.firstIndex(where: { $0.workoutExercise.exerciseId == activeId }),
           isIncomplete(logs[activeIndex], completedExerciseIds: completed) {
            preferredIndex = activeIndex
        } else {
            preferredIndex = logs.indices.first {
                isIncomplete(logs[$0], completedExerciseIds: completed)
            }
        }
        guard let preferredIndex else { return nil }
        let log = logs[preferredIndex]
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        if isCardioRow(log) {
            return NextSetTarget(
                exerciseName: name,
                setNumber: 0,
                setOf: 0,
                lastCaption: lastWorkCaption(in: log, displayUnit: displayUnit),
                isCardio: true
            )
        }
        let done = log.workingSetCount
        let prescribed = max(1, log.workoutExercise.recommendedSets)
        return NextSetTarget(
            exerciseName: name,
            setNumber: done + 1,
            setOf: prescribed,
            lastCaption: lastWorkCaption(in: log, displayUnit: displayUnit),
            isCardio: false
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
}
