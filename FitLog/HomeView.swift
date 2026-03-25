//
//  HomeView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.calendarDayRefresh) private var calendarDayRefresh
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var aiService: AIService

    @State private var showNewWorkout = false
    @State private var showSplitBuilder = false
    @State private var workoutToRename: Workout?
    @State private var renameText = ""

    private var scheduleEngine: TrainingScheduleEngine { TrainingScheduleEngine(calendar: .current) }

    private var todayPlan: ResolvedScheduleDay {
        _ = calendarDayRefresh
        return scheduleEngine.resolve(date: Date(), program: dataVM.trainingProgram)
    }

    private var weekAtAGlance: DataManager.WeekAtAGlance {
        _ = calendarDayRefresh
        return dataVM.weekAtAGlance(referenceDate: Date(), calendar: .current)
    }

    /// True when there is a finished session for this template whose end time falls on the current calendar day.
    private func isPlannedWorkoutCompletedToday(templateId: UUID) -> Bool {
        _ = calendarDayRefresh
        let cal = Calendar.current
        let today = Date()
        return dataVM.completedSessions.contains { session in
            guard session.workout.id == templateId, let end = session.endTime else { return false }
            return cal.isDate(end, inSameDayAs: today)
        }
    }

    private var homeDashboardRowInsets: EdgeInsets {
        EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    aiSplitBuilderCard
                        .listRowInsets(homeDashboardRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                Section {
                    todayPlanSuggestionCard
                        .listRowInsets(homeDashboardRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(dataVM.userWorkouts) { workout in
                        NavigationLink {
                            if let binding = $dataVM.userWorkouts[workout.id] {
                                WorkoutPlanView(workout: binding)
                            } else {
                                Text("Workout not found")  // fallback (should never hit)
                                    .foregroundStyle(.red)
                            }
                        } label: {
                            Text(workout.name)
                                .font(.headline)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                dataVM.deleteWorkout(workout)
                            }

                            Button("Rename") {
                                workoutToRename = workout
                                renameText = workout.name
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove(perform: dataVM.moveWorkout)
                } header: {
                    Text("My Workouts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(8)
            .fitlogWorkoutBarContentInset()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Workout") {
                        showNewWorkout = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Sign Out", role: .destructive) {
                            authVM.logout()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .sheet(isPresented: $showNewWorkout) {
                NewWorkoutSheet()
                    .environmentObject(dataVM)
            }
            .sheet(isPresented: $showSplitBuilder) {
                AISplitBuilderView()
                    .environmentObject(dataVM)
                    .environmentObject(aiService)
            }
            .alert("Rename Workout", isPresented: Binding(
                get: { workoutToRename != nil },
                set: { if !$0 { workoutToRename = nil } }
            )) {
                TextField("New name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let workout = workoutToRename {
                        dataVM.renameWorkout(workout, newName: renameText)
                    }
                }
            }
        }
    }

    private var aiSplitBuilderCard: some View {
        Button {
            showSplitBuilder = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build split with AI")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Goals, schedule, and exercises from your library.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var todayPlanSuggestionCard: some View {
        let plan = todayPlan
        VStack(alignment: .leading, spacing: 10) {
            Label("Today’s plan", systemImage: "calendar.badge.checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            switch plan {
            case .rest:
                Text("Rest day")
                    .font(.title3.weight(.semibold))
                Text("Recovery is part of the program. See the Plan tab to adjust today if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unscheduled:
                Text("No workout scheduled")
                    .font(.title3.weight(.semibold))
                Text("Set your split and weekly schedule in the Plan tab, or start any workout below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .workout(let id):
                if let workout = dataVM.userWorkouts.first(where: { $0.id == id }) {
                    Text(workout.name)
                        .font(.title3.weight(.semibold))
                    Text("Suggested from your training plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if currentVM.isInProgress {
                        Text("Finish your current workout before starting another.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if isPlannedWorkoutCompletedToday(templateId: id) {
                        Label("Completed today", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("You logged this planned workout. Rest up or choose another session below if you like.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            if let binding = $dataVM.userWorkouts[workout.id] {
                                WorkoutPlanView(workout: binding)
                            } else {
                                Text("Workout not found").foregroundStyle(.red)
                            }
                        } label: {
                            Label("View template", systemImage: "list.bullet")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            currentVM.startWorkout(workout)
                        } label: {
                            Label("Start workout", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        NavigationLink {
                            if let binding = $dataVM.userWorkouts[workout.id] {
                                WorkoutPlanView(workout: binding)
                            } else {
                                Text("Workout not found").foregroundStyle(.red)
                            }
                        } label: {
                            Label("View template", systemImage: "list.bullet")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("Missing workout")
                        .font(.title3.weight(.semibold))
                    Text("Your plan references a template that isn’t in My Workouts. Update the split in the Plan tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            thisWeekSubsection(weekAtAGlance)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func thisWeekSubsection(_ glance: DataManager.WeekAtAGlance) -> some View {
        let cal = Calendar.current
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 2)

            Text("This week")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let goal = glance.weeklyGoal {
                if glance.completedCount >= goal {
                    Text("Goal met")
                        .font(.subheadline.weight(.semibold))
                    Text(workoutsPlural(glance.completedCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(glance.completedCount) of \(goal) workouts")
                        .font(.subheadline.weight(.semibold))
                    ProgressView(value: Double(glance.completedCount), total: Double(goal))
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .frame(height: 4)
                }
            } else {
                Text("\(glance.completedCount) workout\(glance.completedCount == 1 ? "" : "s") this week")
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 0) {
                ForEach(glance.days, id: \.date) { day in
                    weekStripDayColumn(
                        weekday: day.weekday,
                        date: day.date,
                        hasWorkout: day.hasWorkout,
                        calendar: cal
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(weekStripAccessibilityLabel(glance))
        }
    }

    private func workoutsPlural(_ n: Int) -> String {
        n == 1 ? "1 workout logged" : "\(n) workouts logged"
    }

    private func shortWeekdayLabel(_ weekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.shortWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "—" }
        return symbols[weekday - 1].prefix(1).uppercased()
    }

    private func weekStripDayColumn(weekday: Int, date: Date, hasWorkout: Bool, calendar: Calendar) -> some View {
        let isToday = calendar.isDateInToday(date)
        return VStack(spacing: 6) {
            Text(shortWeekdayLabel(weekday, calendar: calendar))
                .font(.caption2.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? .primary : .secondary)
            Capsule()
                .fill(hasWorkout ? Color.accentColor : Color.secondary.opacity(0.2))
                .frame(width: isToday ? 10 : 8, height: isToday ? 5 : 4)
                .accessibilityHidden(true)
        }
        .accessibilityLabel(weekDayAccessibilityLabel(weekday: weekday, date: date, hasWorkout: hasWorkout, calendar: calendar))
    }

    private func weekDayAccessibilityLabel(weekday: Int, date: Date, hasWorkout: Bool, calendar: Calendar) -> String {
        let symbols = calendar.weekdaySymbols
        let name: String
        if weekday >= 1, weekday <= symbols.count {
            name = symbols[weekday - 1]
        } else {
            name = "Day"
        }
        let dayNum = calendar.component(.day, from: date)
        let status = hasWorkout ? "workout logged" : "no workout logged"
        return "\(name) \(dayNum), \(status)"
    }

    private func weekStripAccessibilityLabel(_ glance: DataManager.WeekAtAGlance) -> String {
        let filled = glance.days.filter { $0.hasWorkout }.count
        return "This calendar week, \(filled) days with a completed workout"
    }
}
