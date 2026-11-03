//
//  LapisAskFitLog.swift
//  FitLog
//
//  Resume the in-progress workout from Siri / Shortcuts, plus read-only
//  last-session exercise list and days-since-last-workout queries, so
//  log → leave → resume and History last-load do not require a Home
//  round trip (`like.history.logged` / `improve.home.last_weight` /
//  `improve.history.quick_log`). Empty / missing sessions are not
//  started (`like.rest.no_nag` / `improve.home.already_trained`).
//  Distinct from Peridot (finish / in-progress / last-finished name),
//  Onyx (next plan), Garnet (next saved), Amethyst (tomorrow / last
//  duration), Emerald (last strength), Sapphire (today / last cardio),
//  Ruby (Repeat Yesterday), Citrine (last-workout queries), Topaz
//  (last saved start), and 999e (in-app finish-ready banner).
//  Does not change freemium rules.
//

import Foundation

enum LapisAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noFinishedDialog = "No finished workout in History yet."
    static let maxSpokenExerciseLines = 5
    static let maxStoredExerciseLines = 8

    static func querySnapshot(
        inProgress: WorkoutSession?,
        completedSessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.LapisHistorySnapshot {
        let live = cleanedInProgress(inProgress)
        let lastFinished = completedNewestFirst(completedSessions).first
        return FitLogIntentBridge.LapisHistorySnapshot(
            inProgressWorkoutName: live.flatMap { cleanedWorkoutName($0.workout.name) },
            inProgressLoggedSetCount: live.map(loggedSetCount) ?? 0,
            inProgressCaption: live.flatMap { sessionCaption(from: $0, displayUnit: displayUnit) },
            lastFinishedWorkoutName: lastFinished.flatMap { cleanedWorkoutName($0.workout.name) },
            lastFinishedCaption: lastFinished.flatMap { sessionCaption(from: $0, displayUnit: displayUnit) },
            lastFinishedEndedAt: lastFinished.flatMap { $0.endTime ?? $0.startTime },
            lastFinishedExerciseLines: lastFinished.map { exerciseLines(from: $0, displayUnit: displayUnit) } ?? []
        )
    }

    static func canResume(snapshot: FitLogIntentBridge.LapisHistorySnapshot?) -> Bool {
        cleanedWorkoutName(snapshot?.inProgressWorkoutName) != nil
    }

    static func resumeWorkoutDialog(
        snapshot: FitLogIntentBridge.LapisHistorySnapshot?
    ) -> String {
        guard let name = cleanedWorkoutName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        let count = max(0, snapshot?.inProgressLoggedSetCount ?? 0)
        if count == 0 {
            return "Resuming \(name). Nothing logged yet."
        }
        let base = "Resuming \(name). \(setCountPhrase(count))."
        if let caption = cleanedCaption(snapshot?.inProgressCaption) {
            return "\(base) \(caption)."
        }
        return base
    }

    static func lastSessionExercisesDialog(
        snapshot: FitLogIntentBridge.LapisHistorySnapshot?
    ) -> String {
        guard let name = cleanedWorkoutName(snapshot?.lastFinishedWorkoutName) else {
            return noFinishedDialog
        }
        let lines = snapshot?.lastFinishedExerciseLines ?? []
        guard !lines.isEmpty else {
            return "Last session \(name) has no logged exercises yet."
        }
        let spoken = Array(lines.prefix(maxSpokenExerciseLines))
        let remainder = lines.count - spoken.count
        var body = spoken.joined(separator: ", ")
        if remainder > 0 {
            body += ", and \(remainder) more"
        }
        return "Last session \(name) in History: \(body)."
    }

    static func daysSinceLastWorkoutDialog(
        snapshot: FitLogIntentBridge.LapisHistorySnapshot?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let name = cleanedWorkoutName(snapshot?.lastFinishedWorkoutName),
              let endedAt = snapshot?.lastFinishedEndedAt
        else {
            return noFinishedDialog
        }
        let days = calendarDays(from: endedAt, to: now, calendar: calendar)
        let when: String
        switch days {
        case ...(-1):
            when = "You already trained today"
        case 0:
            when = "You already trained today"
        case 1:
            when = "You last trained yesterday"
        default:
            when = "You last trained \(days) days ago"
        }
        let base = "\(when). Last workout was \(name)."
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

    static func calendarDays(
        from end: Date,
        to now: Date,
        calendar: Calendar
    ) -> Int {
        let start = calendar.startOfDay(for: end)
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: start, to: today).day ?? 0
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

    private static func exerciseLines(
        from session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> [String] {
        var lines: [String] = []
        for log in session.exerciseLogs {
            guard lines.count < maxStoredExerciseLines else { break }
            guard let name = exerciseName(from: log) else { continue }
            if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
                lines.append("\(name) \(working.weightRepsDisplaySummary(displayUnit: displayUnit))")
            } else if let sec = lastCardioDurationSec(in: log) {
                lines.append("\(name) \(CardioMetricsCalculator.formatDuration(seconds: sec))")
            } else if !log.loggedSets.isEmpty {
                lines.append(name)
            }
        }
        return lines
    }

    private static func exerciseName(from log: ExerciseLog) -> String? {
        if log.workoutExercise.isSlotPlaceholder { return nil }
        return cleanedWorkoutName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.first(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
