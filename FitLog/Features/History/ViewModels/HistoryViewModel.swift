//
//  HistoryViewModel.swift
//  FitLog
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class HistoryViewModel {
    var dayRange: HistoryDayRange = .d14
    var mainTab: HistoryMainTab = .overview
    var comparePriorPeriod = false
    var exploreSearch = ""
    var sessionsSearch = ""

    var selectedWorkoutsWeek: Date?
    var selectedVolumeWeek: Date?
    var selectedSetsWeek: Date?
    var selectedCardioWeek: Date?

    private(set) var sessionsInDateRange: [WorkoutSession] = []
    private(set) var allSessionsSorted: [WorkoutSession] = []
    /// Sessions before the selected range. Listed in Sessions; omitted from charts/KPIs.
    private(set) var olderSessionsOutsideRange: [WorkoutSession] = []
    private(set) var priorSessions: [WorkoutSession] = []

    private(set) var currentKPIs: HistoryKPIs = .empty
    private(set) var priorKPIs: HistoryKPIs = .empty
    private(set) var currentTrainingStreak: Int = 0

    private(set) var weeklyWorkouts: [WeekData] = []
    private(set) var priorWeeklyWorkouts: [WeekData] = []
    private(set) var weeklyVolume: [WeekVolumeData] = []
    private(set) var priorWeeklyVolume: [WeekVolumeData] = []
    private(set) var weeklySetCounts: [WeekData] = []
    private(set) var priorWeeklySetCounts: [WeekData] = []
    private(set) var weeklyCardio: [WeekCardioData] = []
    private(set) var priorWeeklyCardio: [WeekCardioData] = []

    private(set) var muscleVolumeRows: [MuscleVolumeRow] = []
    private(set) var yearHeatmapDays: [YearHeatmapDay] = []
    private(set) var sessionSections: [HistorySessionSection] = []

    private(set) var exerciseStats: [ExerciseStat] = []
    private(set) var muscleGroupStats: [MuscleGroupStat] = []

    private var sessionSummaries: [UUID: HistorySessionSummary] = [:]
    private var lastDataRevision: Int = -1
    private var lastDayRange: HistoryDayRange?
    private var sessionsDataRevision: Int = -1
    private var exploreDataRevision: Int = -1

    var hasActiveFilters: Bool {
        dayRange != .defaultRange || comparePriorPeriod
    }

    var rangeDescription: String { dayRange.rangeDescription }

    var periodCutoff: Date {
        dayRange.cutoff(from: Date(), calendar: .current)
    }

    var weeksInSelectedRange: Int {
        HistoryAggregator.weekCount(from: periodCutoff, to: Date(), calendar: .current)
    }

    var filteredSessionsForSessionsTab: [WorkoutSession] {
        filterSessions(sessionsInDateRange)
    }

    var filteredOlderSessionsForSessionsTab: [WorkoutSession] {
        filterSessions(olderSessionsOutsideRange)
    }

    var olderSessionsSectionTitle: String {
        HistoryFreePeek.olderSectionTitle(range: dayRange)
    }

    private func filterSessions(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        let q = sessionsSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return sessions }
        return sessions.filter { $0.workout.name.lowercased().contains(q) }
    }

    func sessionSummary(for session: WorkoutSession) -> HistorySessionSummary {
        sessionSummaries[session.id] ?? HistorySessionSummary(
            setCount: 0,
            volume: 0,
            durationSeconds: 0,
            prKinds: []
        )
    }

    func recompute(dataVM: DataManager, now: Date = Date()) {
        let revision = HistoryAggregator.contentRevision(for: dataVM.completedSessions)
        let rangeChanged = lastDayRange != dayRange
        guard revision != lastDataRevision || rangeChanged else { return }

        lastDataRevision = revision
        lastDayRange = dayRange
        sessionsDataRevision = -1
        exploreDataRevision = -1

        recomputeCore(dataVM: dataVM, now: now)
    }

    func ensureSessionsData(dataVM: DataManager) {
        guard sessionsDataRevision != lastDataRevision else { return }
        let calendar = Calendar.current
        sessionSections = HistoryAggregator.groupedSessionSections(sessionsInDateRange, calendar: calendar)

        var summaries: [UUID: HistorySessionSummary] = [:]
        for session in sessionsInDateRange + olderSessionsOutsideRange {
            summaries[session.id] = HistoryAggregator.sessionSummary(session: session, dataVM: dataVM)
        }
        sessionSummaries = summaries
        sessionsDataRevision = lastDataRevision
    }

    func ensureExploreData(dataVM: DataManager) {
        guard exploreDataRevision != lastDataRevision else { return }
        exerciseStats = HistoryAggregator.exerciseStats(in: sessionsInDateRange, dataVM: dataVM)
        muscleGroupStats = HistoryAggregator.muscleGroupStats(in: sessionsInDateRange, dataVM: dataVM)
        exploreDataRevision = lastDataRevision
    }

    private func recomputeCore(dataVM: DataManager, now: Date) {
        let all = dataVM.completedSessions
        let cutoff = dayRange.cutoff(from: now, calendar: .current)
        let calendar = Calendar.current

        sessionsInDateRange = HistoryAggregator.sessionsInDateRange(from: all, cutoff: cutoff)
        allSessionsSorted = HistoryAggregator.allSessionsSorted(from: all)
        olderSessionsOutsideRange = HistoryAggregator.sessionsOutsideDateRange(from: all, cutoff: cutoff)

        if let (priorStart, priorEnd) = dayRange.priorWindow(from: now, calendar: calendar) {
            priorSessions = HistoryAggregator.priorSessions(from: all, priorStart: priorStart, priorEnd: priorEnd)
        } else {
            priorSessions = []
        }

        currentKPIs = HistoryAggregator.computeKPIs(sessionsInDateRange, periodCutoff: cutoff)
        priorKPIs = HistoryAggregator.computeKPIs(priorSessions, periodCutoff: cutoff)

        let allTrainedDays = HistoryAggregator.trainedDays(from: all, calendar: calendar)
        currentTrainingStreak = HistoryAggregator.currentTrainingStreak(trainedDays: allTrainedDays, calendar: calendar)

        weeklyWorkouts = HistoryAggregator.weeklyWorkouts(from: sessionsInDateRange, calendar: calendar)
        weeklyVolume = HistoryAggregator.weeklyVolume(from: sessionsInDateRange, calendar: calendar)
        weeklySetCounts = HistoryAggregator.weeklySetCounts(from: sessionsInDateRange, calendar: calendar)
        weeklyCardio = HistoryAggregator.weeklyCardio(
            from: sessionsInDateRange,
            exercises: dataVM.globalExercises,
            calendar: calendar
        )

        if let weekShift = dayRange.priorToCurrentWeekShift(from: now, calendar: calendar) {
            priorWeeklyWorkouts = HistoryAggregator.shiftWeekData(
                HistoryAggregator.weeklyWorkouts(from: priorSessions, calendar: calendar),
                by: weekShift,
                calendar: calendar
            )
            priorWeeklyVolume = HistoryAggregator.shiftWeekVolumeData(
                HistoryAggregator.weeklyVolume(from: priorSessions, calendar: calendar),
                by: weekShift,
                calendar: calendar
            )
            priorWeeklySetCounts = HistoryAggregator.shiftWeekData(
                HistoryAggregator.weeklySetCounts(from: priorSessions, calendar: calendar),
                by: weekShift,
                calendar: calendar
            )
            priorWeeklyCardio = HistoryAggregator.shiftWeekCardioData(
                HistoryAggregator.weeklyCardio(
                    from: priorSessions,
                    exercises: dataVM.globalExercises,
                    calendar: calendar
                ),
                by: weekShift,
                calendar: calendar
            )
        } else {
            priorWeeklyWorkouts = []
            priorWeeklyVolume = []
            priorWeeklySetCounts = []
            priorWeeklyCardio = []
        }

        muscleVolumeRows = HistoryAggregator.muscleGroupVolumeRows(in: sessionsInDateRange, dataVM: dataVM)
        yearHeatmapDays = HistoryAggregator.yearHeatmapDays(from: all, calendar: calendar)
    }
}
