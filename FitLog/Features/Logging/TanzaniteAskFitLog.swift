//
//  TanzaniteAskFitLog.swift
//  FitLog
//
//  Undo the last real logged set from Siri / Shortcuts, plus sets-logged
//  and elapsed-workout queries, so a logging mistake or a "how far am I"
//  check does not require opening the sheet (`like.history.logged` /
//  `like.rest.no_nag`). Empty / missing sessions, placeholder 0×0
//  rows, and rest days are not turned into an undo, a set, or a start.
//  Distinct from Jasper (repeat this-session working set / remaining /
//  next incomplete), Tourmaline (last cardio duration / last-set /
//  current-exercise), Aquamarine (last History weight / skip rest /
//  rest remaining), Lapis (resume / last-session / days-since),
//  Peridot (finish / in-progress / last-finished), Citrine (last-load
//  query), the Siri start series (Onyx → Topaz), and 999e (in-app
//  finish-ready banner). Does not change freemium rules.
//

import Foundation

enum TanzaniteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noSetToUndoDialog = "No set to undo."
    static let noSetsLoggedDialog = "No sets logged yet."

    struct UndoableLastSet: Equatable {
        var exerciseIndex: Int
        var setIndex: Int
        var exerciseName: String
        var caption: String
    }

    static func querySnapshot(
        inProgress: WorkoutSession?,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.TanzaniteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.TanzaniteSessionSnapshot()
        }
        let undoable = undoableLastSet(in: live, displayUnit: displayUnit)
        let counts = loggedSetCounts(in: live)
        return FitLogIntentBridge.TanzaniteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            undoExerciseName: undoable?.exerciseName,
            undoCaption: undoable?.caption,
            canUndoLastSet: undoable != nil,
            loggedSetCount: counts.total,
            workingSetCount: counts.working,
            startTimeEpoch: live.startTime.timeIntervalSince1970
        )
    }

    static func canUndoLastSet(snapshot: FitLogIntentBridge.TanzaniteSessionSnapshot?) -> Bool {
        snapshot?.canUndoLastSet == true
            && cleanedName(snapshot?.undoExerciseName) != nil
    }

    static func undoableLastSet(
        in session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> UndoableLastSet? {
        guard cleanedInProgress(session) != nil else { return nil }
        var best: (exerciseIndex: Int, setIndex: Int, timestamp: Date, isActive: Bool)?
        let activeId = session.activeExerciseIds.first

        for exerciseIndex in session.exerciseLogs.indices {
            let log = session.exerciseLogs[exerciseIndex]
            guard !log.workoutExercise.isSlotPlaceholder else { continue }
            guard cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) != nil else { continue }
            let isActive = log.workoutExercise.exerciseId != nil
                && log.workoutExercise.exerciseId == activeId
            for setIndex in log.loggedSets.indices {
                let set = log.loggedSets[setIndex]
                guard isRealLoggedSet(set) else { continue }
                let candidate = (exerciseIndex, setIndex, set.timestamp, isActive)
                if let current = best {
                    if set.timestamp > current.timestamp
                        || (set.timestamp == current.timestamp && isActive && !current.isActive)
                        || (set.timestamp == current.timestamp
                            && isActive == current.isActive
                            && (exerciseIndex, setIndex) > (current.exerciseIndex, current.setIndex))
                    {
                        best = candidate
                    }
                } else {
                    best = candidate
                }
            }
        }

        guard let best else { return nil }
        let log = session.exerciseLogs[best.exerciseIndex]
        guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
            return nil
        }
        let set = log.loggedSets[best.setIndex]
        guard let caption = caption(for: set, displayUnit: displayUnit) else { return nil }
        return UndoableLastSet(
            exerciseIndex: best.exerciseIndex,
            setIndex: best.setIndex,
            exerciseName: name,
            caption: caption
        )
    }

    static func undoLastSetDialog(
        snapshot: FitLogIntentBridge.TanzaniteSessionSnapshot?
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard canUndoLastSet(snapshot: snapshot),
              let name = cleanedName(snapshot?.undoExerciseName)
        else {
            return noSetToUndoDialog
        }
        if let caption = cleanedName(snapshot?.undoCaption) {
            return "Undid \(name). \(caption)."
        }
        return "Undid \(name)."
    }

    static func setsLoggedDialog(
        snapshot: FitLogIntentBridge.TanzaniteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let total = max(0, snapshot?.loggedSetCount ?? 0)
        guard total > 0 else { return noSetsLoggedDialog }
        let noun = total == 1 ? "set" : "sets"
        let base = "\(total) \(noun) logged in \(workoutName)."
        let working = max(0, snapshot?.workingSetCount ?? 0)
        if working != total {
            let workingNoun = working == 1 ? "working set" : "working sets"
            return "\(base) \(working) \(workingNoun)."
        }
        return base
    }

    static func elapsedWorkoutDialog(
        snapshot: FitLogIntentBridge.TanzaniteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else {
            return noInProgressDialog
        }
        guard let elapsed = elapsedSeconds(snapshot: snapshot, now: now) else {
            return noInProgressDialog
        }
        return "Workout elapsed: \(CardioMetricsCalculator.spokenDuration(seconds: elapsed))."
    }

    static func elapsedSeconds(
        snapshot: FitLogIntentBridge.TanzaniteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        guard cleanedName(snapshot?.inProgressWorkoutName) != nil else { return nil }
        guard let start = snapshot?.startTime else { return nil }
        let elapsed = Int(floor(now.timeIntervalSince(start)))
        return elapsed >= 0 ? elapsed : nil
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    // MARK: - Private

    private static func cleanedInProgress(_ session: WorkoutSession?) -> WorkoutSession? {
        guard let session, session.endTime == nil else { return nil }
        guard cleanedName(session.workout.name) != nil else { return nil }
        return session
    }

    private static func cleanedName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func loggedSetCounts(in session: WorkoutSession) -> (total: Int, working: Int) {
        var total = 0
        var working = 0
        for log in session.exerciseLogs {
            guard !log.workoutExercise.isSlotPlaceholder else { continue }
            for set in log.loggedSets where isRealLoggedSet(set) {
                total += 1
                if set.countsTowardRecommendedSets {
                    working += 1
                }
            }
        }
        return (total, working)
    }

    private static func isRealLoggedSet(_ set: LoggedSet) -> Bool {
        if set.isCardioEntry {
            let duration = set.cardioMetrics?.durationSec ?? 0
            let distance = set.cardioMetrics?.distanceM ?? 0
            return duration > 0 || distance > 0
        }
        return set.reps > 0
    }

    private static func caption(for set: LoggedSet, displayUnit: WeightDisplayUnit) -> String? {
        if set.isCardioEntry {
            if let seconds = set.cardioMetrics?.durationSec, seconds > 0 {
                return CardioMetricsCalculator.spokenDuration(seconds: seconds)
            }
            return cleanedName(set.cardioDisplaySummary)
        }
        return cleanedName(set.weightRepsDisplaySummary(displayUnit: displayUnit))
    }
}
