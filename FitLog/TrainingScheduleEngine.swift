//
//  TrainingScheduleEngine.swift
//  FitLog
//

import Foundation

struct TrainingScheduleEngine {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func resolve(date: Date, program: TrainingProgramState) -> ResolvedScheduleDay {
        let dk = TrainingProgramState.dayKey(for: date, calendar: calendar)
        if let o = program.dayOverrides[dk] {
            switch o.intent {
            case .inherit:
                break
            case .rest:
                return .rest
            case .workout:
                if let id = o.workoutId { return .workout(.concreteWorkout(id)) }
                break
            }
        }

        let wk = TrainingProgramState.isoWeekKey(for: date, calendar: calendar)
        let wd = calendar.component(.weekday, from: date)
        if let wo = program.weekOverrides[wk],
           let slot = wo.weekdayOverrides[String(wd)] {
            switch slot.intent {
            case .inherit:
                break
            case .rest:
                return .rest
            case .workout:
                if let id = slot.workoutId { return .workout(.concreteWorkout(id)) }
                break
            }
        }

        return defaultPlan(for: date, program: program)
    }

    func defaultPlan(for date: Date, program: TrainingProgramState) -> ResolvedScheduleDay {
        guard !program.cycleEntries.isEmpty else { return .unscheduled }
        guard let entry = defaultCycleEntry(for: date, program: program) else { return .unscheduled }
        switch entry.kind {
        case .concreteWorkout:
            return .workout(.concreteWorkout(entry.id))
        case .slotTemplate:
            return .workout(.slotTemplate(entry.id))
        }
    }

    /// Whether `date` would be a training day under the base program (ignoring overrides).
    func isDefaultTrainingDay(_ date: Date, program: TrainingProgramState) -> Bool {
        let keys = trainingDayKeysInWeek(containing: date, program: program)
        let dk = TrainingProgramState.dayKey(for: date, calendar: calendar)
        return keys.contains(dk)
    }

    func trainingDayKeysInWeek(containing date: Date, program: TrainingProgramState) -> Set<String> {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        var days: [Date] = []
        var d = interval.start
        while d < interval.end {
            days.append(calendar.startOfDay(for: d))
            d = calendar.date(byAdding: .day, value: 1, to: d) ?? interval.end
        }

        let candidateSet: Set<Int>
        if program.preferredWeekdays.isEmpty {
            candidateSet = [2, 3, 4, 5, 6]
        } else {
            candidateSet = Set(program.preferredWeekdays)
        }

        let n = min(max(1, program.sessionsPerWeek), 7)
        let trainingDates = days
            .filter { candidateSet.contains(calendar.component(.weekday, from: $0)) }
            .sorted { $0 < $1 }
        let picked = Array(trainingDates.prefix(n))
        return Set(picked.map { TrainingProgramState.dayKey(for: $0, calendar: calendar) })
    }

    func defaultCycleEntry(for date: Date, program: TrainingProgramState) -> ProgramCycleEntry? {
        guard !program.cycleEntries.isEmpty else { return nil }
        let n = program.cycleEntries.count
        guard isDefaultTrainingDay(date, program: program) else { return nil }
        guard let anchorDate = TrainingProgramState.date(fromDayKey: program.anchorDayKey, calendar: calendar) else {
            return program.cycleEntries[0]
        }
        let anchorStart = calendar.startOfDay(for: anchorDate)
        let dateStart = calendar.startOfDay(for: date)

        if dateStart >= anchorStart {
            var ord = 0
            var walk = anchorStart
            while walk <= dateStart {
                if isDefaultTrainingDay(walk, program: program) {
                    ord += 1
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: walk) else { break }
                walk = next
            }
            let idx = (ord - 1) % n
            return program.cycleEntries[idx]
        }

        var k = 0
        var back = calendar.date(byAdding: .day, value: -1, to: anchorStart) ?? anchorStart
        while back >= dateStart {
            if isDefaultTrainingDay(back, program: program) {
                k += 1
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: back) else { break }
            back = prev
        }
        let idx = ((-k % n) + n) % n
        return program.cycleEntries[idx]
    }
}
