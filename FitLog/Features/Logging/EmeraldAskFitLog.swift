//
//  EmeraldAskFitLog.swift
//  FitLog
//
//  Start last strength, a read-only last-strength load query, and a
//  this-week session count so strength repeats skip a Home or History
//  round trip. Distinct from Sapphire (today's plan / last cardio /
//  did-I-train), Ruby (Repeat Yesterday + Readiness / Today's Workout
//  queries), Citrine (Last Workout / Last Weight queries), and Topaz
//  (unnamed Start of last saved library workout). Does not change
//  freemium rules.
//

import Foundation

enum EmeraldAskFitLog {
    static let noStrengthDialog =
        "No strength session yet. Open Workout Log AI to log one."
    static let noWeekSessionsDialog = "No sessions this week."

    static func querySnapshot(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        calendar: Calendar = .current,
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.EmeraldStrengthSnapshot {
        let completed = completedNewestFirst(sessions)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)

        var lastStrengthWorkoutName: String?
        var lastStrengthCaption: String?
        var thisWeekSessionCount = 0
        var thisWeekLastWorkoutName: String?

        for session in completed {
            let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let ended = session.endTime ?? session.startTime

            if let weekInterval, weekInterval.contains(ended) {
                thisWeekSessionCount += 1
                if thisWeekLastWorkoutName == nil, !name.isEmpty {
                    thisWeekLastWorkoutName = name
                }
            }

            if lastStrengthWorkoutName == nil, let caption = strengthCaption(
                from: session,
                displayUnit: displayUnit
            ) {
                if !name.isEmpty {
                    lastStrengthWorkoutName = name
                }
                lastStrengthCaption = caption
            }
        }

        return FitLogIntentBridge.EmeraldStrengthSnapshot(
            lastStrengthWorkoutName: lastStrengthWorkoutName,
            lastStrengthCaption: lastStrengthCaption,
            thisWeekSessionCount: thisWeekSessionCount,
            thisWeekLastWorkoutName: thisWeekLastWorkoutName
        )
    }

    static func startLastStrengthDialog(
        snapshot: FitLogIntentBridge.EmeraldStrengthSnapshot?
    ) -> String {
        guard let name = snapshot?.lastStrengthWorkoutName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return noStrengthDialog
        }
        if let caption = snapshot?.lastStrengthCaption, !caption.isEmpty {
            return "Starting \(name). \(caption)."
        }
        return "Starting \(name)."
    }

    static func lastStrengthLoadDialog(
        snapshot: FitLogIntentBridge.EmeraldStrengthSnapshot?
    ) -> String {
        guard let name = snapshot?.lastStrengthWorkoutName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return noStrengthDialog
        }
        if let caption = snapshot?.lastStrengthCaption, !caption.isEmpty {
            return "\(name): \(caption)."
        }
        return "Last strength: \(name)."
    }

    static func thisWeeksTrainingDialog(
        snapshot: FitLogIntentBridge.EmeraldStrengthSnapshot?
    ) -> String {
        let count = snapshot?.thisWeekSessionCount ?? 0
        guard count > 0 else { return noWeekSessionsDialog }

        let noun = count == 1 ? "session" : "sessions"
        let prefix = "\(count) \(noun) this week"
        if let name = snapshot?.thisWeekLastWorkoutName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return "\(prefix). Last session: \(name)."
        }
        return "\(prefix)."
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

    private static func strengthCaption(
        from session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> String? {
        for log in session.exerciseLogs {
            if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
                return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
            }
        }
        return nil
    }
}
