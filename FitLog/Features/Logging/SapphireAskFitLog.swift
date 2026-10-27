//
//  SapphireAskFitLog.swift
//  FitLog
//
//  Start today's planned workout, start last cardio, and a read-only
//  "did I train today" Siri dialog so plan / cardio / already-trained
//  answers skip a Home or History round trip. Distinct from Ruby
//  (Repeat Yesterday + query-only Today's Workout / Readiness),
//  Citrine (Last Workout / Last Weight queries), and Topaz (unnamed
//  Start of last saved library workout). Does not change freemium rules.
//

import Foundation

enum SapphireAskFitLog {
    static let restDayDialog = "Today is a rest day."
    static let noTodayPlanDialog = "No workout is assigned today."
    static let noCardioDialog =
        "No cardio session yet. Open Workout Log AI to log one."
    static let notTrainedNoPlanDialog = "You have not logged a session today."

    static func querySnapshot(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        calendar: Calendar = .current,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.SapphireTodaySnapshot {
        var lastCardioWorkoutName: String?
        var lastCardioCaption: String?
        var trainedToday = false
        var trainedTodayWorkoutName: String?
        var lastCaptionByWorkoutName: [String: String] = [:]

        for session in completedNewestFirst(sessions) {
            let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trainedToday, let end = session.endTime, calendar.isDate(end, inSameDayAs: now) {
                trainedToday = true
                if !name.isEmpty {
                    trainedTodayWorkoutName = name
                }
            }

            let key = workoutNameKey(name)
            var sessionCaption: String?
            var sessionCardioCaption: String?

            for log in session.exerciseLogs {
                if sessionCaption == nil, let caption = caption(from: log, displayUnit: displayUnit) {
                    sessionCaption = caption
                }
                if sessionCardioCaption == nil, let sec = lastCardioDurationSec(in: log) {
                    sessionCardioCaption = "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
                }
            }

            if lastCaptionByWorkoutName[key] == nil, let sessionCaption, !key.isEmpty {
                lastCaptionByWorkoutName[key] = sessionCaption
            }
            if lastCardioWorkoutName == nil, let sessionCardioCaption, !name.isEmpty {
                lastCardioWorkoutName = name
                lastCardioCaption = sessionCardioCaption
            }
        }

        return FitLogIntentBridge.SapphireTodaySnapshot(
            lastCardioWorkoutName: lastCardioWorkoutName,
            lastCardioCaption: lastCardioCaption,
            trainedToday: trainedToday,
            trainedTodayWorkoutName: trainedTodayWorkoutName,
            lastCaptionByWorkoutName: lastCaptionByWorkoutName
        )
    }

    static func isStartablePlanTitle(_ planTitle: String?) -> Bool {
        let trimmed = planTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return false }
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame { return false }
        if trimmed.localizedCaseInsensitiveCompare("No plan scheduled") == .orderedSame { return false }
        return true
    }

    static func startTodaysWorkoutDialog(
        planTitle: String?,
        snapshot: FitLogIntentBridge.SapphireTodaySnapshot?
    ) -> String {
        let trimmed = planTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty
            || trimmed.localizedCaseInsensitiveCompare("No plan scheduled") == .orderedSame {
            return noTodayPlanDialog
        }
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame {
            return restDayDialog
        }
        if let caption = lastCaption(forWorkoutName: trimmed, snapshot: snapshot) {
            return "Starting \(trimmed). \(caption)."
        }
        return "Starting \(trimmed)."
    }

    static func didITrainTodayDialog(
        planTitle: String?,
        snapshot: FitLogIntentBridge.SapphireTodaySnapshot?
    ) -> String {
        if snapshot?.trainedToday == true {
            if let name = snapshot?.trainedTodayWorkoutName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return "You already trained today. Last session: \(name)."
            }
            return "You already trained today."
        }

        let trimmed = planTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame {
            return "Today is a rest day. You have not logged a session."
        }
        if isStartablePlanTitle(trimmed) {
            return "Not yet. Today's workout is \(trimmed)."
        }
        return notTrainedNoPlanDialog
    }

    static func startLastCardioDialog(
        snapshot: FitLogIntentBridge.SapphireTodaySnapshot?
    ) -> String {
        guard let name = snapshot?.lastCardioWorkoutName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return noCardioDialog
        }
        if let caption = snapshot?.lastCardioCaption, !caption.isEmpty {
            return "Starting \(name). \(caption)."
        }
        return "Starting \(name)."
    }

    static func lastCaption(
        forWorkoutName name: String,
        snapshot: FitLogIntentBridge.SapphireTodaySnapshot?
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

    private static func caption(from log: ExerciseLog, displayUnit: WeightDisplayUnit) -> String? {
        if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
            return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
        }
        if let sec = lastCardioDurationSec(in: log) {
            return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
        }
        return nil
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.first(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
