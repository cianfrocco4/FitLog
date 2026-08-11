//
//  ProgramGoalProgressEngine.swift
//  FitLog
//
//  Scores phase process goals per calendar week by walking resolved schedule days.
//

import Foundation

struct ProgramGoalProgressEngine: Sendable {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Public API

    func scorecard(
        forWeekContaining date: Date,
        state: DynamicProgramState,
        completedSessions: [WorkoutSession],
        referenceNow: Date = Date()
    ) -> WeekGoalScorecard {
        let dayStarts = TrainingProgramState.orderedCalendarDaysInWeek(containing: date, calendar: calendar)
        let weekStart = dayStarts.first ?? calendar.startOfDay(for: date)
        let isoWeekKey = TrainingProgramState.isoWeekKey(for: weekStart, calendar: calendar)
        let periodization = PeriodizationEngine(calendar: calendar)

        var plannedSessions = 0
        var plannedHardSets = 0
        var plannedCardioMinutes = 0
        var blockVotes: [UUID: Int] = [:]
        var weekInBlockVotes: [Int: Int] = [:]
        var deloadVotes = 0

        for day in dayStarts {
            let resolved = periodization.resolvedTemplateDay(on: day, state: state)
            switch resolved {
            case .training(let template), .flex(let template):
                plannedSessions += 1
                if let placement = periodization.blockPlacement(on: day, state: state) {
                    blockVotes[placement.block.id, default: 0] += 1
                    weekInBlockVotes[placement.weekInBlock, default: 0] += 1
                    let multiplier = ProgramVolumeMath.effectiveVolumeMultiplier(
                        for: placement.block,
                        weekInBlock: placement.weekInBlock
                    )
                    plannedHardSets += ProgramVolumeMath.plannedHardSets(
                        in: template,
                        volumeMultiplier: multiplier
                    )
                    plannedCardioMinutes += ProgramVolumeMath.plannedCardioMinutes(
                        in: template.slots,
                        volumeMultiplier: multiplier
                    )
                    if placement.block.isDeloadBlock
                        || placement.block.focus.kind == .deload
                        || (placement.block.deloadWeekNumber == placement.weekInBlock + 1) {
                        deloadVotes += 1
                    }
                } else {
                    plannedHardSets += ProgramVolumeMath.plannedHardSets(in: template)
                    plannedCardioMinutes += ProgramVolumeMath.plannedCardioMinutes(in: template.slots)
                }
            case .rest, .unscheduled:
                break
            }
        }

        let owningBlockId = blockVotes.max(by: { $0.value < $1.value })?.key
        let weekInBlock = weekInBlockVotes.max(by: { $0.value < $1.value })?.key
        let isDeloadWeek = deloadVotes > 0 && deloadVotes >= (plannedSessions / 2)

        let weekSessions = sessions(in: dayStarts, from: completedSessions)
        let actualSessions = Double(countCompletedSessions(on: dayStarts, from: completedSessions, state: state, engine: periodization))
        let actualHardSets = Double(ProgramVolumeMath.actualHardSets(in: weekSessions))
        let actualCardio = Double(ProgramVolumeMath.actualCardioMinutes(in: weekSessions))

        // Prefer authored phase-goal targets when present; otherwise use walked planned values.
        let phaseGoal = owningBlockId.flatMap { id in state.program.blocks.first(where: { $0.id == id })?.phaseGoal }
        let sessionTarget = targetValue(kind: .sessionsPerWeek, phaseGoal: phaseGoal, walked: Double(plannedSessions))
        let hardSetTarget = targetValue(kind: .weeklyHardSets, phaseGoal: phaseGoal, walked: Double(plannedHardSets))
        let cardioTarget = targetValue(kind: .weeklyCardioMinutes, phaseGoal: phaseGoal, walked: Double(plannedCardioMinutes))

        var metrics: [MetricProgress] = [
            MetricProgress(kind: .sessionsPerWeek, planned: sessionTarget, actual: actualSessions, isPrimary: true),
        ]
        if hardSetTarget > 0 || actualHardSets > 0 {
            metrics.append(
                MetricProgress(kind: .weeklyHardSets, planned: hardSetTarget, actual: actualHardSets, isPrimary: false)
            )
        }
        if cardioTarget > 0 || actualCardio > 0 {
            let includeCardio = phaseGoal?.targets.contains(where: { $0.kind == .weeklyCardioMinutes }) == true
                || cardioTarget > 0
            if includeCardio {
                metrics.append(
                    MetricProgress(kind: .weeklyCardioMinutes, planned: cardioTarget, actual: actualCardio, isPrimary: false)
                )
            }
        }

        let status = resolveStatus(
            metrics: metrics,
            plannedSessions: plannedSessions,
            weekStart: weekStart,
            dayStarts: dayStarts,
            referenceNow: referenceNow,
            phaseGoal: phaseGoal
        )
        let sentence = statusSentence(
            status: status,
            metrics: metrics,
            isDeloadWeek: isDeloadWeek
        )

        return WeekGoalScorecard(
            weekStart: weekStart,
            isoWeekKey: isoWeekKey,
            owningBlockId: owningBlockId,
            weekInBlock: weekInBlock,
            isDeloadWeek: isDeloadWeek,
            metrics: metrics,
            status: status,
            statusSentence: sentence
        )
    }

    func phaseProgress(
        for blockId: UUID,
        state: DynamicProgramState,
        completedSessions: [WorkoutSession],
        referenceNow: Date = Date()
    ) -> PhaseGoalProgress? {
        guard let blockIndex = state.program.blocks.firstIndex(where: { $0.id == blockId }) else { return nil }
        let block = state.program.blocks[blockIndex]
        let engine = PeriodizationEngine(calendar: calendar)
        let blockStart = engine.blockStartDate(blockIndex: blockIndex, state: state)
        let blockEnd = engine.blockEndDate(blockIndex: blockIndex, state: state)

        var weekStarts: [Date] = []
        var cursor = TrainingProgramState.orderedCalendarDaysInWeek(containing: blockStart, calendar: calendar).first
            ?? calendar.startOfDay(for: blockStart)
        let lastWeekStart = TrainingProgramState.orderedCalendarDaysInWeek(containing: blockEnd, calendar: calendar).first
            ?? calendar.startOfDay(for: blockEnd)

        while cursor <= lastWeekStart {
            weekStarts.append(cursor)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }

        let cards = weekStarts.map {
            scorecard(forWeekContaining: $0, state: state, completedSessions: completedSessions, referenceNow: referenceNow)
        }.filter { $0.owningBlockId == blockId || $0.owningBlockId == nil }

        // Only finished weeks (met/missed) count toward the rollup. Live weeks stay in
        // the scorecard list but must not produce "0 of 1 weeks on target" while On track.
        let finished = cards.filter { $0.status == .met || $0.status == .missed }
        let finishedMet = finished.filter { $0.status == .met }.count
        let elapsed = finished.count
        let fraction: Double = elapsed == 0 ? 0 : Double(finishedMet) / Double(elapsed)

        return PhaseGoalProgress(
            blockId: blockId,
            phaseGoal: block.phaseGoal,
            weeksMet: finishedMet,
            weeksElapsed: elapsed,
            overallFraction: fraction,
            weekScorecards: cards
        )
    }

    // MARK: - Internals

    private func targetValue(kind: ProgramGoalMetricKind, phaseGoal: ProgramPhaseGoal?, walked: Double) -> Double {
        if let authored = phaseGoal?.targets.first(where: { $0.kind == kind }) {
            // For sessions, prefer the walked planned count when the week is partial / busy-adjusted,
            // unless the user explicitly set the target.
            if kind == .sessionsPerWeek, authored.source == .auto, walked > 0 {
                return walked
            }
            if kind == .weeklyHardSets, authored.source == .auto, walked > 0 {
                return walked
            }
            if kind == .weeklyCardioMinutes, authored.source == .auto, walked > 0 {
                return walked
            }
            if walked == 0, authored.source == .auto {
                return 0
            }
            return authored.value
        }
        return walked
    }

    private func resolveStatus(
        metrics: [MetricProgress],
        plannedSessions: Int,
        weekStart: Date,
        dayStarts: [Date],
        referenceNow: Date,
        phaseGoal: ProgramPhaseGoal?
    ) -> WeekGoalStatus {
        if plannedSessions == 0 {
            return .notScheduled
        }

        let today = calendar.startOfDay(for: referenceNow)
        let weekEnd = dayStarts.last ?? weekStart
        let isFuture = weekStart > today
        let isCurrent = !isFuture && weekEnd >= today
        let isPast = weekEnd < today

        if isFuture { return .upcoming }

        let primary = metrics.first(where: \.isPrimary) ?? metrics.first
        let tolerance = phaseGoal?.primaryTarget?.tolerance ?? 0
        let primaryMet: Bool = {
            guard let primary else { return false }
            return primary.actual + tolerance + 0.001 >= primary.planned
        }()

        if isPast {
            return primaryMet ? .met : .missed
        }

        // Current week: pace-adjusted against days elapsed in the week.
        guard isCurrent, let primary else { return .onTrack }
        let elapsedDays = max(1, dayStarts.filter { $0 <= today }.count)
        let totalDays = max(1, dayStarts.count)
        let expectedFraction = Double(elapsedDays) / Double(totalDays)
        let expectedActual = primary.planned * expectedFraction
        // Small grace so early-week zeros don't immediately read as at-risk.
        let grace = max(0.35, primary.planned * 0.15)
        if primary.actual + grace + 0.001 >= expectedActual {
            return .onTrack
        }
        return .atRisk
    }

    private func statusSentence(
        status: WeekGoalStatus,
        metrics: [MetricProgress],
        isDeloadWeek: Bool
    ) -> String {
        let sessions = metrics.first(where: { $0.kind == .sessionsPerWeek })
        let hardSets = metrics.first(where: { $0.kind == .weeklyHardSets })
        let sessionPart: String = {
            guard let sessions, sessions.planned > 0 else { return "" }
            let a = Int(sessions.actual.rounded())
            let p = Int(sessions.planned.rounded())
            return "\(a) of \(p) sessions"
        }()
        let volumePart: String = {
            guard let hardSets, hardSets.planned > 0 else { return "" }
            let pct = Int((hardSets.fraction * 100).rounded())
            return "volume \(pct)%"
        }()

        let deloadNote = isDeloadWeek ? " (lighter on purpose)" : ""

        switch status {
        case .upcoming:
            var parts: [String] = []
            if let sessions, sessions.planned > 0 {
                parts.append("\(Int(sessions.planned.rounded())) sessions")
            }
            if let hardSets, hardSets.planned > 0 {
                parts.append("~\(Int(hardSets.planned.rounded())) hard sets")
            }
            let joined = parts.isEmpty ? "Targets coming up" : parts.joined(separator: " · ")
            return joined + deloadNote
        case .notScheduled:
            return "No sessions planned this week"
        case .onTrack:
            let detail = [sessionPart, volumePart].filter { !$0.isEmpty }.joined(separator: ", ")
            return detail.isEmpty ? "On track\(deloadNote)" : "On track — \(detail)\(deloadNote)"
        case .atRisk:
            let detail = [sessionPart, volumePart].filter { !$0.isEmpty }.joined(separator: ", ")
            return detail.isEmpty ? "Needs catch-up\(deloadNote)" : "Needs catch-up — \(detail)\(deloadNote)"
        case .met:
            return sessionPart.isEmpty ? "Goal met\(deloadNote)" : "Goal met — \(sessionPart)\(deloadNote)"
        case .missed:
            return sessionPart.isEmpty ? "Missed this week\(deloadNote)" : "Missed — \(sessionPart)\(deloadNote)"
        }
    }

    private func sessions(in dayStarts: [Date], from completedSessions: [WorkoutSession]) -> [WorkoutSession] {
        guard let first = dayStarts.first, let last = dayStarts.last else { return [] }
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return completedSessions.filter { session in
            guard session.isCompleted else { return false }
            let t = session.endTime ?? session.startTime
            return t >= first && t < endExclusive
        }
    }

    /// Counts completed sessions on planned training/flex days (matches block ring semantics).
    private func countCompletedSessions(
        on dayStarts: [Date],
        from completedSessions: [WorkoutSession],
        state: DynamicProgramState,
        engine: PeriodizationEngine
    ) -> Int {
        var count = 0
        for day in dayStarts {
            switch engine.resolvedTemplateDay(on: day, state: state) {
            case .training, .flex:
                let key = TrainingProgramState.dayKey(for: day, calendar: calendar)
                let has = completedSessions.contains { session in
                    guard session.isCompleted else { return false }
                    let t = session.endTime ?? session.startTime
                    return TrainingProgramState.dayKey(for: t, calendar: calendar) == key
                }
                if has { count += 1 }
            case .rest, .unscheduled:
                break
            }
        }
        return count
    }

}
