//
//  OnyxAskFitLog.swift
//  FitLog
//
//  Start the next assigned *training* day after today (skip rest /
//  unscheduled), a read-only next-plan query, and this week's plan list
//  so plan-ahead skips a Home or History round trip. Distinct from
//  Garnet (next saved library workout), Amethyst (tomorrow's assigned
//  day / last-session duration), Emerald (last strength / this-week
//  completed count), Sapphire (today's plan / last cardio /
//  did-I-train), Ruby (Repeat Yesterday + Readiness / Today's Workout
//  queries), Citrine (Last Workout / Last Weight queries), and Topaz
//  (unnamed Start of last saved library workout). Does not change
//  freemium rules.
//

import Foundation

enum OnyxAskFitLog {
    static let noUpcomingPlanDialog = "No upcoming workout is assigned."
    static let noWeekPlanDialog = "No plan scheduled this week."

    static func querySnapshot(
        from sessions: [WorkoutSession],
        upcomingTrainingDays: [FitLogIntentBridge.OnyxUpcomingTraining],
        thisWeekPlanLines: [String],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.OnyxNextPlanSnapshot {
        var lastCaptionByWorkoutName: [String: String] = [:]

        for session in completedNewestFirst(sessions) {
            let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = workoutNameKey(name)
            if lastCaptionByWorkoutName[key] == nil,
               let caption = sessionCaption(from: session, displayUnit: displayUnit),
               !key.isEmpty {
                lastCaptionByWorkoutName[key] = caption
            }
        }

        let cleanedUpcoming = upcomingTrainingDays.compactMap { day -> FitLogIntentBridge.OnyxUpcomingTraining? in
            let name = day.workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isStartableWorkoutName(name) else { return nil }
            let weekday = day.weekdayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return FitLogIntentBridge.OnyxUpcomingTraining(
                weekdayLabel: weekday,
                workoutName: name
            )
        }

        let cleanedWeekLines = thisWeekPlanLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return FitLogIntentBridge.OnyxNextPlanSnapshot(
            upcomingTrainingDays: cleanedUpcoming,
            thisWeekPlanLines: cleanedWeekLines,
            lastCaptionByWorkoutName: lastCaptionByWorkoutName
        )
    }

    static func isStartableWorkoutName(_ name: String?) -> Bool {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return false }
        if trimmed == "—" { return false }
        if trimmed.localizedCaseInsensitiveCompare("Rest") == .orderedSame { return false }
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame { return false }
        if trimmed.localizedCaseInsensitiveCompare("No plan scheduled") == .orderedSame { return false }
        return true
    }

    static func nextTrainingDay(
        snapshot: FitLogIntentBridge.OnyxNextPlanSnapshot?
    ) -> FitLogIntentBridge.OnyxUpcomingTraining? {
        snapshot?.upcomingTrainingDays.first(where: { isStartableWorkoutName($0.workoutName) })
    }

    static func isStartableNextPlan(
        snapshot: FitLogIntentBridge.OnyxNextPlanSnapshot?
    ) -> Bool {
        nextTrainingDay(snapshot: snapshot) != nil
    }

    static func startNextPlanWorkoutDialog(
        snapshot: FitLogIntentBridge.OnyxNextPlanSnapshot?
    ) -> String {
        guard let day = nextTrainingDay(snapshot: snapshot) else {
            return noUpcomingPlanDialog
        }
        let named = startingPhrase(for: day)
        if let caption = lastCaption(forWorkoutName: day.workoutName, snapshot: snapshot) {
            return "\(named) \(caption)."
        }
        return "\(named)"
    }

    static func nextPlanWorkoutDialog(
        snapshot: FitLogIntentBridge.OnyxNextPlanSnapshot?
    ) -> String {
        guard let day = nextTrainingDay(snapshot: snapshot) else {
            return noUpcomingPlanDialog
        }
        let named = nextPlanPhrase(for: day)
        if let caption = lastCaption(forWorkoutName: day.workoutName, snapshot: snapshot) {
            return "\(named) \(caption)."
        }
        return named
    }

    static func thisWeeksPlanDialog(
        snapshot: FitLogIntentBridge.OnyxNextPlanSnapshot?
    ) -> String {
        let lines = snapshot?.thisWeekPlanLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        guard !lines.isEmpty else { return noWeekPlanDialog }
        if lines.allSatisfy(isUnscheduledWeekLine) {
            return noWeekPlanDialog
        }
        return "This week's plan: \(lines.joined(separator: ", "))."
    }

    static func lastCaption(
        forWorkoutName name: String,
        snapshot: FitLogIntentBridge.OnyxNextPlanSnapshot?
    ) -> String? {
        let key = workoutNameKey(name)
        guard !key.isEmpty, let caption = snapshot?.lastCaptionByWorkoutName[key], !caption.isEmpty else {
            return nil
        }
        return caption
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    static func workoutNameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Private

    private static func startingPhrase(for day: FitLogIntentBridge.OnyxUpcomingTraining) -> String {
        let weekday = day.weekdayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if weekday.isEmpty {
            return "Starting \(day.workoutName)."
        }
        return "Starting \(day.workoutName) on \(weekday)."
    }

    private static func nextPlanPhrase(for day: FitLogIntentBridge.OnyxUpcomingTraining) -> String {
        let weekday = day.weekdayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if weekday.isEmpty {
            return "Next planned workout is \(day.workoutName)."
        }
        return "Next planned workout is \(day.workoutName) on \(weekday)."
    }

    private static func isUnscheduledWeekLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("—") { return true }
        if trimmed.localizedCaseInsensitiveContains("No plan scheduled") { return true }
        return false
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
