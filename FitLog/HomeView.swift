//
//  HomeView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dayMonitor: CalendarDayMonitor
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection

    @State private var showNewWorkout = false
    @State private var newWorkoutLaunchHint: NewWorkoutLaunchHint?
    @State private var showSplitBuilder = false
    @State private var workoutToRename: Workout?
    @State private var renameText = ""
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?
    /// After starting from Today's plan, push this detail route and open the workout sheet.
    @State private var todayPlanDetailRoute: TodayPlanDetailRoute?
    /// If Today's plan Start hit a replace conflict, navigate here after the user confirms.
    @State private var pendingTodayPlanNavigateAfterReplace: TodayPlanDetailRoute?

    @State private var cachedTodayPlan: ResolvedScheduleDay = .unscheduled
    @State private var cachedWeekGlance: DataManager.WeekAtAGlance?
    @State private var cachedTodayCompletedRefs: Set<String> = []
    @State private var cachedProgressSummary: HomeProgressSummary?
    @State private var cachedWeeklyRecap: DataManager.WeeklyRecapSummary?
    @State private var weekGlanceExpanded = true
    @State private var workoutSearchText = ""
    @State private var showNewExercise = false
    @State private var homeFirstPaintSkeleton = true
    @State private var homeBlockTransitionToast: String?
    @State private var homeBlockTransitionToastSerial = 0

    private var homeRefreshKey: String {
        let cycleSig = dataVM.trainingProgram.cycleEntries.map(\.cacheKey).joined(separator: ",")
        let dynSig: String = {
            guard let d = dataVM.dynamicProgramState else { return "dyn:none" }
            let shiftSig = d.blockShiftDays.map { "\($0.key.uuidString):\($0.value)" }.sorted().joined(separator: ",")
            return "dyn:\(d.program.id.uuidString)-\(Int(d.anchorDate.timeIntervalSince1970))-\(d.materializedTemplateWorkoutIds.count)-\(d.busyDayKeys.count)-\(d.missedSessionDayKeys.count)-\(shiftSig)"
        }()
        return "\(dayMonitor.currentDayKey)-\(dataVM.completedSessions.count)-\(cycleSig)-\(dataVM.trainingProgram.anchorDayKey)-\(dataVM.trainingProgram.dayOverrides.count)-\(dataVM.trainingProgram.weekOverrides.count)-\(userPreferences.dismissedProgramAssignmentBanner)-\(dynSig)"
    }

    private var workoutSearchTrimmed: String {
        workoutSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredWorkouts: [Workout] {
        guard !workoutSearchTrimmed.isEmpty else { return dataVM.userWorkouts }
        return dataVM.userWorkouts.filter {
            $0.name.localizedCaseInsensitiveContains(workoutSearchTrimmed)
        }
    }

    /// Beyond this count (with no search query), Home shows a short preview plus **All workouts**.
    private var homeWorkoutFullListThreshold: Int { 8 }
    private var homeWorkoutPreviewCount: Int { 6 }

    private var shouldShowProgramAssignmentBanner: Bool {
        !userPreferences.dismissedProgramAssignmentBanner
            && !dataVM.userWorkouts.isEmpty
            && dataVM.trainingProgram.cycleEntries.isEmpty
            && dataVM.dynamicProgramState == nil
    }

    private var homeShowsWorkoutPreviewOnly: Bool {
        dataVM.userWorkouts.count > homeWorkoutFullListThreshold && workoutSearchTrimmed.isEmpty
    }

    private var homePreviewWorkouts: [Workout] {
        Array(dataVM.userWorkouts.prefix(homeWorkoutPreviewCount))
    }

    private var homeDashboardListInsets: EdgeInsets {
        EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    }

    private var programAssignmentBannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assign workouts to your week")
                .font(.headline)
            Text("You have saved workouts, but your Plan calendar needs a training lineup. Set how many days you train and order your sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Open Program builder") {
                    if let tab = rootTabSelection {
                        tab.wrappedValue = .plan
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        NotificationCenter.default.post(name: .fitlogOpenProgramBuilder, object: nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Dismiss") {
                    userPreferences.dismissedProgramAssignmentBanner = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private var homeEmptyWorkoutsCallout: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No workouts yet")
                .font(.headline)
            Text("Create your first workout or set up your split in Plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("New workout") {
                    newWorkoutLaunchHint = nil
                    showNewWorkout = true
                }
                    .buttonStyle(.borderedProminent)
                if let tab = rootTabSelection {
                    Button("Open Plan") { tab.wrappedValue = .plan }
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
    }

    private static let homeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private func refreshCachedHomeData() {
        cachedTodayPlan = dataVM.resolvedScheduleDay(for: Date(), calendar: .current)
        cachedWeekGlance = dataVM.weekAtAGlance(referenceDate: Date(), calendar: .current)
        cachedProgressSummary = dataVM.homeProgressSummary(referenceDate: Date(), calendar: .current)
        cachedWeeklyRecap = dataVM.weeklyRecapSummary()

        let cal = Calendar.current
        let today = Date()
        var completedRefs = Set<String>()
        for session in dataVM.completedSessions {
            guard let end = session.endTime, cal.isDate(end, inSameDayAs: today) else { continue }
            if let origin = session.sessionPlanOrigin {
                completedRefs.insert(origin.cacheKey)
            } else {
                completedRefs.insert(WorkoutPlanRef.workout(session.workout.id).cacheKey)
            }
        }
        cachedTodayCompletedRefs = completedRefs
    }

    private func isPlannedWorkoutCompletedToday(plan: WorkoutPlanRef) -> Bool {
        cachedTodayCompletedRefs.contains(plan.cacheKey)
    }

    private func startWorkoutFromLibrary(_ library: Workout) {
        let toStart = library.hasFlexibleSlots ? dataVM.sessionInstance(from: library) : library
        currentVM.startWorkoutResolvingConflict(toStart, sessionPlanOrigin: .workout(library.id)) {
            pendingWorkoutReplace = $0
        }
    }

    private func startWorkoutFromTodayPlan(_ library: Workout) {
        let ref = WorkoutPlanRef.workout(library.id)
        let toStart = library.hasFlexibleSlots ? dataVM.sessionInstance(from: library) : library
        switch currentVM.resolveStartingWorkout(toStart, sessionPlanOrigin: ref) {
        case .performStart:
            currentVM.startWorkout(toStart, sessionPlanOrigin: ref)
            navigateTodayPlanDetailAndOpenWorkoutSheet(.plannedWorkout(library.id))
        case .noOpAlreadyActive:
            break
        case .needsReplaceConfirmation(let pending):
            pendingWorkoutReplace = pending
            pendingTodayPlanNavigateAfterReplace = .plannedWorkout(library.id)
        }
    }

    /// Resume today’s last completed instance of this plan (same logged sets), or start fresh if none.
    private func resumeTodayPlanFromLastCompletedSession(_ library: Workout) {
        guard let last = dataVM.mostRecentCompletedSessionToday(forLibraryWorkoutId: library.id) else {
            startWorkoutFromTodayPlan(library)
            return
        }
        currentVM.startWorkoutResumingFromCompleted(last) { pending in
            pendingWorkoutReplace = pending
            pendingTodayPlanNavigateAfterReplace = .plannedWorkout(library.id)
        }
        if currentVM.isInProgress {
            navigateTodayPlanDetailAndOpenWorkoutSheet(.plannedWorkout(library.id))
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
        @Bindable var dm = dataVM
        return NavigationStack {
            List {
                if let homeBlockTransitionToast {
                    Section {
                        Text(homeBlockTransitionToast)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
                            .accessibilityLabel(homeBlockTransitionToast)
                    }
                    .listRowInsets(homeDashboardListInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                Section {
                    if currentVM.isInProgress {
                        activeWorkoutIndicatorCard
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    if homeFirstPaintSkeleton {
                        FitlogSkeletonCardBlock()
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        todayDashboardBlock
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        if let progress = cachedProgressSummary {
                            progressSummaryCard(progress)
                                .listRowInsets(homeDashboardListInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        if let recap = cachedWeeklyRecap, recap.shouldShowRecapCard {
                            weeklyRecapCard(recap)
                                .listRowInsets(homeDashboardListInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }

                if shouldShowProgramAssignmentBanner {
                    Section {
                        programAssignmentBannerCard
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    aiSplitProgramRow
                        .listRowInsets(homeDashboardListInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    if let dyn = dataVM.dynamicProgramState {
                        dynamicProgramActiveSummaryRow(programName: dyn.program.name, blockCount: dyn.program.blocks.count)
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        dynamicProgramProgressAndScheduleCard(state: dyn)
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Program")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("Uses your goals, schedule, and exercise library—then updates Plan.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section {
                    if dataVM.userWorkouts.isEmpty {
                        homeEmptyWorkoutsCallout
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if homeShowsWorkoutPreviewOnly {
                        ForEach(homePreviewWorkouts) { workout in
                            HomeWorkoutListRow(
                                workout: workout,
                                workoutToRename: $workoutToRename,
                                renameText: $renameText,
                                onStartLibrary: startWorkoutFromLibrary
                            )
                        }
                        NavigationLink {
                            HomeWorkoutLibraryView()
                                .environment(dataVM)
                                .environment(currentVM)
                                .environmentObject(aiService)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.stack")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("All workouts")
                                        .font(.headline)
                                    Text("\(dataVM.userWorkouts.count) saved · search, reorder, and edit")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else if workoutSearchTrimmed.isEmpty {
                        ForEach(dataVM.userWorkouts) { workout in
                            HomeWorkoutListRow(
                                workout: workout,
                                workoutToRename: $workoutToRename,
                                renameText: $renameText,
                                onStartLibrary: startWorkoutFromLibrary
                            )
                        }
                        .onMove(perform: dataVM.moveWorkout)
                    } else {
                        ForEach(filteredWorkouts) { workout in
                            HomeWorkoutListRow(
                                workout: workout,
                                workoutToRename: $workoutToRename,
                                renameText: $renameText,
                                onStartLibrary: startWorkoutFromLibrary
                            )
                        }
                    }
                } header: {
                    Text("Your workouts")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text(
                        dataVM.userWorkouts.isEmpty
                            ? "Workouts you create appear here and in Plan."
                            : homeShowsWorkoutPreviewOnly
                                ? "Showing the first \(homeWorkoutPreviewCount) in your list order. Open All workouts for the full library."
                                : "Swipe right on a row to start quickly."
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(12)
            .fitlogWorkoutBarContentInset()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .modifier(HomeWorkoutSearchModifier(
                isEnabled: !homeShowsWorkoutPreviewOnly,
                text: $workoutSearchText,
                prompt: "Search workouts"
            ))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(!workoutSearchTrimmed.isEmpty || homeShowsWorkoutPreviewOnly || dataVM.userWorkouts.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New workout", systemImage: "plus.rectangle.on.folder") {
                            newWorkoutLaunchHint = nil
                            showNewWorkout = true
                        }
                        Button("Build program", systemImage: "rectangle.stack.badge.plus") {
                            showSplitBuilder = true
                        }
                        NavigationLink {
                            ExercisesLibraryView()
                                .environment(dataVM)
                        } label: {
                            Label("Exercise library", systemImage: "books.vertical")
                        }
                        Button("New exercise", systemImage: "dumbbell") {
                            showNewExercise = true
                        }
                        Divider()
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            authVM.logout()
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showNewWorkout, onDismiss: { newWorkoutLaunchHint = nil }) {
                NewWorkoutSheet(launchHint: newWorkoutLaunchHint)
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
            }
            .onReceive(NotificationCenter.default.publisher(for: .fitlogPresentNewWorkout)) { output in
                if let hint = output.object as? NewWorkoutLaunchHint {
                    newWorkoutLaunchHint = hint
                } else {
                    newWorkoutLaunchHint = nil
                }
                showNewWorkout = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .fitlogDynamicProgramBlockChanged)) { note in
                let name = (note.userInfo?["newBlockName"] as? String) ?? "Next block"
                let idx = (note.userInfo?["newBlockIndex"] as? Int) ?? 0
                let total = (note.userInfo?["blockCount"] as? Int) ?? 0
                homeBlockTransitionToastSerial += 1
                let serial = homeBlockTransitionToastSerial
                homeBlockTransitionToast = total > 0 ? "Now in block \(idx) of \(total): \(name)" : "New training phase: \(name)"
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if serial == homeBlockTransitionToastSerial {
                        homeBlockTransitionToast = nil
                    }
                }
            }
            .sheet(isPresented: $showSplitBuilder) {
                SplitBuilderView()
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
            }
            .sheet(isPresented: $showNewExercise) {
                NewExerciseSheet()
                    .environment(dataVM)
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
            .navigationDestination(item: $todayPlanDetailRoute) { route in
                switch route {
                case .plannedWorkout(let id):
                    if let binding = $dm.userWorkouts[id] {
                        WorkoutPlanView(workout: binding, currentVM: currentVM)
                            .environment(dataVM)
                            .environmentObject(aiService)
                    } else {
                        Text("Workout not found")
                            .foregroundStyle(.red)
                    }
                }
            }
            .task(id: homeRefreshKey) {
                refreshCachedHomeData()
            }
            .task {
                try? await Task.sleep(nanoseconds: 280_000_000)
                homeFirstPaintSkeleton = false
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
                    .foregroundStyle(FitlogPalette.success)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(FitlogPalette.success)
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
                                .foregroundStyle(FitlogPalette.caution)
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
                    .strokeBorder(FitlogPalette.success.opacity(0.4), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the current workout")
    }

    private func dynamicProgramActiveSummaryRow(programName: String, blockCount: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(FitlogPalette.success)
            VStack(alignment: .leading, spacing: 4) {
                Text("Active dynamic program")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(programName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text("\(blockCount) blocks · matches Plan and Today above")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active dynamic program \(programName), \(blockCount) blocks")
    }

    private var aiSplitProgramRow: some View {
        Button {
            showSplitBuilder = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build a program")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Goals, phases, schedule, then save to Plan")
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
        .accessibilityHint("Opens the program builder")
    }

    private func dynamicProgramProgressAndScheduleCard(state: DynamicProgramState) -> some View {
        let cal = Calendar.current
        let pe = PeriodizationEngine(calendar: cal)
        let today = cal.startOfDay(for: Date())
        let placement = pe.blockPlacement(on: today, state: state)
        let sessionProgress = dataVM.dynamicProgramBlockSessionProgress(calendar: cal)
        let nextBlockLine: String? = {
            guard let placement else { return nil }
            let nextIdx = placement.index + 1
            guard state.program.blocks.indices.contains(nextIdx) else { return nil }
            let nb = state.program.blocks[nextIdx]
            return "Up next: \(nb.name) (\(nb.durationWeeks) wk)"
        }()
        return VStack(alignment: .leading, spacing: 10) {
            Label("Block & schedule", systemImage: "chart.bar.doc.horizontal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let placement {
                HStack(alignment: .center, spacing: 14) {
                    if let pr = sessionProgress, pr.planned > 0 {
                        dynamicProgramSessionProgressRing(completed: pr.completed, planned: pr.planned)
                            .accessibilityLabel("Sessions completed in this block through today, \(pr.completed) of \(pr.planned)")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if state.program.blocks.count > 1 {
                            Text("Block \(placement.index + 1) of \(state.program.blocks.count): \(placement.block.name)")
                                .font(.headline)
                            Text("Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks) in this phase")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(placement.block.name)
                                .font(.headline)
                            Text("Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let nextBlockLine {
                            Text(nextBlockLine)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(nextBlockLine)
                        }
                    }
                }
            } else {
                Text("Program starts \(state.anchorDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Divider()
            Text(dynamicProgramScheduleAdaptationSummary(state))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dynamicProgramProgressAccessibility(state: state, placement: placement, sessionProgress: sessionProgress))
    }

    private func dynamicProgramSessionProgressRing(completed: Int, planned: Int) -> some View {
        let total = max(1, planned)
        let frac = min(1, max(0, Double(completed) / Double(total)))
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.22), lineWidth: 6)
            Circle()
                .trim(from: 0, to: frac)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(completed)/\(planned)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(4)
        }
        .frame(width: 52, height: 52)
    }

    private func dynamicProgramScheduleAdaptationSummary(_ state: DynamicProgramState) -> String {
        let busy = state.busyDayKeys.count
        let missed = state.missedSessionDayKeys.count
        let policy = state.program.busyDayPolicy
        let policyLine: String = {
            switch policy {
            case .compress: return "Busy-day policy: compress remaining sessions in the week."
            case .shift: return "Busy-day policy: shift the active block when life gets in the way."
            case .flexDay: return "Busy-day policy: swap in lighter flex sessions on marked days."
            case .skip: return "Busy-day policy: skip — rotation stays on the default cadence."
            }
        }()
        var parts: [String] = [policyLine]
        if busy > 0 { parts.append("\(busy) busy day(s) on your calendar.") }
        if missed > 0 { parts.append("\(missed) missed training day(s) recorded for adaptation.") }
        if busy == 0, missed == 0 {
            parts.append("No busy flags or missed sessions tracked yet.")
        }
        return parts.joined(separator: " ")
    }

    private func dynamicProgramProgressAccessibility(
        state: DynamicProgramState,
        placement: (index: Int, block: ProgramBlock, weekInBlock: Int)?,
        sessionProgress: (completed: Int, planned: Int)?
    ) -> String {
        var parts: [String] = ["Block and schedule summary for \(state.program.name)"]
        if let placement {
            parts.append("\(placement.block.name), week \(placement.weekInBlock + 1)")
        }
        if let pr = sessionProgress {
            parts.append("\(pr.completed) of \(pr.planned) planned sessions in this block logged through today")
        }
        parts.append(dynamicProgramScheduleAdaptationSummary(state))
        return parts.joined(separator: " ")
    }

    private func weeklyRecapCard(_ recap: DataManager.WeeklyRecapSummary) -> some View {
        let unit = userPreferences.weightDisplayUnit
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Week in review", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if recap.metWeeklyGoal {
                    Text("Goal met")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FitlogPalette.success)
                }
            }
            Text("\(recap.sessionsThisWeek) workout\(recap.sessionsThisWeek == 1 ? "" : "s") · \(recap.setsThisWeek) sets")
                .font(.title3.weight(.semibold))
            Text(WeightStoreConversion.formatVolumeLbRep(recap.volumeThisWeekLbRep, unit: unit))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let fr = recap.volumeChangeFraction, recap.sessionsPriorWeek > 0 {
                let pct = Int((fr * 100).rounded())
                Text(
                    pct >= 0
                        ? "Training volume up about \(pct)% vs last week."
                        : "Training volume down about \(-pct)% vs last week."
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func progressSummaryCard(_ summary: HomeProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    metricChip(
                        title: "Strength",
                        value: "\(summary.strengthScore.score)",
                        subtitle: strengthScoreDeltaLine(summary.strengthScore)
                    )
                    metricChip(
                        title: "PRs (week)",
                        value: "\(summary.weeklyPRCount)",
                        subtitle: summary.weeklyPRCount == 0 ? "Keep pushing" : "New records"
                    )
                    metricChip(
                        title: "Streak",
                        value: "\(summary.dayStreak)d",
                        subtitle: summary.weekStreak > 0 ? "\(summary.weekStreak)w consistency" : "Build momentum"
                    )
                }
            }

            strengthTrendSparkline(summary.strengthScore.trend)

            if let unlocked = summary.latestUnlockedMilestone {
                HStack(spacing: 8) {
                    Image(systemName: "rosette")
                        .foregroundStyle(.yellow)
                    Text("Latest: \(unlocked.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else if let next = summary.nextMilestone {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.blue)
                    Text("Next: \(next.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func metricChip(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(width: 120, alignment: .leading)
        .frame(minHeight: 72, alignment: .top)
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private func strengthScoreDeltaLine(_ summary: StrengthScoreSummary) -> String {
        guard let delta = summary.delta else { return "No prior period" }
        if delta == 0 { return "Flat vs prior" }
        return delta > 0 ? "+\(delta) vs prior" : "\(delta) vs prior"
    }

    @ViewBuilder
    private func strengthTrendSparkline(_ trend: [StrengthScorePoint]) -> some View {
        let hasAny = trend.contains { $0.score > 0 }
        if hasAny {
            VStack(alignment: .leading, spacing: 6) {
                Text("8-week strength trend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart(trend) { pt in
                    AreaMark(
                        x: .value("Week", pt.weekStart),
                        y: .value("Score", pt.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FitlogPalette.chartPrimary.opacity(0.35), FitlogPalette.chartPrimary.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Week", pt.weekStart),
                        y: .value("Score", pt.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(FitlogPalette.chartPrimary)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 88)
            }
            .padding(.top, 4)
        }
    }

    private var todayDashboardBlock: some View {
        let plan = cachedTodayPlan
        return VStack(alignment: .leading, spacing: 10) {
            Text(Self.homeDateFormatter.string(from: Date()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Label("Today", systemImage: "sun.max.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)

            switch plan {
            case .rest:
                Text("Rest day")
                    .font(.title3.weight(.semibold))
                Text("Recovery is part of the program. Adjust today in the Plan tab if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unscheduled:
                Text("Nothing scheduled")
                    .font(.title3.weight(.semibold))
                Text("Set your split in the Plan tab, or start a workout below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .workout(let ref):
                let id = ref.libraryWorkoutId
                if let workout = dataVM.userWorkouts.first(where: { $0.id == id }) {
                    let sessionWorkout = workout.hasFlexibleSlots ? dataVM.sessionInstance(from: workout) : workout
                    let thisPlanActive = currentVM.isActiveSessionMatching(workout: sessionWorkout, planRef: ref)
                    let subtitle = "\(workout.listDetailSubtitle) · from your plan"
                    TodayWorkoutCard(
                        title: workout.name,
                        subtitle: subtitle,
                        isCompleted: isPlannedWorkoutCompletedToday(plan: ref),
                        isThisPlanActive: thisPlanActive,
                        isAnotherWorkoutActive: currentVM.isInProgress && !thisPlanActive,
                        onStartPlanWorkout: { startWorkoutFromTodayPlan(workout) },
                        onResumeCompletedToday: { resumeTodayPlanFromLastCompletedSession(workout) },
                        openActiveWorkout: { openCurrentWorkoutSheet?() },
                        onViewWorkoutDetail: { todayPlanDetailRoute = .plannedWorkout(id) },
                        detailLabel: "View workout"
                    )
                } else {
                    missingItemMessage("Missing workout", detail: "Your plan references a workout that isn’t in your library. Update the split in the Plan tab.")
                }
            }

            if let glance = cachedWeekGlance {
                DisclosureGroup(isExpanded: $weekGlanceExpanded) {
                    thisWeekSubsection(glance)
                        .padding(.top, 6)
                } label: {
                    Text("This week")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityHint("Shows workouts completed each day this week")
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
                        .foregroundStyle(FitlogPalette.success)
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

// MARK: - Workout library row (Home + full list)

private struct HomeWorkoutListRow: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var aiService: AIService

    let workout: Workout
    @Binding var workoutToRename: Workout?
    @Binding var renameText: String
    let onStartLibrary: (Workout) -> Void

    var body: some View {
        @Bindable var dm = dataVM
        return Group {
            NavigationLink {
                if let binding = $dm.userWorkouts[workout.id] {
                    WorkoutPlanView(workout: binding, currentVM: currentVM)
                        .environment(dataVM)
                        .environmentObject(aiService)
                } else {
                    Text("Workout not found")
                        .foregroundStyle(.red)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.headline)
                    Text(workout.listDetailSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button {
                onStartLibrary(workout)
            } label: {
                Label("Start workout", systemImage: "play.fill")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onStartLibrary(workout)
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .tint(FitlogPalette.success)
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
}

// MARK: - Full workout library (pushed from Home when the list is long)

private struct HomeWorkoutLibraryView: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var aiService: AIService

    @State private var workoutSearchText = ""
    @State private var workoutToRename: Workout?
    @State private var renameText = ""
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?

    private var searchTrimmed: String {
        workoutSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedWorkouts: [Workout] {
        guard !searchTrimmed.isEmpty else { return dataVM.userWorkouts }
        return dataVM.userWorkouts.filter { $0.name.localizedCaseInsensitiveContains(searchTrimmed) }
    }

    private func startWorkoutFromLibrary(_ library: Workout) {
        let toStart = library.hasFlexibleSlots ? dataVM.sessionInstance(from: library) : library
        currentVM.startWorkoutResolvingConflict(toStart, sessionPlanOrigin: .workout(library.id)) {
            pendingWorkoutReplace = $0
        }
    }

    var body: some View {
        List {
            ForEach(displayedWorkouts) { workout in
                HomeWorkoutListRow(
                    workout: workout,
                    workoutToRename: $workoutToRename,
                    renameText: $renameText,
                    onStartLibrary: startWorkoutFromLibrary
                )
            }
            .onMove { source, dest in
                guard searchTrimmed.isEmpty else { return }
                dataVM.moveWorkout(from: source, to: dest)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $workoutSearchText, prompt: "Search workouts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .disabled(!searchTrimmed.isEmpty)
            }
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
        .workoutReplaceConflictConfirmation(currentVM: currentVM, pending: $pendingWorkoutReplace)
        .fitlogWorkoutBarContentInset()
    }
}

// MARK: - Today’s plan → detail navigation

private enum TodayPlanDetailRoute: Hashable, Identifiable {
    case plannedWorkout(UUID)

    var id: String {
        switch self {
        case .plannedWorkout(let uuid):
            return "pw-\(uuid.uuidString)"
        }
    }
}

// MARK: - Reusable today-workout card

/// Unified card component for the today-plan section, handling active/completed/startable states.
private struct TodayWorkoutCard: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let isThisPlanActive: Bool
    let isAnotherWorkoutActive: Bool
    let onStartPlanWorkout: () -> Void
    let onResumeCompletedToday: () -> Void
    let openActiveWorkout: () -> Void
    let onViewWorkoutDetail: () -> Void
    let detailLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isThisPlanActive {
                Label("In progress", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FitlogPalette.success)
                Text("Continue from the bar below or open the full workout.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                primaryDetailRow(
                    primaryTitle: "Open workout",
                    primarySystemImage: "arrow.up.circle",
                    primaryTint: FitlogPalette.success,
                    primaryAction: openActiveWorkout
                )
            } else if isAnotherWorkoutActive {
                Text("Another workout is active. Starting this one will save it to history.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                primaryDetailRow(
                    primaryTitle: "Start workout",
                    primarySystemImage: "play.fill",
                    primaryTint: Color.accentColor,
                    primaryAction: onStartPlanWorkout
                )
            } else if isCompleted {
                Label("Done today", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FitlogPalette.success)
                Text("Pick up where you left off—including logged sets—or start fresh below.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                primaryDetailRow(
                    primaryTitle: "Continue session",
                    primarySystemImage: "arrow.clockwise.circle.fill",
                    primaryTint: Color.accentColor,
                    primaryAction: onResumeCompletedToday
                )
                Button(action: onStartPlanWorkout) {
                    Text("Start fresh instead")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                primaryDetailRow(
                    primaryTitle: "Start workout",
                    primarySystemImage: "play.fill",
                    primaryTint: Color.accentColor,
                    primaryAction: onStartPlanWorkout
                )
            }
        }
    }

    @ViewBuilder
    private func primaryDetailRow(
        primaryTitle: String,
        primarySystemImage: String,
        primaryTint: Color,
        primaryAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: primaryAction) {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Image(systemName: primarySystemImage)
                        .font(.subheadline.weight(.semibold))
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryTint)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)

            Button(action: onViewWorkoutDetail) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .accessibilityLabel(detailLabel)
        }
    }

    private var compactDetailLink: some View {
        Button(action: onViewWorkoutDetail) {
            Label(detailLabel, systemImage: "list.bullet.rectangle")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
    }
}

/// Applies `.searchable` only when enabled (SwiftUI has no built-in conditional searchable).
private struct HomeWorkoutSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String
    let prompt: String

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $text, prompt: prompt)
        } else {
            content
        }
    }
}
