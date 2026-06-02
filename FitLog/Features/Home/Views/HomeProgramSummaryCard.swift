//
//  HomeProgramSummaryCard.swift
//  FitLog
//
//  Consolidated active program card for the Home tab with this-week session strip.
//

import SwiftUI

struct HomeProgramWeekSession: Identifiable, Equatable {
    let id: String
    let date: Date
    let weekdayLabel: String
    let title: String
    let libraryWorkoutId: UUID?
    let isToday: Bool
    let isCompleted: Bool
    let isRest: Bool
    let isUnscheduled: Bool
}

struct HomeProgramSummaryCard: View {
    @Environment(DataManager.self) var dataVM

    let state: DynamicProgramState
    let onOpenDetail: () -> Void
    let onBuildNew: () -> Void
    let onOpenWorkout: (UUID) -> Void
    let onStartWorkout: (Workout) -> Void

    private var calendar: Calendar { .current }

    private var weekSessions: [HomeProgramWeekSession] {
        let dayStarts = TrainingProgramState.orderedCalendarDaysInWeek(containing: Date(), calendar: calendar)
        let weekdayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f
        }()
        return dayStarts.map { dayStart in
            let plan = dataVM.resolvedScheduleDay(for: dayStart, calendar: calendar)
            let dayKey = TrainingProgramState.dayKey(for: dayStart, calendar: calendar)
            let isToday = calendar.isDateInToday(dayStart)
            switch plan {
            case .rest:
                return HomeProgramWeekSession(
                    id: dayKey,
                    date: dayStart,
                    weekdayLabel: weekdayFormatter.string(from: dayStart),
                    title: "Rest",
                    libraryWorkoutId: nil,
                    isToday: isToday,
                    isCompleted: false,
                    isRest: true,
                    isUnscheduled: false
                )
            case .unscheduled:
                return HomeProgramWeekSession(
                    id: dayKey,
                    date: dayStart,
                    weekdayLabel: weekdayFormatter.string(from: dayStart),
                    title: "—",
                    libraryWorkoutId: nil,
                    isToday: isToday,
                    isCompleted: false,
                    isRest: false,
                    isUnscheduled: true
                )
            case .workout(let ref):
                let name = dataVM.userWorkouts.first(where: { $0.id == ref.libraryWorkoutId })?.name ?? "Workout"
                let completed = dataVM.completedSessions.contains { session in
                    guard let end = session.endTime else { return false }
                    guard calendar.isDate(end, inSameDayAs: dayStart) else { return false }
                    return session.sessionPlanOrigin?.cacheKey == ref.cacheKey
                }
                return HomeProgramWeekSession(
                    id: dayKey,
                    date: dayStart,
                    weekdayLabel: weekdayFormatter.string(from: dayStart),
                    title: name,
                    libraryWorkoutId: ref.libraryWorkoutId,
                    isToday: isToday,
                    isCompleted: completed,
                    isRest: false,
                    isUnscheduled: false
                )
            }
        }
    }

    var body: some View {
        let cal = calendar
        let pe = PeriodizationEngine(calendar: cal)
        let today = cal.startOfDay(for: Date())
        let placement = pe.blockPlacement(on: today, state: state)
        let sessionProgress = dataVM.dynamicProgramBlockSessionProgress(calendar: cal)
        let sessions = weekSessions

        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpenDetail) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.program.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        if let placement {
                            Text(blockWeekLine(placement: placement, blockCount: state.program.blocks.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Starts \(state.anchorDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if let pr = sessionProgress, pr.planned > 0 {
                        sessionProgressRing(completed: pr.completed, planned: pr.planned)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your active program details")

            VStack(alignment: .leading, spacing: 6) {
                Text("This week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(sessions) { session in
                    programWeekRow(session)
                }
            }

            HStack(spacing: 10) {
                Button("View full program", action: onOpenDetail)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("New program", action: onBuildNew)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
        .homeCardTier(.tertiary)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func programWeekRow(_ session: HomeProgramWeekSession) -> some View {
        let rowContent = HStack(spacing: 10) {
            Text(session.weekdayLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(session.isToday ? Color.accentColor : Color.secondary)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline.weight(session.isToday ? .semibold : .regular))
                    .foregroundStyle(session.isRest || session.isUnscheduled ? .secondary : .primary)
                    .lineLimit(1)
                if session.isToday, !session.isRest, !session.isUnscheduled {
                    Text("Today")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Spacer(minLength: 0)

            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Completed")
            } else if session.isToday,
                      let libraryId = session.libraryWorkoutId,
                      let workout = dataVM.userWorkouts.first(where: { $0.id == libraryId }) {
                Button("Start") {
                    onStartWorkout(workout)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .accessibilityHint("Starts today's scheduled workout")
            } else if session.isRest {
                Image(systemName: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Rest day")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(session.isToday ? Color.accentColor.opacity(0.08) : Color(.tertiarySystemFill).opacity(0.5))
        }

        if let libraryId = session.libraryWorkoutId, !session.isRest {
            Button {
                onOpenWorkout(libraryId)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens workout details")
        } else {
            rowContent
        }
    }

    private func blockWeekLine(placement: (index: Int, block: ProgramBlock, weekInBlock: Int), blockCount: Int) -> String {
        if blockCount > 1 {
            return "Block \(placement.index + 1) of \(blockCount) · Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks)"
        }
        return "\(placement.block.name) · Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks)"
    }

    private func sessionProgressRing(completed: Int, planned: Int) -> some View {
        let total = max(1, planned)
        let frac = min(1, max(0, Double(completed) / Double(total)))
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.22), lineWidth: 5)
            Circle()
                .trim(from: 0, to: frac)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(completed)/\(planned)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(2)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("\(completed) of \(planned) sessions completed in this block")
    }
}

struct HomeBuildProgramCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build your program")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Goals, phases, and weekly schedule—then save to Plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                Text("Get started")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .buttonStyle(.plain)
        .homeCardTier(.tertiary)
        .accessibilityLabel("Build a program")
        .accessibilityHint("Opens the program builder")
    }
}
