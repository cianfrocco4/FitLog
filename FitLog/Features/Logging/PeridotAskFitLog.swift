//
//  PeridotAskFitLog.swift
//  FitLog
//
//  Finish the in-progress workout from Siri / Shortcuts, plus read-only
//  in-progress and last-finished queries, so log → Finish → History
//  does not require hunting for Done (`like.history.logged` /
//  `improve.history.quick_log`). Empty sessions are not finished
//  (`like.rest.no_nag`). Distinct from Onyx (next plan), Garnet (next
//  saved), Amethyst (tomorrow / last duration), Emerald (last strength),
//  Sapphire (today / last cardio), Ruby (Repeat Yesterday), Citrine
//  (last-workout queries), Topaz (last saved start), and 999e (in-app
//  finish-ready banner). Does not change freemium rules.
//

import Foundation

enum PeridotAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let nothingLoggedDialog = "Nothing logged yet — open Workout Log AI to finish or cancel."
    static let noFinishedDialog = "No finished workout in History yet."

    static func querySnapshot(
        inProgress: WorkoutSession?,
        completedSessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.PeridotFinishSnapshot {
        let live = cleanedInProgress(inProgress)
        let lastFinished = completedNewestFirst(completedSessions).first
        return FitLogIntentBridge.PeridotFinishSnapshot(
            inProgressWorkoutName: live.flatMap { cleanedWorkoutName($0.workout.name) },
            inProgressLoggedSetCount: live.map(loggedSetCount) ?? 0,
            inProgressCaption: live.flatMap { sessionCaption(from: $0, displayUnit: displayUnit) },
            lastFinishedWorkoutName: lastFinished.flatMap { cleanedWorkoutName($0.workout.name) },
            lastFinishedCaption: lastFinished.flatMap { sessionCaption(from: $0, displayUnit: displayUnit) }
        )
    }

    static func canFinish(snapshot: FitLogIntentBridge.PeridotFinishSnapshot?) -> Bool {
        guard let snapshot else { return false }
        guard cleanedWorkoutName(snapshot.inProgressWorkoutName) != nil else { return false }
        return snapshot.inProgressLoggedSetCount > 0
    }

    static func finishWorkoutDialog(
        snapshot: FitLogIntentBridge.PeridotFinishSnapshot?
    ) -> String {
        guard let name = cleanedWorkoutName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let count = max(0, snapshot?.inProgressLoggedSetCount ?? 0)
        guard count > 0 else { return nothingLoggedDialog }
        let base = "Finishing \(name). \(setCountPhrase(count))."
        if let caption = cleanedCaption(snapshot?.inProgressCaption) {
            return "\(base) \(caption)."
        }
        return base
    }

    static func inProgressWorkoutDialog(
        snapshot: FitLogIntentBridge.PeridotFinishSnapshot?
    ) -> String {
        guard let name = cleanedWorkoutName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let count = max(0, snapshot?.inProgressLoggedSetCount ?? 0)
        if count == 0 {
            return "\(name) is in progress. Nothing logged yet."
        }
        let base = "\(name) is in progress. \(setCountPhrase(count))."
        if let caption = cleanedCaption(snapshot?.inProgressCaption) {
            return "\(base) \(caption)."
        }
        return base
    }

    static func lastFinishedWorkoutDialog(
        snapshot: FitLogIntentBridge.PeridotFinishSnapshot?
    ) -> String {
        guard let name = cleanedWorkoutName(snapshot?.lastFinishedWorkoutName) else {
            return noFinishedDialog
        }
        let base = "Last finished workout is \(name) in History."
        if let caption = cleanedCaption(snapshot?.lastFinishedCaption) {
            return "\(base) \(caption)."
        }
        return base
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
        guard cleanedWorkoutName(session.workout.name) != nil else { return nil }
        return session
    }

    private static func cleanedWorkoutName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cleanedCaption(_ caption: String?) -> String? {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func loggedSetCount(_ session: WorkoutSession) -> Int {
        session.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
    }

    private static func setCountPhrase(_ count: Int) -> String {
        count == 1 ? "1 set logged" : "\(count) sets logged"
    }

    private static func completedNewestFirst(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private static func sessionCaption(
        from session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> String? {
        for log in session.exerciseLogs {
            if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
                return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
            }
            if let sec = lastCardioDurationSec(in: log) {
                return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
            }
        }
        return nil
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.first(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
