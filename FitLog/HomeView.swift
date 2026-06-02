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
    @State private var showActiveProgramDetail = false
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
    @State private var workoutSearchText = ""
    @State private var showNewExercise = false
    @State private var showStartWorkoutSheet = false
    @State private var startWorkoutFeedbackSerial = 0
    @State private var homeFirstPaintSkeleton = true
    @State private var homeBlockTransitionToast: String?
    @State private var homeBlockTransitionToastSerial = 0
    @State private var showCardioResolveFailureAlert = false
    @State private var homeCardioFinisherOffered = false
    @State private var showHomeFinishEmptyConfirm = false
    @State private var showHomeFinishUnresolvedConfirm = false
    @State private var showHomeCardioFinisherOffer = false
    @State private var homeUnresolvedExerciseNames: [String] = []

    private var homeRefreshKey: String {
        let cycleSig = dataVM.trainingProgram.cycleEntries.map(\.cacheKey).joined(separator: ",")
        let dynSig: String = {
            guard let d = dataVM.dynamicProgramState else { return "dyn:none" }
            let shiftSig = d.blockShiftDays.map { "\($0.key.uuidString):\($0.value)" }.sorted().joined(separator: ",")
            return "dyn:\(d.program.id.uuidString)-\(Int(d.anchorDate.timeIntervalSince1970))-\(d.materializedTemplateWorkoutIds.count)-\(d.busyDayKeys.count)-\(d.missedSessionDayKeys.count)-\(shiftSig)"
        }()
        return "\(dayMonitor.currentDayKey)-\(dataVM.completedSessions.count)-\(cycleSig)-\(dataVM.trainingProgram.anchorDayKey)-\(dataVM.trainingProgram.dayOverrides.count)-\(dataVM.trainingProgram.weekOverrides.count)-\(userPreferences.dismissedProgramAssignmentBanner)-\(userPreferences.dismissedCardioGetStartedBanner)-\(dynSig)"
    }

    private var homeGreetingFirstName: String? {
        HomeGreeting.firstName(from: authVM.userName)
    }

    private var homeNavigationTitle: String {
        HomeGreeting.navigationTitle(firstName: homeGreetingFirstName)
    }

    private var scheduledWorkoutForToday: Workout? {
        guard case .workout(let ref) = cachedTodayPlan else { return nil }
        return dataVM.userWorkouts.first(where: { $0.id == ref.libraryWorkoutId })
    }

    private var recentQuickStartWorkouts: [Workout] {
        let ids = dataVM.recentCompletedLibraryWorkoutIds(limit: 4)
        return ids.compactMap { id in dataVM.userWorkouts.first(where: { $0.id == id }) }
    }

    private var recentWorkoutLastDoneDates: [UUID: Date] {
        Dictionary(uniqueKeysWithValues: dataVM.userWorkouts.map { workout in
            (workout.id, dataVM.lastCompletedDate(forLibraryWorkoutId: workout.id))
        }.compactMap { pair -> (UUID, Date)? in
            guard let date = pair.1 else { return nil }
            return (pair.0, date)
        })
    }

    private var shouldShowCardioGetStartedCard: Bool {
        !userPreferences.dismissedCardioGetStartedBanner && !dataVM.hasLoggedCardio()
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
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var homeEmptyWorkoutsCallout: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: homeFirstPaintSkeleton)
            Text("No workouts yet")
                .font(.title3.weight(.semibold))
            Text("Get training in three quick steps:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                emptyStepRow(number: 1, text: "Create a workout or pick a template")
                emptyStepRow(number: 2, text: "Add exercises from your library")
                emptyStepRow(number: 3, text: "Start training and log your sets")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            HStack(spacing: 12) {
                Button("New workout") {
                    newWorkoutLaunchHint = nil
                    showNewWorkout = true
                }
                .buttonStyle(.borderedProminent)
                Button("From template") {
                    newWorkoutLaunchHint = .templatesFirst
                    showNewWorkout = true
                }
                .buttonStyle(.bordered)
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

    private func emptyStepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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

    private func handleHomeFinishTap() {
        switch currentVM.nextFinishStep(cardioFinisherAlreadyOffered: homeCardioFinisherOffered) {
        case .confirmEmptyWorkout:
            showHomeFinishEmptyConfirm = true
        case .confirmUnresolvedExercises(let names):
            homeUnresolvedExerciseNames = names
            showHomeFinishUnresolvedConfirm = true
        case .offerCardioFinisher:
            showHomeCardioFinisherOffer = true
        case .ready:
            currentVM.finishWorkoutFromUI(showCompletionSummary: true)
            homeCardioFinisherOffered = false
        }
    }

    private func proceedHomeFinishAfterUnresolvedCheck() {
        switch currentVM.nextFinishStep(cardioFinisherAlreadyOffered: homeCardioFinisherOffered) {
        case .offerCardioFinisher:
            showHomeCardioFinisherOffer = true
        default:
            currentVM.finishWorkoutFromUI(showCompletionSummary: true)
            homeCardioFinisherOffered = false
        }
    }

    private func isPlannedWorkoutCompletedToday(plan: WorkoutPlanRef) -> Bool {
        cachedTodayCompletedRefs.contains(plan.cacheKey)
    }

    private func startWorkoutFromLibrary(_ library: Workout) {
        startWorkoutFeedbackSerial += 1
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
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                Section {
                    if currentVM.isInProgress {
                        HomeActiveWorkoutCard(
                            onOpen: { openCurrentWorkoutSheet?() },
                            onFinish: handleHomeFinishTap
                        )
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))

                        if let progress = cachedProgressSummary {
                            progressSummaryCard(progress)
                                .listRowInsets(homeDashboardListInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        if shouldShowCardioGetStartedCard {
                            cardioGetStartedCard
                                .listRowInsets(homeDashboardListInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        if let recap = cachedWeeklyRecap, recap.shouldShowRecapCard {
                            weeklyRecapCard(recap)
                                .listRowInsets(homeDashboardListInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        if !recentQuickStartWorkouts.isEmpty {
                            HomeRecentWorkoutsRow(
                                workouts: recentQuickStartWorkouts,
                                lastCompletedDates: recentWorkoutLastDoneDates,
                                onStart: startWorkoutFromLibrary
                            )
                            .listRowInsets(homeDashboardListInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
                    if let dyn = dataVM.dynamicProgramState {
                        HomeProgramSummaryCard(
                            state: dyn,
                            onOpenDetail: { showActiveProgramDetail = true },
                            onBuildNew: { showSplitBuilder = true },
                            onOpenWorkout: { todayPlanDetailRoute = .plannedWorkout($0) },
                            onStartWorkout: { startWorkoutFromTodayPlan($0) }
                        )
                        .listRowInsets(homeDashboardListInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        HomeBuildProgramCard { showSplitBuilder = true }
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
            .animation(.easeInOut(duration: 0.28), value: homeFirstPaintSkeleton)
            .workoutBottomScrollClearance()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !currentVM.isInProgress {
                    HomeStartWorkoutFAB(isWorkoutActive: currentVM.isInProgress) {
                        showStartWorkoutSheet = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(.bar)
                }
            }
            .navigationTitle(homeNavigationTitle)
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
                        Button("New exercise", systemImage: "dumbbell") {
                            showNewExercise = true
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showStartWorkoutSheet) {
                HomeStartWorkoutSheet(
                    todayPlan: cachedTodayPlan,
                    scheduledWorkout: scheduledWorkoutForToday,
                    recentWorkouts: recentQuickStartWorkouts,
                    lastCompletedDates: recentWorkoutLastDoneDates,
                    onStartScheduled: {
                        if let workout = scheduledWorkoutForToday {
                            startWorkoutFromTodayPlan(workout)
                        }
                    },
                    onStartLibrary: startWorkoutFromLibrary,
                    onNewWorkout: {
                        newWorkoutLaunchHint = nil
                        showNewWorkout = true
                    },
                    onNewFromTemplate: {
                        newWorkoutLaunchHint = .templatesFirst
                        showNewWorkout = true
                    }
                )
                .environment(dataVM)
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
                withAnimation(.easeInOut(duration: 0.25)) {
                    homeBlockTransitionToast = total > 0 ? "Now in block \(idx) of \(total): \(name)" : "New training phase: \(name)"
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if serial == homeBlockTransitionToastSerial {
                        withAnimation(.easeOut(duration: 0.2)) {
                            homeBlockTransitionToast = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showSplitBuilder) {
                SplitBuilderView()
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
            }
            .sheet(isPresented: $showActiveProgramDetail) {
                ActiveProgramDetailView()
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
            .alert(
                "No cardio exercises",
                isPresented: $showCardioResolveFailureAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add a cardio exercise to your library first, then try again.")
            }
            .confirmationDialog(
                "Finish without logging any sets?",
                isPresented: $showHomeFinishEmptyConfirm,
                titleVisibility: .visible
            ) {
                Button("Finish anyway", role: .destructive) {
                    currentVM.finishWorkoutFromUI(showCompletionSummary: true)
                    homeCardioFinisherOffered = false
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Some exercises have no logged sets",
                isPresented: $showHomeFinishUnresolvedConfirm,
                titleVisibility: .visible
            ) {
                Button("Finish anyway", role: .destructive) {
                    proceedHomeFinishAfterUnresolvedCheck()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(homeUnresolvedExerciseNames.joined(separator: ", "))
            }
            .confirmationDialog(
                "Add a cardio finisher?",
                isPresented: $showHomeCardioFinisherOffer,
                titleVisibility: .visible
            ) {
                Button("Skip") {
                    homeCardioFinisherOffered = true
                    currentVM.finishWorkoutFromUI(showCompletionSummary: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Optional quick cardio before you wrap up.")
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    homeFirstPaintSkeleton = false
                }
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
            .sensoryFeedback(.impact(weight: .medium), trigger: startWorkoutFeedbackSerial)
        }
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
        .homeCardTier(.secondary)
        .sensoryFeedback(.success, trigger: recap.metWeeklyGoal)
    }

    private var cardioGetStartedCard: some View {
        let hasCardioLibrary = dataVM.hasCardioWorkoutInLibrary()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 0)
                Button("Don't show again") {
                    userPreferences.dismissedCardioGetStartedBanner = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHint("Hides the cardio get-started card on Home")
            }

            CardioEmptyStateView(
                title: hasCardioLibrary
                    ? "Log your first cardio session"
                    : "Build your first cardio workout",
                message: "Use interval or steady-state templates, then track time and distance while you train.",
                primaryTitle: hasCardioLibrary ? "Start cardio workout" : "Build cardio workout",
                primaryAccessibilityHint: hasCardioLibrary
                    ? "Starts your saved cardio workout"
                    : "Opens the cardio workout builder",
                onPrimary: {
                    if hasCardioLibrary,
                       let workout = dataVM.userWorkouts.first(where: { $0.workoutKind == .cardio || $0.workoutKind == .hybrid }) {
                        startWorkoutFromLibrary(workout)
                    } else {
                        newWorkoutLaunchHint = .cardioFirst
                        showNewWorkout = true
                    }
                },
                secondaryTitle: nil,
                onSecondary: nil
            )

            if !currentVM.isInProgress {
                Text("Quick cardio")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CardioQuickAddTemplate.all) { template in
                            Button {
                                startInstantCardio(template)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Image(systemName: template.systemImage)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(FitlogPalette.chartSecondary)
                                    Text(template.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(template.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(width: 132, alignment: .leading)
                                .padding(12)
                                .background(FitlogPalette.chartSecondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(template.name), \(template.subtitle)")
                            .accessibilityHint("Starts a cardio session immediately with this template.")
                        }
                    }
                }
            }
        }
        .homeCardTier(.tertiary)
    }

    private func startInstantCardio(_ template: CardioQuickAddTemplate) {
        guard let exercise = template.resolveExercise(in: dataVM.globalExercises) else {
            showCardioResolveFailureAlert = true
            return
        }
        let quickWorkoutName = "Quick \(template.name)"
        if let existing = dataVM.userWorkouts.first(where: {
            $0.workoutKind == .cardio && $0.name == quickWorkoutName
        }) {
            startWorkoutFromLibrary(existing)
            return
        }
        let workoutId = dataVM.createCardioWorkout(name: quickWorkoutName, kind: .cardio)
        guard let created = dataVM.workout(id: workoutId) else { return }
        _ = dataVM.addCardioExercise(to: created, exercise: exercise, prescription: template.prescription)
        guard let updated = dataVM.workout(id: workoutId) else { return }
        startWorkoutFromLibrary(updated)
    }

    private func progressSummaryCard(_ summary: HomeProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if let tab = rootTabSelection {
                    Button("See stats") { tab.wrappedValue = .history }
                        .font(.caption.weight(.semibold))
                        .accessibilityHint("Opens the History tab for more analytics")
                }
            }

            HStack(spacing: 10) {
                homeStatTile(
                    title: "Strength",
                    value: "\(summary.strengthScore.score)",
                    systemImage: "bolt.fill",
                    accent: strengthDeltaColor(summary.strengthScore),
                    subtitle: strengthScoreDeltaLine(summary.strengthScore)
                )
                homeStatTile(
                    title: "PRs (week)",
                    value: "\(summary.weeklyPRCount)",
                    systemImage: "trophy.fill",
                    accent: summary.weeklyPRCount > 0 ? FitlogPalette.highlight : .secondary,
                    subtitle: summary.weeklyPRCount == 0 ? "Keep pushing" : "New records"
                )
                homeStatTile(
                    title: "Streak",
                    value: "\(summary.dayStreak)d",
                    systemImage: "flame.fill",
                    accent: summary.dayStreak > 0 ? FitlogPalette.highlight : .secondary,
                    subtitle: summary.weekStreak > 0 ? "\(summary.weekStreak)w consistency" : "Build momentum"
                )
            }

            if summary.weeklyCardioMinutes > 0 || summary.cardioDistanceKm > 0.01 {
                homeStatTile(
                    title: "Cardio",
                    value: "\(summary.weeklyCardioMinutes)m",
                    systemImage: "figure.run",
                    accent: FitlogPalette.chartSecondary,
                    subtitle: summary.cardioDistanceKm >= 0.1
                        ? String(format: "%.1f km this week", summary.cardioDistanceKm)
                        : "\(summary.cardioStreakDays)d cardio streak"
                )
            }

            strengthTrendSparkline(summary.strengthScore.trend)

            if let unlocked = summary.latestUnlockedMilestone {
                HStack(spacing: 8) {
                    Image(systemName: "rosette")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .symbolEffect(.bounce, value: unlocked.label)
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
        .homeCardTier(.secondary)
        .sensoryFeedback(.success, trigger: summary.latestUnlockedMilestone?.label)
    }

    private func homeStatTile(title: String, value: String, systemImage: String, accent: Color, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(value)
                .font(.headline.weight(.semibold))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(subtitle)")
    }

    private func strengthDeltaColor(_ summary: StrengthScoreSummary) -> Color {
        guard let delta = summary.delta else { return FitlogPalette.chartPrimary }
        if delta > 0 { return FitlogPalette.success }
        if delta < 0 { return FitlogPalette.caution }
        return .secondary
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
        let scheduledName = scheduledWorkoutForToday?.name
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.homeDateFormatter.string(from: Date()))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                Text(HomeGreeting.headline(firstName: homeGreetingFirstName))
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text(HomeGreeting.contextualSubtitle(
                    plan: plan,
                    weekGlance: cachedWeekGlance,
                    scheduledWorkoutName: scheduledName
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

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
                Divider()
                    .padding(.vertical, 2)
                HomeWeekStripView(
                    glance: glance,
                    streakDays: cachedProgressSummary?.dayStreak ?? 0
                )
            }
        }
        .homeCardTier(.primary)
    }

    @ViewBuilder
    private func missingItemMessage(_ title: String, detail: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
        Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
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

    private var exerciseCount: Int { workout.exercises.count }
    private var estimatedMinutes: Int {
        HomeWorkoutFormatting.estimatedDurationMinutes(exerciseCount: exerciseCount)
    }
    private var lastDoneText: String {
        HomeWorkoutFormatting.lastDoneLabel(
            for: dataVM.lastCompletedDate(forLibraryWorkoutId: workout.id)
        )
    }

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
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(workout.workoutKind.homeAccentColor.opacity(0.14))
                            .frame(width: 40, height: 40)
                        Image(systemName: workout.workoutKind.homeSystemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(workout.workoutKind.homeAccentColor)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(.headline)
                        if exerciseCount > 0 {
                            Text("\(exerciseCount) exercises · ~\(estimatedMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(workout.listDetailSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(lastDoneText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(workout.workoutKind.homeAccentColor)
                        .frame(width: 3)
                        .padding(.vertical, 4)
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
        .workoutBottomScrollClearance()
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
