//
//  HomeView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var dayMonitor: CalendarDayMonitor
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var aiService: AIService
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet

    @State private var showNewWorkout = false
    @State private var showSplitBuilder = false
    @State private var workoutToRename: Workout?
    @State private var renameText = ""
    /// After creating a slot template from the Add menu, push the editor for that template.
    @State private var newSlotTemplateToEdit: UUID?

    @State private var pendingWorkoutReplace: PendingWorkoutReplace?
    /// After starting from Today's plan, push this detail route and open the workout sheet.
    @State private var todayPlanDetailRoute: TodayPlanDetailRoute?
    /// If Today's plan Start hit a replace conflict, navigate here after the user confirms.
    @State private var pendingTodayPlanNavigateAfterReplace: TodayPlanDetailRoute?

    @State private var cachedTodayPlan: ResolvedScheduleDay = .unscheduled
    @State private var cachedWeekGlance: DataManager.WeekAtAGlance?
    @State private var cachedTodayCompletedRefs: Set<String> = []

    private var scheduleEngine: TrainingScheduleEngine { TrainingScheduleEngine(calendar: .current) }

    private var homeRefreshKey: String {
        "\(dayMonitor.currentDayKey)-\(dataVM.completedSessions.count)-\(dataVM.trainingProgram.cycleEntries.count)-\(dataVM.trainingProgram.anchorDayKey)-\(dataVM.trainingProgram.dayOverrides.count)-\(dataVM.trainingProgram.weekOverrides.count)"
    }

    private func refreshCachedHomeData() {
        cachedTodayPlan = scheduleEngine.resolve(date: Date(), program: dataVM.trainingProgram)
        cachedWeekGlance = dataVM.weekAtAGlance(referenceDate: Date(), calendar: .current)

        let cal = Calendar.current
        let today = Date()
        var completedRefs = Set<String>()
        for session in dataVM.completedSessions {
            guard let end = session.endTime, cal.isDate(end, inSameDayAs: today) else { continue }
            if let origin = session.sessionPlanOrigin {
                completedRefs.insert(origin.cacheKey)
            } else {
                completedRefs.insert(WorkoutPlanRef.concreteWorkout(session.workout.id).cacheKey)
            }
        }
        cachedTodayCompletedRefs = completedRefs
    }

    private func isPlannedWorkoutCompletedToday(plan: WorkoutPlanRef) -> Bool {
        cachedTodayCompletedRefs.contains(plan.cacheKey)
    }

    private var homeDashboardRowInsets: EdgeInsets {
        EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16)
    }

    private func startWorkout(fromSlotTemplate template: WorkoutTemplate) {
        guard !template.slots.isEmpty else { return }
        let sessionWorkout = dataVM.instantiateWorkout(from: template)
        currentVM.startWorkoutResolvingConflict(sessionWorkout, sessionPlanOrigin: .slotTemplate(template.id)) {
            pendingWorkoutReplace = $0
        }
    }

    private func startConcreteWorkoutFromTodayPlan(_ workout: Workout) {
        let ref = WorkoutPlanRef.concreteWorkout(workout.id)
        switch currentVM.resolveStartingWorkout(workout, sessionPlanOrigin: ref) {
        case .performStart:
            currentVM.startWorkout(workout, sessionPlanOrigin: ref)
            navigateTodayPlanDetailAndOpenWorkoutSheet(.concreteWorkout(workout.id))
        case .noOpAlreadyActive:
            break
        case .needsReplaceConfirmation(let pending):
            pendingWorkoutReplace = pending
            pendingTodayPlanNavigateAfterReplace = .concreteWorkout(workout.id)
        }
    }

    private func startWorkoutFromTodayPlan(template: WorkoutTemplate) {
        guard !template.slots.isEmpty else { return }
        let sessionWorkout = dataVM.instantiateWorkout(from: template)
        let ref = WorkoutPlanRef.slotTemplate(template.id)
        switch currentVM.resolveStartingWorkout(sessionWorkout, sessionPlanOrigin: ref) {
        case .performStart:
            currentVM.startWorkout(sessionWorkout, sessionPlanOrigin: ref)
            navigateTodayPlanDetailAndOpenWorkoutSheet(.slotTemplate(template.id))
        case .noOpAlreadyActive:
            break
        case .needsReplaceConfirmation(let pending):
            pendingWorkoutReplace = pending
            pendingTodayPlanNavigateAfterReplace = .slotTemplate(template.id)
        }
    }

    private func navigateTodayPlanDetailAndOpenWorkoutSheet(_ route: TodayPlanDetailRoute) {
        todayPlanDetailRoute = route
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            openCurrentWorkoutSheet?()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if currentVM.isInProgress {
                    Section {
                        activeWorkoutIndicatorCard
                            .listRowInsets(homeDashboardRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name)
                                    .font(.headline)
                                Text("Saved workout")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
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

                Section {
                    ForEach(dataVM.userWorkoutTemplates) { template in
                        NavigationLink {
                            SlotTemplatePlanView(templateId: template.id)
                                .environmentObject(dataVM)
                                .environmentObject(currentVM)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.headline)
                                Text("Template · \(template.slots.count) exercise\(template.slots.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            Button {
                                startWorkout(fromSlotTemplate: template)
                            } label: {
                                Label("Start workout", systemImage: "play.fill")
                            }
                            .disabled(template.slots.isEmpty)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !template.slots.isEmpty {
                                Button {
                                    startWorkout(fromSlotTemplate: template)
                                } label: {
                                    Label("Start", systemImage: "play.fill")
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                dataVM.deleteSlotTemplate(template)
                            }
                        }
                    }
                } header: {
                    Text("Flexible Templates")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .textCase(nil)
                } footer: {
                    Text("Long-press for Start workout, or swipe right on a template. You can also open a template and tap Start in the toolbar.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                    Menu {
                        Button("New workout") {
                            showNewWorkout = true
                        }
                        Button("New flexible template") {
                            newSlotTemplateToEdit = dataVM.createSlotTemplate(name: "Template")
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle")
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
            .navigationDestination(item: $newSlotTemplateToEdit) { templateId in
                SlotTemplatePlanView(templateId: templateId)
                    .environmentObject(dataVM)
                    .environmentObject(currentVM)
            }
            .navigationDestination(item: $todayPlanDetailRoute) { route in
                switch route {
                case .concreteWorkout(let id):
                    if let binding = $dataVM.userWorkouts[id] {
                        WorkoutPlanView(workout: binding)
                            .environmentObject(dataVM)
                            .environmentObject(currentVM)
                            .environmentObject(aiService)
                    } else {
                        Text("Workout not found")
                            .foregroundStyle(.red)
                    }
                case .slotTemplate(let id):
                    SlotTemplatePlanView(templateId: id)
                        .environmentObject(dataVM)
                        .environmentObject(currentVM)
                }
            }
            .task(id: homeRefreshKey) {
                refreshCachedHomeData()
            }
            .workoutReplaceConflictConfirmation(
                currentVM: currentVM,
                pending: $pendingWorkoutReplace,
                onAfterReplace: {
                    if let route = pendingTodayPlanNavigateAfterReplace {
                        pendingTodayPlanNavigateAfterReplace = nil
                        navigateTodayPlanDetailAndOpenWorkoutSheet(route)
                    }
                },
                onCancelReplace: {
                    pendingTodayPlanNavigateAfterReplace = nil
                }
            )
        }
    }

    private var activeWorkoutIndicatorCard: some View {
        Button {
            openCurrentWorkoutSheet?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Workout in progress")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(currentVM.currentSession?.workout.name ?? "")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(currentVM.workoutElapsedFormatted)
                            .font(.subheadline.weight(.medium).monospacedDigit())
                        if currentVM.isWorkoutPaused {
                            Text("Paused")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.green.opacity(0.4), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the current workout")
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
        let plan = cachedTodayPlan
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
            case .workout(let ref):
                switch ref {
                case .concreteWorkout(let id):
                    if let workout = dataVM.userWorkouts.first(where: { $0.id == id }) {
                        let planRef = WorkoutPlanRef.concreteWorkout(workout.id)
                        let thisPlanActive = currentVM.isActiveSessionMatching(workout: workout, planRef: planRef)
                        TodayWorkoutCard(
                            title: workout.name,
                            subtitle: "Saved workout · from your training plan",
                            isCompleted: isPlannedWorkoutCompletedToday(plan: ref),
                            isThisPlanActive: thisPlanActive,
                            isAnotherWorkoutActive: currentVM.isInProgress && !thisPlanActive,
                            onStart: { startConcreteWorkoutFromTodayPlan(workout) },
                            openActiveWorkout: { openCurrentWorkoutSheet?() },
                            detailLabel: "View workout"
                        ) {
                            if let binding = $dataVM.userWorkouts[workout.id] {
                                WorkoutPlanView(workout: binding)
                            } else {
                                Text("Workout not found").foregroundStyle(.red)
                            }
                        }
                    } else {
                        missingItemMessage("Missing workout", detail: "Your plan references a workout that isn’t in My Workouts. Update the split in the Plan tab.")
                    }

                case .slotTemplate(let templateId):
                    if let template = dataVM.slotTemplate(id: templateId) {
                        let sessionWorkout = dataVM.instantiateWorkout(from: template)
                        let planRef = WorkoutPlanRef.slotTemplate(templateId)
                        let thisPlanActive = currentVM.isActiveSessionMatching(workout: sessionWorkout, planRef: planRef)
                        TodayWorkoutCard(
                            title: template.name,
                            subtitle: "Flexible template · pick exercises when you train",
                            isCompleted: isPlannedWorkoutCompletedToday(plan: ref),
                            isThisPlanActive: thisPlanActive,
                            isAnotherWorkoutActive: currentVM.isInProgress && !thisPlanActive,
                            onStart: { startWorkoutFromTodayPlan(template: template) },
                            openActiveWorkout: { openCurrentWorkoutSheet?() },
                            detailLabel: "Edit template"
                        ) {
                            SlotTemplatePlanView(templateId: templateId)
                                .environmentObject(dataVM)
                                .environmentObject(currentVM)
                        }
                    } else {
                        missingItemMessage("Missing template", detail: "Your plan references a template that was removed. Update the split in the Plan tab.")
                    }
                }
            }
            if let glance = cachedWeekGlance {
                thisWeekSubsection(glance)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func missingItemMessage(_ title: String, detail: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
        Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
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
        return VStack(spacing: 4) {
            Text(shortWeekdayLabel(weekday, calendar: calendar))
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(isToday ? Color.accentColor.opacity(0.15) : Color.clear)
                    .frame(width: 28, height: 28)
                if hasWorkout {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
        }
        .accessibilityLabel(weekDayAccessibilityLabel(weekday: weekday, date: date, hasWorkout: hasWorkout, calendar: calendar))
        .accessibilityAddTraits(hasWorkout ? .isSelected : [])
        .accessibilityValue(hasWorkout ? "completed" : "not completed")
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

// MARK: - Today’s plan → detail navigation

private enum TodayPlanDetailRoute: Hashable, Identifiable {
    case concreteWorkout(UUID)
    case slotTemplate(UUID)

    var id: String {
        switch self {
        case .concreteWorkout(let uuid):
            return "cw-\(uuid.uuidString)"
        case .slotTemplate(let uuid):
            return "st-\(uuid.uuidString)"
        }
    }
}

// MARK: - Reusable today-workout card

/// Unified card component for the today-plan section, handling active/completed/startable states.
private struct TodayWorkoutCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let isThisPlanActive: Bool
    let isAnotherWorkoutActive: Bool
    let onStart: () -> Void
    let openActiveWorkout: () -> Void
    let detailLabel: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)

        if isThisPlanActive {
            Label("This plan is in progress", systemImage: "figure.run")
                .font(.headline)
                .foregroundStyle(.green)
            Text("Continue logging sets from the bar below or open the full workout.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                openActiveWorkout()
            } label: {
                Label("Open workout", systemImage: "arrow.up.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            NavigationLink(destination: destination) {
                Label(detailLabel, systemImage: "list.bullet")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else if isAnotherWorkoutActive {
            Text("Another workout is still active. Starting this one will complete it and save it to your history.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: onStart) {
                Label("Start workout", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink(destination: destination) {
                Label(detailLabel, systemImage: "list.bullet")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else if isCompleted {
            Label("Completed today", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("You finished this planned session. Rest up or choose another below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            NavigationLink(destination: destination) {
                Label(detailLabel, systemImage: "list.bullet")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else {
            Button(action: onStart) {
                Label("Start workout", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink(destination: destination) {
                Label(detailLabel, systemImage: "list.bullet")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
