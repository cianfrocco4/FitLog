//
//  SplitCalendarPreview.swift
//  FitLog
//
//  4-week calendar preview showing how the proposed split will schedule (Task 23).
//

import SwiftUI

struct SplitCalendarPreview: View {
    let cycleEntries: [WorkoutPlanRef]
    let sessionsPerWeek: Int
    let preferredWeekdays: [Int]
    let anchorDate: Date
    let workouts: [UUID: Workout]

    @State private var previewSchedule: [Date: ResolvedScheduleDay] = [:]

    private let calendar = Calendar.current
    private let weeksToShow = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("4-Week Preview")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if previewSchedule.isEmpty {
                Text("Generating preview...")
                    .foregroundStyle(.secondary)
            } else {
                calendarGrid
            }
        }
        .onAppear {
            generatePreview()
        }
        .onChange(of: anchorDate) {
            generatePreview()
        }
        .onChange(of: sessionsPerWeek) {
            generatePreview()
        }
        .onChange(of: preferredWeekdays) {
            generatePreview()
        }
    }

    @ViewBuilder
    private var calendarGrid: some View {
        let weeks = buildWeeks()
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                weekRow(week: week, weekNumber: weekIndex + 1)
            }
        }
    }

    @ViewBuilder
    private func weekRow(week: [Date], weekNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Week \(weekNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(week, id: \.self) { date in
                    dayChip(for: date)
                }
            }
        }
    }

    @ViewBuilder
    private func dayChip(for date: Date) -> some View {
        let resolved = previewSchedule[date] ?? .unscheduled
        let daySymbol = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        let dayNumber = calendar.component(.day, from: date)

        VStack(spacing: 2) {
            Text(daySymbol.prefix(1))
                .font(.caption2)
                .fontWeight(.medium)
            Text("\(dayNumber)")
                .font(.caption)
        }
        .frame(width: 40, height: 44)
        .background(chipBackground(for: resolved))
        .foregroundStyle(chipForeground(for: resolved))
        .cornerRadius(6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(daySymbol) \(dayNumber), \(accessibilityLabel(for: resolved))")
    }

    @ViewBuilder
    private func chipBackground(for resolved: ResolvedScheduleDay) -> some View {
        switch resolved {
        case .workout:
            Color.accentColor.opacity(0.15)
        case .rest:
            Color.secondary.opacity(0.1)
        case .unscheduled:
            Color.clear
        }
    }

    private func chipForeground(for resolved: ResolvedScheduleDay) -> Color {
        switch resolved {
        case .workout:
            return .accentColor
        case .rest, .unscheduled:
            return .secondary
        }
    }

    private func accessibilityLabel(for resolved: ResolvedScheduleDay) -> String {
        switch resolved {
        case .workout(let ref):
            if case .workout(let id) = ref, let w = workouts[id] {
                return "Workout: \(w.name)"
            }
            return "Workout scheduled"
        case .rest:
            return "Rest day"
        case .unscheduled:
            return "Unscheduled"
        }
    }

    private func buildWeeks() -> [[Date]] {
        var weeks: [[Date]] = []
        let start = calendar.startOfDay(for: anchorDate)
        for weekOffset in 0..<weeksToShow {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: start),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else {
                continue
            }
            var days: [Date] = []
            var d = interval.start
            while d < interval.end && days.count < 7 {
                days.append(calendar.startOfDay(for: d))
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
            weeks.append(days)
        }
        return weeks
    }

    private func generatePreview() {
        let engine = TrainingScheduleEngine(calendar: calendar)
        previewSchedule = engine.previewSchedule(
            cycleEntries: cycleEntries,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            anchorDate: anchorDate,
            weeksAhead: weeksToShow
        )
    }
}

#Preview {
    let mockWorkout = Workout(id: UUID(), name: "Push Day", exercises: [])
    SplitCalendarPreview(
        cycleEntries: [.workout(mockWorkout.id)],
        sessionsPerWeek: 3,
        preferredWeekdays: [2, 4, 6],
        anchorDate: Date(),
        workouts: [mockWorkout.id: mockWorkout]
    )
    .padding()
}
