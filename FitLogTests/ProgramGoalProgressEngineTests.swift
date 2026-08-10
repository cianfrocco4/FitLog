//
//  ProgramGoalProgressEngineTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class ProgramGoalProgressEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeProgram(
        sessionsPerWeek: Int = 3,
        preferredWeekdays: [Int] = [2, 4, 6],
        durationWeeks: Int = 4,
        deload: Bool = false
    ) -> DynamicProgram {
        let slots = [
            SplitBuilderEditableSlot(label: "Squat", targetMuscleNames: ["quads"], sets: 4, reps: "5"),
            SplitBuilderEditableSlot(label: "Bench", targetMuscleNames: ["chest"], sets: 3, reps: "8"),
        ]
        let block = ProgramBlock(
            name: "Main",
            focus: BlockFocus(kind: deload ? .deload : .hypertrophy, emphasisLabel: ""),
            durationWeeks: durationWeeks,
            weeklyTemplates: [
                BlockWeeklyTemplate(dayName: "A", focus: "", slots: slots),
                BlockWeeklyTemplate(dayName: "B", focus: "", slots: slots),
                BlockWeeklyTemplate(dayName: "C", focus: "", slots: slots),
            ],
            isDeloadBlock: deload,
            volumeMultiplier: deload ? 0.7 : 1.0
        )
        let program = DynamicProgram(
            name: "Test",
            blocks: [block],
            defaultSessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays
        )
        return ProgramPhaseGoalFactory.attachingAutoGoals(to: program, primaryGoal: .buildMuscle)
    }

    private func monday(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)!
    }

    func testMidWeekAnchorPartialFirstWeek() {
        // Wednesday anchor inside an ISO week.
        let anchor = monday(year: 2026, month: 3, day: 4).addingTimeInterval(2 * 24 * 3600) // Wed Mar 6
        let program = makeProgram()
        let state = DynamicProgramState(program: program, anchorDate: calendar.startOfDay(for: anchor))
        let engine = ProgramGoalProgressEngine(calendar: calendar)
        let card = engine.scorecard(
            forWeekContaining: anchor,
            state: state,
            completedSessions: [],
            referenceNow: anchor
        )
        // Only training days on/after Wed in preferred Mon/Wed/Fri → Wed + Fri = 2 (Mon already passed before anchor → unscheduled)
        XCTAssertGreaterThanOrEqual(card.metrics.first(where: { $0.kind == .sessionsPerWeek })?.planned ?? 0, 1)
        XCTAssertNotEqual(card.status, .missed)
    }

    func testFullyBusyWeekIsNotScheduled() {
        let anchor = monday(year: 2026, month: 3, day: 2)
        let program = makeProgram()
        var state = DynamicProgramState(program: program, anchorDate: anchor)
        let days = TrainingProgramState.orderedCalendarDaysInWeek(containing: anchor, calendar: calendar)
        state.busyDayKeys = Set(days.map { TrainingProgramState.dayKey(for: $0, calendar: calendar) })
        let engine = ProgramGoalProgressEngine(calendar: calendar)
        let card = engine.scorecard(
            forWeekContaining: anchor,
            state: state,
            completedSessions: [],
            referenceNow: anchor
        )
        XCTAssertEqual(card.status, .notScheduled)
    }

    func testCurrentWeekNeverReportsMissed() {
        let anchor = monday(year: 2026, month: 3, day: 2)
        let program = makeProgram()
        let state = DynamicProgramState(program: program, anchorDate: anchor)
        let engine = ProgramGoalProgressEngine(calendar: calendar)
        let midWeek = anchor.addingTimeInterval(3 * 24 * 3600)
        let card = engine.scorecard(
            forWeekContaining: midWeek,
            state: state,
            completedSessions: [],
            referenceNow: midWeek
        )
        XCTAssertNotEqual(card.status, .missed)
        XCTAssertTrue(card.status == .onTrack || card.status == .atRisk || card.status == .notScheduled)
    }

    func testPastWeekMetWhenSessionsComplete() {
        let anchor = monday(year: 2026, month: 3, day: 2)
        let program = makeProgram(sessionsPerWeek: 3, preferredWeekdays: [2, 4, 6])
        let state = DynamicProgramState(program: program, anchorDate: anchor)
        let pe = PeriodizationEngine(calendar: calendar)
        let days = TrainingProgramState.orderedCalendarDaysInWeek(containing: anchor, calendar: calendar)
        var sessions: [WorkoutSession] = []
        for day in days {
            switch pe.resolvedTemplateDay(on: day, state: state) {
            case .training, .flex:
                sessions.append(makeCompletedSession(on: day))
            default:
                break
            }
        }
        let engine = ProgramGoalProgressEngine(calendar: calendar)
        let later = anchor.addingTimeInterval(10 * 24 * 3600)
        let card = engine.scorecard(
            forWeekContaining: anchor,
            state: state,
            completedSessions: sessions,
            referenceNow: later
        )
        XCTAssertEqual(card.status, .met)
    }

    func testDeloadWeekUsesScaledTargets() {
        let anchor = monday(year: 2026, month: 3, day: 2)
        let program = makeProgram(deload: true)
        let state = DynamicProgramState(program: program, anchorDate: anchor)
        let engine = ProgramGoalProgressEngine(calendar: calendar)
        let card = engine.scorecard(
            forWeekContaining: anchor,
            state: state,
            completedSessions: [],
            referenceNow: anchor
        )
        XCTAssertTrue(card.isDeloadWeek)
        let hard = card.metrics.first(where: { $0.kind == .weeklyHardSets })?.planned ?? 0
        XCTAssertGreaterThan(hard, 0)
        // 3 days × 7 sets × 0.7 ≈ 15
        XCTAssertLessThan(hard, 3 * 7)
    }

    func testNoSessionsLoggedStillScores() {
        let anchor = monday(year: 2026, month: 3, day: 2)
        let program = makeProgram()
        let state = DynamicProgramState(program: program, anchorDate: anchor)
        let engine = ProgramGoalProgressEngine(calendar: calendar)
        let card = engine.scorecard(
            forWeekContaining: anchor,
            state: state,
            completedSessions: [],
            referenceNow: anchor.addingTimeInterval(2 * 24 * 3600)
        )
        XCTAssertEqual(card.metrics.first(where: { $0.kind == .sessionsPerWeek })?.actual, 0)
    }

    func testPhaseRollupExcludesInProgressWeekFromElapsed() throws {
        let anchor = monday(year: 2026, month: 3, day: 2)
        let program = makeProgram()
        let state = DynamicProgramState(program: program, anchorDate: anchor)
        let blockId = program.blocks[0].id
        let engine = ProgramGoalProgressEngine(calendar: calendar)
        let midWeek = anchor.addingTimeInterval(2 * 24 * 3600)
        let progress = try XCTUnwrap(
            engine.phaseProgress(
                for: blockId,
                state: state,
                completedSessions: [],
                referenceNow: midWeek
            )
        )
        XCTAssertEqual(progress.weeksElapsed, 0, "Live week must not inflate weeksElapsed")
        XCTAssertEqual(progress.weeksMet, 0)
        XCTAssertEqual(progress.completionLabel, "Not started")
        XCTAssertTrue(progress.weekScorecards.contains { $0.status == .onTrack || $0.status == .atRisk })
    }

    private func makeCompletedSession(on day: Date) -> WorkoutSession {
        let exercise = Exercise(id: UUID(), name: "Squat", description: "", targetedMuscles: [.quads], isCustom: false)
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "5")
        let sets = (0..<4).map { _ in
            LoggedSet(id: UUID(), weight: 100, reps: 5, restTime: 90, timestamp: day, setType: .working)
        }
        let log = ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: sets)
        let start = day.addingTimeInterval(12 * 3600)
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "A", exercises: [we]),
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            exerciseLogs: [log],
            activeExerciseIds: [],
            completedExerciseIds: [we.id]
        )
    }
}
