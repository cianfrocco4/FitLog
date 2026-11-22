//
//  AzuriteAskFitLog.swift
//  FitLog
//
//  Apply the most recently finished strength exercise's prescribed
//  rest to a live rest countdown from Siri / Shortcuts, plus this-
//  workout last-cardio-duration and last-completed-exercise queries,
//  so a mid-session "use the rest the last finished lift called
//  for" / "how long was last cardio" / "which exercise did I just
//  finish" check does not require hunting through the sheet
//  (`like.history.logged` / `like.rest.no_nag`). Empty / missing
//  sessions, idle rest timers, open placeholders, and rest days
//  are not turned into a rest start, a skip, a set, or a start.
//  Distinct from RestTimerIntent (starts rest), Malachite (use
//  next leftover prescribed rest / this-workout last prescribed
//  rest *query* / this-workout sets completed), Hematite (use
//  previous leftover prescribed rest / this-exercise last rest /
//  this-workout exercises completed), Sunstone (use this-workout
//  last *logged* rest / remaining sets / last working), Larimar
//  (use next last rest / previous prescribed rest query /
//  this-workout last rest), Turquoise (use previous last rest /
//  previous last rest / next prescribed rest query), Coral (use
//  focused last rest / previous remaining / next last rest),
//  Amber (double rest / next remaining / this last rest), Jade
//  (halve rest / previous last working / this remaining sets),
//  Zircon (add rest / this-exercise target / prescribed rest on
//  the focused row), Obsidian (subtract 30s / next-exercise
//  target / next last working), Fluorite (reset rest to focused
//  prescribed / previous target / this last working), Aquamarine
//  (skip rest / rest remaining), Tourmaline (use last cardio
//  duration *action* / last-set / current-exercise), Spinel (go
//  to previous / previous name / this-exercise sets), Jasper
//  (repeat / session remaining / next incomplete), Moonstone
//  (skip remaining / next set / ready-to-finish), Tanzanite
//  (undo / sets logged / elapsed), Alexandrite (remaining
//  exercises row count), Citrine (last-load query), the Siri
//  start series (Onyx → Topaz), and 999e (in-app finish-ready
//  banner). Does not change freemium rules.
//

import Foundation

enum AzuriteAskFitLog {
    static let noInProgressDialog = "No workout in progress."
    static let noRestTimerDialog = "No rest timer running."
    static let noRestPrescriptionDialog = "No rest prescription this workout."
    static let minRestSeconds = 1
    static let maxRestSeconds = 600

    static func querySnapshot(
        inProgress: WorkoutSession?,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> FitLogIntentBridge.AzuriteSessionSnapshot {
        guard let live = cleanedInProgress(inProgress) else {
            return FitLogIntentBridge.AzuriteSessionSnapshot(
                restEndsAtEpoch: restEpoch(restEndsAt, now: now)
            )
        }
        let focused = focusedExercise(in: live)
        let lastCompleted = lastCompletedExercise(in: live)
        let lastPrescribed = lastCompletedPrescribedRest(in: live)
        let lastCardio = lastCardioDuration(in: live)
        let finish = finishReadiness(in: live)
        let remaining = remainingRestSeconds(restEndsAt: restEndsAt, now: now)
        return FitLogIntentBridge.AzuriteSessionSnapshot(
            inProgressWorkoutName: cleanedName(live.workout.name),
            focusedExerciseName: focused?.exerciseName,
            focusedIsIncomplete: focused?.isIncomplete ?? false,
            lastCompletedExerciseName: lastCompleted?.exerciseName,
            lastCompletedIsCardio: lastCompleted?.isCardio ?? false,
            lastCompletedPrescribedRestSeconds: lastPrescribed?.prescribedRestSeconds,
            lastCardioExerciseName: lastCardio?.exerciseName,
            lastCardioDurationSeconds: lastCardio?.durationSeconds,
            canUseLastPrescribedRest: canUseLastPrescribedRest(
                remaining: remaining,
                prescribedSeconds: lastPrescribed?.prescribedRestSeconds
            ),
            restEndsAtEpoch: restEpoch(restEndsAt, now: now),
            hasOpenPlaceholder: finish.hasOpenPlaceholder,
            isReadyToFinish: finish.isReady
        )
    }

    static func canUseLastPrescribedRest(
        snapshot: FitLogIntentBridge.AzuriteSessionSnapshot?,
        now: Date = Date()
    ) -> Bool {
        canUseLastPrescribedRest(
            remaining: remainingRestSeconds(snapshot: snapshot, now: now),
            prescribedSeconds: snapshot?.lastCompletedPrescribedRestSeconds
        ) && cleanedName(snapshot?.inProgressWorkoutName) != nil
    }

    static func lastPrescribedRestTargetSeconds(
        snapshot: FitLogIntentBridge.AzuriteSessionSnapshot?
    ) -> Int? {
        guard let seconds = snapshot?.lastCompletedPrescribedRestSeconds, seconds > 0 else {
            return nil
        }
        return min(maxRestSeconds, max(minRestSeconds, seconds))
    }

    static func remainingRestSeconds(
        snapshot: FitLogIntentBridge.AzuriteSessionSnapshot?,
        now: Date = Date()
    ) -> Int? {
        remainingRestSeconds(restEndsAt: snapshot?.restEndsAt, now: now)
    }

    static func remainingRestSeconds(restEndsAt: Date?, now: Date = Date()) -> Int? {
        guard let restEndsAt else { return nil }
        let remaining = Int(ceil(restEndsAt.timeIntervalSince(now)))
        return remaining > 0 ? remaining : nil
    }

    static func useThisWorkoutLastPrescribedRestDialog(
        snapshot: FitLogIntentBridge.AzuriteSessionSnapshot?,
        now: Date = Date()
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        guard remainingRestSeconds(snapshot: snapshot, now: now) != nil else {
            return noRestTimerDialog
        }
        if let target = lastPrescribedRestTargetSeconds(snapshot: snapshot) {
            return "Rest now \(CardioMetricsCalculator.spokenDuration(seconds: target))."
        }
        if snapshot?.lastCompletedIsCardio == true,
           cleanedName(snapshot?.lastCompletedExerciseName) != nil {
            return "Last finished exercise is cardio."
        }
        if snapshot?.isReadyToFinish == true {
            return noRestPrescriptionDialog
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return noRestPrescriptionDialog
    }

    static func thisWorkoutLastCardioDurationDialog(
        snapshot: FitLogIntentBridge.AzuriteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let seconds = snapshot?.lastCardioDurationSeconds, seconds > 0 {
            let spoken = CardioMetricsCalculator.spokenDuration(seconds: seconds)
            if let name = cleanedName(snapshot?.lastCardioExerciseName) {
                return "Last cardio this workout was \(spoken) on \(name)."
            }
            return "Last cardio this workout was \(spoken)."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "No cardio duration this workout."
    }

    static func thisWorkoutLastCompletedExerciseDialog(
        snapshot: FitLogIntentBridge.AzuriteSessionSnapshot?
    ) -> String {
        guard let workoutName = cleanedName(snapshot?.inProgressWorkoutName) else {
            return noInProgressDialog
        }
        if let name = cleanedName(snapshot?.lastCompletedExerciseName) {
            return "Last finished exercise this workout was \(name)."
        }
        if snapshot?.hasOpenPlaceholder == true {
            return "\(workoutName) still has an open slot."
        }
        return "No finished exercise this workout."
    }

    // MARK: - Private

    private struct FocusedExercise: Equatable {
        var exerciseName: String
        var isIncomplete: Bool
    }

    private struct CompletedExercise: Equatable {
        var exerciseName: String
        var isCardio: Bool
    }

    private struct CompletedPrescribedRest: Equatable {
        var exerciseName: String
        var prescribedRestSeconds: Int
    }

    private struct LastCardioDuration: Equatable {
        var exerciseName: String
        var durationSeconds: Int
    }

    private struct FinishReadiness: Equatable {
        var hasOpenPlaceholder: Bool
        var isReady: Bool
    }

    private static func canUseLastPrescribedRest(
        remaining: Int?,
        prescribedSeconds: Int?
    ) -> Bool {
        guard let remaining, remaining >= minRestSeconds else { return false }
        guard let prescribedSeconds, prescribedSeconds > 0 else { return false }
        return true
    }

    private static func restEpoch(_ restEndsAt: Date?, now: Date) -> TimeInterval? {
        guard remainingRestSeconds(restEndsAt: restEndsAt, now: now) != nil else {
            return nil
        }
        return restEndsAt?.timeIntervalSince1970
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

    private static func focusedExercise(
        in session: WorkoutSession
    ) -> FocusedExercise? {
        guard let activeId = session.activeExerciseIds.first,
              let log = session.exerciseLogs.first(where: {
                  $0.workoutExercise.exerciseId == activeId
              }),
              let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog)
        else { return nil }
        let completed = Set(session.completedExerciseIds)
        return FocusedExercise(
            exerciseName: name,
            isIncomplete: isIncomplete(log, completedExerciseIds: completed)
        )
    }

    private static func lastCompletedExercise(
        in session: WorkoutSession
    ) -> CompletedExercise? {
        let completed = Set(session.completedExerciseIds)
        for log in session.exerciseLogs.reversed() {
            guard isRowReady(log, completedExerciseIds: completed) else { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            return CompletedExercise(
                exerciseName: name,
                isCardio: isCardioRow(log)
            )
        }
        return nil
    }

    private static func lastCompletedPrescribedRest(
        in session: WorkoutSession
    ) -> CompletedPrescribedRest? {
        let completed = Set(session.completedExerciseIds)
        for log in session.exerciseLogs.reversed() {
            guard isRowReady(log, completedExerciseIds: completed) else { continue }
            guard !isCardioRow(log) else { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            guard let seconds = prescribedRestSeconds(in: log), seconds > 0 else { continue }
            return CompletedPrescribedRest(
                exerciseName: name,
                prescribedRestSeconds: seconds
            )
        }
        return nil
    }

    private static func lastCardioDuration(
        in session: WorkoutSession
    ) -> LastCardioDuration? {
        for log in session.exerciseLogs.reversed() {
            guard !log.workoutExercise.isSlotPlaceholder else { continue }
            guard let name = cleanedName(log.workoutExercise.snapshot?.nameAtTimeOfLog) else {
                continue
            }
            for set in log.loggedSets.reversed() {
                guard set.countsTowardCardioTotals else { continue }
                let seconds = set.cardioMetrics?.durationSec ?? 0
                guard seconds > 0 else { continue }
                return LastCardioDuration(exerciseName: name, durationSeconds: seconds)
            }
        }
        return nil
    }

    private static func finishReadiness(in session: WorkoutSession) -> FinishReadiness {
        let logs = session.exerciseLogs
        let hasOpenPlaceholder = logs.contains { $0.workoutExercise.isSlotPlaceholder }
        let completed = Set(session.completedExerciseIds)
        let incompleteCount = logs.filter { isIncomplete($0, completedExerciseIds: completed) }.count
        let hasStartable = logs.contains { !$0.workoutExercise.isSlotPlaceholder }
        let isReady = hasStartable && !hasOpenPlaceholder && incompleteCount == 0
        return FinishReadiness(
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

    /// Session rest override wins over the library default. Cardio rows skip this.
    private static func prescribedRestSeconds(in log: ExerciseLog) -> Int? {
        if let override = log.sessionRestOverrideSeconds, override > 0 {
            return override
        }
        let planDefault = log.workoutExercise.defaultRestTime
        return planDefault > 0 ? planDefault : nil
    }
}

extension FitLogIntentBridge.AzuriteSessionSnapshot {
    var restEndsAt: Date? {
        guard let restEndsAtEpoch else { return nil }
        return Date(timeIntervalSince1970: restEndsAtEpoch)
    }
}
