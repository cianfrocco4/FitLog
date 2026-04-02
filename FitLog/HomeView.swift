//
//  HomeView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

private enum HomeListSegment: String, CaseIterable, Identifiable {
    case workouts = "Workouts"
    case templates = "Templates"
    var id: String { rawValue }
}

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

    @State private var homeListSegment: HomeListSegment = .workouts
    @State private var homeSearchText = ""
    @State private var templateToRename: WorkoutTemplate?
    @State private var renameTemplateText = ""

    private let homeListPreviewLimit = 5

    private var scheduleEngine: TrainingScheduleEngine { TrainingScheduleEngine(calendar: .current) }

    private var homeRefreshKey: String {
        let pinN = dataVM.userWorkouts.filter(\.isPinned).count
        let pinT = dataVM.userWorkoutTemplates.filter(\.isPinned).count
        return "\(dayMonitor.currentDayKey)-\(dataVM.completedSessions.count)-\(dataVM.trainingProgram.cycleEntries.count)-\(dataVM.trainingProgram.anchorDayKey)-\(dataVM.trainingProgram.dayOverrides.count)-\(dataVM.trainingProgram.weekOverrides.count)-\(pinN)-\(pinT)"
    }

    /// User has configured a rotation on the Plan tab (`cycleEntries` non-empty).
    private var hasActiveSplit: Bool {
        !dataVM.trainingProgram.cycleEntries.isEmpty
    }

    private var splitConcreteIds: Set<UUID> {
        HomeListOrdering.splitConcreteWorkoutIds(from: dataVM.trainingProgram)
    }

    private var splitTemplateIds: Set<UUID> {
        HomeListOrdering.splitTemplateIds(from: dataVM.trainingProgram)
    }

    private var todayConcretePlanId: UUID? {
        if case .workout(.concreteWorkout(let id)) = cachedTodayPlan { return id }
        return nil
    }

    private var todayTemplatePlanId: UUID? {
        if case .workout(.slotTemplate(let id)) = cachedTodayPlan { return id }
        return nil
    }

    private var homeSearchQuery: String {
        homeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Workouts on Home: full rotation order when a split exists; otherwise a short preview of the library.
    private var homeWorkoutsToShow: [Workout] {
        let base: [Workout]
        if hasActiveSplit {
            base = HomeListOrdering.workoutsInSplitDisplayOrder(dataVM.userWorkouts, program: dataVM.trainingProgram)
        } else {
            base = HomeListOrdering.orderWorkouts(
                dataVM.userWorkouts,
                program: dataVM.trainingProgram,
                sessions: dataVM.completedSessions
            )
        }
        guard !homeSearchQuery.isEmpty else {
            return hasActiveSplit ? base : Array(base.prefix(homeListPreviewLimit))
        }
        return base.filter { $0.name.lowercased().contains(homeSearchQuery) }
    }

    /// Templates on Home: rotation only with a split; otherwise a short preview.
    private var homeTemplatesToShow: [WorkoutTemplate] {
        let base: [WorkoutTemplate]
        if hasActiveSplit {
            base = HomeListOrdering.templatesInSplitDisplayOrder(
                dataVM.userWorkoutTemplates,
                program: dataVM.trainingProgram
            )
        } else {
            base = HomeListOrdering.orderTemplates(
                dataVM.userWorkoutTemplates,
                program: dataVM.trainingProgram,
                sessions: dataVM.completedSessions
            )
        }
        guard !homeSearchQuery.isEmpty else {
            return hasActiveSplit ? base : Array(base.prefix(homeListPreviewLimit))
        }
        return base.filter { $0.name.lowercased().contains(homeSearchQuery) }
    }

    private var offSplitWorkoutCount: Int {
        dataVM.userWorkouts.filter { !splitConcreteIds.contains($0.id) }.count
    }

    private var offSplitTemplateCount: Int {
        dataVM.userWorkoutTemplates.filter { !splitTemplateIds.contains($0.id) }.count
    }

    private func preferredHomeListSegment(program: TrainingProgramState, today: ResolvedScheduleDay) -> HomeListSegment {
        switch today {
        case .workout(.concreteWorkout):
            return .workouts
        case .workout(.slotTemplate):
            return .templates
        case .rest, .unscheduled:
            if let first = program.cycleEntries.first {
                switch first {
                case .concreteWorkout: return .workouts
                case .slotTemplate: return .templates
                }
            }
            return .workouts
        }
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

    private func startConcreteWorkoutFromHomeList(_ workout: Workout) {
        currentVM.startWorkoutResolvingConflict(workout, sessionPlanOrigin: .concreteWorkout(workout.id)) {
            pendingWorkoutReplace = $0
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
                    Picker("", selection: $homeListSegment) {
                        ForEach(HomeListSegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

                    if homeListSegment == .workouts {
                        if homeWorkoutsToShow.isEmpty {
                            homeWorkoutsEmptyPlaceholder
                                .listRowInsets(homeDashboardRowInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(homeWorkoutsToShow) { workout in
                                homeWorkoutRow(workout)
                            }
                        }
                        if hasActiveSplit {
                            if offSplitWorkoutCount > 0 {
                                NavigationLink {
                                    HomeLibraryView(kind: .workouts, scope: .notInSplit)
                                } label: {
                                    Label("Other workouts (\(offSplitWorkoutCount))", systemImage: "chevron.right")
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        } else if dataVM.userWorkouts.count > homeListPreviewLimit {
                            NavigationLink {
                                HomeLibraryView(kind: .workouts, scope: .all)
                            } label: {
                                Label("View all \(dataVM.userWorkouts.count) workouts", systemImage: "chevron.right")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    } else {
                        if homeTemplatesToShow.isEmpty {
                            homeTemplatesEmptyPlaceholder
                                .listRowInsets(homeDashboardRowInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(homeTemplatesToShow) { template in
                                homeTemplateRow(template)
                            }
                        }
                        if hasActiveSplit {
                            if offSplitTemplateCount > 0 {
                                NavigationLink {
                                    HomeLibraryView(kind: .templates, scope: .notInSplit)
                                } label: {
                                    Label("Other templates (\(offSplitTemplateCount))", systemImage: "chevron.right")
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        } else if dataVM.userWorkoutTemplates.count > homeListPreviewLimit {
                            NavigationLink {
                                HomeLibraryView(kind: .templates, scope: .all)
                            } label: {
                                Label("View all \(dataVM.userWorkoutTemplates.count) templates", systemImage: "chevron.right")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                } header: {
                    Text("Library")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .textCase(nil)
                } footer: {
                    if homeListSegment == .workouts {
                        if hasActiveSplit {
                            Text("Workouts in your Plan rotation appear here. Everything else is under Other workouts.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Set up a split in the Plan tab to focus this list on your program. Until then, you’ll see a short preview of your library.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if homeListSegment == .templates {
                        if hasActiveSplit {
                            Text("Templates in your Plan rotation appear here. Long-press for actions, or swipe right to start.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Long-press for actions, or swipe right to start. Open a template and tap Start in the toolbar for the full editor.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(8)
            .fitlogWorkoutBarContentInset()
            .navigationTitle("Home")
            .searchable(
                text: $homeSearchText,
                prompt: homeListSegment == .workouts ? "Search workouts" : "Search templates"
            )
            .toolbar {
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
            .alert("Rename Template", isPresented: Binding(
                get: { templateToRename != nil },
                set: { if !$0 { templateToRename = nil } }
            )) {
                TextField("New name", text: $renameTemplateText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let template = templateToRename {
                        dataVM.renameSlotTemplate(template, newName: renameTemplateText)
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
            .task(id: dayMonitor.currentDayKey) {
                let today = scheduleEngine.resolve(date: Date(), program: dataVM.trainingProgram)
                homeListSegment = preferredHomeListSegment(program: dataVM.trainingProgram, today: today)
            }
        }
    }

    private var homeWorkoutsEmptyPlaceholder: some View {
        Group {
            if !homeSearchQuery.isEmpty {
                Text("No workouts match your search.")
            } else if hasActiveSplit, !dataVM.userWorkouts.isEmpty {
                Text("Your Plan rotation includes workouts that aren’t in your library. Update your split in the Plan tab.")
            } else if dataVM.userWorkouts.isEmpty {
                Text("No workouts yet. Tap Add to create one.")
            } else {
                Text("No workouts to show.")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var homeTemplatesEmptyPlaceholder: some View {
        Group {
            if !homeSearchQuery.isEmpty {
                Text("No templates match your search.")
            } else if hasActiveSplit, !dataVM.userWorkoutTemplates.isEmpty {
                Text("Your Plan rotation includes templates that aren’t in your library. Update your split in the Plan tab.")
            } else if dataVM.userWorkoutTemplates.isEmpty {
                Text("No templates yet. Tap Add to create a flexible template.")
            } else {
                Text("No templates to show.")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func homeWorkoutRow(_ workout: Workout) -> some View {
        NavigationLink {
            if let binding = $dataVM.userWorkouts[workout.id] {
                WorkoutPlanView(workout: binding)
            } else {
                Text("Workout not found")
                    .foregroundStyle(.red)
            }
        } label: {
            HomeWorkoutRowLabel(
                title: workout.name,
                subtitle: "Saved workout",
                isScheduledToday: workout.id == todayConcretePlanId,
                isInProgram: false,
                isPinned: workout.isPinned
            )
        }
        .contextMenu {
            Button {
                startConcreteWorkoutFromHomeList(workout)
            } label: {
                Label("Start workout", systemImage: "play.fill")
            }
            Button {
                dataVM.setWorkoutPinned(workout, pinned: !workout.isPinned)
            } label: {
                Label(workout.isPinned ? "Unpin" : "Pin", systemImage: workout.isPinned ? "pin.slash" : "pin")
            }
            Button {
                workoutToRename = workout
                renameText = workout.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button("Delete", role: .destructive) {
                dataVM.deleteWorkout(workout)
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

    @ViewBuilder
    private func homeTemplateRow(_ template: WorkoutTemplate) -> some View {
        NavigationLink {
            SlotTemplatePlanView(templateId: template.id)
                .environmentObject(dataVM)
                .environmentObject(currentVM)
        } label: {
            HomeWorkoutRowLabel(
                title: template.name,
                subtitle: "Template · \(template.slots.count) exercise\(template.slots.count == 1 ? "" : "s")",
                isScheduledToday: template.id == todayTemplatePlanId,
                isInProgram: false,
                isPinned: template.isPinned
            )
        }
        .contextMenu {
            Button {
                startWorkout(fromSlotTemplate: template)
            } label: {
                Label("Start workout", systemImage: "play.fill")
            }
            .disabled(template.slots.isEmpty)
            Button {
                dataVM.setTemplatePinned(template, pinned: !template.isPinned)
            } label: {
                Label(template.isPinned ? "Unpin" : "Pin", systemImage: template.isPinned ? "pin.slash" : "pin")
            }
            Button {
                templateToRename = template
                renameTemplateText = template.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button("Delete", role: .destructive) {
                dataVM.deleteSlotTemplate(template)
            }
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
