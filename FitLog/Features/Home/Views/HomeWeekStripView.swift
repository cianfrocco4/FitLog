//
//  HomeWeekStripView.swift
//  FitLog
//
//  Always-visible weekly activity strip with goal progress ring.
//

import SwiftUI

struct HomeWeekStripView: View {
    let glance: DataManager.WeekAtAGlance
    let streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label("This week", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                if streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FitlogPalette.highlight)
                        Text("\(streakDays)d streak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("\(streakDays) day workout streak")
                }

                if let goal = glance.weeklyGoal, goal > 0 {
                    HomeWeeklyGoalRing(completed: glance.completedCount, goal: goal)
                }
            }

            goalSummaryLine

            HStack(spacing: 0) {
                ForEach(glance.days, id: \.date) { day in
                    HomeWeekDayColumn(
                        weekday: day.weekday,
                        date: day.date,
                        hasWorkout: day.hasWorkout
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(weekStripAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var goalSummaryLine: some View {
        if let goal = glance.weeklyGoal {
            if glance.completedCount >= goal {
                Label("Weekly goal met", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.success)
            } else {
                Text("\(glance.completedCount) of \(goal) workouts logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("\(glance.completedCount) workout\(glance.completedCount == 1 ? "" : "s") logged")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var weekStripAccessibilityLabel: String {
        let filled = glance.days.filter(\.hasWorkout).count
        return "This calendar week, \(filled) days with a completed workout"
    }
}

private struct HomeWeeklyGoalRing: View {
    let completed: Int
    let goal: Int

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(completed) / Double(goal))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.22), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(completed)/\(goal)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: 40, height: 40)
        .accessibilityLabel("\(completed) of \(goal) weekly workouts completed")
    }
}

private struct HomeWeekDayColumn: View {
    let weekday: Int
    let date: Date
    let hasWorkout: Bool

    private var calendar: Calendar { .current }

    var body: some View {
        let isToday = calendar.isDateInToday(date)
        VStack(spacing: 6) {
            Text(shortWeekdayLabel)
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(isToday ? Color.accentColor.opacity(0.18) : Color.clear)
                    .frame(width: 34, height: 34)
                if hasWorkout {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(FitlogPalette.success)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.45), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(hasWorkout ? .isSelected : [])
        .accessibilityValue(hasWorkout ? "completed" : "not completed")
    }

    private var shortWeekdayLabel: String {
        let symbols = calendar.shortWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "—" }
        return symbols[weekday - 1].prefix(1).uppercased()
    }

    private var accessibilityLabel: String {
        let symbols = calendar.weekdaySymbols
        let name = (weekday >= 1 && weekday <= symbols.count) ? symbols[weekday - 1] : "Day"
        let dayNum = calendar.component(.day, from: date)
        let status = hasWorkout ? "workout logged" : "no workout logged"
        return "\(name) \(dayNum), \(status)"
    }
}

#if DEBUG
#Preview("Week strip") {
    let cal = Calendar.current
    let today = Date()
    let days: [(date: Date, weekday: Int, hasWorkout: Bool)] = (0..<7).compactMap { offset in
        guard let d = cal.date(byAdding: .day, value: offset - 3, to: today) else { return nil }
        return (d, cal.component(.weekday, from: d), offset % 2 == 0)
    }
    return HomeWeekStripView(
        glance: DataManager.WeekAtAGlance(
            isoWeekKey: "2026-W21",
            days: days,
            completedCount: 3,
            weeklyGoal: 5
        ),
        streakDays: 4
    )
    .padding()
}
#endif
