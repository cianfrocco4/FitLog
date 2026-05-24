//
//  TrainingInsights.swift
//  FitLog
//
//  Progress insights used by Home, logging, and planning surfaces.
//

import Foundation

// MARK: - PR / milestones / score / progression models

struct PersonalRecordEvent: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Hashable {
        case maxWeight = "Heaviest load"
        case estimatedOneRM = "Estimated 1RM"
        case maxVolumeSet = "Set volume"
        case maxDistance = "Longest distance"
        case bestPace = "Best pace"
        case longestDuration = "Longest duration"
        case maxCalories = "Most calories"
    }

    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    let kind: Kind
    let newValue: Double
    let previousValue: Double?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        exerciseName: String,
        kind: Kind,
        newValue: Double,
        previousValue: Double?,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.kind = kind
        self.newValue = newValue
        self.previousValue = previousValue
        self.timestamp = timestamp
    }

    var title: String {
        switch kind {
        case .maxWeight:
            return "New weight PR"
        case .estimatedOneRM:
            return "New est. 1RM PR"
        case .maxVolumeSet:
            return "New set-volume PR"
        case .maxDistance:
            return "New distance PR"
        case .bestPace:
            return "New pace PR"
        case .longestDuration:
            return "New duration PR"
        case .maxCalories:
            return "New calorie PR"
        }
    }

    var detail: String {
        let value: String
        switch kind {
        case .maxWeight, .estimatedOneRM:
            value = Self.weightString(newValue) + " lb"
        case .maxVolumeSet:
            value = Self.weightString(newValue) + " lb*rep"
        case .maxDistance:
            value = Self.distanceString(newValue)
        case .bestPace:
            value = Self.paceString(newValue)
        case .longestDuration:
            value = Self.durationString(newValue)
        case .maxCalories:
            value = Self.weightString(newValue) + " kcal"
        }
        return "\(exerciseName) - \(value)"
    }

    private static func distanceString(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private static func paceString(_ secPerKm: Double) -> String {
        let total = Int(secPerKm.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    private static func durationString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private static func weightString(_ n: Double) -> String {
        if n == floor(n) { return String(Int(n)) }
        return String(format: "%.1f", n)
    }
}

/// One row in the all-time personal records timeline (derived from completed sessions).
struct ArchivedPersonalRecord: Identifiable, Equatable {
    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    let kind: PersonalRecordEvent.Kind
    let value: Double
    let achievedAt: Date

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        exerciseName: String,
        kind: PersonalRecordEvent.Kind,
        value: Double,
        achievedAt: Date
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.kind = kind
        self.value = value
        self.achievedAt = achievedAt
    }
}

struct ProgressMilestone: Equatable {
    enum Metric: String {
        case sessions = "Sessions"
        case totalSets = "Sets"
        case totalVolume = "Volume"
    }

    let metric: Metric
    let target: Int
    let current: Int

    var isUnlocked: Bool { current >= target }

    var label: String {
        switch metric {
        case .sessions:
            return "\(target) workouts completed"
        case .totalSets:
            return "\(target) sets logged"
        case .totalVolume:
            return "\(target) lb*rep moved"
        }
    }
}

struct StrengthScorePoint: Identifiable, Equatable {
    let weekStart: Date
    let score: Int
    var id: Date { weekStart }
}

struct StrengthScoreSummary: Equatable {
    let score: Int
    let previousScore: Int?
    let trend: [StrengthScorePoint]

    var delta: Int? {
        guard let previousScore else { return nil }
        return score - previousScore
    }
}

struct ProgressionSuggestion: Equatable {
    enum Direction {
        case increase
        case hold
        case decrease
    }

    let direction: Direction
    let suggestedWeight: Double?
    let targetReps: String
    let rationale: String

    var shortLine: String {
        let loadLine: String
        if let suggestedWeight {
            let text = suggestedWeight == floor(suggestedWeight)
                ? "\(Int(suggestedWeight))"
                : String(format: "%.1f", suggestedWeight)
            loadLine = "\(text) lb"
        } else {
            loadLine = "Current load"
        }

        switch direction {
        case .increase:
            return "Next target: \(loadLine), \(targetReps) reps"
        case .hold:
            return "Next target: hold load, \(targetReps) reps"
        case .decrease:
            return "Next target: \(loadLine), rebuild to \(targetReps)"
        }
    }
}

struct HomeProgressSummary: Equatable {
    let weeklyPRCount: Int
    let dayStreak: Int
    let weekStreak: Int
    let strengthScore: StrengthScoreSummary
    let latestUnlockedMilestone: ProgressMilestone?
    let nextMilestone: ProgressMilestone?
    let weeklyCardioMinutes: Int
    let cardioDistanceKm: Double
    let cardioStreakDays: Int
}

// MARK: - PR detector

enum PersonalRecordDetector {
    private static let epsilon = 0.0001

    static func detect(
        newSet: LoggedSet,
        priorSets: [LoggedSet],
        exerciseId: UUID,
        exerciseName: String,
        timestamp: Date = Date()
    ) -> [PersonalRecordEvent] {
        if newSet.countsTowardCardioTotals {
            return detectCardio(
                newSet: newSet,
                priorSets: priorSets,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                timestamp: timestamp
            )
        }
        guard newSet.countsTowardLoadPRMetrics else { return [] }

        let priorRelevant = priorSets.filter { $0.countsTowardLoadPRMetrics }
        let previousMaxWeight = priorRelevant.map(\.weight).max()
        let previousMax1RM = priorRelevant.map { epley(weight: $0.weight, reps: $0.reps) }.max()
        let previousMaxVolume = priorRelevant.map(\.totalVolumeLoad).max()

        let newWeight = newSet.weight
        let new1RM = epley(weight: newSet.weight, reps: newSet.reps)
        let newVolume = newSet.totalVolumeLoad

        var events: [PersonalRecordEvent] = []

        if previousMaxWeight == nil || newWeight > (previousMaxWeight! + epsilon) {
            events.append(
                PersonalRecordEvent(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    kind: .maxWeight,
                    newValue: newWeight,
                    previousValue: previousMaxWeight,
                    timestamp: timestamp
                )
            )
        }
        if previousMax1RM == nil || new1RM > (previousMax1RM! + epsilon) {
            events.append(
                PersonalRecordEvent(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    kind: .estimatedOneRM,
                    newValue: new1RM,
                    previousValue: previousMax1RM,
                    timestamp: timestamp
                )
            )
        }
        if previousMaxVolume == nil || newVolume > (previousMaxVolume! + epsilon) {
            events.append(
                PersonalRecordEvent(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    kind: .maxVolumeSet,
                    newValue: newVolume,
                    previousValue: previousMaxVolume,
                    timestamp: timestamp
                )
            )
        }

        return events
    }

    static func detectCardio(
        newSet: LoggedSet,
        priorSets: [LoggedSet],
        exerciseId: UUID,
        exerciseName: String,
        timestamp: Date = Date()
    ) -> [PersonalRecordEvent] {
        guard newSet.countsTowardCardioTotals, let metrics = newSet.cardioMetrics else { return [] }
        let priorRelevant = priorSets.filter { $0.countsTowardCardioTotals }

        let prevMaxDistance = priorRelevant.compactMap(\.cardioMetrics?.distanceM).max()
        let prevMaxDuration = priorRelevant.compactMap { $0.cardioMetrics?.durationSec }.map(Double.init).max()
        let prevBestPace = priorRelevant.compactMap { $0.cardioMetrics?.resolvedPaceSecPerKm }.map(Double.init).min()
        let prevMaxCalories = priorRelevant.compactMap(\.cardioMetrics?.calories).max()

        var events: [PersonalRecordEvent] = []

        if let dist = metrics.distanceM, dist > 0 {
            if prevMaxDistance == nil || dist > prevMaxDistance! + epsilon {
                events.append(
                    PersonalRecordEvent(
                        exerciseId: exerciseId,
                        exerciseName: exerciseName,
                        kind: .maxDistance,
                        newValue: dist,
                        previousValue: prevMaxDistance,
                        timestamp: timestamp
                    )
                )
            }
        }

        if let sec = metrics.durationSec, sec > 0 {
            let duration = Double(sec)
            if prevMaxDuration == nil || duration > prevMaxDuration! + epsilon {
                events.append(
                    PersonalRecordEvent(
                        exerciseId: exerciseId,
                        exerciseName: exerciseName,
                        kind: .longestDuration,
                        newValue: duration,
                        previousValue: prevMaxDuration,
                        timestamp: timestamp
                    )
                )
            }
        }

        if let pace = metrics.resolvedPaceSecPerKm, pace > 0 {
            let paceValue = Double(pace)
            if prevBestPace == nil || paceValue < prevBestPace! - epsilon {
                events.append(
                    PersonalRecordEvent(
                        exerciseId: exerciseId,
                        exerciseName: exerciseName,
                        kind: .bestPace,
                        newValue: paceValue,
                        previousValue: prevBestPace,
                        timestamp: timestamp
                    )
                )
            }
        }

        if let cal = metrics.calories, cal > 0 {
            if prevMaxCalories == nil || cal > prevMaxCalories! + epsilon {
                events.append(
                    PersonalRecordEvent(
                        exerciseId: exerciseId,
                        exerciseName: exerciseName,
                        kind: .maxCalories,
                        newValue: cal,
                        previousValue: prevMaxCalories,
                        timestamp: timestamp
                    )
                )
            }
        }

        return events
    }

    static func epley(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}

// MARK: - DataManager insights

extension DataManager {
    func homeProgressSummary(referenceDate: Date = Date(), calendar: Calendar = .current) -> HomeProgressSummary {
        let cardioWeek = weeklyCardioTotals(referenceDate: referenceDate, calendar: calendar)
        return HomeProgressSummary(
            weeklyPRCount: weeklyPersonalRecordCount(referenceDate: referenceDate, calendar: calendar),
            dayStreak: currentWorkoutDayStreak(referenceDate: referenceDate, calendar: calendar),
            weekStreak: currentWorkoutWeekStreak(referenceDate: referenceDate, calendar: calendar),
            strengthScore: strengthScoreSummary(referenceDate: referenceDate, calendar: calendar),
            latestUnlockedMilestone: latestUnlockedMilestone(),
            nextMilestone: nextMilestone(),
            weeklyCardioMinutes: cardioWeek.minutes,
            cardioDistanceKm: cardioWeek.distanceKm,
            cardioStreakDays: cardioDayStreak(referenceDate: referenceDate, calendar: calendar)
        )
    }

    func weeklyCardioTotals(referenceDate: Date = Date(), calendar: Calendar = .current) -> (minutes: Int, distanceKm: Double) {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return (0, 0)
        }
        let sessions = completedSessions.filter {
            guard $0.isCompleted, let end = $0.endTime else { return false }
            return end >= weekInterval.start && end < weekInterval.end
        }
        var seconds = 0
        var meters = 0.0
        for session in sessions {
            let agg = CardioSessionAggregatesCalculator.aggregates(for: session, exercises: globalExercises)
            seconds += agg.durationSeconds
            meters += agg.distanceMeters
        }
        return (seconds / 60, meters / 1000.0)
    }

    func cardioDayStreak(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let cardioDays = Set(
            completedSessions
                .filter(\.isCompleted)
                .filter { session in
                    CardioSessionAggregatesCalculator
                        .aggregates(for: session, exercises: globalExercises)
                        .hasCardio
                }
                .map { calendar.startOfDay(for: $0.endTime ?? $0.startTime) }
        )
        guard !cardioDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        let anchor: Date = cardioDays.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var streak = 0
        var cursor = anchor
        while cardioDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    func weeklyPersonalRecordCount(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        let sortedSessions = completedSessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }

        struct Maxima {
            var maxWeight: Double = 0
            var maxOneRM: Double = 0
            var maxSetVolume: Double = 0
            var maxDistance: Double = 0
            var maxDuration: Double = 0
            var bestPace: Double = 0
            var maxCalories: Double = 0
            var initialized = false
        }

        var maximaByExercise: [UUID: Maxima] = [:]
        var weeklyCount = 0

        func syntheticCardioPriorSets(from maxima: Maxima) -> [LoggedSet] {
            guard maxima.initialized else { return [] }
            var metrics = CardioMetrics(source: .manual)
            if maxima.maxDistance > 0 { metrics.distanceM = maxima.maxDistance }
            if maxima.maxDuration > 0 { metrics.durationSec = Int(maxima.maxDuration) }
            if maxima.bestPace > 0 { metrics.avgPaceSecPerKm = Int(maxima.bestPace) }
            if maxima.maxCalories > 0 { metrics.calories = maxima.maxCalories }
            return [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: .distantPast,
                    setType: .steadyState,
                    configuration: [:],
                    dropSegments: [],
                    rpe: nil,
                    cardioMetrics: metrics
                )
            ]
        }

        for session in sortedSessions {
            for log in session.exerciseLogs {
                guard let exerciseId = log.workoutExercise.exerciseId else { continue }
                let name = displayName(for: log.workoutExercise)
                let orderedSets = log.loggedSets.sorted { $0.timestamp < $1.timestamp }
                var prior: [LoggedSet] = []
                for set in orderedSets {
                    if set.countsTowardLoadPRMetrics {
                        let oneRM = PersonalRecordDetector.epley(weight: set.weight, reps: set.reps)
                        let setVolume = set.totalVolumeLoad
                        var maxima = maximaByExercise[exerciseId] ?? Maxima()

                        let isWeightPR = !maxima.initialized || set.weight > maxima.maxWeight + 0.0001
                        let isOneRMPR = !maxima.initialized || oneRM > maxima.maxOneRM + 0.0001
                        let isVolumePR = !maxima.initialized || setVolume > maxima.maxSetVolume + 0.0001

                        if isWeightPR || isOneRMPR || isVolumePR {
                            if set.timestamp >= weekInterval.start && set.timestamp < weekInterval.end {
                                weeklyCount += 1
                            }
                        }

                        maxima.maxWeight = max(maxima.maxWeight, set.weight)
                        maxima.maxOneRM = max(maxima.maxOneRM, oneRM)
                        maxima.maxSetVolume = max(maxima.maxSetVolume, setVolume)
                        maxima.initialized = true
                        maximaByExercise[exerciseId] = maxima
                    }

                    if set.countsTowardCardioTotals {
                        var maxima = maximaByExercise[exerciseId] ?? Maxima()
                        let priorFromMaxima = syntheticCardioPriorSets(from: maxima)
                        let events = PersonalRecordDetector.detectCardio(
                            newSet: set,
                            priorSets: priorFromMaxima,
                            exerciseId: exerciseId,
                            exerciseName: name,
                            timestamp: set.timestamp
                        )
                        if !events.isEmpty,
                           set.timestamp >= weekInterval.start,
                           set.timestamp < weekInterval.end {
                            weeklyCount += 1
                        }
                        if let metrics = set.cardioMetrics {
                            if let dist = metrics.distanceM, dist > 0 {
                                maxima.maxDistance = max(maxima.maxDistance, dist)
                            }
                            if let sec = metrics.durationSec, sec > 0 {
                                maxima.maxDuration = max(maxima.maxDuration, Double(sec))
                            }
                            if let pace = metrics.resolvedPaceSecPerKm, pace > 0 {
                                let paceValue = Double(pace)
                                if maxima.bestPace <= 0 {
                                    maxima.bestPace = paceValue
                                } else {
                                    maxima.bestPace = min(maxima.bestPace, paceValue)
                                }
                            }
                            if let cal = metrics.calories, cal > 0 {
                                maxima.maxCalories = max(maxima.maxCalories, cal)
                            }
                            maxima.initialized = true
                            maximaByExercise[exerciseId] = maxima
                        }
                    }

                    prior.append(set)
                }
            }
        }

        return weeklyCount
    }

    func currentWorkoutDayStreak(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let doneDays = Set(
            completedSessions
                .filter(\.isCompleted)
                .map { calendar.startOfDay(for: $0.endTime ?? $0.startTime) }
        )
        guard !doneDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        let anchor: Date = doneDays.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var streak = 0
        var cursor = anchor
        while doneDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    func currentWorkoutWeekStreak(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let sessionsByWeek = Dictionary(grouping: completedSessions.filter(\.isCompleted)) {
            TrainingProgramState.isoWeekKey(for: $0.endTime ?? $0.startTime, calendar: calendar)
        }
        guard !sessionsByWeek.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: referenceDate)
        while true {
            let key = TrainingProgramState.isoWeekKey(for: cursor, calendar: calendar)
            if let rows = sessionsByWeek[key], !rows.isEmpty {
                streak += 1
                guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
                cursor = prevWeek
            } else {
                break
            }
        }
        return streak
    }

    func latestUnlockedMilestone() -> ProgressMilestone? {
        milestoneProgress()
            .filter(\.isUnlocked)
            .sorted { a, b in
                if a.metric == b.metric { return a.target > b.target }
                return metricOrder(a.metric) > metricOrder(b.metric)
            }
            .first
    }

    func nextMilestone() -> ProgressMilestone? {
        milestoneProgress()
            .filter { !$0.isUnlocked }
            .sorted { a, b in
                let da = max(0, a.target - a.current)
                let db = max(0, b.target - b.current)
                if da != db { return da < db }
                return metricOrder(a.metric) > metricOrder(b.metric)
            }
            .first
    }

    func strengthScoreSummary(referenceDate: Date = Date(), calendar: Calendar = .current) -> StrengthScoreSummary {
        let currentWindowEnd = referenceDate
        let currentWindowStart = calendar.date(byAdding: .day, value: -28, to: currentWindowEnd) ?? currentWindowEnd
        let previousWindowEnd = currentWindowStart
        let previousWindowStart = calendar.date(byAdding: .day, value: -28, to: previousWindowEnd) ?? previousWindowEnd

        let currentScore = strengthScore(in: currentWindowStart..<currentWindowEnd)
        let previous = strengthScore(in: previousWindowStart..<previousWindowEnd)
        let previousScore = previous == 0 ? nil : previous

        let trend = weeklyStrengthTrend(referenceDate: referenceDate, calendar: calendar, weeks: 8)
        return StrengthScoreSummary(score: currentScore, previousScore: previousScore, trend: trend)
    }

    func progressionSuggestion(for workoutExercise: WorkoutExercise) -> ProgressionSuggestion? {
        guard let exerciseId = workoutExercise.exerciseId else { return nil }
        let repRange = parseRepRange(workoutExercise.recommendedReps)
        let recommendedSets = max(1, workoutExercise.recommendedSets)
        let blockCtx = activeBlockContext()
        let stepScale: Double = {
            guard let b = blockCtx else { return 1.0 }
            if b.isDeloadBlock { return 0.65 }
            return max(0.72, min(1.12, b.volumeMultiplier))
        }()
        let blockRationaleSuffix: String = {
            guard let b = blockCtx else { return "" }
            if b.isDeloadBlock { return " Deload phase — smaller jumps fit better." }
            switch b.progressionStrategy {
            case .linear: return " Linear progression phase — prioritize quality reps."
            case .undulating: return " Varied loading phase."
            case .autoregulated: return " Autoregulated phase — adjust by feel."
            case .doubleProgression: return ""
            }
        }()

        let recentLogs: [(Date, ExerciseLog)] = completedSessions
            .compactMap { session in
                guard let date = session.endTime,
                      let log = session.exerciseLogs.first(where: { $0.workoutExercise.exerciseId == exerciseId })
                else { return nil }
                return (date, log)
            }
            .sorted { $0.0 > $1.0 }

        guard let last = recentLogs.first else { return nil }
        let workingSets = last.1.loggedSets
            .filter { $0.countsTowardLoadPRMetrics }
            .sorted { $0.timestamp < $1.timestamp }
        guard !workingSets.isEmpty else { return nil }

        let topWeight = workingSets.map(\.weight).max() ?? 0
        guard topWeight > 0 else { return nil }
        let topWeightSets = workingSets.filter { abs($0.weight - topWeight) < 0.0001 }
        guard !topWeightSets.isEmpty else { return nil }
        let avgTopReps = Double(topWeightSets.reduce(0) { $0 + $1.reps }) / Double(topWeightSets.count)
        let performedSets = topWeightSets.count

        let resolvedExercise = workoutExercise.snapshot.flatMap { resolveExercise(for: $0) }
        let baseStep: Double = {
            if let resolvedExercise, resolvedExercise.exerciseRole == .isolation {
                return 2.5
            }
            return topWeight >= 60 ? 5 : 2.5
        }()
        let scaledStep = baseStep * stepScale
        let step = max(2.5, ((scaledStep / 2.5).rounded() * 2.5))

        if let repRange, avgTopReps >= Double(repRange.high), performedSets >= min(recommendedSets, topWeightSets.count) {
            return ProgressionSuggestion(
                direction: .increase,
                suggestedWeight: max(0, topWeight + step),
                targetReps: "\(repRange.low)-\(repRange.high)",
                rationale: "You hit the top of your rep target on your latest working sets.\(blockRationaleSuffix)"
            )
        }

        if let repRange, avgTopReps < Double(repRange.low) - 1 {
            return ProgressionSuggestion(
                direction: .decrease,
                suggestedWeight: max(0, topWeight - step),
                targetReps: "\(repRange.low)-\(repRange.high)",
                rationale: "Recent reps were below target. A small load reduction can improve quality reps.\(blockRationaleSuffix)"
            )
        }

        let repsText: String
        if let repRange {
            repsText = "\(repRange.low)-\(repRange.high)"
        } else {
            repsText = workoutExercise.recommendedReps
        }
        return ProgressionSuggestion(
            direction: .hold,
            suggestedWeight: topWeight,
            targetReps: repsText,
            rationale: "Build consistency at this load, then progress once reps are stable at the top of range.\(blockRationaleSuffix)"
        )
    }

    // MARK: - Internals

    private func metricOrder(_ metric: ProgressMilestone.Metric) -> Int {
        switch metric {
        case .sessions: return 3
        case .totalSets: return 2
        case .totalVolume: return 1
        }
    }

    private func milestoneProgress() -> [ProgressMilestone] {
        let sessionCount = completedSessions.count
        let totalSets = completedSessions.reduce(0) { $0 + $1.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count } }
        let volume = Int(completedSessions
            .flatMap(\.exerciseLogs)
            .flatMap(\.loggedSets)
            .reduce(0.0) { $0 + $1.totalVolumeLoad }
            .rounded())

        let sessionTargets = [1, 5, 10, 25, 50, 100, 250]
        let setTargets = [50, 100, 250, 500, 1000, 2500, 5000]
        let volumeTargets = [5000, 10000, 25000, 50000, 100000, 250000, 500000]

        return sessionTargets.map { ProgressMilestone(metric: .sessions, target: $0, current: sessionCount) }
            + setTargets.map { ProgressMilestone(metric: .totalSets, target: $0, current: totalSets) }
            + volumeTargets.map { ProgressMilestone(metric: .totalVolume, target: $0, current: volume) }
    }

    private enum StrengthBucket: String {
        case push, pull, legs, core, other
    }

    private func bucket(for exercise: Exercise?) -> StrengthBucket {
        guard let exercise else { return .other }
        let muscles = Set(exercise.targetedMuscles)
        if !muscles.isDisjoint(with: [.chest, .frontDelts, .triceps, .upperChest, .lowerChest]) {
            return .push
        }
        if !muscles.isDisjoint(with: [.lats, .upperBack, .midBack, .rhomboids, .rearDelts, .biceps, .traps]) {
            return .pull
        }
        if !muscles.isDisjoint(with: [.quads, .hamstrings, .glutes, .calves, .soleus, .adductors, .abductors, .hipFlexors]) {
            return .legs
        }
        if !muscles.isDisjoint(with: [.core, .abs, .lowerAbs, .obliques]) {
            return .core
        }
        return .other
    }

    private func strengthScore(in range: Range<Date>) -> Int {
        var maxByBucket: [StrengthBucket: Double] = [:]

        let inRange = completedSessions.filter { session in
            let t = session.endTime ?? session.startTime
            return t >= range.lowerBound && t < range.upperBound
        }

        for session in inRange {
            for log in session.exerciseLogs {
                guard let snap = log.workoutExercise.snapshot else { continue }
                let exercise = resolveExercise(for: snap)
                let bucket = bucket(for: exercise)
                for set in log.loggedSets where set.countsTowardVolumeTotals {
                    let est = PersonalRecordDetector.epley(weight: set.weight, reps: set.reps)
                    maxByBucket[bucket] = max(maxByBucket[bucket] ?? 0, est)
                }
            }
        }

        let push = maxByBucket[.push] ?? 0
        let pull = maxByBucket[.pull] ?? 0
        let legs = maxByBucket[.legs] ?? 0
        let core = maxByBucket[.core] ?? 0
        let other = maxByBucket[.other] ?? 0

        if push == 0 && pull == 0 && legs == 0 && core == 0 && other == 0 { return 0 }
        let weighted = (push * 1.0) + (pull * 1.0) + (legs * 1.2) + (core * 0.5) + (other * 0.3)
        return Int((weighted / 3.0).rounded())
    }

    private func weeklyStrengthTrend(referenceDate: Date, calendar: Calendar, weeks: Int) -> [StrengthScorePoint] {
        guard weeks > 0 else { return [] }
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? calendar.startOfDay(for: referenceDate)
        let starts: [Date] = (0..<weeks).compactMap { n in
            calendar.date(byAdding: .weekOfYear, value: -(weeks - 1 - n), to: thisWeekStart)
        }
        return starts.map { weekStart in
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
            return StrengthScorePoint(weekStart: weekStart, score: strengthScore(in: weekStart..<weekEnd))
        }
    }

    private func parseRepRange(_ text: String) -> (low: Int, high: Int)? {
        let nums = text
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        if nums.isEmpty { return nil }
        if nums.count == 1 {
            let n = max(1, nums[0])
            return (n, n)
        }
        let low = max(1, min(nums[0], nums[1]))
        let high = max(low, max(nums[0], nums[1]))
        return (low, high)
    }

    // MARK: - All-time PRs & historical set context

    private struct PRScanMaxima {
        var maxWeight: Double = 0
        var maxOneRM: Double = 0
        var maxSetVolume: Double = 0
        var maxDistance: Double = 0
        var maxDuration: Double = 0
        var bestPace: Double = 0
        var maxCalories: Double = 0
        var hasBestPace = false
        var initialized = false
    }

    /// Chronological scan: every time a set establishes a new best for weight, est. 1RM, or set volume for that exercise.
    func allTimePersonalRecords() -> [ArchivedPersonalRecord] {
        let sessions = completedSessions.filter(\.isCompleted).sorted {
            let a = $0.endTime ?? $0.startTime
            let b = $1.endTime ?? $1.startTime
            if a != b { return a < b }
            return $0.id.uuidString < $1.id.uuidString
        }
        var maximaByExercise: [UUID: PRScanMaxima] = [:]
        var records: [ArchivedPersonalRecord] = []

        for session in sessions {
            let when = session.endTime ?? session.startTime
            for log in session.exerciseLogs {
                guard let exerciseId = log.workoutExercise.exerciseId else { continue }
                let name = displayName(for: log.workoutExercise)
                let ordered = log.loggedSets.sorted { $0.timestamp < $1.timestamp }
                var prior: [LoggedSet] = []
                for set in ordered {
                    if set.countsTowardLoadPRMetrics {
                        var m = maximaByExercise[exerciseId] ?? PRScanMaxima()
                        let oneRM = PersonalRecordDetector.epley(weight: set.weight, reps: set.reps)
                        let vol = set.totalVolumeLoad

                        let isWeightPR = !m.initialized || set.weight > m.maxWeight + 0.0001
                        let isOneRMPR = !m.initialized || oneRM > m.maxOneRM + 0.0001
                        let isVolumePR = !m.initialized || vol > m.maxSetVolume + 0.0001

                        if isWeightPR {
                            records.append(
                                ArchivedPersonalRecord(
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .maxWeight,
                                    value: set.weight,
                                    achievedAt: when
                                )
                            )
                        }
                        if isOneRMPR {
                            records.append(
                                ArchivedPersonalRecord(
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .estimatedOneRM,
                                    value: oneRM,
                                    achievedAt: when
                                )
                            )
                        }
                        if isVolumePR {
                            records.append(
                                ArchivedPersonalRecord(
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .maxVolumeSet,
                                    value: vol,
                                    achievedAt: when
                                )
                            )
                        }

                        m.maxWeight = max(m.maxWeight, set.weight)
                        m.maxOneRM = max(m.maxOneRM, oneRM)
                        m.maxSetVolume = max(m.maxSetVolume, vol)
                        m.initialized = true
                        maximaByExercise[exerciseId] = m
                    }

                    if set.countsTowardCardioTotals, let metrics = set.cardioMetrics {
                        var m = maximaByExercise[exerciseId] ?? PRScanMaxima()
                        if let dist = metrics.distanceM, dist > 0,
                           !m.initialized || dist > m.maxDistance + 0.0001 {
                            records.append(
                                ArchivedPersonalRecord(
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .maxDistance,
                                    value: dist,
                                    achievedAt: when
                                )
                            )
                            m.maxDistance = max(m.maxDistance, dist)
                        }
                        if let sec = metrics.durationSec, sec > 0 {
                            let d = Double(sec)
                            if !m.initialized || d > m.maxDuration + 0.0001 {
                                records.append(
                                    ArchivedPersonalRecord(
                                        exerciseId: exerciseId,
                                        exerciseName: name,
                                        kind: .longestDuration,
                                        value: d,
                                        achievedAt: when
                                    )
                                )
                                m.maxDuration = max(m.maxDuration, d)
                            }
                        }
                        if let pace = metrics.resolvedPaceSecPerKm, pace > 0 {
                            let p = Double(pace)
                            if !m.hasBestPace || p < m.bestPace - 0.0001 {
                                records.append(
                                    ArchivedPersonalRecord(
                                        exerciseId: exerciseId,
                                        exerciseName: name,
                                        kind: .bestPace,
                                        value: p,
                                        achievedAt: when
                                    )
                                )
                                m.bestPace = p
                                m.hasBestPace = true
                            }
                        }
                        if let cal = metrics.calories, cal > 0,
                           !m.initialized || cal > m.maxCalories + 0.0001 {
                            records.append(
                                ArchivedPersonalRecord(
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .maxCalories,
                                    value: cal,
                                    achievedAt: when
                                )
                            )
                            m.maxCalories = max(m.maxCalories, cal)
                        }
                        m.initialized = true
                        maximaByExercise[exerciseId] = m
                    }

                    prior.append(set)
                }
            }
        }

        return records.sorted { $0.achievedAt > $1.achievedAt }
    }

    private func isHistoricalSetStrictlyBefore(
        sessionA: WorkoutSession,
        setA: LoggedSet,
        sessionB: WorkoutSession,
        setB: LoggedSet
    ) -> Bool {
        guard sessionA.isCompleted, sessionB.isCompleted else { return false }
        let endA = sessionA.endTime ?? sessionA.startTime
        let endB = sessionB.endTime ?? sessionB.startTime
        if endA != endB { return endA < endB }
        if sessionA.id != sessionB.id { return sessionA.id.uuidString < sessionB.id.uuidString }
        if setA.timestamp != setB.timestamp { return setA.timestamp < setB.timestamp }
        return setA.id.uuidString < setB.id.uuidString
    }

    /// Sets for the same exercise that count as \"before\" this set for PR detection (completed history only).
    func priorSetsForPersonalRecordDetection(
        exerciseId: UUID,
        beforeSession: WorkoutSession,
        beforeSet: LoggedSet
    ) -> [LoggedSet] {
        var out: [LoggedSet] = []
        for s in completedSessions where s.isCompleted {
            for log in s.exerciseLogs {
                guard log.workoutExercise.exerciseId == exerciseId else { continue }
                for ls in log.loggedSets {
                    let counts = beforeSet.countsTowardCardioTotals
                        ? ls.countsTowardCardioTotals
                        : ls.countsTowardLoadPRMetrics
                    guard counts else { continue }
                    if isHistoricalSetStrictlyBefore(sessionA: s, setA: ls, sessionB: beforeSession, setB: beforeSet) {
                        out.append(ls)
                    }
                }
            }
        }
        return out
    }

    func personalRecordKindsForHistoricalSet(
        set: LoggedSet,
        log: ExerciseLog,
        session: WorkoutSession
    ) -> [PersonalRecordEvent.Kind] {
        guard let exerciseId = log.workoutExercise.exerciseId, session.isCompleted else { return [] }
        let prior = priorSetsForPersonalRecordDetection(
            exerciseId: exerciseId,
            beforeSession: session,
            beforeSet: set
        )
        let name = displayName(for: log.workoutExercise)
        return PersonalRecordDetector.detect(
            newSet: set,
            priorSets: prior,
            exerciseId: exerciseId,
            exerciseName: name,
            timestamp: set.timestamp
        ).map(\.kind)
    }
}
