//
//  FitLogSimulatedUserLivingDay.swift
//  FitLog
//
//  One calendar day for a persistent simulated user. Does not wipe history.
//  Launch with `-fitlog-ui-daily-living -fitlog-ui-persistent-store -fitlog-ui-persona <id>`.
//

import Foundation

enum FitLogSimulatedUserLivingDay {
    enum Outcome: String, Equatable, Sendable {
        case restDay
        case alreadyLoggedToday
        case logged
        case skippedEmptyLibrary
        case skippedUnloggableWorkout
    }

    struct TickRecord: Codable, Equatable {
        var persona: String
        var dayKey: String
        var outcome: String
        var sessionCount: Int
        var workoutName: String?
    }

    /// Bootstrap library on first launch, then log today's workout when it is a training day.
    @discardableResult
    @MainActor
    static func runTick(
        _ persona: FitLogSimulatedUserPersona,
        into dataVM: DataManager,
        now: Date = Date(),
        calendar: Calendar = .current,
        writeTickLog: Bool = true
    ) -> Outcome {
        FitLogSimulatedUserSeeder.bootstrapLibraryIfNeeded(persona, into: dataVM, now: now, calendar: calendar)

        let dayKey = TrainingProgramState.dayKey(for: now, calendar: calendar)
        let outcome: Outcome
        var workoutName: String?

        if !persona.isTrainingDay(on: now, calendar: calendar) {
            outcome = .restDay
        } else if hasCompletedSession(on: now, in: dataVM, calendar: calendar) {
            outcome = .alreadyLoggedToday
        } else if dataVM.userWorkouts.isEmpty {
            outcome = .skippedEmptyLibrary
        } else {
            let workout = pickWorkout(persona: persona, dataVM: dataVM)
            let weeks = dataVM.completedSessions.count / max(persona.trainingWeekdays.count, 1)
            let weight = 135 + Double(weeks * 5)
            let logged = FitLogSimulatedUserSeeder.logCompletedWorkout(
                from: workout,
                endedAt: now,
                into: dataVM,
                cardio: persona.trainsWithCardio,
                workingWeight: weight
            )
            if logged {
                outcome = .logged
                workoutName = dataVM.workout(id: workout.id)?.name ?? workout.name
            } else {
                outcome = .skippedUnloggableWorkout
            }
        }

        if writeTickLog {
            appendTickLog(
                TickRecord(
                    persona: persona.rawValue,
                    dayKey: dayKey,
                    outcome: outcome.rawValue,
                    sessionCount: dataVM.completedSessions.count,
                    workoutName: workoutName
                )
            )
        }
        return outcome
    }

    @MainActor
    static func hasCompletedSession(
        on date: Date,
        in dataVM: DataManager,
        calendar: Calendar = .current
    ) -> Bool {
        dataVM.completedSessions.contains { session in
            guard let end = session.endTime else { return false }
            return calendar.isDate(end, inSameDayAs: date)
        }
    }

    @MainActor
    private static func pickWorkout(
        persona: FitLogSimulatedUserPersona,
        dataVM: DataManager
    ) -> Workout {
        let workouts = dataVM.userWorkouts
        if persona.trainsWithCardio, let cardio = workouts.first(where: { $0.workoutKind == .cardio }) {
            return cardio
        }
        let index = dataVM.completedSessions.count % max(workouts.count, 1)
        return workouts[index]
    }

    static func tickLogURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appending(path: "fitlog-living-ticks.jsonl")
    }

    private static func appendTickLog(_ record: TickRecord) {
        guard let url = tickLogURL(),
              let data = try? JSONEncoder().encode(record),
              var line = String(data: data, encoding: .utf8)
        else { return }
        line.append("\n")
        if fileExists(url) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
