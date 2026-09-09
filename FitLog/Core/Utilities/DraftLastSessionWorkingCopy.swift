//
//  DraftLastSessionWorkingCopy.swift
//  FitLog
//
//  Last-session working load (warm-ups skipped) and a fresh Start from
//  New workout, plus last cardio duration for logging and template pick.
//  Unique vs other nightly helpers: RailLastSessionWorkingCopy (279a),
//  NestLastSessionWorkingCopy (55b5), GlanceLastSessionWorkingCopy (f2d8),
//  EntryLastSessionWorkingCopy (c7a2), HubLastSessionWorkingCopy (b8e1),
//  LastCompletedSessionWorkingCopy (3f91), LastSessionWorkingRecap (e2c4),
//  LibraryWorkoutLastSessionCopy (a209), HistoryStartFreshWorkout (9816/a831).
//

import Foundation

enum DraftLastSessionWorkingCopy {
    struct Recap: Equatable {
        let workoutName: String
        /// `Last done today` / `yesterday` / `Nd ago`.
        let lastDoneLine: String
        /// Last working load or cardio duration (warm-ups skipped).
        let loadLine: String
        /// Exercise name when the load line is a strength set.
        let exerciseName: String?
        let endedAt: Date

        var subtitleLine: String {
            if let exerciseName, !exerciseName.isEmpty {
                return "\(lastDoneLine) · \(exerciseName) · \(loadLine)"
            }
            return "\(lastDoneLine) · \(loadLine)"
        }

        var accessibilityLabel: String {
            if let exerciseName, !exerciseName.isEmpty {
                return "\(workoutName), \(lastDoneLine), last working \(exerciseName) \(loadLine)"
            }
            return "\(workoutName), \(lastDoneLine), last working \(loadLine)"
        }
    }

    /// Last cardio segment for an exercise, used to prefill manual logging.
    struct CardioLastFill: Equatable {
        let durationSec: Int
        let distanceM: Double?
        let avgHeartRate: Int?
        let calories: Double?
        let summaryLine: String
        let lastDoneLine: String
        let exerciseName: String

        var accessibilityLabel: String {
            "Last time \(exerciseName), \(lastDoneLine), \(summaryLine)"
        }
    }

    static func latestCompletedSession(in sessions: [WorkoutSession]) -> WorkoutSession? {
        sessions
            .filter(\.isCompleted)
            .max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    static func lastCompletedSession(
        forLibraryWorkoutId libraryId: UUID,
        in sessions: [WorkoutSession]
    ) -> WorkoutSession? {
        sessions
            .filter { session in
                guard session.isCompleted else { return false }
                if session.sessionPlanOrigin?.libraryWorkoutId == libraryId { return true }
                return session.workout.id == libraryId
            }
            .max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) })
    }

    static func recap(
        from session: WorkoutSession,
        weightUnit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recap? {
        guard let endedAt = session.endTime else { return nil }
        let lastDoneLine = HomeWorkoutFormatting.lastDoneLabel(for: endedAt, reference: now, calendar: calendar)
        let workoutName = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let working = lastWorkingLoad(in: session, weightUnit: weightUnit) {
            return Recap(
                workoutName: workoutName,
                lastDoneLine: lastDoneLine,
                loadLine: working.loadLine,
                exerciseName: working.exerciseName,
                endedAt: endedAt
            )
        }

        if let cardio = lastCardioSummary(in: session) {
            return Recap(
                workoutName: workoutName,
                lastDoneLine: lastDoneLine,
                loadLine: cardio,
                exerciseName: nil,
                endedAt: endedAt
            )
        }

        let durationSeconds = max(0, Int(endedAt.timeIntervalSince(session.startTime)))
        guard durationSeconds > 0 else { return nil }
        return Recap(
            workoutName: workoutName,
            lastDoneLine: lastDoneLine,
            loadLine: HistoryFormatters.formatAvgDuration(durationSeconds),
            exerciseName: nil,
            endedAt: endedAt
        )
    }

    static func recap(
        forLibraryWorkoutId libraryId: UUID,
        sessions: [WorkoutSession],
        weightUnit: WeightDisplayUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Recap? {
        guard let session = lastCompletedSession(forLibraryWorkoutId: libraryId, in: sessions) else {
            return nil
        }
        return recap(from: session, weightUnit: weightUnit, now: now, calendar: calendar)
    }

    /// Library workout when the finished session still points at one; otherwise the session snapshot.
    static func sourceWorkout(session: WorkoutSession, library: [Workout]) -> Workout? {
        if let id = session.sessionPlanOrigin?.libraryWorkoutId,
           let found = library.first(where: { $0.id == id }),
           !found.exercises.isEmpty {
            return found
        }
        if let found = library.first(where: { $0.id == session.workout.id }),
           !found.exercises.isEmpty {
            return found
        }
        return session.workout.exercises.isEmpty ? nil : session.workout
    }

    /// Starts a **new** session and leaves the finished History entry intact.
    @MainActor
    static func startFresh(
        from session: WorkoutSession,
        dataVM: DataManager,
        currentVM: CurrentWorkoutSessionViewModel,
        openCurrentWorkoutSheet: (() -> Void)?,
        setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
    ) {
        guard let source = sourceWorkout(session: session, library: dataVM.userWorkouts) else { return }
        startLibraryWorkout(
            source,
            dataVM: dataVM,
            currentVM: currentVM,
            originHint: session.sessionPlanOrigin,
            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
            setPendingReplace: setPendingReplace
        )
    }

    @MainActor
    static func startLibraryWorkout(
        _ workout: Workout,
        dataVM: DataManager,
        currentVM: CurrentWorkoutSessionViewModel,
        originHint: WorkoutPlanRef? = nil,
        openCurrentWorkoutSheet: (() -> Void)?,
        setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
    ) {
        let toStart = workout.hasFlexibleSlots ? dataVM.sessionInstance(from: workout) : workout
        let origin: WorkoutPlanRef? = {
            if dataVM.workout(id: workout.id) != nil {
                return .workout(workout.id)
            }
            return originHint
        }()
        currentVM.startWorkoutResolvingConflict(toStart, sessionPlanOrigin: origin) {
            setPendingReplace($0)
        }
        if currentVM.isInProgress {
            openCurrentWorkoutSheet?()
        }
    }

    /// Last cardio duration for a template whose name matches a completed session.
    static func lastCardioDurationLine(
        matchingTemplateName name: String,
        in sessions: [WorkoutSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let needle = normalizedName(name)
        guard !needle.isEmpty else { return nil }
        let matching = sessions.filter { session in
            guard session.isCompleted else { return false }
            return namesLooselyMatch(normalizedName(session.workout.name), needle)
        }
        guard let session = matching.max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }),
              let endedAt = session.endTime,
              let summary = lastCardioSummary(in: session)
        else { return nil }
        let lastDone = HomeWorkoutFormatting.lastDoneLabel(for: endedAt, reference: now, calendar: calendar)
        return "\(lastDone) · \(summary)"
    }

    static func lastCardioFill(
        matchingExerciseIds: Set<UUID>,
        in sessions: [WorkoutSession],
        preferredWorkoutId: UUID?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CardioLastFill? {
        guard !matchingExerciseIds.isEmpty else { return nil }

        func logMatches(_ log: ExerciseLog) -> Bool {
            if let eid = log.workoutExercise.exerciseId, matchingExerciseIds.contains(eid) { return true }
            if let sid = log.workoutExercise.snapshot?.exerciseId, matchingExerciseIds.contains(sid) { return true }
            return false
        }

        func latestFill(in candidateSessions: [WorkoutSession]) -> CardioLastFill? {
            var best: (fill: CardioLastFill, timestamp: Date)?
            for session in candidateSessions where session.isCompleted {
                for log in session.exerciseLogs where logMatches(log) {
                    guard let set = log.loggedSets.last(where: { $0.countsTowardCardioTotals }),
                          let metrics = set.cardioMetrics,
                          let durationSec = metrics.durationSec, durationSec > 0
                    else { continue }
                    let stamp = set.timestamp
                    let summary = set.cardioDisplaySummary.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !summary.isEmpty else { continue }
                    let fill = CardioLastFill(
                        durationSec: durationSec,
                        distanceM: metrics.distanceM.flatMap { $0 > 0 ? $0 : nil },
                        avgHeartRate: metrics.avgHeartRate.flatMap { $0 > 0 ? $0 : nil },
                        calories: metrics.calories.flatMap { $0 > 0 ? $0 : nil },
                        summaryLine: summary,
                        lastDoneLine: HomeWorkoutFormatting.lastDoneLabel(
                            for: session.endTime ?? stamp,
                            reference: now,
                            calendar: calendar
                        ),
                        exerciseName: exerciseName(for: log)
                    )
                    if let existing = best {
                        if stamp > existing.timestamp {
                            best = (fill, stamp)
                        }
                    } else {
                        best = (fill, stamp)
                    }
                }
            }
            return best?.fill
        }

        if let preferredWorkoutId {
            let sameWorkout = sessions.filter { session in
                session.workout.id == preferredWorkoutId
                    || session.sessionPlanOrigin?.libraryWorkoutId == preferredWorkoutId
            }
            if let fill = latestFill(in: sameWorkout) {
                return fill
            }
        }
        return latestFill(in: sessions)
    }

    static func namesLooselyMatch(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a == b || a.hasPrefix(b) || b.hasPrefix(a)
    }

    static func normalizedName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func lastWorkingLoad(
        in session: WorkoutSession,
        weightUnit: WeightDisplayUnit
    ) -> (exerciseName: String, loadLine: String)? {
        for log in session.exerciseLogs.reversed() {
            guard let set = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) else { continue }
            return (exerciseName(for: log), set.weightRepsDisplaySummary(displayUnit: weightUnit))
        }
        return nil
    }

    private static func lastCardioSummary(in session: WorkoutSession) -> String? {
        for log in session.exerciseLogs.reversed() {
            guard let set = log.loggedSets.last(where: { $0.countsTowardCardioTotals }) else { continue }
            let summary = set.cardioDisplaySummary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty { return summary }
        }
        return nil
    }

    private static func exerciseName(for log: ExerciseLog) -> String {
        if let snap = log.workoutExercise.snapshot {
            let name = snap.nameAtTimeOfLog.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return log.workoutExercise.slotLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
