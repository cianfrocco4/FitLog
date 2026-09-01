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
    @EnvironmentObject var userPreferences: UserPreferences

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

            if let scorecard = dataVM.programGoalScorecard(calendar: cal),
               scorecard.status != .notScheduled {
                Button(action: onOpenDetail) {
                    thisWeekGoalRow(scorecard)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens program goals")
                .sensoryFeedback(.success, trigger: scorecard.status == .met)
            }

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
                if let recap = lastWorkingLine(for: session) {
                    Text(recap)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
                if let workout = libraryWorkout(for: session) {
                    Button("Again") {
                        onStartWorkout(workout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityHint("Starts this workout again as a new session")
                }
            } else if session.isToday,
                      let workout = libraryWorkout(for: session) {
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

    @ViewBuilder
    private func thisWeekGoalRow(_ scorecard: WeekGoalScorecard) -> some View {
        let sessions = scorecard.metrics.first(where: { $0.kind == .sessionsPerWeek })
        let hardSets = scorecard.metrics.first(where: { $0.kind == .weeklyHardSets })
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                goalStatusBadge(scorecard.status)
                VStack(alignment: .leading, spacing: 2) {
                    if let sessions, sessions.planned > 0 {
                        Text("\(Int(sessions.actual.rounded())) of \(Int(sessions.planned.rounded())) sessions")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    } else {
                        Text("This week’s goals")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(scorecard.statusSentence)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if let hardSets, hardSets.planned > 0 {
                    Text("\(Int((hardSets.fraction * 100).rounded()))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Hard sets \(Int((hardSets.fraction * 100).rounded())) percent of target")
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    goalStatusBadge(scorecard.status)
                    Spacer(minLength: 0)
                    if let hardSets, hardSets.planned > 0 {
                        Text("\(Int((hardSets.fraction * 100).rounded()))% volume")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                if let sessions, sessions.planned > 0 {
                    Text("\(Int(sessions.actual.rounded())) of \(Int(sessions.planned.rounded())) sessions")
                        .font(.subheadline.weight(.semibold))
                }
                Text(scorecard.statusSentence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week’s goals, \(scorecard.status.plainLanguageLabel). \(scorecard.statusSentence)")
    }

    private func goalStatusBadge(_ status: WeekGoalStatus) -> some View {
        Text(status.plainLanguageLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status == .met || status == .onTrack ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.accentColor.opacity(status == .atRisk || status == .missed ? 0.08 : 0.14))
            )
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

    private func libraryWorkout(for session: HomeProgramWeekSession) -> Workout? {
        guard let libraryId = session.libraryWorkoutId else { return nil }
        return dataVM.userWorkouts.first(where: { $0.id == libraryId })
    }

    private func lastWorkingLine(for session: HomeProgramWeekSession) -> String? {
        guard let libraryId = session.libraryWorkoutId,
              let completed = dataVM.lastCompletedSession(forLibraryWorkoutId: libraryId) else {
            return nil
        }
        return LastSessionWorkingRecap.compactLine(
            from: completed,
            weightUnit: userPreferences.weightDisplayUnit
        )
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
