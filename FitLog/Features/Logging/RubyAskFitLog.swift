//
//  RubyAskFitLog.swift
//  FitLog
//
//  Repeat-yesterday start plus read-only readiness / today's-plan Siri dialogs
//  so yesterday and today are visible without a Home round trip. Distinct from
//  Citrine (Last Workout / Last Weight queries) and Topaz (unnamed Start Workout
//  / Log Set). Does not change freemium rules.
//

import Foundation

enum RubyAskFitLog {
    static let noCompletedWorkoutDialog =
        "No completed workout yet. Open Workout Log AI to log one."
    static let noReadinessDialog =
        "Readiness isn't available yet. Open Workout Log AI to update it."
    static let noTodayPlanDialog =
        "No workout is assigned today."
    static let restDayDialog =
        "Today is a rest day."

    static func querySnapshot(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.RubyRepeatSnapshot {
        var lastWorkoutName: String?
        var newestCaption: String?
        var lastCardioCaption: String?

        for session in completedNewestFirst(sessions) {
            if lastWorkoutName == nil {
                let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    lastWorkoutName = name
                }
            }
            for log in session.exerciseLogs {
                guard let caption = caption(from: log, displayUnit: displayUnit) else { continue }
                if newestCaption == nil {
                    newestCaption = caption
                }
                if lastCardioCaption == nil, let sec = lastCardioDurationSec(in: log) {
                    lastCardioCaption = "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
                }
            }
            if lastWorkoutName != nil, newestCaption != nil {
                break
            }
        }

        return FitLogIntentBridge.RubyRepeatSnapshot(
            lastWorkoutName: lastWorkoutName,
            newestCaption: newestCaption,
            lastCardioCaption: lastCardioCaption
        )
    }

    static func repeatYesterdayDialog(
        snapshot: FitLogIntentBridge.RubyRepeatSnapshot?
    ) -> String {
        guard let name = snapshot?.lastWorkoutName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return noCompletedWorkoutDialog
        }
        if let caption = snapshot?.newestCaption, !caption.isEmpty {
            return "Starting \(name). \(caption)."
        }
        return "Starting \(name)."
    }

    static func readinessDialog(payload: WidgetSnapshotStore.Payload?) -> String {
        let hasReadiness = payload?.readinessScore != nil
            || !(payload?.readinessBandTitle ?? "").isEmpty
            || !(payload?.readinessSummary ?? "").isEmpty
        guard let payload, hasReadiness else {
            return noReadinessDialog
        }

        var parts: [String] = []
        if let score = payload.readinessScore {
            parts.append("Readiness \(score) out of 100")
        } else {
            parts.append("Readiness")
        }
        if let band = payload.readinessBandTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !band.isEmpty {
            parts.append(band)
        } else if let summary = payload.readinessSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !summary.isEmpty {
            parts.append(summary)
        }
        if let plan = payload.todayPlanTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plan.isEmpty {
            parts.append("Today: \(plan)")
        }
        return parts.joined(separator: ". ") + "."
    }

    static func todayPlanDialog(planTitle: String?) -> String {
        let trimmed = planTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty
            || trimmed.localizedCaseInsensitiveCompare("No plan scheduled") == .orderedSame {
            return noTodayPlanDialog
        }
        if trimmed.localizedCaseInsensitiveCompare("Rest day") == .orderedSame {
            return restDayDialog
        }
        return "Today's workout is \(trimmed)."
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
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
