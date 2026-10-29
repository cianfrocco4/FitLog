//
//  AmethystAskFitLog.swift
//  FitLog
//
//  Start tomorrow's planned workout, a read-only tomorrow-plan query, and
//  last-session duration so plan-ahead and recap skip a Home or History
//  round trip. Distinct from Emerald (last strength / this-week count),
//  Sapphire (today's plan / last cardio / did-I-train), Ruby (Repeat
//  Yesterday + Readiness / Today's Workout queries), Citrine (Last
//  Workout / Last Weight queries), and Topaz (unnamed Start of last
//  saved library workout). Does not change freemium rules.
//

import Foundation

enum AmethystAskFitLog {
    static let restDayDialog = "Tomorrow is a rest day."
    static let noTomorrowPlanDialog = "No workout is assigned tomorrow."
    static let noSessionDialog = "No completed session yet."

    static func querySnapshot(
        from sessions: [WorkoutSession],
        tomorrowPlanTitle: String? = nil,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.AmethystTomorrowSnapshot {
        var lastCaptionByWorkoutName: [String: String] = [:]
        var lastSessionWorkoutName: String?
        var lastSessionDurationSeconds = 0

        for session in completedNewestFirst(sessions) {
            let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if lastSessionWorkoutName == nil {
                if !name.isEmpty {
                    lastSessionWorkoutName = name
                }
                lastSessionDurationSeconds = wallDurationSeconds(session)
            }

            let key = workoutNameKey(name)
            if lastCaptionByWorkoutName[key] == nil, let caption = sessionCaption(
                from: session,
                displayUnit: displayUnit
            ), !key.isEmpty {
                lastCaptionByWorkoutName[key] = caption
            }
        }

        return FitLogIntentBridge.AmethystTomorrowSnapshot(
            tomorrowPlanTitle: tomorrowPlanTitle,
            lastCaptionByWorkoutName: lastCaptionByWorkoutName,
            lastSessionWorkoutName: lastSessionWorkoutName,
            lastSessionDurationSeconds: lastSessionDurationSeconds
        )
    }

    static func isStartablePlanTitle(_ planTitle: String?) -> Bool {
        let trimmed = planTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return false }
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame { return false }
        if trimmed.localizedCaseInsensitiveCompare("No plan scheduled") == .orderedSame { return false }
        return true
    }

    static func startTomorrowsWorkoutDialog(
        snapshot: FitLogIntentBridge.AmethystTomorrowSnapshot?
    ) -> String {
        let trimmed = snapshot?.tomorrowPlanTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty
            || trimmed.localizedCaseInsensitiveCompare("No plan scheduled") == .orderedSame {
            return noTomorrowPlanDialog
        }
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame {
            return restDayDialog
        }
        if let caption = lastCaption(forWorkoutName: trimmed, snapshot: snapshot) {
            return "Starting \(trimmed). \(caption)."
        }
        return "Starting \(trimmed)."
    }

    static func tomorrowsWorkoutDialog(
        snapshot: FitLogIntentBridge.AmethystTomorrowSnapshot?
    ) -> String {
        let trimmed = snapshot?.tomorrowPlanTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty
            || trimmed.localizedCaseInsensitiveCompare("No plan scheduled") == .orderedSame {
            return noTomorrowPlanDialog
        }
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame {
            return restDayDialog
        }
        if let caption = lastCaption(forWorkoutName: trimmed, snapshot: snapshot) {
            return "Tomorrow's workout is \(trimmed). \(caption)."
        }
        return "Tomorrow's workout is \(trimmed)."
    }

    static func lastSessionDurationDialog(
        snapshot: FitLogIntentBridge.AmethystTomorrowSnapshot?
    ) -> String {
        guard let name = snapshot?.lastSessionWorkoutName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return noSessionDialog
        }
        let seconds = snapshot?.lastSessionDurationSeconds ?? 0
        if seconds > 0 {
            let spoken = CardioMetricsCalculator.spokenDuration(seconds: seconds)
            return "\(name) lasted \(spoken)."
        }
        return "Last session: \(name)."
    }

    static func lastCaption(
        forWorkoutName name: String,
        snapshot: FitLogIntentBridge.AmethystTomorrowSnapshot?
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

    private static func completedNewestFirst(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private static func wallDurationSeconds(_ session: WorkoutSession) -> Int {
        guard let end = session.endTime else { return 0 }
        return max(0, Int(end.timeIntervalSince(session.startTime)))
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
