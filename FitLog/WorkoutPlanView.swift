//
//  WorkoutPlanView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

/// View-only display order; persisted order is unchanged.
enum ExerciseDisplayOrder: String, CaseIterable {
    case defaultOrder = "Order"
    case alphabetical = "A–Z"
    case byMuscleGroup = "By muscle"
}

/// Pushes `FlexibleSlotEditorView` after adding an open slot.
private struct OpenSlotEditorNavigation: Identifiable, Hashable {
    let id: UUID
}

private enum AddExerciseSheetMode: Identifiable {
    case quickAdd
    case fullAdd(prefillExerciseId: UUID?)

    var id: String {
        switch self {
        case .quickAdd: return "quickAdd"
        case .fullAdd(let uuid): return "fullAdd-\(uuid?.uuidString ?? "none")"
        }
    }
}

/// Wraps a workout exercise with its index in the persisted array (for tap/delete/move).
private struct ExerciseDisplayItem: Identifiable {
    let id: UUID
    let workoutExercise: WorkoutExercise
    let sourceIndex: Int
    
    init(workoutExercise: WorkoutExercise, sourceIndex: Int) {
        self.id = workoutExercise.id
        self.workoutExercise = workoutExercise
        self.sourceIndex = sourceIndex
    }
}

struct WorkoutPlanView: View {
    @Binding var workout: Workout
    /// When set (e.g. new-workout flow), shows a Done button that calls this to dismiss the enclosing sheet.
    var creationFlowOnDone: (() -> Void)? = nil
    /// Passed in so this view does not observe timer-driven `@Published` updates from the session VM (avoids flicker in static content like muscle summaries).
    let currentVM: CurrentWorkoutSessionViewModel
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject var aiService: AIService
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.openPullUpToExerciseLogIndex) private var openPullUpToExerciseLogIndex
    @Environment(\.undoManager) private var undoManager
    @State private var addExercisePresentation: AddExerciseSheetMode?
    @State private var showRenameAlert = false
    @State private var newWorkoutName = ""
    @State private var displayOrder: ExerciseDisplayOrder = .defaultOrder
    @State private var suggestionsResult: Result<[String], Error>?
    @State private var suggestionsLoading = false
    @State private var suggestionsExpanded = true
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?
    @State private var openSlotEditorNavigation: OpenSlotEditorNavigation?
    @State private var progressionSuggestions: [UUID: ProgressionSuggestion] = [:]
    @State private var showAIExerciseSuggestSheet = false
    @State private var showCardioBuilder = false
    @State private var showCardioExercisePicker = false
    @State private var cardioPrescriptionEdit: CardioPrescriptionEditItem?
    @State private var planCardioFinisherOffered = false
    @State private var showPlanFinishEmptyConfirm = false
    @State private var showPlanFinishUnresolvedConfirm = false
    @State private var showPlanCardioFinisherOffer = false
    @State private var planUnresolvedExerciseNames: [String] = []
    @State private var showPlanCardioResolveFailureAlert = false
    @State private var showPlanFinisherQuickAdd = false
    @State private var planFinisherQuickAddLogCountBefore: Int?

    private struct CardioPrescriptionEditItem: Identifiable {
        let id: UUID
        let exerciseName: String
        var prescription: CardioPrescription
    }

    /// Active session started from this library workout (`sessionInstance` uses a different workout id).
    private var isThisLibrarySessionActive: Bool {
        guard let s = currentVM.currentSession, s.endTime == nil else { return false }
        return s.sessionPlanOrigin == .workout(workout.id)
    }

    private var workoutForSessionStart: Workout {
        workout.hasFlexibleSlots ? dataVM.sessionInstance(from: workout) : workout
    }

    /// Display list for default and alphabetical (flat). Order is view-only.
    private var displayedItems: [ExerciseDisplayItem] {
        let enumerated = workout.exercises.enumerated().map { ExerciseDisplayItem(workoutExercise: $0.element, sourceIndex: $0.offset) }
        switch displayOrder {
        case .defaultOrder:
            return enumerated
        case .alphabetical:
            return enumerated.sorted {
                dataVM.displayName(for: $0.workoutExercise)
                    .localizedCaseInsensitiveCompare(dataVM.displayName(for: $1.workoutExercise)) == .orderedAscending
            }
        case .byMuscleGroup:
            return enumerated
        }
    }
    
    /// Sections for "By muscle" view only. Order is view-only.
    private var displayedSections: [(String, [ExerciseDisplayItem])] {
        let enumerated = workout.exercises.enumerated().map { ExerciseDisplayItem(workoutExercise: $0.element, sourceIndex: $0.offset) }
        let grouped = Dictionary(grouping: enumerated) { item -> String in
            let we = item.workoutExercise
            if let eid = we.exerciseId, let ex = dataVM.globalExercises.first(where: { $0.id == eid }) {
                return ex.targetedMuscles.first?.rawValue ?? MuscleGroup.other.rawValue
            }
            if let snap = we.snapshot, let ex = dataVM.resolveExercise(for: snap) {
                return ex.targetedMuscles.first?.rawValue ?? MuscleGroup.other.rawValue
            }
            if case .flexible(let b) = we.resolution, let first = b.targetedMuscles.first {
                return first.rawValue
            }
            return MuscleGroup.other.rawValue
        }
        return grouped.keys.sorted().map { key in
            (key, (grouped[key] ?? []).sorted {
                dataVM.displayName(for: $0.workoutExercise)
                    .localizedCaseInsensitiveCompare(dataVM.displayName(for: $1.workoutExercise)) == .orderedAscending
            })
        }
    }
    
    /// Displayed suggestions: from AI when configured and successful, else heuristic.
    private var displayedSuggestions: [String] {
        switch suggestionsResult {
        case .success(let list): return list
        case .failure, .none: return heuristicImprovementSuggestions(for: workout, dataVM: dataVM)
        }
    }

    var body: some View {
        Group {
            if displayOrder == .byMuscleGroup {
                listWithSections
            } else {
                listFlat
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                if let onDone = creationFlowOnDone {
                    Button("Done", action: onDone)
                }
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isThisLibrarySessionActive ? "Stop" : "Start") {
                    if isThisLibrarySessionActive {
                        handlePlanStopTap()
                    } else {
                        guard !workout.exercises.isEmpty else { return }
                        currentVM.startWorkoutResolvingConflict(
                            workoutForSessionStart,
                            sessionPlanOrigin: .workout(workout.id)
                        ) {
                            pendingWorkoutReplace = $0
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isThisLibrarySessionActive ? .red : .green)
                .disabled(!isThisLibrarySessionActive && workout.exercises.isEmpty)
                .accessibilityLabel(isThisLibrarySessionActive ? "Stop workout" : "Start workout")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newWorkoutName = workout.name
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Picker("View", selection: $displayOrder) {
                        ForEach(ExerciseDisplayOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Workout options")
                .accessibilityHint("Rename workout or change exercise list view")
            }
        }
        .workoutBottomScrollClearance()
        .sheet(item: $addExercisePresentation) { mode in
            switch mode {
            case .quickAdd:
                PlanQuickAddExerciseSheet(
                    workoutId: workout.id,
                    currentVM: currentVM,
                    presentation: $addExercisePresentation
                )
                .environment(dataVM)
                .environmentObject(aiService)
            case .fullAdd(let prefillId):
                AddExerciseSheet(workout: workout, currentVM: currentVM, presetExerciseId: prefillId)
                    .environment(dataVM)
                    .environmentObject(aiService)
            }
        }
        .alert("Rename Workout", isPresented: $showRenameAlert) {
            TextField("New name", text: $newWorkoutName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                dataVM.renameWorkout(workout, newName: newWorkoutName)
            }
        }
        .workoutReplaceConflictConfirmation(currentVM: currentVM, pending: $pendingWorkoutReplace)
        .navigationDestination(item: $openSlotEditorNavigation) { nav in
            FlexibleSlotEditorView(workoutId: workout.id, slotId: nav.id, autoFocusLabelOnAppear: true)
                .environment(dataVM)
                .onDisappear {
                    if openSlotEditorNavigation?.id == nav.id {
                        openSlotEditorNavigation = nil
                    }
                }
        }
        .task(id: progressionRefreshKey) {
            refreshProgressionSuggestions()
        }
        .sheet(isPresented: $showAIExerciseSuggestSheet) {
            AISuggestExercisesFillSheet(
                workoutId: workout.id,
                currentVM: currentVM
            )
            .environment(dataVM)
            .environmentObject(aiService)
            .environment(entitlementStore)
        }
        .sheet(isPresented: $showCardioBuilder) {
            NavigationStack {
                CardioWorkoutBuilderView(workoutId: workout.id, dataManager: dataVM)
                    .environment(dataVM)
            }
        }
        .sheet(isPresented: $showCardioExercisePicker) {
            CardioExercisePickerSheet { exercise in
                let rx = defaultCardioPrescription(for: exercise)
                _ = dataVM.addCardioExercise(to: workout, exercise: exercise, prescription: rx)
                if let updated = dataVM.workout(id: workout.id) {
                    workout = updated
                    currentVM.syncExercises(withUpdatedWorkout: updated)
                }
            }
            .environment(dataVM)
        }
        .sheet(item: $cardioPrescriptionEdit) { item in
            CardioRowPrescriptionEditorSheet(
                workoutId: workout.id,
                rowId: item.id,
                exerciseName: item.exerciseName,
                prescription: item.prescription
            )
            .environment(dataVM)
        }
        .confirmationDialog(
            "Finish without logging any sets?",
            isPresented: $showPlanFinishEmptyConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish anyway", role: .destructive) {
                currentVM.finishWorkoutFromUI(showCompletionSummary: true)
                planCardioFinisherOffered = false
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Some exercises have no logged sets",
            isPresented: $showPlanFinishUnresolvedConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish anyway", role: .destructive) {
                proceedPlanStopAfterUnresolvedCheck()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(planUnresolvedExerciseNames.joined(separator: ", "))
        }
        .confirmationDialog(
            "Add a cardio finisher?",
            isPresented: $showPlanCardioFinisherOffer,
            titleVisibility: .visible
        ) {
            Button("Quick 10 min") {
                if let template = CardioQuickAddTemplate.all.first,
                   let exercise = template.resolveExercise(in: dataVM.globalExercises),
                   currentVM.appendCardioExerciseToSession(exercise: exercise, prescription: template.prescription) {
                    planCardioFinisherOffered = true
                    if let idx = currentVM.currentSession?.exerciseLogs.indices.last {
                        openPullUpToExerciseLogIndex?(idx)
                    }
                } else {
                    showPlanCardioResolveFailureAlert = true
                }
            }
            .accessibilityLabel("Quick 10 minute cardio finisher")
            .accessibilityHint("Adds a 10 minute zone 2 cardio exercise to this workout.")
            Button("Choose exercise…") {
                planFinisherQuickAddLogCountBefore = currentVM.currentSession?.exerciseLogs.count
                showPlanFinisherQuickAdd = true
            }
            .accessibilityLabel("Choose cardio exercise")
            .accessibilityHint("Opens the exercise picker to add a cardio finisher.")
            Button("Skip") {
                planCardioFinisherOffered = true
                currentVM.finishWorkoutFromUI(showCompletionSummary: true)
            }
            .accessibilityLabel("Skip cardio finisher")
            .accessibilityHint("Finishes the workout without adding cardio.")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Optional cardio after your main work. You can log it now or skip and finish.")
        }
        .alert(
            "No cardio exercises",
            isPresented: $showPlanCardioResolveFailureAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add a cardio exercise to your library first, then try again.")
        }
        .sheet(isPresented: $showPlanFinisherQuickAdd) {
            if let session = currentVM.currentSession {
                SessionQuickAddExerciseSheet(
                    workout: session.workout,
                    currentVM: currentVM,
                    dataVM: dataVM
                )
                .environmentObject(aiService)
            }
        }
        .onChange(of: showPlanFinisherQuickAdd) { _, isPresented in
            guard !isPresented, let before = planFinisherQuickAddLogCountBefore else { return }
            planFinisherQuickAddLogCountBefore = nil
            let after = currentVM.currentSession?.exerciseLogs.count ?? 0
            if after > before {
                planCardioFinisherOffered = true
                if let idx = currentVM.currentSession?.exerciseLogs.indices.last {
                    openPullUpToExerciseLogIndex?(idx)
                }
            }
        }
    }

    private func handlePlanStopTap() {
        switch currentVM.nextFinishStep(cardioFinisherAlreadyOffered: planCardioFinisherOffered) {
        case .confirmEmptyWorkout:
            showPlanFinishEmptyConfirm = true
        case .confirmUnresolvedExercises(let names):
            planUnresolvedExerciseNames = names
            showPlanFinishUnresolvedConfirm = true
        case .offerCardioFinisher:
            showPlanCardioFinisherOffer = true
        case .ready:
            currentVM.finishWorkoutFromUI(showCompletionSummary: true)
            planCardioFinisherOffered = false
        }
    }

    private func proceedPlanStopAfterUnresolvedCheck() {
        switch currentVM.nextFinishStep(cardioFinisherAlreadyOffered: planCardioFinisherOffered) {
        case .offerCardioFinisher:
            showPlanCardioFinisherOffer = true
        default:
            currentVM.finishWorkoutFromUI(showCompletionSummary: true)
            planCardioFinisherOffered = false
        }
    }

    private func defaultCardioPrescription(for exercise: Exercise) -> CardioPrescription {
        let metric = exercise.cardioMetadata?.primaryMetric ?? .time
        switch metric {
        case .distance:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 20 * 60, targetDistanceM: 3_000)
        default:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 30 * 60, targetZone: .zone2)
        }
    }

    private var progressionRefreshKey: String {
        "\(workout.id.uuidString)-\(workout.exercises.count)-\(dataVM.completedSessions.count)"
    }

    private func refreshProgressionSuggestions() {
        var next: [UUID: ProgressionSuggestion] = [:]
        for we in workout.exercises {
            if let suggestion = dataVM.progressionSuggestion(for: we) {
                next[we.id] = suggestion
            }
        }
        progressionSuggestions = next
    }

    private func deleteExerciseRows(atOffsets indexSet: IndexSet, items: [ExerciseDisplayItem]) {
        let ids = indexSet.map { items[$0].workoutExercise.id }
        let dm = dataVM
        let vm = currentVM
        for weId in ids {
            guard let lib = dm.userWorkouts.first(where: { $0.id == workout.id }) else { continue }
            guard let snap = dm.deleteExerciseReturningSnapshot(from: lib, exerciseId: weId) else { continue }
            if let um = undoManager {
                um.registerUndo(withTarget: um) { _ in
                    dm.restoreWorkoutExercise(snap)
                    if let w = dm.userWorkouts.first(where: { $0.id == snap.workoutId }) {
                        vm.syncExercises(withUpdatedWorkout: w)
                    }
                }
                um.setActionName("Delete Exercise")
            }
        }
        if let updated = dm.userWorkouts.first(where: { $0.id == workout.id }) {
            vm.syncExercises(withUpdatedWorkout: updated)
        }
    }

    private var listFlat: some View {
        List {
            workoutSummarySection
            workoutInsightsBannerSection
            if displayOrder == .defaultOrder {
                Section("Exercises") {
                    ForEach(displayedItems) { item in
                        exerciseRow(item: item)
                    }
                    .onDelete { indexSet in
                        deleteExerciseRows(atOffsets: indexSet, items: displayedItems)
                    }
                    .onMove { from, to in
                        let count = displayedItems.count
                        guard count > 0 else { return }
                        let safeFrom = IndexSet(from.filter { $0 >= 0 && $0 < count })
                        guard !safeFrom.isEmpty else { return }
                        let safeTo = min(max(0, to), count)
                        dataVM.moveExercise(in: workout, from: safeFrom, to: safeTo)
                        if let updatedWorkout = dataVM.userWorkouts.first(where: { $0.id == workout.id }) {
                            currentVM.syncExercises(withUpdatedWorkout: updatedWorkout)
                        }
                    }
                }
            } else {
                Section("Exercises") {
                    ForEach(displayedItems) { item in
                        exerciseRow(item: item)
                    }
                    .onDelete { indexSet in
                        deleteExerciseRows(atOffsets: indexSet, items: displayedItems)
                    }
                }
            }
            addMenuSection
        }
    }
    
    private var listWithSections: some View {
        List {
            workoutSummarySection
            workoutInsightsBannerSection
            ForEach(displayedSections, id: \.0) { sectionName, items in
                Section(header: Text(sectionName)) {
                    ForEach(items) { item in
                        exerciseRow(item: item)
                    }
                    .onDelete { indexSet in
                        deleteExerciseRows(atOffsets: indexSet, items: items)
                    }
                }
            }
            addMenuSection
        }
    }

    private var workoutTotalRecommendedSets: Int {
        workout.exercises.reduce(0) { $0 + $1.recommendedSets }
    }

    private var workoutPrimaryMuscleSummary: String {
        var setsByMuscle: [MuscleGroup: Int] = [:]
        for we in workout.exercises {
            let primary: MuscleGroup
            if let eid = we.exerciseId, let ex = dataVM.globalExercises.first(where: { $0.id == eid }) {
                primary = ex.targetedMuscles.first ?? .other
            } else if let snap = we.snapshot, let ex = dataVM.resolveExercise(for: snap) {
                primary = ex.targetedMuscles.first ?? .other
            } else if case .flexible(let b) = we.resolution, let first = b.targetedMuscles.first {
                primary = first
            } else {
                primary = .other
            }
            setsByMuscle[primary, default: 0] += we.recommendedSets
        }
        let top = setsByMuscle.sorted { $0.value > $1.value }.prefix(4).map { $0.key.rawValue }
        return top.isEmpty ? "—" : top.joined(separator: ", ")
    }

    private var currentWorkoutGapHints: [String] {
        workoutStructureGapHints(for: workout, dataVM: dataVM)
    }

    private var workoutSummarySection: some View {
        Section {
            if workout.workoutKind != .strength {
                LabeledContent("Workout type") {
                    Text(workout.workoutKind.displayName)
                        .foregroundStyle(FitlogPalette.chartSecondary)
                        .fontWeight(.medium)
                }
            }
            LabeledContent("Exercises", value: "\(workout.exercises.count)")
            LabeledContent("Planned sets (sum)", value: "\(workoutTotalRecommendedSets)")
            if workout.workoutKind == .strength || workout.workoutKind == .hybrid {
                LabeledContent("Top muscles (by sets)", value: workoutPrimaryMuscleSummary)
            }
            if workout.workoutKind == .cardio || workout.workoutKind == .hybrid {
                Button {
                    showCardioBuilder = true
                } label: {
                    Label("Open cardio builder", systemImage: "figure.run")
                }
                .accessibilityHint("Edit cardio prescriptions and templates")
            }
            if workout.exercises.isEmpty {
                Text("Add movements below, or use Add → Suggest exercises for starter ideas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !currentWorkoutGapHints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(currentWorkoutGapHints, id: \.self) { line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Balance looks reasonable for the muscles you’ve included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Overview")
        }
    }

    private var workoutInsightsBannerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Tips & structure")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        Task { await loadSuggestions() }
                    } label: {
                        Text(suggestionsResult == nil ? "Get AI tips" : "Refresh")
                    }
                    .font(.caption.weight(.semibold))
                    .disabled(suggestionsLoading)
                }
                if suggestionsLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DisclosureGroup(isExpanded: $suggestionsExpanded) {
                    if case .failure(let error) = suggestionsResult {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    ForEach(displayedSuggestions, id: \.self) { suggestion in
                        Text("• \(suggestion)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Text("Show coaching suggestions")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    private var addMenuSection: some View {
        Section {
            Menu {
                if workout.workoutKind == .cardio || workout.workoutKind == .hybrid {
                    Button {
                        showCardioExercisePicker = true
                    } label: {
                        Label("Cardio exercise…", systemImage: "figure.run")
                    }
                }
                Button {
                    addExercisePresentation = .quickAdd
                } label: {
                    Label("Exercise (quick add)", systemImage: "bolt.fill")
                }
                Button {
                    addExercisePresentation = .fullAdd(prefillExerciseId: nil)
                } label: {
                    Label("Exercise (full options…)", systemImage: "slider.horizontal.3")
                }
                Button {
                    addOpenSlot()
                } label: {
                    Label("Open slot (flexible)", systemImage: "square.dashed")
                }
                Divider()
                Button {
                    showAIExerciseSuggestSheet = true
                } label: {
                    let useCloudAI = entitlementStore.hasAccess(to: .aiWorkoutSuggestions) && aiService.isConfigured
                    Label(
                        useCloudAI ? "Suggest exercises (AI)…" : "Suggest exercises…",
                        systemImage: useCloudAI ? "sparkles" : "wand.and.stars"
                    )
                }
            } label: {
                Label("Add to workout", systemImage: "plus.circle.fill")
            }
        }
    }
    
    @ViewBuilder
    private func exerciseRow(item: ExerciseDisplayItem) -> some View {
        let we = item.workoutExercise
        let progression = progressionSuggestions[we.id]
        if case .flexible = we.resolution, let slotId = we.templateSlotId {
            NavigationLink {
                FlexibleSlotEditorView(workoutId: workout.id, slotId: slotId)
                    .environment(dataVM)
            } label: {
                flexibleRowLabel(we, progression: progression)
            }
        } else {
            HStack(spacing: 8) {
                Button {
                    guard isThisLibrarySessionActive,
                          item.sourceIndex < workout.exercises.count
                    else { return }
                    let rowId = workout.exercises[item.sourceIndex].id
                    guard let logIndex = currentVM.currentSession?.exerciseLogs.firstIndex(where: { $0.workoutExercise.id == rowId })
                    else { return }
                    openPullUpToExerciseLogIndex?(logIndex)
                } label: {
                    concreteRowLabel(we, progression: progression)
                }
                if let exercise = libraryExercise(for: we), exercise.modality != .cardio {
                    ExerciseFormGuideInfoButton(exercise: exercise)
                }
            }
        }
    }

    private func libraryExercise(for workoutExercise: WorkoutExercise) -> Exercise? {
        if let snapshot = workoutExercise.snapshot {
            return dataVM.resolveExercise(for: snapshot)
        }
        if let exerciseId = workoutExercise.exerciseId {
            return dataVM.globalExercises.first { $0.id == exerciseId }
        }
        return nil
    }

    private func flexibleRowLabel(_ we: WorkoutExercise, progression: ProgressionSuggestion? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(dataVM.displayName(for: we))
                            .font(.headline)
                        Text("Open slot")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if case .flexible(let b) = we.resolution, !b.targetedMuscles.isEmpty {
                        Text(b.targetedMuscles.prefix(3).map(\.rawValue).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let suggestion = progression {
                    progressionBadge(suggestion)
                }
                Spacer()
                strengthRecLabel(for: we)
            }
            cardioPrescriptionBlock(for: we)
            if let suggestion = progression {
                Text(suggestion.shortLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func concreteRowLabel(_ we: WorkoutExercise, progression: ProgressionSuggestion? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dataVM.displayName(for: we)).font(.headline)
                if let suggestion = progression {
                    progressionBadge(suggestion)
                }
                Spacer()
                strengthRecLabel(for: we)
            }
            cardioPrescriptionBlock(for: we)
            if let suggestion = progression {
                Text(suggestion.shortLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func strengthRecLabel(for we: WorkoutExercise) -> some View {
        if we.effectiveCardioPrescription == nil {
            Text("Rec: \(we.recommendedSets) sets x \(we.recommendedReps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func cardioPrescriptionBlock(for we: WorkoutExercise) -> some View {
        if let rx = we.effectiveCardioPrescription {
            let exercise = we.exerciseId.flatMap { id in dataVM.globalExercises.first { $0.id == id } }
            Button {
                cardioPrescriptionEdit = CardioPrescriptionEditItem(
                    id: we.id,
                    exerciseName: dataVM.displayName(for: we),
                    prescription: rx
                )
            } label: {
                CardioPrescriptionRowView(prescription: rx, exercise: exercise)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit cardio prescription")
        }
    }

    @ViewBuilder
    private func progressionBadge(_ suggestion: ProgressionSuggestion) -> some View {
        let (symbol, color): (String, Color) = {
            switch suggestion.direction {
            case .increase: return ("arrow.up.circle.fill", .green)
            case .hold: return ("equal.circle.fill", .orange)
            case .decrease: return ("arrow.down.circle.fill", .red)
            }
        }()
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(color)
            .accessibilityLabel("Progression: \(suggestion.shortLine)")
    }

    private func addOpenSlot() {
        let slots = dataVM.flexibleSlots(from: workout)
        let n = slots.count + 1
        let inferred = inferredOpenSlotDefaults()
        let slot = TemplateSlot(
            label: "Slot \(n)",
            targetedMuscles: inferred.muscles,
            exerciseRole: inferred.role,
            movementPattern: inferred.pattern,
            defaultExerciseId: nil,
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8-12"
        )
        guard let newSlotId = dataVM.appendFlexibleSlot(toWorkoutId: workout.id, slot: slot) else { return }
        if let updated = dataVM.userWorkouts.first(where: { $0.id == workout.id }) {
            workout = updated
        }
        openSlotEditorNavigation = OpenSlotEditorNavigation(id: newSlotId)
    }

    /// Primary muscle distribution in the workout → defaults for a new open slot (avoids always defaulting to chest).
    private func inferredOpenSlotDefaults() -> (muscles: [MuscleGroup], role: ExerciseRole, pattern: MovementPattern) {
        var counts: [MuscleGroup: Int] = [:]
        for we in workout.exercises {
            let primary: MuscleGroup
            if let eid = we.exerciseId, let ex = dataVM.globalExercises.first(where: { $0.id == eid }) {
                primary = ex.targetedMuscles.first ?? .other
            } else if let snap = we.snapshot, let ex = dataVM.resolveExercise(for: snap) {
                primary = ex.targetedMuscles.first ?? .other
            } else if case .flexible(let b) = we.resolution {
                primary = b.targetedMuscles.first ?? .other
            } else {
                primary = .other
            }
            counts[primary, default: 0] += max(1, we.recommendedSets)
        }
        let nonOther = counts.filter { $0.key != .other }
        let pool = nonOther.isEmpty ? counts : nonOther
        guard let best = pool.max(by: { $0.value < $1.value }), best.value > 0 else {
            return ([.other], .accessory, .other)
        }
        return ([best.key], .compound, movementPatternHeuristic(for: best.key))
    }

    private func movementPatternHeuristic(for muscle: MuscleGroup) -> MovementPattern {
        switch muscle {
        case .chest, .upperChest, .lowerChest, .serratusAnterior: return .horizontalPush
        case .lats, .upperBack, .midBack, .rhomboids, .traps: return .verticalPull
        case .lowerBack, .posteriorChain: return .hinge
        case .quads, .hipFlexors: return .squat
        case .hamstrings, .glutes: return .hinge
        case .adductors, .abductors: return .lunge
        case .biceps, .triceps, .brachialis, .forearms, .rotatorCuff: return .isolation
        case .frontDelts, .sideDelts, .rearDelts: return .verticalPush
        case .calves, .soleus: return .isolation
        case .abs, .lowerAbs, .obliques, .core: return .rotation
        case .neck: return .isolation
        case .other: return .other
        }
    }

    private func loadSuggestions() async {
        guard entitlementStore.hasAccess(to: .aiWorkoutSuggestions), aiService.isConfigured else {
            suggestionsResult = .success(heuristicImprovementSuggestions(for: workout, dataVM: dataVM))
            return
        }
        suggestionsLoading = true
        suggestionsResult = nil
        defer { suggestionsLoading = false }
        do {
            let list = try await aiService.fetchWorkoutSuggestions(for: workout, globalExercises: dataVM.globalExercises)
            suggestionsResult = .success(list)
        } catch {
            suggestionsResult = .failure(error)
        }
    }
}

// MARK: - Structure / balance helpers
@MainActor
private func workoutStructureGapHints(for workout: Workout, dataVM: DataManager) -> [String] {
    guard !workout.exercises.isEmpty else { return [] }
    var hints: [String] = []
    var setsByMuscle: [MuscleGroup: Int] = [:]
    for we in workout.exercises {
        let primary: MuscleGroup
        if let eid = we.exerciseId, let ex = dataVM.globalExercises.first(where: { $0.id == eid }) {
            primary = ex.targetedMuscles.first ?? .other
        } else if let snap = we.snapshot, let ex = dataVM.resolveExercise(for: snap) {
            primary = ex.targetedMuscles.first ?? .other
        } else if case .flexible(let b) = we.resolution, let first = b.targetedMuscles.first {
            primary = first
        } else {
            primary = .other
        }
        setsByMuscle[primary, default: 0] += we.recommendedSets
    }
    let quadSets = (setsByMuscle[.quads] ?? 0)
    let hamSets = (setsByMuscle[.hamstrings] ?? 0)
    if quadSets > 0 && hamSets == 0 {
        hints.append("You have quad work but no direct hamstring work; consider a hinge or leg curl.")
    }
    let pushSets = (setsByMuscle[.chest] ?? 0) + (setsByMuscle[.frontDelts] ?? 0) + (setsByMuscle[.triceps] ?? 0)
    let pullSets = (setsByMuscle[.lats] ?? 0) + (setsByMuscle[.upperBack] ?? 0) + (setsByMuscle[.biceps] ?? 0)
    if pushSets >= pullSets * 2 && pullSets > 0 {
        hints.append("Push volume is much higher than pull; consider rowing or pulldown work.")
    }
    if workout.exercises.count > 8 {
        hints.append("Many exercises listed; consider focusing on 4–6 key lifts and adding sets.")
    }
    return hints
}

// MARK: - Heuristic fallback suggestions
@MainActor
private func heuristicImprovementSuggestions(for workout: Workout, dataVM: DataManager) -> [String] {
    guard !workout.exercises.isEmpty else {
        return ["Add 4–6 compound and accessory movements that cover all major muscle groups you want to train."]
    }
    let gaps = workoutStructureGapHints(for: workout, dataVM: dataVM)
    if gaps.isEmpty {
        return ["Your workout looks reasonably balanced. Add small amounts of volume or load over time to progress."]
    }
    return gaps
}

// MARK: - Exercise picker (search, favorites, recent, subgrouping, section index)
private struct ExercisePickerView: View {
    let exercises: [Exercise]
    @Binding var selection: Exercise?
    /// When set, choosing a row invokes this instead of updating `selection` (e.g. one-tap add flow).
    var onExerciseChosen: ((Exercise) -> Void)? = nil
    var navigationTitleText: String = "Select Exercise"
    @Environment(DataManager.self) var dataVM
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var favoriteIds: Set<UUID> = []
    @State private var recentIds: [UUID] = []

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return exercises }
        return exercises.filter { ex in
            ex.matchesExerciseSearch(query: q, resolvedDisplayName: dataVM.resolvedDisplayName(for: ex))
        }
    }

    private var favoriteExercises: [Exercise] {
        filtered.filter { favoriteIds.contains($0.id) }
            .sorted {
                dataVM.resolvedDisplayName(for: $0).localizedCaseInsensitiveCompare(dataVM.resolvedDisplayName(for: $1)) == .orderedAscending
            }
    }

    private var recentExercises: [Exercise] {
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        return recentIds.compactMap { byId[$0] }
            .filter { filtered.contains($0) && !favoriteIds.contains($0.id) }
    }

    private var exercisesForBucketGrouping: [Exercise] {
        let pinned = Set(favoriteExercises.map(\.id)).union(Set(recentExercises.map(\.id)))
        return filtered.filter { !pinned.contains($0.id) }
    }

    /// Subgrouped: (bucketName, [(muscle, [Exercise])]) in bucket order.
    private var bucketedSections: [(String, [(MuscleGroup, [Exercise])])] {
        ExerciseCategoryGrouping.bucketedSections(exercises: exercisesForBucketGrouping) { dataVM.resolvedDisplayName(for: $0) }
    }

    /// Section IDs for scroll-to (section index).
    private var sectionIds: [String] {
        var ids: [String] = []
        if !favoriteExercises.isEmpty { ids.append("favorites") }
        if !recentExercises.isEmpty { ids.append("recent") }
        ids.append(contentsOf: bucketedSections.map { $0.0.lowercased() })
        return ids
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !favoriteExercises.isEmpty {
                    Section(header: Text("Favorites")) {
                        exerciseRows(favoriteExercises, showFavorite: true)
                    }
                    .id("favorites")
                }
                if !recentExercises.isEmpty {
                    Section(header: Text("Recent")) {
                        exerciseRows(recentExercises, showFavorite: true)
                    }
                    .id("recent")
                }
                ForEach(bucketedSections, id: \.0) { bucket, musclePairs in
                    Section(header: Text(bucket)) {
                        ForEach(musclePairs, id: \.0.id) { muscle, list in
                            Section(header: Text(muscle.rawValue)) {
                                exerciseRows(list, showFavorite: true)
                            }
                        }
                    }
                    .id(bucket.lowercased())
                }
            }
            .searchable(text: $searchText, prompt: "Search by name or muscle")
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if sectionIds.count > 1 {
                    ExerciseSectionIndexStrip(proxy: proxy, ids: sectionIds)
                }
            }
            .onAppear {
                favoriteIds = ExercisePickerPersistence.loadFavorites()
                recentIds = ExercisePickerPersistence.loadRecent()
            }
        }
    }

    @ViewBuilder
    private func exerciseRows(_ list: [Exercise], showFavorite: Bool) -> some View {
        ForEach(list) { ex in
            Button {
                if let onExerciseChosen {
                    onExerciseChosen(ex)
                } else {
                    selection = ex
                    dismiss()
                }
            } label: {
                HStack {
                    Text(dataVM.resolvedDisplayName(for: ex))
                    Spacer()
                    if showFavorite {
                        Button {
                            toggleFavorite(ex.id)
                        } label: {
                            Image(systemName: favoriteIds.contains(ex.id) ? "heart.fill" : "heart")
                                .foregroundStyle(favoriteIds.contains(ex.id) ? .red : .secondary)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                    }
                    if selection?.id == ex.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    private func toggleFavorite(_ id: UUID) {
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
        } else {
            favoriteIds.insert(id)
        }
        ExercisePickerPersistence.saveFavorites(favoriteIds)
    }
}

// MARK: - Quick add to plan (one tap + toast)

private struct PlanQuickAddExerciseToast: Equatable {
    let workoutExerciseId: UUID
    let exerciseId: UUID
    let exerciseName: String
}

private struct PlanQuickAddExerciseSheet: View {
    let workoutId: UUID
    let currentVM: CurrentWorkoutSessionViewModel
    @Binding var presentation: AddExerciseSheetMode?
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseList: [Exercise] = []
    @State private var toast: PlanQuickAddExerciseToast?
    @State private var showCreateCustomExercise = false

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                ExercisePickerView(
                    exercises: exerciseList,
                    selection: .constant(nil),
                    onExerciseChosen: { ex in
                        addExerciseQuick(ex)
                    },
                    navigationTitleText: "Add exercise"
                )
                .environment(dataVM)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            presentation = nil
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                presentation = .fullAdd(prefillExerciseId: nil)
                            } label: {
                                Label("Custom add exercise…", systemImage: "slider.horizontal.3")
                            }
                            Button {
                                showCreateCustomExercise = true
                            } label: {
                                Label("New custom exercise", systemImage: "plus.square.on.square")
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showCreateCustomExercise) {
                    NewExerciseSheet(onCreated: { created in
                        exerciseList = dataVM.globalExercises
                        addExerciseQuick(created)
                    })
                    .environment(dataVM)
                    .environmentObject(aiService)
                }
            }
            if let t = toast {
                quickAddToastBar(t)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: toast != nil)
        .onAppear {
            exerciseList = dataVM.globalExercises
        }
    }

    private func syncLibraryIfNeeded() {
        guard let updated = dataVM.workout(id: workoutId) else { return }
        currentVM.syncExercises(withUpdatedWorkout: updated)
    }

    private func addExerciseQuick(_ ex: Exercise) {
        let def = ExercisePrescriptionMemory.rememberedSetsAndReps(for: ex.id) ?? (3, "8-12")
        let config = Array(repeating: [String: String](), count: def.sets)
        guard let lib = dataVM.workout(id: workoutId) else { return }
        if let we = dataVM.addExercise(
            to: lib,
            exercise: ex,
            recommendedSets: def.sets,
            recommendedReps: def.reps,
            configurationFields: [],
            recommendedConfigBySet: config
        ) {
            ExercisePickerPersistence.recordRecent(exerciseId: ex.id)
            syncLibraryIfNeeded()
            toast = PlanQuickAddExerciseToast(
                workoutExerciseId: we.id,
                exerciseId: ex.id,
                exerciseName: dataVM.resolvedDisplayName(for: ex)
            )
        }
    }

    private func quickAddToastBar(_ t: PlanQuickAddExerciseToast) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(t.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button("Undo") {
                undoToast(t)
            }
            .buttonStyle(.bordered)
            Button("Customize") {
                customizeFromToast(t)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }

    private func undoToast(_ t: PlanQuickAddExerciseToast) {
        guard let lib = dataVM.workout(id: workoutId) else { return }
        dataVM.deleteExercise(from: lib, exerciseId: t.workoutExerciseId)
        syncLibraryIfNeeded()
        toast = nil
    }

    private func customizeFromToast(_ t: PlanQuickAddExerciseToast) {
        guard let lib = dataVM.workout(id: workoutId) else { return }
        dataVM.deleteExercise(from: lib, exerciseId: t.workoutExerciseId)
        syncLibraryIfNeeded()
        toast = nil
        presentation = .fullAdd(prefillExerciseId: t.exerciseId)
    }
}

struct AddExerciseSheet: View {
    let workout: Workout
    /// Passed in so the sheet doesn't observe it; avoids timer-driven re-renders that reset scroll position.
    let currentVM: CurrentWorkoutSessionViewModel
    /// When non-nil, pre-selects this exercise (e.g. after “Customize” from quick add).
    var presetExerciseId: UUID? = nil
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedExercise: Exercise?
    @State private var recommendedSets = 3
    @State private var recommendedReps = "8-12"
    @State private var configFieldRows: [ConfigFieldRow] = []
    @State private var perSetConfig: [Int: [String: String]] = [:]
    @State private var autoPausedWorkout = false
    /// Snapshot so the list doesn't depend on dataVM and re-scroll when parent updates.
    @State private var exerciseList: [Exercise] = []
    @State private var showCreateCustomExercise = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Exercise") {
                    NavigationLink {
                        ExercisePickerView(exercises: exerciseList, selection: $selectedExercise)
                            .environment(dataVM)
                    } label: {
                        HStack {
                            Text("Exercise")
                            Spacer()
                            Text(selectedExercise.map { dataVM.resolvedDisplayName(for: $0) } ?? "Tap to choose")
                                .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                        }
                    }
                    Button {
                        showCreateCustomExercise = true
                    } label: {
                        Label("Create new custom exercise", systemImage: "plus.circle")
                    }
                }
                
                Section("Recommended") {
                    Stepper("Sets: \(recommendedSets)", value: $recommendedSets, in: 1...10)
                    TextField("Reps (e.g. 8-12)", text: $recommendedReps)
                }

                if selectedExercise != nil {
                    Section("Configuration fields (optional)") {
                        ForEach(configFieldRows.indices, id: \.self) { idx in
                            HStack {
                                TextField("Field name (e.g. Grip, Seat)", text: $configFieldRows[idx].name)
                                Button(role: .destructive) {
                                    configFieldRows.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                            }
                        }
                        Button {
                            configFieldRows.append(ConfigFieldRow())
                        } label: {
                            Label("Add field", systemImage: "plus.circle")
                        }
                    }

                    if !configFieldRows.isEmpty {
                        Section("Per-set recommended configuration") {
                            ForEach(0..<recommendedSets, id: \.self) { setIndex in
                                DisclosureGroup("Set \(setIndex + 1)") {
                                    ForEach(configFieldRows.indices, id: \.self) { idx in
                                        let fieldName = configFieldRows[idx].name.trimmingCharacters(in: .whitespaces)
                                        if !fieldName.isEmpty {
                                            TextField(fieldName, text: bindingForSetField(setIndex: setIndex, field: fieldName))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .onAppear {
                exerciseList = dataVM.globalExercises
                if let pid = presetExerciseId {
                    if selectedExercise == nil {
                        selectedExercise = dataVM.globalExercises.first(where: { $0.id == pid })
                    }
                    if let mem = ExercisePrescriptionMemory.rememberedSetsAndReps(for: pid) {
                        recommendedSets = mem.sets
                        recommendedReps = mem.reps
                    }
                }
                // Pause the workout while the sheet is open so timer-driven updates don't affect the parent.
                if currentVM.isInProgress,
                   currentVM.currentSession?.workout.id == workout.id,
                   !currentVM.isWorkoutPaused {
                    currentVM.pauseWorkout()
                    autoPausedWorkout = true
                }
            }
            .onDisappear {
                if autoPausedWorkout,
                   currentVM.isInProgress,
                   currentVM.currentSession?.workout.id == workout.id,
                   currentVM.isWorkoutPaused {
                    currentVM.resumeWorkout()
                }
                autoPausedWorkout = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if let ex = selectedExercise {
                            let fieldNames = configFieldRows
                                .map { $0.name.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            let recommendedConfigBySet: [[String: String]] = (0..<recommendedSets).map { idx in
                                let raw = perSetConfig[idx] ?? [:]
                                // Keep only known fields and non-empty values
                                var cleaned: [String: String] = [:]
                                for name in fieldNames {
                                    if let value = raw[name], !value.trimmingCharacters(in: .whitespaces).isEmpty {
                                        cleaned[name] = value.trimmingCharacters(in: .whitespaces)
                                    }
                                }
                                return cleaned
                            }

                            ExercisePickerPersistence.recordRecent(exerciseId: ex.id)
                            ExercisePrescriptionMemory.remember(
                                exerciseId: ex.id,
                                sets: recommendedSets,
                                reps: recommendedReps
                            )
                            if dataVM.userWorkouts.contains(where: { $0.id == workout.id }) {
                                if let _ = dataVM.addExercise(to: workout,
                                                              exercise: ex,
                                                              recommendedSets: recommendedSets,
                                                              recommendedReps: recommendedReps,
                                                              configurationFields: fieldNames,
                                                              recommendedConfigBySet: recommendedConfigBySet),
                                   let updatedWorkout = dataVM.userWorkouts.first(where: { $0.id == workout.id }) {
                                    currentVM.syncExercises(withUpdatedWorkout: updatedWorkout)
                                }
                            } else if currentVM.isInProgress,
                                      currentVM.currentSession?.workout.id == workout.id {
                                currentVM.appendExerciseToSession(
                                    exercise: ex,
                                    recommendedSets: recommendedSets,
                                    recommendedReps: recommendedReps,
                                    configurationFields: fieldNames,
                                    recommendedConfigBySet: recommendedConfigBySet
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(selectedExercise == nil)
                }
            }
            .keyboardDismissToolbar()
            .sheet(isPresented: $showCreateCustomExercise) {
                NewExerciseSheet(onCreated: { created in
                    exerciseList = dataVM.globalExercises
                    selectedExercise = created
                })
                .environment(dataVM)
                .environmentObject(aiService)
            }
        }
    }
}

// MARK: - Suggest exercises (AI or offline)

private struct AISuggestExercisesFillSheet: View {
    let workoutId: UUID
    let currentVM: CurrentWorkoutSessionViewModel
    @Environment(DataManager.self) var dataVM
    @Environment(EntitlementStore.self) private var entitlementStore
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var suggestions: [(exercise: Exercise, sets: Int, reps: String)] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Finding exercises…")
                } else if let err = errorMessage {
                    ContentUnavailableView(
                        "Couldn’t load suggestions",
                        systemImage: "exclamationmark.triangle",
                        description: Text(err)
                    )
                } else if suggestions.isEmpty {
                    ContentUnavailableView(
                        "No new suggestions",
                        systemImage: "checkmark.circle",
                        description: Text("Your workout may already cover typical movements, or try renaming it (e.g. “Push day”) for better offline matches.")
                    )
                } else {
                    List {
                        Section {
                            Text(
                                entitlementStore.hasAccess(to: .aiWorkoutSuggestions) && aiService.isConfigured
                                    ? "Pick exercises to append to your plan. Sets and reps are starting points."
                                    : "Based on your workout name and what’s already included. Tap to add."
                            )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(suggestions, id: \.exercise.id) { item in
                            Button {
                                addOne(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dataVM.resolvedDisplayName(for: item.exercise))
                                        .font(.headline)
                                    Text("\(item.sets) sets × \(item.reps)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Section {
                            Button("Add all") {
                                for item in suggestions {
                                    addOne(item)
                                }
                                dismiss()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Suggest exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await load()
            }
        }
    }

    private func addOne(_ item: (exercise: Exercise, sets: Int, reps: String)) {
        let sets = min(max(1, item.sets), 10)
        let reps = item.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        let repsFinal = reps.isEmpty ? "8-12" : reps
        guard let fresh = dataVM.workout(id: workoutId) else { return }
        _ = dataVM.addExercise(
            to: fresh,
            exercise: item.exercise,
            recommendedSets: sets,
            recommendedReps: repsFinal,
            configurationFields: [],
            recommendedConfigBySet: Array(repeating: [:], count: sets)
        )
        if let updated = dataVM.workout(id: workoutId) {
            currentVM.syncExercises(withUpdatedWorkout: updated)
        }
        suggestions.removeAll { $0.exercise.id == item.exercise.id }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        guard let w = dataVM.workout(id: workoutId) else {
            errorMessage = "Workout not found."
            return
        }
        if entitlementStore.hasAccess(to: .aiWorkoutSuggestions), aiService.isConfigured {
            do {
                let list = try await aiService.fetchExercisesToAddToWorkout(workout: w, globalExercises: dataVM.globalExercises)
                let existing = Set(w.exercises.compactMap { $0.exerciseId })
                suggestions = list.filter { !existing.contains($0.exercise.id) }
                if suggestions.isEmpty {
                    suggestions = WorkoutStarterResolution.heuristicExercisesToAdd(to: w, library: dataVM.globalExercises)
                }
            } catch {
                suggestions = WorkoutStarterResolution.heuristicExercisesToAdd(to: w, library: dataVM.globalExercises)
                if suggestions.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            suggestions = WorkoutStarterResolution.heuristicExercisesToAdd(to: w, library: dataVM.globalExercises)
        }
    }
}

private struct ConfigFieldRow: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
}

private extension AddExerciseSheet {
    func bindingForSetField(setIndex: Int, field: String) -> Binding<String> {
        Binding(
            get: {
                perSetConfig[setIndex]?[field] ?? ""
            },
            set: { newValue in
                var copy = perSetConfig[setIndex] ?? [:]
                copy[field] = newValue
               var all = perSetConfig
                all[setIndex] = copy
                perSetConfig = all
            }
        )
    }
}
