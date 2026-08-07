//
//  CurrentWorkoutPullUpSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import Foundation

/// Drives `LogSetView` presentation so the sheet always has a defined exercise index (avoids empty `sheet` content).
private struct LogSetSheetSelection: Identifiable {
    let id = UUID()
    let exerciseIndex: Int
    var prefillDisplayWeight: Double? = nil
    var prefillReps: Int? = nil
    /// When true, `LogSetView` opens in reps-first bodyweight layout (added / assisted optional).
    var prefillBodyweightMode: Bool = false
    /// Opens `LogSetView` with drop-set mode enabled and first drop row seeded.
    var prefillDropSetEnabled: Bool = false
}

private struct InlineDropDraft: Equatable {
    let exerciseIndex: Int
    let setIndex: Int
}

private struct ResolveSlotWE: Identifiable {
    let workoutExerciseId: UUID
    let templateSlotId: UUID?
    var isSwapExercise: Bool = false
    var id: UUID { workoutExerciseId }
}

private struct ResolveSlotExerciseSheet: View {
    let workoutExerciseId: UUID
    let templateSlotId: UUID?
    var isSwapExercise: Bool = false
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var swappedWorkoutExercise: WorkoutExercise? {
        currentVM.currentSession?.exerciseLogs.first { $0.workoutExercise.id == workoutExerciseId }?.workoutExercise
    }

    /// Full library exercise for the row being swapped, when still in the catalog.
    private var exerciseBeingSwapped: Exercise? {
        guard isSwapExercise, let snap = swappedWorkoutExercise?.snapshot else { return nil }
        return dataVM.resolveExercise(for: snap)
    }

    private var templateSlot: TemplateSlot? {
        guard let slotId = templateSlotId,
              let origin = currentVM.currentSession?.sessionPlanOrigin,
              case .workout(let libraryId) = origin,
              let lib = dataVM.workout(id: libraryId)
        else { return nil }
        return dataVM.flexibleSlots(from: lib).first(where: { $0.id == slotId })
    }

    private var slotMuscles: Set<MuscleGroup> {
        guard let slot = templateSlot else { return [] }
        return Set(slot.targetedMuscles)
    }

    private func matchesSearch(_ ex: Exercise) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return dataVM.resolvedDisplayName(for: ex).localizedCaseInsensitiveContains(q)
            || ex.name.localizedCaseInsensitiveContains(q)
    }

    private func matchesSlot(_ ex: Exercise) -> Bool {
        let muscles = slotMuscles
        guard !muscles.isEmpty else { return false }
        return ex.targetedMuscles.contains(where: { muscles.contains($0) })
    }

    private var suggestedExercises: [Exercise] {
        dataVM.globalExercises.filter { matchesSlot($0) && matchesSearch($0) }
    }

    private var otherExercises: [Exercise] {
        let muscles = slotMuscles
        if muscles.isEmpty {
            return dataVM.globalExercises.filter { matchesSearch($0) }
        }
        return dataVM.globalExercises.filter { !matchesSlot($0) && matchesSearch($0) }
    }

    /// Sorted strongest → weakest for template-session swap; excludes current exercise id.
    private var swapRankedExercises: [(exercise: Exercise, score: Int)] {
        let baseline = exerciseBeingSwapped
        let slot = templateSlot
        let excludeId = baseline?.id
        return dataVM.globalExercises
            .filter { matchesSearch($0) && $0.id != excludeId }
            .map { ex -> (Exercise, Int) in
                let score: Int
                if let b = baseline {
                    score = ExerciseSwapSimilarity.score(
                        candidate: ex,
                        baseline: b,
                        slotMuscleMatch: matchesSlot(ex)
                    )
                } else if let s = slot {
                    score = ExerciseSwapSimilarity.scoreFromSlotOnly(
                        candidate: ex,
                        slot: s,
                        slotMuscleMatch: matchesSlot(ex)
                    )
                } else {
                    score = matchesSlot(ex) ? 40 : 0
                }
                return (ex, score)
            }
            .sorted { $0.score > $1.score }
    }

    /// Groups consecutive same-tier rows (list stays strongest → weakest within each tier).
    private func swapGroupedSections() -> [(tier: String, items: [(Exercise, Int)])] {
        var out: [(String, [(Exercise, Int)])] = []
        for pair in swapRankedExercises {
            let tier = ExerciseSwapSimilarity.tierLabel(score: pair.score)
            if !out.isEmpty, out[out.count - 1].0 == tier {
                var last = out.removeLast()
                last.1.append((pair.exercise, pair.score))
                out.append(last)
            } else {
                out.append((tier, [(pair.exercise, pair.score)]))
            }
        }
        return out.map { (tier: $0.0, items: $0.1) }
    }

    var body: some View {
        List {
            if isSwapExercise {
                swapContextSection

                if exerciseBeingSwapped != nil || templateSlot != nil {
                    let groups = swapGroupedSections()
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        Section {
                            ForEach(group.items, id: \.0.id) { item in
                                swapSuggestionButton(item.0)
                            }
                        } header: {
                            Text(group.tier)
                        }
                    }
                } else {
                    Section {
                        ForEach(swapRankedExercises, id: \.exercise.id) { item in
                            swapSuggestionButton(item.exercise)
                        }
                    } header: {
                        Text("Exercises")
                    }
                }
            } else {
                let suggested = suggestedExercises
                if !suggested.isEmpty {
                    Section {
                        ForEach(suggested) { ex in
                            exerciseButton(ex)
                        }
                    } header: {
                        Text("Suggested")
                    }
                }

                Section {
                    ForEach(otherExercises) { ex in
                        exerciseButton(ex)
                    }
                } header: {
                    if !suggested.isEmpty {
                        Text("All exercises")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle(isSwapExercise ? "Swap exercise" : "Choose exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var swapContextSection: some View {
        if let ex = exerciseBeingSwapped {
            Section {
                LabeledContent("Name") {
                    Text(dataVM.resolvedDisplayName(for: ex))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Movement pattern") {
                    Text(ex.movementPattern.map(\.rawValue) ?? "Not set")
                }
                LabeledContent("Role") {
                    Text(ex.exerciseRole.rawValue)
                }
                LabeledContent("Target muscles") {
                    Text(ex.targetedMuscles.isEmpty ? "—" : ex.targetedMuscles.map(\.rawValue).joined(separator: ", "))
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Exercise you’re swapping out")
            } footer: {
                if templateSlot == nil {
                    Text("Suggestions below are ordered by movement pattern, role, and shared target muscles (strongest match first).")
                        .font(.caption)
                }
            }
        } else if let we = swappedWorkoutExercise, we.snapshot != nil {
            Section {
                LabeledContent("Name") {
                    Text(dataVM.displayName(for: we))
                        .multilineTextAlignment(.trailing)
                }
                Text("This exercise isn’t in your library anymore. Rankings use your template slot criteria.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Exercise you’re swapping out")
            }
        }

        if let slot = templateSlot {
            Section {
                LabeledContent("Slot label") {
                    Text(slot.label.isEmpty ? "—" : slot.label)
                }
                if !slot.targetedMuscles.isEmpty {
                    LabeledContent("Target muscles") {
                        Text(slot.targetedMuscles.map(\.rawValue).joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
                if let sr = slot.exerciseRole {
                    LabeledContent("Role") {
                        Text(sr.rawValue)
                    }
                }
                if let sp = slot.movementPattern {
                    LabeledContent("Movement pattern") {
                        Text(sp.rawValue)
                    }
                }
            } header: {
                Text("Template slot criteria")
            } footer: {
                if exerciseBeingSwapped != nil {
                    Text("Each suggestion is scored like the exercise you’re replacing, then gets a boost when it also fits this slot’s muscles.")
                        .font(.caption)
                } else {
                    Text("Suggestions are ordered to match this slot (pattern, role, muscles), strongest first.")
                        .font(.caption)
                }
            }
        }
    }

    private func exerciseButton(_ ex: Exercise) -> some View {
        Button {
            currentVM.resolveSlotPlaceholder(workoutExerciseId: workoutExerciseId, exercise: ex)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(dataVM.resolvedDisplayName(for: ex))
                if !ex.targetedMuscles.isEmpty {
                    Text(ex.targetedMuscles.map(\.rawValue).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func swapSuggestionButton(_ ex: Exercise) -> some View {
        Button {
            currentVM.resolveSlotPlaceholder(workoutExerciseId: workoutExerciseId, exercise: ex)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(dataVM.resolvedDisplayName(for: ex))
                    .font(.body.weight(.medium))
                Text(ExerciseSwapSimilarity.matchSummary(
                    candidate: ex,
                    baseline: exerciseBeingSwapped,
                    slot: templateSlot,
                    slotMuscleMatch: matchesSlot(ex)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                if !ex.targetedMuscles.isEmpty {
                    Text(ex.targetedMuscles.map(\.rawValue).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private enum PullUpNumericFieldFocus: Hashable {
    case inlineWeight(UUID)
    case inlineAdded(UUID)
    case inlineAssisted(UUID)
    case inlineReps(UUID)
    case editWeight
    case editReps
}

private struct PlateCalculatorInlinePick: Identifiable {
    let logId: UUID
    var id: UUID { logId }
}

private struct SwapSheetIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

struct CurrentWorkoutPullUpSheet: View {
    @Binding private var sheetDetent: PresentationDetent

    init(sheetDetent: Binding<PresentationDetent> = .constant(FitlogWorkoutSheetDetent.defaultOpen)) {
        _sheetDetent = sheetDetent
    }

    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(ExerciseFormGuideService.self) private var formGuideService
    @Environment(\.dismiss) var dismiss
    @Environment(\.undoManager) private var undoManager

    @FocusState private var numericFieldFocus: PullUpNumericFieldFocus?
    
    @State private var expandedExerciseIndex: Int? = nil
    @State private var logSetSheetSelection: LogSetSheetSelection?
    @State private var resolveSlotSelection: ResolveSlotWE?
    @State private var showFinishConfirmation = false
    @State private var showFinishEmptyConfirm = false
    @State private var showCardioFinisherOffer = false
    @State private var cardioFinisherOffered = false
    @State private var exerciseLogCountBeforeFinisherQuickAdd: Int?
    @State private var showCardioResolveFailureAlert = false
    @State private var showDiscardWorkoutConfirmation = false
    @State private var showQuickAddExercise = false
    @State private var showFullAddExercise = false
    @State private var showExerciseReorderSheet = false
    @State private var plateCalculatorInlinePick: PlateCalculatorInlinePick?

    /// Inline quick-log draft per exercise log (stable across reorder).
    @State private var draftStore = SetEntryDraftStore()

    /// Inline edit for an existing set (array indices; stable until list mutates).
    @State private var editingSetExerciseIndex: Int?
    @State private var editingSetIndex: Int?
    @State private var editingSetId: UUID?
    @State private var editWeightDisplay: Double = 0
    @State private var editReps: Int = 0
    @State private var editSetType: ExerciseSetType = .working

    /// Shown briefly after auto-advance when rest completes.
    @State private var restCompleteBannerMessage: String?

    /// Brief highlight on the most recently logged set (chronological list).
    @State private var highlightedLoggedSetId: UUID?
    /// Collapsed by default so the expanded exercise shows a simple “log next set → sets” flow first.
    @State private var exerciseDetailMoreExpandedLogId: UUID?
    /// After a set is logged, show a transient "Add drop set" affordance for ~5 seconds.
    @State private var dropPromptLogId: UUID?
    @State private var dropPromptExerciseIndex: Int?
    /// Quick exercise swap sheet (long-press on exercise card header).
    @State private var swapSheetExerciseIndex: Int?
    /// PR celebration overlay (replaces the simple in-list banner).
    @State private var celebratedPREvent: PersonalRecordEvent?
    /// Swipe-delete undo (brief window).
    @State private var pendingUndoSet: PendingUndoSet?
    @State private var inlineLogSuccessTick = 0
    @State private var exerciseSwipeTick = 0
    @State private var formGuideExercise: Exercise?
    @State private var sessionChromeExpanded = false
    @State private var inlineDropDraft: InlineDropDraft?
    @State private var inlineDropWeightDisplay: Double = 0
    @State private var inlineDropReps: Int = 8

    private struct PendingUndoSet: Identifiable {
        let id: UUID
        let exerciseIndex: Int
        let insertAt: Int
        let set: LoggedSet

        init(exerciseIndex: Int, insertAt: Int, set: LoggedSet) {
            self.id = UUID()
            self.exerciseIndex = exerciseIndex
            self.insertAt = insertAt
            self.set = set
        }
    }

    private var showsWorkoutList: Bool {
        sheetDetent == FitlogWorkoutSheetDetent.expanded || sheetDetent == FitlogWorkoutSheetDetent.medium
    }

    private var activeSessionWorkout: Workout? {
        currentVM.currentSession?.workout
    }

    private var isFlexibleLibrarySession: Bool {
        guard let origin = currentVM.currentSession?.sessionPlanOrigin,
              case .workout(let libraryId) = origin,
              let lib = dataVM.workout(id: libraryId) else { return false }
        return lib.hasFlexibleSlots
    }

    private func effectiveFocusedExerciseIndex(in logs: [ExerciseLog]) -> Int {
        if let idx = expandedExerciseIndex, logs.indices.contains(idx) { return idx }
        return primaryExerciseLogIndex ?? 0
    }

    private func nextFocusIndex(after index: Int, logs: [ExerciseLog]) -> Int? {
        guard let session = currentVM.currentSession else { return nil }
        if isSupersetLoggingContext(exerciseIndex: index),
           session.activeExerciseIds.count > 1,
           let exId = logs[index].workoutExercise.exerciseId,
           let posInActive = session.activeExerciseIds.firstIndex(of: exId),
           posInActive < session.activeExerciseIds.count - 1 {
            let nextId = session.activeExerciseIds[posInActive + 1]
            if let nextIdx = logs.firstIndex(where: { $0.workoutExercise.exerciseId == nextId }) {
                return nextIdx
            }
        }
        let next = index + 1
        return logs.indices.contains(next) ? next : nil
    }

    private func previousFocusIndex(before index: Int, logs: [ExerciseLog]) -> Int? {
        guard let session = currentVM.currentSession else { return nil }
        if isSupersetLoggingContext(exerciseIndex: index),
           session.activeExerciseIds.count > 1,
           let exId = logs[index].workoutExercise.exerciseId,
           let posInActive = session.activeExerciseIds.firstIndex(of: exId),
           posInActive > 0 {
            let prevId = session.activeExerciseIds[posInActive - 1]
            if let prevIdx = logs.firstIndex(where: { $0.workoutExercise.exerciseId == prevId }) {
                return prevIdx
            }
        }
        let prev = index - 1
        return prev >= 0 ? prev : nil
    }

    private func advanceFocusedExercise(by delta: Int) {
        guard let logs = currentVM.currentSession?.exerciseLogs, !logs.isEmpty else { return }
        let cur = effectiveFocusedExerciseIndex(in: logs)
        let target: Int?
        if delta > 0 {
            target = nextFocusIndex(after: cur, logs: logs)
        } else {
            target = previousFocusIndex(before: cur, logs: logs)
        }
        guard let target else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            expandedExerciseIndex = target
        }
        exerciseSwipeTick += 1
    }

    private func supersetRoundIndices(in logs: [ExerciseLog]) -> [Int] {
        guard let session = currentVM.currentSession,
              session.activeExerciseIds.count > 1
        else { return [] }
        return session.activeExerciseIds.compactMap { activeId in
            logs.firstIndex(where: { $0.workoutExercise.exerciseId == activeId })
        }
    }

    @ViewBuilder
    private func supersetRoundSwitcher(exerciseIndex: Int, logs: [ExerciseLog]) -> some View {
        let indices = supersetRoundIndices(in: logs)
        if indices.count > 1, indices.contains(exerciseIndex) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(indices, id: \.self) { idx in
                        let log = logs[idx]
                        let letter = supersetLetter(for: log) ?? "?"
                        let isCurrent = idx == exerciseIndex
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedExerciseIndex = idx
                            }
                            if let exId = log.workoutExercise.exerciseId {
                                currentVM.setPrimaryExercise(exerciseId: exId)
                            }
                        } label: {
                            Text(letter)
                                .font(.subheadline.weight(.bold))
                                .frame(minWidth: 36, minHeight: 36)
                                .background(isCurrent ? Color.accentColor : Color.blue.opacity(0.15))
                                .foregroundStyle(isCurrent ? Color.white : Color.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Superset exercise \(letter)")
                        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 4)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Superset round switcher")
        }
    }

    @ViewBuilder
    private func largeSheetWorkoutList(scrollProxy: ScrollViewProxy) -> some View {
                    List {
                        if currentVM.remainingRestTime <= 0 {
                            if sessionLoggedSetCount == 0 {
                                Section {
                                    expandedListFirstSetBanner
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } else if let primaryIndex = primaryExerciseLogIndex,
                                      let logs = currentVM.currentSession?.exerciseLogs,
                                      logs.indices.contains(primaryIndex) {
                                Section {
                                    expandedListNextExerciseBanner(
                                        log: logs[primaryIndex],
                                        exerciseIndex: primaryIndex,
                                        scrollProxy: scrollProxy
                                    )
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }

                        if let exerciseLogs = currentVM.currentSession?.exerciseLogs, !exerciseLogs.isEmpty {
                            let focusIndex = effectiveFocusedExerciseIndex(in: exerciseLogs)
                            let log = exerciseLogs[focusIndex]

                            Section {
                                        if log.workoutExercise.isSlotPlaceholder {
                                            Button {
                                                resolveSlotSelection = ResolveSlotWE(workoutExerciseId: log.workoutExercise.id, templateSlotId: log.workoutExercise.templateSlotId)
                                            } label: {
                                                HStack {
                                                    Image(systemName: "square.dashed")
                                                        .font(.title3)
                                                        .foregroundStyle(.orange)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(log.workoutExercise.slotLabel.isEmpty ? "Choose exercise" : log.workoutExercise.slotLabel)
                                                            .font(.headline)
                                                        Text("Tap to pick an exercise")
                                                            .font(.caption)
                                                            .foregroundStyle(.orange)
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .foregroundStyle(.orange)
                                                }
                                                .padding(.vertical, 4)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .listRowBackground(Color.orange.opacity(0.08))
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button("Remove", role: .destructive) {
                                                    removeExerciseAtListIndex(focusIndex, rowId: log.workoutExercise.id)
                                                }
                                            }
                                        } else {
                                            exerciseCollapsedHeader(log: log, isExpanded: true)
                                                .overlay(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(FitlogPalette.success)
                                                        .frame(width: 4)
                                                        .padding(.vertical, 4)
                                                        .offset(x: -12)
                                                }
                                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                                .listRowBackground(FitlogPalette.success.opacity(0.04))

                                            if isSupersetLoggingContext(exerciseIndex: focusIndex) {
                                                Text(supersetInlineHint(exerciseIndex: focusIndex))
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(.secondary)
                                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                                                    .listRowBackground(FitlogPalette.success.opacity(0.04))

                                                supersetRoundSwitcher(exerciseIndex: focusIndex, logs: exerciseLogs)
                                                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 6, trailing: 16))
                                                    .listRowBackground(FitlogPalette.success.opacity(0.04))
                                            }
                                            if let libraryExercise = libraryExercise(for: log),
                                               libraryExercise.modality != .cardio {
                                                ExerciseFormGuideCompactView(
                                                    exercise: libraryExercise
                                                ) {
                                                    formGuideExercise = libraryExercise
                                                }
                                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                                .listRowSeparator(.hidden)
                                                .listRowBackground(FitlogPalette.success.opacity(0.04))
                                            }

                                            planAndCompletionRow(log: log)
                                                .moveDisabled(true)
                                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                                .listRowBackground(FitlogPalette.success.opacity(0.04))

                                            inlineSetEntryRow(exerciseIndex: focusIndex, log: log)
                                                .moveDisabled(true)
                                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                                .listRowBackground(FitlogPalette.success.opacity(0.04))
                                                .simultaneousGesture(
                                                    DragGesture(minimumDistance: 50)
                                                        .onEnded { value in
                                                            guard showsWorkoutList else { return }
                                                            let t = value.translation
                                                            guard abs(t.width) > abs(t.height) else { return }
                                                            if t.width < -55 {
                                                                advanceFocusedExercise(by: 1)
                                                            } else if t.width > 55 {
                                                                advanceFocusedExercise(by: -1)
                                                            }
                                                        }
                                                )

                                            if CardioWorkoutExerciseHelpers.isCardioLoggingRow(
                                                log.workoutExercise,
                                                exercises: dataVM.globalExercises
                                            ) {
                                                cardioLoggedSetsSection(exerciseIndex: focusIndex, log: log)
                                                    .moveDisabled(true)
                                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                                                    .listRowBackground(FitlogPalette.success.opacity(0.04))
                                            } else {
                                                currentAndPreviousSetsSection(
                                                    exerciseIndex: focusIndex,
                                                    log: log,
                                                    previousLog: lastCompletedLog(for: log)
                                                )
                                                .moveDisabled(true)
                                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                                                .listRowBackground(FitlogPalette.success.opacity(0.04))
                                            }

                                            DisclosureGroup(isExpanded: Binding(
                                                get: { exerciseDetailMoreExpandedLogId == log.id },
                                                set: { exerciseDetailMoreExpandedLogId = $0 ? log.id : nil }
                                            )) {
                                                VStack(alignment: .leading, spacing: 12) {
                                                    if !log.workoutExercise.configurationFields.isEmpty {
                                                        recommendedConfigurationRow(for: log.workoutExercise, includeListRowInsets: false)
                                                    }

                                                    HStack(alignment: .top, spacing: 8) {
                                                        TextField("Notes for this exercise", text: Binding(
                                                            get: {
                                                                guard let logs = currentVM.currentSession?.exerciseLogs,
                                                                      logs.indices.contains(focusIndex)
                                                                else { return "" }
                                                                return logs[focusIndex].notes
                                                            },
                                                            set: { newText in
                                                                guard let logs = currentVM.currentSession?.exerciseLogs,
                                                                      logs.indices.contains(focusIndex)
                                                                else { return }
                                                                currentVM.setExerciseLogNotes(at: focusIndex, notes: newText)
                                                            }
                                                        ), axis: .vertical)
                                                        .lineLimit(2...4)
                                                        .textFieldStyle(.roundedBorder)
                                                        .font(.subheadline)
                                                        .textInputAutocapitalization(.sentences)
                                                    }
                                                    Text("Use the microphone key on the keyboard to dictate notes.")
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)

                                                    sessionRestOverrideEditor(exerciseIndex: focusIndex, log: log)

                                                    HStack(spacing: 12) {
                                                        Button("Repeat last") {
                                                            currentVM.repeatLastSet(exerciseIndex: focusIndex)
                                                            syncInlineDraftAfterLog(for: log.id, exerciseIndex: focusIndex)
                                                            triggerHighlightForLastSet(exerciseIndex: focusIndex)
                                                        }
                                                        .buttonStyle(.bordered)
                                                        .disabled(log.loggedSets.isEmpty)

                                                        Menu {
                                                            if let exId = log.workoutExercise.exerciseId {
                                                                if let slotId = currentVM.currentSession?.workout.templateSlotId(forWorkoutExerciseRow: log.workoutExercise.id) {
                                                                    Button("Swap exercise") {
                                                                        resolveSlotSelection = ResolveSlotWE(
                                                                            workoutExerciseId: log.workoutExercise.id,
                                                                            templateSlotId: slotId,
                                                                            isSwapExercise: true
                                                                        )
                                                                    }
                                                                }
                                                                Button("Quick swap exercise", systemImage: "arrow.left.arrow.right") {
                                                                        swapSheetExerciseIndex = focusIndex
                                                                    }
                                                                    Divider()
                                                                    Button("Set as current") {
                                                                        currentVM.setPrimaryExercise(exerciseId: exId)
                                                                    }
                                                                    Button(statusSupersetToggleTitle(for: log)) {
                                                                        currentVM.toggleSupersetExercise(exerciseId: exId)
                                                                    }
                                                                Button("Mark completed") {
                                                                    currentVM.markExerciseCompleted(exerciseId: exId)
                                                                }
                                                            }
                                                            Button("Remove from workout", role: .destructive) {
                                                                removeExerciseAtListIndex(focusIndex, rowId: log.workoutExercise.id)
                                                            }
                                                        } label: {
                                                            Label("More", systemImage: "ellipsis.circle")
                                                        }
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .padding(.vertical, 4)
                                            } label: {
                                                Label("Config, notes, and actions", systemImage: "text.alignleft")
                                                    .font(.subheadline.weight(.medium))
                                            }
                                            .moveDisabled(true)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                                            .listRowBackground(FitlogPalette.success.opacity(0.04))
                                        }
                                }
                                .id(log.id)

                            if !log.workoutExercise.isSlotPlaceholder {
                                Section {
                                    WorkoutFocusedExerciseNavBar(
                                        exerciseTitle: dataVM.displayName(for: log.workoutExercise),
                                        positionLabel: "Exercise \(focusIndex + 1) of \(exerciseLogs.count)",
                                        canGoPrevious: previousFocusIndex(before: focusIndex, logs: exerciseLogs) != nil,
                                        canGoNext: nextFocusIndex(after: focusIndex, logs: exerciseLogs) != nil,
                                        onPrevious: { advanceFocusedExercise(by: -1) },
                                        onNext: { advanceFocusedExercise(by: 1) }
                                    )
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                            }
                        } else {
                            Section {
                                Text("No exercises in current session")
                                    .foregroundStyle(.secondary)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }

                        Section {
                            Color.clear
                                .frame(height: pendingUndoSet == nil ? 24 : 72)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .accessibilityHidden(true)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                    .keyboardDismissToolbar()
                    .onChange(of: expandedExerciseIndex) { _, newValue in
                        if newValue != nil, sheetDetent != FitlogWorkoutSheetDetent.expanded {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                sheetDetent = FitlogWorkoutSheetDetent.expanded
                            }
                        }
                        exerciseDetailMoreExpandedLogId = nil
                        initializeInlineDraftIfNeeded(forExpandedIndex: newValue)
                        guard let idx = newValue,
                              let logs = currentVM.currentSession?.exerciseLogs,
                              idx < logs.count else { return }
                        if let currentExercise = libraryExercise(for: logs[idx]) {
                            formGuideService.preloadGuide(for: currentExercise)
                            if idx + 1 < logs.count, let nextExercise = libraryExercise(for: logs[idx + 1]) {
                                formGuideService.preloadGuide(for: nextExercise)
                            }
                        }
                        let targetId = logs[idx].id
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scrollProxy.scrollTo(targetId, anchor: .center)
                            }
                        }
                    }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Rest timer — compact strip
                if currentVM.remainingRestTime > 0 {
                    WorkoutRestTimerBar(
                        remainingSeconds: currentVM.remainingRestTime,
                        totalSeconds: max(currentVM.restCountdownTotalSeconds, currentVM.remainingRestTime),
                        onAdjust: { currentVM.adjustRestCountdown(by: $0) },
                        onSkip: { currentVM.cancelRestTimer() }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                if let session = currentVM.currentSession {
                    WorkoutSessionCompactChrome(
                        workoutName: session.workout.name,
                        elapsedFormatted: currentVM.workoutElapsedFormatted,
                        isPaused: currentVM.isWorkoutPaused,
                        setsLogged: sessionLoggedSetCount,
                        volumeSummary: sessionVolumeSummary(session: session),
                        detailsExpanded: $sessionChromeExpanded,
                        sessionNotes: Binding(
                            get: { currentVM.currentSession?.sessionNotes ?? "" },
                            set: { currentVM.setSessionNotes($0) }
                        ),
                        onPauseResume: {
                            if currentVM.isWorkoutPaused {
                                currentVM.resumeWorkout()
                            } else {
                                currentVM.pauseWorkout()
                            }
                        }
                    )
                    .padding(.top, currentVM.remainingRestTime > 0 ? 0 : 4)
                }

                unresolvedSlotsBanner
                restCompleteNextUpBanner

                if let logs = currentVM.currentSession?.exerciseLogs, !logs.isEmpty {
                    WorkoutExercisePillStrip(
                        logs: logs,
                        expandedExerciseIndex: $expandedExerciseIndex,
                        activeExerciseIdsCount: currentVM.currentSession?.activeExerciseIds.count ?? 0,
                        displayName: { dataVM.displayName(for: $0) },
                        isExerciseCompleted: { isExerciseCompleted($0) },
                        isExerciseActive: { isExerciseActive($0) },
                        supersetLetter: { supersetLetter(for: $0) },
                        onSelectExercise: { _ in
                            if sheetDetent != FitlogWorkoutSheetDetent.expanded {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    sheetDetent = FitlogWorkoutSheetDetent.expanded
                                }
                            }
                        },
                        onAddExercise: { showQuickAddExercise = true },
                        onQuickSwap: { swapSheetExerciseIndex = $0 },
                        onToggleSuperset: { idx in
                            guard logs.indices.contains(idx),
                                  let exId = logs[idx].workoutExercise.exerciseId else { return }
                            currentVM.toggleSupersetExercise(exerciseId: exId)
                        },
                        onMarkCompleted: { idx in
                            guard logs.indices.contains(idx),
                                  let exId = logs[idx].workoutExercise.exerciseId else { return }
                            currentVM.markExerciseCompleted(exerciseId: exId)
                        },
                        onRemoveExercise: { idx in
                            guard logs.indices.contains(idx) else { return }
                            removeExerciseAtListIndex(idx, rowId: logs[idx].workoutExercise.id)
                        }
                    )
                }

                ScrollViewReader { scrollProxy in
                    if showsWorkoutList {
                        largeSheetWorkoutList(scrollProxy: scrollProxy)
                            .transition(.opacity)
                    } else {
                        compactWorkoutPeekPlaceholder
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: showsWorkoutList)
            }
            .navigationTitle("Current Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard") {
                        showDiscardWorkoutConfirmation = true
                    }
                    .foregroundStyle(.red)
                    .accessibilityLabel("Discard workout")
                    .accessibilityHint("Ends the workout without saving it to history")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExerciseReorderSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Reorder exercises")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        handleFinishTap()
                    }
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $logSetSheetSelection) { selection in
                LogSetView(
                    sessionVM: currentVM,
                    exerciseIndex: selection.exerciseIndex,
                    prefillDisplayWeight: selection.prefillDisplayWeight,
                    prefillReps: selection.prefillReps,
                    prefillBodyweightMode: selection.prefillBodyweightMode,
                    prefillDropSetEnabled: selection.prefillDropSetEnabled
                )
                .environment(dataVM)
                .environmentObject(userPreferences)
            }
            .sheet(item: $resolveSlotSelection) { sel in
                NavigationStack {
                    ResolveSlotExerciseSheet(
                        workoutExerciseId: sel.workoutExerciseId,
                        templateSlotId: sel.templateSlotId,
                        isSwapExercise: sel.isSwapExercise
                    )
                    .environment(dataVM)
                    .environment(currentVM)
                }
            }
            .overlay(alignment: .bottom) {
                ZStack {
                    if let event = celebratedPREvent {
                        PRCelebrationOverlay(
                            event: event,
                            unit: userPreferences.weightDisplayUnit,
                            onDismiss: { celebratedPREvent = nil }
                        )
                    }
                    if let undo = pendingUndoSet {
                        undoDeletionSnackBar(undo: undo)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .sheet(item: Binding(
                get: { swapSheetExerciseIndex.map { idx in SwapSheetIndex(index: idx) } },
                set: { swapSheetExerciseIndex = $0?.index }
            )) { sel in
                if let logs = currentVM.currentSession?.exerciseLogs,
                   sel.index < logs.count {
                    let log = logs[sel.index]
                    InlineSwapSheet(
                        exerciseLog: log,
                        allExercises: dataVM.globalExercises,
                        displayNames: dataVM.exerciseLocalDisplayNames,
                        baselineExercise: libraryExercise(for: log)
                    ) { newExercise in
                        currentVM.swapExercise(atIndex: sel.index, to: newExercise)
                    }
                }
            }
            .sheet(isPresented: $showQuickAddExercise) {
                if let w = activeSessionWorkout {
                    SessionQuickAddExerciseSheet(
                        workout: w,
                        currentVM: currentVM,
                        dataVM: dataVM,
                        isFlexibleLibrarySession: isFlexibleLibrarySession,
                        onRequestCustomSetsAndFields: {
                            showFullAddExercise = true
                        },
                        onAddTemplateSlot: {
                            currentVM.appendSlotToFlexibleLibrarySession()
                        }
                    )
                    .environmentObject(aiService)
                }
            }
            .onChange(of: showQuickAddExercise) { _, isPresented in
                guard !isPresented, let before = exerciseLogCountBeforeFinisherQuickAdd else { return }
                exerciseLogCountBeforeFinisherQuickAdd = nil
                let after = currentVM.currentSession?.exerciseLogs.count ?? 0
                if after > before {
                    cardioFinisherOffered = true
                }
            }
            .sheet(isPresented: $showFullAddExercise) {
                if let w = activeSessionWorkout {
                    AddExerciseSheet(workout: w, currentVM: currentVM)
                        .environment(dataVM)
                        .environmentObject(aiService)
                }
            }
            .sheet(isPresented: $showExerciseReorderSheet) {
                ExerciseReorderSheet()
                    .environment(currentVM)
                    .environment(dataVM)
            }
            .sheet(item: $plateCalculatorInlinePick) { pick in
                let suggest = {
                    let w = inlineNetDisplayWeight(for: pick.logId)
                    return w > 0 ? w : nil
                }()
                PlateCalculatorSheet(
                    displayUnit: userPreferences.weightDisplayUnit,
                    suggestedTargetDisplay: suggest,
                    onApplyDisplayWeight: { w in
                        let unit = userPreferences.weightDisplayUnit
                        let clamped = WeightStoreConversion.clampNonNegativeDisplay(w, unit: unit)
                        if draftStore.bodyweightModeLogIds.contains(pick.logId) {
                            draftStore.bodyweightAddedByLogId[pick.logId] = clamped
                            draftStore.bodyweightAssistedByLogId[pick.logId] = 0
                            draftStore.bodyweightAddedTextByLogId[pick.logId] = formattedInlineWeight(clamped)
                            draftStore.bodyweightAssistedTextByLogId[pick.logId] = ""
                        } else {
                            draftStore.weightByLogId[pick.logId] = clamped
                            draftStore.weightTextByLogId[pick.logId] = formattedInlineWeight(clamped)
                        }
                    }
                )
            }
            .sheet(item: $formGuideExercise) { exercise in
                ExerciseFormGuideSheet(exercise: exercise)
                    .environment(formGuideService)
                    .environmentObject(aiService)
                    .environmentObject(userPreferences)
            }
            .modifier(
                PullUpFinishGuardAlerts(
                    showFinishConfirmation: $showFinishConfirmation,
                    showFinishEmptyConfirm: $showFinishEmptyConfirm,
                    unresolvedExerciseNames: resolvedExercisesWithNoSets,
                    onProceedAfterUnresolved: proceedFinishAfterUnresolvedCheck,
                    onProceedAfterEmpty: proceedFinishAfterEmptyCheck
                )
            )
            .confirmationDialog(
                "Add a cardio finisher?",
                isPresented: $showCardioFinisherOffer,
                titleVisibility: .visible
            ) {
                Button("Quick 10 min") {
                    if let template = CardioQuickAddTemplate.all.first,
                       let exercise = template.resolveExercise(in: dataVM.globalExercises),
                       currentVM.appendCardioExerciseToSession(exercise: exercise, prescription: template.prescription) {
                        cardioFinisherOffered = true
                    } else {
                        showCardioResolveFailureAlert = true
                    }
                }
                .accessibilityLabel("Quick 10 minute cardio finisher")
                .accessibilityHint("Adds a 10 minute zone 2 cardio exercise to this workout.")
                Button("Choose exercise…") {
                    exerciseLogCountBeforeFinisherQuickAdd = currentVM.currentSession?.exerciseLogs.count
                    showQuickAddExercise = true
                }
                .accessibilityLabel("Choose cardio exercise")
                .accessibilityHint("Opens the exercise picker to add a cardio finisher.")
                Button("Skip", role: .cancel) {
                    cardioFinisherOffered = true
                    finishWorkout()
                }
                .accessibilityLabel("Skip cardio finisher")
                .accessibilityHint("Finishes the workout without adding cardio.")
            } message: {
                Text("Optional cardio after your main work. You can log it now or skip and finish.")
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
                "Discard workout?",
                isPresented: $showDiscardWorkoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard without saving", role: .destructive) {
                    currentVM.cancelWorkout()
                    dismiss()
                }
                Button("Keep working out", role: .cancel) {}
            } message: {
                Text("Nothing will be added to your history.")
            }
            .onChange(of: currentVM.recentPersonalRecordEvent) { _, newValue in
                guard let event = newValue else { return }
                celebratedPREvent = event
            }
            .onAppear {
                if resolveSlotSelection == nil,
                   let first = currentVM.currentSession?.exerciseLogs.first(where: { $0.workoutExercise.isSlotPlaceholder }) {
                    resolveSlotSelection = ResolveSlotWE(workoutExerciseId: first.workoutExercise.id, templateSlotId: first.workoutExercise.templateSlotId)
                } else if consumePendingPullUpFocusIfNeeded() {
                    // Focus (and optionally log set) from deep link, e.g. workout plan row tap.
                } else {
                    applyAutoExpandForPrimaryExercise()
                }
                initializeInlineDraftIfNeeded(forExpandedIndex: expandedExerciseIndex)
                if currentVM.showRestCompleteAlert {
                    handleRestCompleteAutoAdvance()
                }
            }
            .onChange(of: currentVM.showRestCompleteAlert) { _, isShowing in
                guard isShowing else { return }
                handleRestCompleteAutoAdvance()
            }
            .onChange(of: sheetDetent) { _, newDetent in
                if newDetent == FitlogWorkoutSheetDetent.expanded {
                    if expandedExerciseIndex == nil {
                        applyAutoExpandForPrimaryExercise()
                    }
                    if expandedExerciseIndex == nil,
                       let logs = currentVM.currentSession?.exerciseLogs,
                       !logs.isEmpty {
                        expandedExerciseIndex = effectiveFocusedExerciseIndex(in: logs)
                    }
                    initializeInlineDraftIfNeeded(forExpandedIndex: expandedExerciseIndex)
                }
            }
            .sensoryFeedback(.success, trigger: inlineLogSuccessTick)
            .sensoryFeedback(.selection, trigger: exerciseSwipeTick)
        }
    }

    @ViewBuilder
    private var compactWorkoutPeekPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("Swipe up for full log")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Rest timer and exercise pills stay visible. Expand the sheet to log sets.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Compact workout view. Swipe the sheet up to expand and log sets.")
    }

    private func undoDeletionSnackBar(undo: PendingUndoSet) -> some View {
        HStack(spacing: 14) {
            Text("Set removed")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Undo") {
                currentVM.insertLoggedSet(undo.set, exerciseIndex: undo.exerciseIndex, at: undo.insertAt)
                pendingUndoSet = nil
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Undo delete set")
            .accessibilityHint("Restores the set you removed")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func advanceExpandedExercise(by delta: Int) {
        advanceFocusedExercise(by: delta)
    }

    private var resolvedExercisesWithNoSets: [String] {
        currentVM.resolvedExercisesWithNoSets()
    }

    private func handleFinishTap() {
        switch currentVM.nextFinishStep(cardioFinisherAlreadyOffered: cardioFinisherOffered) {
        case .confirmEmptyWorkout:
            showFinishEmptyConfirm = true
        case .confirmUnresolvedExercises:
            showFinishConfirmation = true
        case .offerCardioFinisher:
            showCardioFinisherOffer = true
        case .ready:
            finishWorkout()
        }
    }

    private func proceedFinishAfterEmptyCheck() {
        switch currentVM.nextFinishStep(cardioFinisherAlreadyOffered: cardioFinisherOffered) {
        case .confirmUnresolvedExercises:
            showFinishConfirmation = true
        case .offerCardioFinisher:
            showCardioFinisherOffer = true
        default:
            finishWorkout()
        }
    }

    private func proceedFinishAfterUnresolvedCheck() {
        switch currentVM.nextFinishStep(cardioFinisherAlreadyOffered: cardioFinisherOffered) {
        case .offerCardioFinisher:
            showCardioFinisherOffer = true
        default:
            finishWorkout()
        }
    }

    private func finishWorkout() {
        currentVM.finishWorkoutFromUI(showCompletionSummary: true)
        dismiss()
    }

    private func removeExerciseAtListIndex(_ index: Int, rowId: UUID) {
        if let session = currentVM.currentSession, session.exerciseLogs.indices.contains(index) {
            let lid = session.exerciseLogs[index].id
            clearInlineDraft(for: lid)
        }
        clearEditingSet()

        if resolveSlotSelection?.workoutExerciseId == rowId {
            resolveSlotSelection = nil
        }

        let oldLogSel = logSetSheetSelection
        if oldLogSel?.exerciseIndex == index {
            logSetSheetSelection = nil
        } else if let sel = oldLogSel, sel.exerciseIndex > index {
            logSetSheetSelection = LogSetSheetSelection(exerciseIndex: sel.exerciseIndex - 1)
        }

        currentVM.removeExerciseFromSession(exerciseLogIndex: index, undoManager: undoManager)

        if expandedExerciseIndex == index {
            expandedExerciseIndex = nil
        } else if let e = expandedExerciseIndex, e > index {
            expandedExerciseIndex = e - 1
        }
    }

    private func clearInlineDraft(for logId: UUID) {
        draftStore.clear(logId: logId)
    }

    /// Returns whether a pending focus was applied (so caller skips default auto-expand).
    @discardableResult
    private func consumePendingPullUpFocusIfNeeded() -> Bool {
        guard let pending = currentVM.pendingPullUpFocus else { return false }
        currentVM.pendingPullUpFocus = nil
        guard let logs = currentVM.currentSession?.exerciseLogs,
              logs.indices.contains(pending.exerciseLogIndex)
        else { return false }

        let idx = pending.exerciseLogIndex
        expandedExerciseIndex = idx

        if pending.presentLogSetSheet {
            let we = logs[idx].workoutExercise
            guard !we.isSlotPlaceholder else { return true }
            DispatchQueue.main.async {
                logSetSheetSelection = LogSetSheetSelection(exerciseIndex: idx)
            }
        }
        return true
    }

    private func applyAutoExpandForPrimaryExercise() {
        guard resolveSlotSelection == nil,
              let logs = currentVM.currentSession?.exerciseLogs, !logs.isEmpty,
              let primaryId = currentVM.primaryActiveExerciseId,
              let idx = logs.firstIndex(where: { $0.workoutExercise.exerciseId == primaryId })
        else { return }
        expandedExerciseIndex = idx
    }

    private var sessionLoggedSetCount: Int {
        currentVM.currentSession?.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count } ?? 0
    }

    private var primaryExerciseLogIndex: Int? {
        guard let logs = currentVM.currentSession?.exerciseLogs,
              let primaryId = currentVM.primaryActiveExerciseId else { return nil }
        return logs.firstIndex(where: { $0.workoutExercise.exerciseId == primaryId })
    }

    private var expandedListFirstSetBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(FitlogPalette.success)
            VStack(alignment: .leading, spacing: 4) {
                Text("Log your first set")
                    .font(.subheadline.weight(.semibold))
                Text("Tap an exercise below, then enter weight and reps to log your first set.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FitlogPalette.success.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FitlogPalette.success.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Log your first set. Tap an exercise below, then enter weight and reps.")
    }

    private func expandedListNextExerciseBanner(
        log: ExerciseLog,
        exerciseIndex: Int,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        Button {
            focusPrimaryExercise(at: exerciseIndex, scrollProxy: scrollProxy)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(FitlogPalette.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: \(dataVM.displayName(for: log.workoutExercise))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Tap to log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Expands the next exercise and scrolls to it")
    }

    private func focusPrimaryExercise(at index: Int, scrollProxy: ScrollViewProxy) {
        guard let logs = currentVM.currentSession?.exerciseLogs,
              logs.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedExerciseIndex = index
        }
        initializeInlineDraftIfNeeded(forExpandedIndex: index)
        let targetId = logs[index].id
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollProxy.scrollTo(targetId, anchor: .center)
            }
        }
    }

    private func handleRestCompleteAutoAdvance() {
        advanceToNextExerciseAfterRestIfNeeded()
        let name: String? = {
            guard let idx = expandedExerciseIndex,
                  let logs = currentVM.currentSession?.exerciseLogs,
                  idx < logs.count
            else { return nil }
            return dataVM.displayName(for: logs[idx].workoutExercise)
        }()
        restCompleteBannerMessage = name.map { "Rest over — Next up: \($0)" } ?? "Rest over — time for your next set."
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            restCompleteBannerMessage = nil
            currentVM.showRestCompleteAlert = false
        }
    }

    private func advanceToNextExerciseAfterRestIfNeeded() {
        guard let logs = currentVM.currentSession?.exerciseLogs, !logs.isEmpty else {
            applyAutoExpandForPrimaryExercise()
            return
        }
        guard let primaryId = currentVM.primaryActiveExerciseId,
              let primaryIndex = logs.firstIndex(where: { $0.workoutExercise.exerciseId == primaryId })
        else {
            applyAutoExpandForPrimaryExercise()
            return
        }

        let primaryLog = logs[primaryIndex]
        let we = primaryLog.workoutExercise
        guard !we.isSlotPlaceholder, we.recommendedSets > 0,
              primaryLog.loggedSets.count >= we.recommendedSets
        else {
            applyAutoExpandForPrimaryExercise()
            return
        }

        if let nextIndex = logs.indices.first(where: { i in
            guard i > primaryIndex else { return false }
            let log = logs[i]
            guard !log.workoutExercise.isSlotPlaceholder, let eid = log.workoutExercise.exerciseId else { return false }
            if currentVM.currentSession?.completedExerciseIds.contains(eid) == true { return false }
            let rec = log.workoutExercise.recommendedSets
            return rec == 0 || log.loggedSets.count < rec
        }) {
            expandedExerciseIndex = nextIndex
            if let nextEid = logs[nextIndex].workoutExercise.exerciseId {
                currentVM.setPrimaryExercise(exerciseId: nextEid)
            }
        } else {
            applyAutoExpandForPrimaryExercise()
        }
    }

    // MARK: - Inline quick log & edit

    private func initializeInlineDraftIfNeeded(forExpandedIndex newValue: Int?) {
        guard let idx = newValue,
              let logs = currentVM.currentSession?.exerciseLogs,
              idx < logs.count else { return }
        let log = logs[idx]
        guard !log.workoutExercise.isSlotPlaceholder else { return }
        let lid = log.id
        guard !draftStore.initializedLogIds.contains(lid) else { return }
        let (w, r) = prefillInlineWeightReps(for: log)
        draftStore.repsByLogId[lid] = r
        let unit = userPreferences.weightDisplayUnit
        if let last = log.loggedSets.last {
            let net = WeightStoreConversion.displayValue(storedPounds: last.weight, unit: unit)
            let netClamped = clampSignedNetDisplayForUser(net)
            if netClamped <= 0 && shouldSuggestBodyweightMode(for: log) {
                draftStore.bodyweightModeLogIds.insert(lid)
                draftStore.bodyweightAddedByLogId[lid] = 0
                draftStore.bodyweightAssistedByLogId[lid] = netClamped < 0
                    ? WeightStoreConversion.clampNonNegativeDisplay(-netClamped, unit: unit)
                    : 0
                draftStore.weightByLogId[lid] = 0
            } else {
                draftStore.weightByLogId[lid] = WeightStoreConversion.clampNonNegativeDisplay(netClamped, unit: unit)
            }
        } else {
            draftStore.weightByLogId[lid] = w
            let autoBodyweight = shouldSuggestBodyweightMode(for: log)
            if autoBodyweight {
                draftStore.bodyweightModeLogIds.insert(lid)
                draftStore.bodyweightAddedByLogId[lid] = w
                draftStore.bodyweightAssistedByLogId[lid] = 0
                draftStore.weightByLogId[lid] = 0
                draftStore.bodyweightAddedTextByLogId[lid] = formattedInlineWeight(w)
                draftStore.bodyweightAssistedTextByLogId[lid] = ""
                draftStore.weightTextByLogId[lid] = ""
            }
        }
        seedInlineText(for: lid)
        draftStore.initializedLogIds.insert(lid)
    }

    private func clampDisplayWeightForUser(_ w: Double) -> Double {
        WeightStoreConversion.clampNonNegativeDisplay(w, unit: userPreferences.weightDisplayUnit)
    }

    private func clampSignedNetDisplayForUser(_ w: Double) -> Double {
        WeightStoreConversion.clampSignedNetDisplay(w, unit: userPreferences.weightDisplayUnit)
    }

    private func inlineNetDisplayWeight(for logId: UUID) -> Double {
        if draftStore.bodyweightModeLogIds.contains(logId) {
            let added = WeightStoreConversion.clampNonNegativeDisplay(
                draftStore.bodyweightAddedByLogId[logId] ?? 0,
                unit: userPreferences.weightDisplayUnit
            )
            let assisted = WeightStoreConversion.clampNonNegativeDisplay(
                draftStore.bodyweightAssistedByLogId[logId] ?? 0,
                unit: userPreferences.weightDisplayUnit
            )
            return clampSignedNetDisplayForUser(added - assisted)
        }
        return clampDisplayWeightForUser(draftStore.weightByLogId[logId] ?? 0)
    }

    private func inlineBodyweightNetCaption(logId: UUID, unitLabel: String) -> String? {
        let net = inlineNetDisplayWeight(for: logId)
        guard net != 0 else { return nil }
        if net > 0 {
            return "Net: +\(WeightStoreConversion.formatDisplay(net)) \(unitLabel)"
        }
        return "Net: −\(WeightStoreConversion.formatDisplay(-net)) \(unitLabel) (assisted)"
    }

    private func formattedInlineWeight(_ value: Double) -> String {
        value == 0 ? "" : WeightStoreConversion.formatDisplay(value)
    }

    private func formattedInlineReps(_ value: Int) -> String {
        value == 0 ? "" : "\(value)"
    }

    private func parseInlineDouble(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func parseInlineInt(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func seedInlineText(for logId: UUID) {
        draftStore.weightTextByLogId[logId] = formattedInlineWeight(draftStore.weightByLogId[logId] ?? 0)
        draftStore.repsTextByLogId[logId] = formattedInlineReps(draftStore.repsByLogId[logId] ?? 0)
        draftStore.bodyweightAddedTextByLogId[logId] = formattedInlineWeight(draftStore.bodyweightAddedByLogId[logId] ?? 0)
        draftStore.bodyweightAssistedTextByLogId[logId] = formattedInlineWeight(draftStore.bodyweightAssistedByLogId[logId] ?? 0)
    }

    private func inlineWeightTextBinding(logId: UUID) -> Binding<String> {
        Binding(
            get: { draftStore.weightTextByLogId[logId] ?? "" },
            set: { raw in
                draftStore.weightTextByLogId[logId] = raw
                if let value = parseInlineDouble(raw) {
                    draftStore.weightByLogId[logId] = clampDisplayWeightForUser(value)
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draftStore.weightByLogId[logId] = 0
                }
            }
        )
    }

    private func inlineRepsTextBinding(logId: UUID) -> Binding<String> {
        Binding(
            get: { draftStore.repsTextByLogId[logId] ?? "" },
            set: { raw in
                draftStore.repsTextByLogId[logId] = raw
                if let value = parseInlineInt(raw) {
                    draftStore.repsByLogId[logId] = min(50, max(0, value))
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draftStore.repsByLogId[logId] = 0
                }
            }
        )
    }

    private func inlineBodyweightAddedTextBinding(logId: UUID, unit: WeightDisplayUnit) -> Binding<String> {
        Binding(
            get: { draftStore.bodyweightAddedTextByLogId[logId] ?? "" },
            set: { raw in
                draftStore.bodyweightAddedTextByLogId[logId] = raw
                if let value = parseInlineDouble(raw) {
                    draftStore.bodyweightAddedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(value, unit: unit)
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draftStore.bodyweightAddedByLogId[logId] = 0
                }
            }
        )
    }

    private func inlineBodyweightAssistedTextBinding(logId: UUID, unit: WeightDisplayUnit) -> Binding<String> {
        Binding(
            get: { draftStore.bodyweightAssistedTextByLogId[logId] ?? "" },
            set: { raw in
                draftStore.bodyweightAssistedTextByLogId[logId] = raw
                if let value = parseInlineDouble(raw) {
                    draftStore.bodyweightAssistedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(value, unit: unit)
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draftStore.bodyweightAssistedByLogId[logId] = 0
                }
            }
        )
    }

    private func prefillInlineWeightReps(for exerciseLog: ExerciseLog) -> (weight: Double, reps: Int) {
        let unit = userPreferences.weightDisplayUnit
        if let last = exerciseLog.loggedSets.last {
            let w = WeightStoreConversion.displayValue(storedPounds: last.weight, unit: unit)
            return (clampDisplayWeightForUser(w), last.reps)
        }
        guard let targetExerciseId = exerciseLog.workoutExercise.exerciseId
            ?? exerciseLog.workoutExercise.snapshot?.exerciseId else { return (0, 0) }
        var latestSet: LoggedSet?
        for pastSession in dataVM.completedSessions {
            for log in pastSession.exerciseLogs
                where log.workoutExercise.exerciseId == targetExerciseId
                || log.workoutExercise.snapshot?.exerciseId == targetExerciseId {
                for set in log.loggedSets {
                    if let existing = latestSet {
                        if set.timestamp > existing.timestamp { latestSet = set }
                    } else {
                        latestSet = set
                    }
                }
            }
        }
        if let recent = latestSet {
            let w = WeightStoreConversion.displayValue(storedPounds: recent.weight, unit: unit)
            return (clampDisplayWeightForUser(w), recent.reps)
        }
        return (0, 0)
    }

    private func suggestedRestSecondsForNextSet(exerciseLog: ExerciseLog, exerciseIndex: Int) -> Int {
        if let last = exerciseLog.loggedSets.last {
            return last.restTime
        }
        guard let targetExerciseId = exerciseLog.workoutExercise.exerciseId
            ?? exerciseLog.workoutExercise.snapshot?.exerciseId else { return exerciseLog.workoutExercise.defaultRestTime }
        var latestSet: LoggedSet?
        for pastSession in dataVM.completedSessions {
            for log in pastSession.exerciseLogs
                where log.workoutExercise.exerciseId == targetExerciseId
                || log.workoutExercise.snapshot?.exerciseId == targetExerciseId {
                for set in log.loggedSets {
                    if let existing = latestSet {
                        if set.timestamp > existing.timestamp { latestSet = set }
                    } else {
                        latestSet = set
                    }
                }
            }
        }
        if let recent = latestSet {
            return recent.restTime
        }
        if let override = exerciseLog.sessionRestOverrideSeconds {
            return override
        }
        return exerciseLog.workoutExercise.defaultRestTime
    }

    private func supersetRestAppliesAfterThisSet(exerciseIndex: Int) -> Bool {
        guard let session = currentVM.currentSession,
              exerciseIndex < session.exerciseLogs.count,
              let id = session.exerciseLogs[exerciseIndex].workoutExercise.exerciseId,
              session.activeExerciseIds.count > 1,
              let idx = session.activeExerciseIds.firstIndex(of: id)
        else { return true }
        return idx == session.activeExerciseIds.count - 1
    }

    private func inlineConfiguration(for exerciseLog: ExerciseLog) -> [String: String] {
        if let last = exerciseLog.loggedSets.last, !last.configuration.isEmpty {
            return last.configuration
        }
        let nextIndex = exerciseLog.loggedSets.count
        if nextIndex < exerciseLog.workoutExercise.recommendedConfigBySet.count {
            return exerciseLog.workoutExercise.recommendedConfigBySet[nextIndex]
        }
        return [:]
    }

    private func inlineQuickLog(exerciseIndex: Int, logId: UUID) {
        guard let logs = currentVM.currentSession?.exerciseLogs,
              exerciseIndex < logs.count,
              logs[exerciseIndex].id == logId
        else { return }
        let exerciseLog = logs[exerciseIndex]
        let r = draftStore.repsByLogId[logId] ?? 0
        guard r > 0 else { return }

        let restBase = suggestedRestSecondsForNextSet(exerciseLog: exerciseLog, exerciseIndex: exerciseIndex)
        let effectiveRest = supersetRestAppliesAfterThisSet(exerciseIndex: exerciseIndex) ? restBase : 0

        let unit = userPreferences.weightDisplayUnit
        let wDisplay = inlineNetDisplayWeight(for: logId)
        let stored = WeightStoreConversion.storedPounds(
            displayValue: wDisplay,
            unit: unit
        )
        let rpeVal: Double? = draftStore.rpeByLogId[logId]
        let chosenType = draftStore.setTypeByLogId[logId] ?? .working
        if chosenType == .dropSet, !exerciseLog.loggedSets.isEmpty {
            let lastIndex = exerciseLog.loggedSets.count - 1
            currentVM.appendDropSegment(
                exerciseIndex: exerciseIndex,
                setIndex: lastIndex,
                weight: stored,
                reps: r
            )
            syncInlineDraftAfterLog(for: logId, exerciseIndex: exerciseIndex)
            triggerHighlightForLastSet(exerciseIndex: exerciseIndex)
            inlineLogSuccessTick += 1
            draftStore.setTypeByLogId[logId] = .working
            return
        }

        let resolvedSetType: ExerciseSetType = chosenType == .dropSet ? .working : chosenType

        currentVM.logSet(
            exerciseIndex: exerciseIndex,
            weight: stored,
            reps: r,
            restTime: effectiveRest,
            setType: resolvedSetType,
            configuration: inlineConfiguration(for: exerciseLog),
            dropSegments: [],
            rpe: rpeVal
        )
        syncInlineDraftAfterLog(for: logId, exerciseIndex: exerciseIndex)
        triggerHighlightForLastSet(exerciseIndex: exerciseIndex)
        inlineLogSuccessTick += 1
        // Show "Add drop" affordance for ~5 seconds (Task 14)
        dropPromptLogId = logId
        dropPromptExerciseIndex = exerciseIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if dropPromptLogId == logId { dropPromptLogId = nil; dropPromptExerciseIndex = nil }
        }
    }

    private func syncInlineDraftAfterLog(for logId: UUID, exerciseIndex: Int) {
        guard let logs = currentVM.currentSession?.exerciseLogs,
              exerciseIndex < logs.count,
              logs[exerciseIndex].id == logId,
              let last = logs[exerciseIndex].loggedSets.last
        else { return }
        let unit = userPreferences.weightDisplayUnit
        let netDisplay = WeightStoreConversion.displayValue(storedPounds: last.weight, unit: unit)
        if draftStore.bodyweightModeLogIds.contains(logId) {
            let clampedNet = clampSignedNetDisplayForUser(netDisplay)
            if clampedNet >= 0 {
                draftStore.bodyweightAddedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(clampedNet, unit: unit)
                draftStore.bodyweightAssistedByLogId[logId] = 0
            } else {
                draftStore.bodyweightAddedByLogId[logId] = 0
                draftStore.bodyweightAssistedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(-clampedNet, unit: unit)
            }
            draftStore.weightByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(max(0, clampedNet), unit: unit)
        } else {
            draftStore.weightByLogId[logId] = clampDisplayWeightForUser(netDisplay)
        }
        draftStore.repsByLogId[logId] = last.reps
    }

    private func isSupersetLoggingContext(exerciseIndex: Int) -> Bool {
        guard (currentVM.currentSession?.activeExerciseIds.count ?? 0) > 1 else { return false }
        guard let session = currentVM.currentSession,
              exerciseIndex < session.exerciseLogs.count,
              let id = session.exerciseLogs[exerciseIndex].workoutExercise.exerciseId
        else { return false }
        return session.activeExerciseIds.contains(id)
    }

    private func supersetInlineHint(exerciseIndex: Int) -> String {
        guard let session = currentVM.currentSession,
              exerciseIndex < session.exerciseLogs.count,
              let id = session.exerciseLogs[exerciseIndex].workoutExercise.exerciseId,
              session.activeExerciseIds.count > 1,
              let idx = session.activeExerciseIds.firstIndex(of: id)
        else { return "" }
        if idx == session.activeExerciseIds.count - 1 {
            return "Superset: rest starts after this set."
        }
        return "Superset: no rest after this set — next exercise in the round."
    }

    @ViewBuilder
    private func exerciseCollapsedHeader(log: ExerciseLog, isExpanded: Bool) -> some View {
        let rec = log.workoutExercise.recommendedSets
        let progress: Double = {
            guard rec > 0 else { return log.loggedSets.isEmpty ? 0 : 1 }
            return min(1, Double(log.loggedSets.count) / Double(rec))
        }()

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(dataVM.displayName(for: log.workoutExercise))
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    if let letter = supersetLetter(for: log) {
                        Text(letter)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Circle().fill(Color.blue.gradient))
                            .accessibilityLabel("Superset \(letter)")
                    }
                    if let libraryExercise = libraryExercise(for: log),
                       libraryExercise.modality != .cardio,
                       formGuideService.isConfigured {
                        ExerciseFormGuideInfoButton(exercise: libraryExercise)
                    }
                }
                ProgressView(value: progress)
                    .tint(exerciseProgressTint(for: log))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                let countStr = rec > 0 ? "\(log.loggedSets.count)/\(rec)" : "\(log.loggedSets.count)"
                Text(countStr)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                statusDot(for: log)
            }
            if !isExpanded {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func exerciseProgressTint(for log: ExerciseLog) -> Color {
        if isExerciseCompleted(log) { return .gray }
        if isPrimaryExercise(log) { return .green }
        if isExerciseActive(log) { return .blue }
        if !log.loggedSets.isEmpty { return .orange }
        return .secondary
    }

    private func libraryExercise(for log: ExerciseLog) -> Exercise? {
        if let snapshot = log.workoutExercise.snapshot {
            return dataVM.resolveExercise(for: snapshot)
        }
        if let exerciseId = log.workoutExercise.exerciseId {
            return dataVM.globalExercises.first { $0.id == exerciseId }
        }
        return nil
    }

    @ViewBuilder
    private func sessionRestOverrideEditor(exerciseIndex: Int, log: ExerciseLog) -> some View {
        let planDefault = log.workoutExercise.defaultRestTime
        VStack(alignment: .leading, spacing: 6) {
            Text("Default rest (this session)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Stepper(
                value: Binding(
                    get: {
                        guard let logs = currentVM.currentSession?.exerciseLogs,
                              logs.indices.contains(exerciseIndex)
                        else { return planDefault }
                        return logs[exerciseIndex].sessionRestOverrideSeconds ?? planDefault
                    },
                    set: { currentVM.setExerciseLogSessionRestOverride(at: exerciseIndex, seconds: $0) }
                ),
                in: 0...300,
                step: 15
            ) {
                let shown: Int = {
                    guard let logs = currentVM.currentSession?.exerciseLogs,
                          logs.indices.contains(exerciseIndex)
                    else { return planDefault }
                    return logs[exerciseIndex].sessionRestOverrideSeconds ?? planDefault
                }()
                Text("Next set rest: \(shown)s")
                    .font(.subheadline)
                Text("Plan default: \(planDefault)s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if log.sessionRestOverrideSeconds != nil {
                Button("Reset to plan default") {
                    currentVM.clearExerciseLogSessionRestOverride(at: exerciseIndex)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.caption)
            }
            Text(
                log.loggedSets.isEmpty
                    ? "Used for your first set and inline quick-log until you log a set."
                    : "After the first set, rest follows each logged set. Change rest in full log for new sets."
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sessionRunningStatsStrip(session: WorkoutSession) -> some View {
        let allSets = session.exerciseLogs.flatMap(\.loggedSets)
        let workingSets = allSets.filter { $0.countsTowardVolumeTotals }
        let setCount = workingSets.count
        let volLb = workingSets.reduce(0.0) { total, set in
            total + max(0, set.weight) * Double(set.reps)
        }
        let volDisplay = WeightStoreConversion.displayValue(storedPounds: volLb, unit: userPreferences.weightDisplayUnit)
        let volumeUnit = userPreferences.weightDisplayUnit == .kilograms ? "kg·rep" : "lb·rep"

        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sets")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(setCount)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Vol")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(volDisplay == floor(volDisplay) ? "\(Int(volDisplay)) \(volumeUnit)" : String(format: "%.1f %@", volDisplay, volumeUnit))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private func sessionVolumeSummary(session: WorkoutSession) -> String {
        let workingSets = session.exerciseLogs.flatMap(\.loggedSets).filter { $0.countsTowardVolumeTotals }
        guard !workingSets.isEmpty else { return "" }
        let volLb = workingSets.reduce(0.0) { $0 + max(0, $1.weight) * Double($1.reps) }
        let volDisplay = WeightStoreConversion.displayValue(storedPounds: volLb, unit: userPreferences.weightDisplayUnit)
        let unit = userPreferences.weightDisplayUnit == .kilograms ? "kg·rep" : "lb·rep"
        if volDisplay == floor(volDisplay) {
            return "\(Int(volDisplay)) \(unit)"
        }
        return String(format: "%.1f %@", volDisplay, unit)
    }

    private func inlineSetTypeBinding(logId: UUID) -> Binding<ExerciseSetType> {
        Binding(
            get: { draftStore.setTypeByLogId[logId] ?? .working },
            set: { draftStore.setTypeByLogId[logId] = $0 }
        )
    }

    private func inlineProgressionSuggestion(for log: ExerciseLog) -> InlineProgressionTarget? {
        guard let exId = log.workoutExercise.exerciseId else { return nil }
        let lastWorkingSets = ProgressionAdvisor.lastWorkingSets(
            forExerciseId: exId,
            from: dataVM.completedSessions,
            limit: 5
        )
        return ProgressionAdvisor.suggest(
            for: log,
            lastWorkingSets: lastWorkingSets,
            exerciseRole: dataVM.globalExercises.first(where: { $0.id == exId })?.exerciseRole ?? .accessory,
            blockContext: dataVM.activeBlockContext()
        )
    }

    private func shouldSuggestBodyweightMode(for log: ExerciseLog) -> Bool {
        let name = dataVM.displayName(for: log.workoutExercise).lowercased()
        let patterns = [
            "pull-up", "pull up", "pullup",
            "chin-up", "chin up", "chinup",
            "push-up", "push up", "pushup",
            "dip",
            "muscle-up", "muscle up",
            "bodyweight",
            "plank",
            "hanging",
            "leg raise",
            "burpee",
            "inverted row",
            "pistol squat",
            "l-sit", "l sit",
            "human flag",
            "toes to bar", "toes-to-bar",
            "ring row",
            "body row",
        ]
        let nameMatch = patterns.contains { name.contains($0) }
        guard nameMatch else { return false }

        guard let exId = log.workoutExercise.exerciseId
            ?? log.workoutExercise.snapshot?.exerciseId else { return true }
        for session in dataVM.completedSessions {
            for pastLog in session.exerciseLogs
                where pastLog.workoutExercise.exerciseId == exId
                || pastLog.workoutExercise.snapshot?.exerciseId == exId {
                if pastLog.loggedSets.contains(where: { $0.weight > 0 }) {
                    return false
                }
            }
        }
        return true
    }

    private func setInlineBodyweightMode(logId: UUID, enabled: Bool) {
        if enabled {
            draftStore.bodyweightModeLogIds.insert(logId)
            let w = draftStore.weightByLogId[logId] ?? 0
            draftStore.bodyweightAddedByLogId[logId] = w
            draftStore.bodyweightAssistedByLogId[logId] = 0
            draftStore.weightByLogId[logId] = 0
            draftStore.bodyweightAddedTextByLogId[logId] = formattedInlineWeight(w)
            draftStore.bodyweightAssistedTextByLogId[logId] = ""
            draftStore.weightTextByLogId[logId] = ""
        } else {
            draftStore.bodyweightModeLogIds.remove(logId)
            let added = draftStore.bodyweightAddedByLogId[logId] ?? 0
            let assisted = draftStore.bodyweightAssistedByLogId[logId] ?? 0
            draftStore.weightByLogId[logId] = clampDisplayWeightForUser(max(0, added - assisted))
            draftStore.bodyweightAddedByLogId.removeValue(forKey: logId)
            draftStore.bodyweightAssistedByLogId.removeValue(forKey: logId)
            draftStore.weightTextByLogId[logId] = formattedInlineWeight(draftStore.weightByLogId[logId] ?? 0)
            draftStore.bodyweightAddedTextByLogId.removeValue(forKey: logId)
            draftStore.bodyweightAssistedTextByLogId.removeValue(forKey: logId)
        }
    }

    @ViewBuilder
    private func inlineSetEntryRow(exerciseIndex: Int, log: ExerciseLog) -> some View {
        if CardioWorkoutExerciseHelpers.isCardioLoggingRow(log.workoutExercise, exercises: dataVM.globalExercises) {
            CardioLogView(exerciseIndex: exerciseIndex, sessionVM: currentVM)
                .environment(dataVM)
                .padding(.vertical, 4)
        } else {
            inlineStrengthSetEntryRow(exerciseIndex: exerciseIndex, log: log)
        }
    }

    @ViewBuilder
    private func inlineStrengthSetEntryRow(exerciseIndex: Int, log: ExerciseLog) -> some View {
        let logId = log.id
        let unit = userPreferences.weightDisplayUnit
        let unitLabel = unit.shortLabel
        let bwMode = draftStore.bodyweightModeLogIds.contains(logId)
        let weightTextBinding = inlineWeightTextBinding(logId: logId)
        let addedTextBinding = inlineBodyweightAddedTextBinding(logId: logId, unit: unit)
        let assistedTextBinding = inlineBodyweightAssistedTextBinding(logId: logId, unit: unit)
        let repsTextBinding = inlineRepsTextBinding(logId: logId)
        /// Single compact row: ~44pt tall fields without stacking actions underneath.
        let fieldPadding = EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)

        // Progression suggestion and previous-session strip
        let exId = log.workoutExercise.exerciseId
        let lastWorkingSets: [LoggedSet] = exId.map { id in
            ProgressionAdvisor.lastWorkingSets(forExerciseId: id, from: dataVM.completedSessions, limit: 5)
        } ?? []
        let draftWeightStored = WeightStoreConversion.storedPounds(
            displayValue: inlineNetDisplayWeight(for: logId),
            unit: unit
        )
        let draftReps = draftStore.repsByLogId[logId] ?? 0
        let progressionSuggestion: InlineProgressionTarget? = exId.flatMap { id in
            ProgressionAdvisor.suggest(
                for: log,
                lastWorkingSets: lastWorkingSets,
                exerciseRole: dataVM.globalExercises.first(where: { $0.id == id })?.exerciseRole ?? .accessory,
                blockContext: dataVM.activeBlockContext()
            )
        }
        let prevSessionSets = lastWorkingSets.filter { $0.countsTowardLoadPRMetrics }.prefix(3).map { $0 }
        let effortValueSummary: String? = {
            guard let rpeVal = draftStore.rpeByLogId[logId] else { return nil }
            let d = userPreferences.effortInputStyle.displayValue(fromRPE: rpeVal)
            if abs(d - Double(Int(d))) < 0.001 { return "\(Int(d))" }
            return String(format: "%.1f", d)
        }()

        VStack(alignment: .leading, spacing: 6) {
            // Suggested target chip
            if let suggestion: InlineProgressionTarget = progressionSuggestion, !lastWorkingSets.isEmpty {
                SuggestedTargetChip(
                    suggestion: suggestion,
                    lastWeight: lastWorkingSets.first?.weight,
                    lastReps: lastWorkingSets.first?.reps,
                    effortStyle: userPreferences.effortInputStyle,
                    unit: unit,
                    onTap: {
                    // Pre-fill the inline fields from the suggestion
                    let displayW = WeightStoreConversion.displayValue(storedPounds: suggestion.weight, unit: unit)
                    draftStore.weightByLogId[logId] = displayW
                    draftStore.weightTextByLogId[logId] = WeightStoreConversion.formatDisplay(displayW)
                    draftStore.repsByLogId[logId] = suggestion.reps
                    draftStore.repsTextByLogId[logId] = "\(suggestion.reps)"
                    if let rpe = suggestion.rpe {
                        draftStore.rpeByLogId[logId] = userPreferences.effortInputStyle.toRPE(rpe)
                        draftStore.rpeExpandedLogIds.insert(logId)
                    }
                },
                    onLogNow: {
                        let displayW = WeightStoreConversion.displayValue(storedPounds: suggestion.weight, unit: unit)
                        draftStore.weightByLogId[logId] = displayW
                        draftStore.weightTextByLogId[logId] = WeightStoreConversion.formatDisplay(displayW)
                        draftStore.repsByLogId[logId] = suggestion.reps
                        draftStore.repsTextByLogId[logId] = "\(suggestion.reps)"
                        if let rpe = suggestion.rpe {
                            draftStore.rpeByLogId[logId] = userPreferences.effortInputStyle.toRPE(rpe)
                        }
                        fitlogDismissKeyboard()
                        numericFieldFocus = nil
                        inlineQuickLog(exerciseIndex: exerciseIndex, logId: logId)
                    }
                )
            }
            // Previous session strip
            if !prevSessionSets.isEmpty {
                PreviousSessionStrip(
                    sets: prevSessionSets,
                    draftWeight: draftWeightStored,
                    draftReps: draftReps,
                    unit: unit
                )
            }
            HStack {
                Text("Next set")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(bwMode ? "Reps first — optional +/− load" : "Tap ✓ to log, or edit first")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            WorkoutQuickSetTypeBar(
                selection: inlineSetTypeBinding(logId: logId),
                dropSetEnabled: !log.loggedSets.isEmpty
            )
            WorkoutQuickActionsBar(
                bodyweightMode: bwMode,
                rpeExpanded: draftStore.rpeExpandedLogIds.contains(logId),
                effortValueSummary: effortValueSummary,
                effortKindLabel: userPreferences.effortInputStyle.label,
                onToggleBodyweight: {
                    setInlineBodyweightMode(logId: logId, enabled: !bwMode)
                },
                onToggleRPE: {
                    if draftStore.rpeExpandedLogIds.contains(logId) {
                        draftStore.rpeExpandedLogIds.remove(logId)
                    } else {
                        draftStore.rpeExpandedLogIds.insert(logId)
                    }
                },
                onPlates: {
                    fitlogDismissKeyboard()
                    numericFieldFocus = nil
                    plateCalculatorInlinePick = PlateCalculatorInlinePick(logId: logId)
                },
                onNotes: {
                    exerciseDetailMoreExpandedLogId = log.id
                },
                onFullLog: {
                    fitlogDismissKeyboard()
                    numericFieldFocus = nil
                    logSetSheetSelection = LogSetSheetSelection(
                        exerciseIndex: exerciseIndex,
                        prefillDisplayWeight: bwMode ? inlineNetDisplayWeight(for: logId) : draftStore.weightByLogId[logId],
                        prefillReps: draftStore.repsByLogId[logId],
                        prefillBodyweightMode: bwMode
                    )
                }
            )
            if bwMode {
                HStack(alignment: .center, spacing: 6) {
                    TextField("Reps", text: repsTextBinding)
                        .keyboardType(.numberPad)
                        .focused($numericFieldFocus, equals: .inlineReps(logId))
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 52, minHeight: 36)
                        .padding(fieldPadding)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button {
                        fitlogDismissKeyboard()
                        numericFieldFocus = nil
                        inlineQuickLog(exerciseIndex: exerciseIndex, logId: logId)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled((draftStore.repsByLogId[logId] ?? 0) <= 0)
                    .accessibilityLabel(
                        InlineLogSetAccessibility.logSetLabel(
                            exerciseName: dataVM.displayName(for: log.workoutExercise),
                            bodyweightMode: true,
                            displayWeight: inlineNetDisplayWeight(for: logId),
                            reps: draftStore.repsByLogId[logId] ?? 0,
                            unitLabel: unitLabel
                        )
                    )
                    .accessibilityHint(InlineLogSetAccessibility.logSetHint)
                }
                HStack(alignment: .center, spacing: 6) {
                    Text("+")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Added", text: addedTextBinding)
                        .keyboardType(.decimalPad)
                        .focused($numericFieldFocus, equals: .inlineAdded(logId))
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 48, minHeight: 32)
                        .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("−")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Assist", text: assistedTextBinding)
                        .keyboardType(.decimalPad)
                        .focused($numericFieldFocus, equals: .inlineAssisted(logId))
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 48, minHeight: 32)
                        .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(unitLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let netCaption = inlineBodyweightNetCaption(logId: logId, unitLabel: unitLabel) {
                    Text(netCaption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(alignment: .center, spacing: 6) {
                    TextField("Wt", text: weightTextBinding)
                        .keyboardType(.decimalPad)
                        .focused($numericFieldFocus, equals: .inlineWeight(logId))
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 52, minHeight: 36)
                        .padding(fieldPadding)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(unitLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Text("×")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    TextField("Reps", text: repsTextBinding)
                        .keyboardType(.numberPad)
                        .focused($numericFieldFocus, equals: .inlineReps(logId))
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 44, minHeight: 36)
                        .padding(fieldPadding)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        fitlogDismissKeyboard()
                        numericFieldFocus = nil
                        inlineQuickLog(exerciseIndex: exerciseIndex, logId: logId)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled((draftStore.repsByLogId[logId] ?? 0) <= 0)
                    .accessibilityLabel(
                        InlineLogSetAccessibility.logSetLabel(
                            exerciseName: dataVM.displayName(for: log.workoutExercise),
                            bodyweightMode: false,
                            displayWeight: draftStore.weightByLogId[logId] ?? 0,
                            reps: draftStore.repsByLogId[logId] ?? 0,
                            unitLabel: unitLabel
                        )
                    )
                    .accessibilityHint(InlineLogSetAccessibility.logSetHint)
                }
            }
            // RPE / RIR quick chip row (respects effortInputStyle)
            if draftStore.rpeExpandedLogIds.contains(logId) {
                let effortLabel = userPreferences.effortInputStyle.label
                let clearLabel = "Clear \(effortLabel)"
                HStack(spacing: 6) {
                    Button(clearLabel) {
                        var next = draftStore.rpeByLogId
                        next.removeValue(forKey: logId)
                        draftStore.rpeByLogId = next
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption2)
                    .accessibilityLabel(clearLabel)
                    .accessibilityHint("Removes the selected effort value for this set")
                    // Show 10 down to 6 — for RIR these map to 0..4 RIR (displayed inverted)
                    ForEach((6...10).reversed(), id: \.self) { n in
                        let rpeVal = Double(n)
                        let displayVal = userPreferences.effortInputStyle.displayValue(fromRPE: rpeVal)
                        let selected = draftStore.rpeByLogId[logId] == rpeVal
                        Button("\(Int(displayVal))") {
                            var next = draftStore.rpeByLogId
                            if selected { next.removeValue(forKey: logId) } else { next[logId] = rpeVal }
                            draftStore.rpeByLogId = next
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selected ? .blue : .secondary)
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("\(effortLabel) \(Int(displayVal))")
                        .accessibilityHint(selected ? "Selected. Double tap to clear." : "Sets effort for the next logged set")
                    }
                }
            }
            // Drop-set prompt (visible ~5 s after tapping ✓)
            if dropPromptLogId == logId {
                Button {
                    beginInlineDropDraft(exerciseIndex: exerciseIndex, logId: logId)
                    dropPromptLogId = nil
                    dropPromptExerciseIndex = nil
                } label: {
                    Label("Add drop", systemImage: "arrow.down.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(response: 0.3), value: dropPromptLogId)
                .accessibilityHint("Adds a lighter drop segment to the set you just logged")
            }
            if let draft = inlineDropDraft, draft.exerciseIndex == exerciseIndex,
               let logs = currentVM.currentSession?.exerciseLogs,
               draft.exerciseIndex < logs.count,
               logs[draft.exerciseIndex].id == logId {
                inlineDropSegmentEditor(exerciseIndex: exerciseIndex, logId: logId, unit: unit)
            }
            if isSupersetLoggingContext(exerciseIndex: exerciseIndex) {
                Text(supersetInlineHint(exerciseIndex: exerciseIndex))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            switch numericFieldFocus {
            case .inlineWeight(let id) where id == logId,
                 .inlineAdded(let id) where id == logId,
                 .inlineAssisted(let id) where id == logId,
                 .inlineReps(let id) where id == logId:
                fitlogDismissKeyboard()
                numericFieldFocus = nil
            default:
                break
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func cardioLoggedSetsSection(exerciseIndex: Int, log: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Logged segments")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if log.loggedSets.isEmpty {
                Text("No segments logged yet")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(log.loggedSets.enumerated()), id: \.element.id) { setIndex, set in
                        readOnlyCardioLoggedSetRow(
                            exerciseIndex: exerciseIndex,
                            setIndex: setIndex,
                            chronologicalSetNumber: setIndex + 1,
                            set: set,
                            isHighlighted: set.id == highlightedLoggedSetId,
                            onDelete: {
                                deleteLoggedSet(
                                    exerciseIndex: exerciseIndex,
                                    setIndex: setIndex,
                                    set: set
                                )
                            }
                        )
                    }
                }
            }
        }
    }

    private func readOnlyCardioLoggedSetRow(
        exerciseIndex: Int,
        setIndex: Int,
        chronologicalSetNumber: Int,
        set: LoggedSet,
        isHighlighted: Bool,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Segment \(chronologicalSetNumber)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                Text(set.cardioDisplaySummary)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete segment \(chronologicalSetNumber)")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(isHighlighted ? 0.22 : 0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Segment \(chronologicalSetNumber), \(set.cardioDisplaySummary)")
        .animation(.easeOut(duration: 0.45), value: isHighlighted)
    }

    private func deleteLoggedSet(exerciseIndex: Int, setIndex: Int, set: LoggedSet) {
        clearEditingSetIfNeeded(setId: set.id)
        let undo = PendingUndoSet(
            exerciseIndex: exerciseIndex,
            insertAt: setIndex,
            set: set
        )
        pendingUndoSet = undo
        currentVM.deleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
        let undoId = undo.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if pendingUndoSet?.id == undoId {
                pendingUndoSet = nil
            }
        }
    }

    private func beginInlineDropDraft(exerciseIndex: Int, logId: UUID) {
        guard let logs = currentVM.currentSession?.exerciseLogs,
              exerciseIndex < logs.count,
              logs[exerciseIndex].id == logId,
              let lastSet = logs[exerciseIndex].loggedSets.last
        else { return }
        let unit = userPreferences.weightDisplayUnit
        let displayW = WeightStoreConversion.displayValue(storedPounds: lastSet.weight, unit: unit)
        inlineDropWeightDisplay = clampDisplayWeightForUser(max(0, displayW * 0.8))
        inlineDropReps = lastSet.reps
        inlineDropDraft = InlineDropDraft(exerciseIndex: exerciseIndex, setIndex: logs[exerciseIndex].loggedSets.count - 1)
    }

    @ViewBuilder
    private func inlineDropSegmentEditor(exerciseIndex: Int, logId: UUID, unit: WeightDisplayUnit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drop segment")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("Wt", value: $inlineDropWeightDisplay, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 52, minHeight: 36)
                    .padding(7)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(unit.shortLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("×")
                    .font(.caption.weight(.semibold))
                TextField("Reps", value: $inlineDropReps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 44, minHeight: 36)
                    .padding(7)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button {
                    confirmInlineDropSegment(exerciseIndex: exerciseIndex, logId: logId)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(inlineDropReps <= 0)
                Button("Cancel") {
                    inlineDropDraft = nil
                }
                .font(.caption)
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func confirmInlineDropSegment(exerciseIndex: Int, logId: UUID) {
        guard let draft = inlineDropDraft,
              draft.exerciseIndex == exerciseIndex,
              let logs = currentVM.currentSession?.exerciseLogs,
              exerciseIndex < logs.count,
              logs[exerciseIndex].id == logId,
              inlineDropReps > 0
        else { return }
        let unit = userPreferences.weightDisplayUnit
        let stored = WeightStoreConversion.storedPounds(
            displayValue: inlineDropWeightDisplay,
            unit: unit
        )
        currentVM.appendDropSegment(
            exerciseIndex: exerciseIndex,
            setIndex: draft.setIndex,
            weight: stored,
            reps: inlineDropReps
        )
        inlineDropDraft = nil
        triggerHighlightForLastSet(exerciseIndex: exerciseIndex)
    }

    @ViewBuilder
    private func interactiveLoggedSetRow(
        exerciseIndex: Int,
        setIndex: Int,
        chronologicalSetNumber: Int,
        set: LoggedSet,
        workoutExercise: WorkoutExercise,
        isHighlighted: Bool,
        onDelete: @escaping () -> Void
    ) -> some View {
        if set.isCardioEntry || set.countsTowardCardioTotals {
            readOnlyCardioLoggedSetRow(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                chronologicalSetNumber: chronologicalSetNumber,
                set: set,
                isHighlighted: isHighlighted,
                onDelete: onDelete
            )
        } else if editingSetId == set.id,
           editingSetExerciseIndex == exerciseIndex,
           editingSetIndex == setIndex {
            let fieldPadding = EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)
            VStack(alignment: .leading, spacing: 6) {
                Text("Edit set \(chronologicalSetNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if set.dropSegments.isEmpty {
                    Picker("Type", selection: $editSetType) {
                        Text(ExerciseSetType.working.logPickerLabel).tag(ExerciseSetType.working)
                        Text(ExerciseSetType.warmup.logPickerLabel).tag(ExerciseSetType.warmup)
                        Text(ExerciseSetType.amrap.logPickerLabel).tag(ExerciseSetType.amrap)
                        Text(ExerciseSetType.failure.logPickerLabel).tag(ExerciseSetType.failure)
                        Text(ExerciseSetType.timed.logPickerLabel).tag(ExerciseSetType.timed)
                    }
                    .pickerStyle(.segmented)
                    if editSetType == .timed {
                        Text("Reps = hold seconds. Weight = optional added load (display units).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Drop set — type stays Drop; edit loads in full log if needed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    TextField("Wt", value: Binding(
                        get: { editWeightDisplay },
                        set: { editWeightDisplay = clampSignedNetDisplayForUser($0) }
                    ), format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .focused($numericFieldFocus, equals: .editWeight)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 52, minHeight: 36)
                    .padding(fieldPadding)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(userPreferences.weightDisplayUnit.shortLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("×")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    TextField("Reps", value: $editReps, format: .number)
                        .keyboardType(.numberPad)
                        .focused($numericFieldFocus, equals: .editReps)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 44, minHeight: 36)
                        .padding(fieldPadding)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        fitlogDismissKeyboard()
                        numericFieldFocus = nil
                        confirmEditingSet()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(editReps <= 0)
                    Button("Cancel") {
                        fitlogDismissKeyboard()
                        numericFieldFocus = nil
                        clearEditingSet()
                    }
                    .font(.caption)
                }
            }
            .padding(8)
            .contentShape(Rectangle())
            .onTapGesture {
                switch numericFieldFocus {
                case .editWeight, .editReps:
                    fitlogDismissKeyboard()
                    numericFieldFocus = nil
                default:
                    break
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Button {
                        beginEditingSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set \(chronologicalSetNumber)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.tertiary)
                            setRow(set: set, workoutExercise: workoutExercise)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.body)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete set \(chronologicalSetNumber)")
                    .accessibilityHint("Removes this set. Undo is available briefly afterward.")
                }
                ForEach(Array(set.dropSegments.enumerated()), id: \.offset) { dropIndex, segment in
                    dropSegmentSubRow(
                        segment: segment,
                        dropIndex: dropIndex + 1,
                        workoutExercise: workoutExercise
                    )
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(isHighlighted ? 0.22 : 0))
            )
            .animation(.easeOut(duration: 0.45), value: isHighlighted)
        }
    }

    private func dropSegmentSubRow(
        segment: DropSetSegment,
        dropIndex: Int,
        workoutExercise: WorkoutExercise
    ) -> some View {
        let unit = userPreferences.weightDisplayUnit
        let displayW = WeightStoreConversion.displayValue(storedPounds: segment.weight, unit: unit)
        let weightLabel = displayW == floor(displayW)
            ? "\(Int(displayW)) \(unit.shortLabel)"
            : String(format: "%.1f %@", displayW, unit.shortLabel)
        let summary = "\(weightLabel) × \(segment.reps)"
        return HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("Drop \(dropIndex): \(summary)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, 12)
        .accessibilityLabel("Drop \(dropIndex), \(summary)")
    }

    private func beginEditingSet(exerciseIndex: Int, setIndex: Int) {
        guard let session = currentVM.currentSession,
              exerciseIndex < session.exerciseLogs.count,
              setIndex < session.exerciseLogs[exerciseIndex].loggedSets.count
        else { return }
        let set = session.exerciseLogs[exerciseIndex].loggedSets[setIndex]
        editingSetExerciseIndex = exerciseIndex
        editingSetIndex = setIndex
        editingSetId = set.id
        let unit = userPreferences.weightDisplayUnit
        editWeightDisplay = clampSignedNetDisplayForUser(
            WeightStoreConversion.displayValue(storedPounds: set.weight, unit: unit)
        )
        editReps = set.reps
        if set.dropSegments.isEmpty {
            editSetType = set.setType == .dropSet ? .working : set.setType
        } else {
            editSetType = .working
        }
    }

    private func confirmEditingSet() {
        guard let exIdx = editingSetExerciseIndex, let sIdx = editingSetIndex else { return }
        guard editReps > 0 else { return }
        let unit = userPreferences.weightDisplayUnit
        let stored = WeightStoreConversion.storedPounds(
            displayValue: clampSignedNetDisplayForUser(editWeightDisplay),
            unit: unit
        )
        let typeArg: ExerciseSetType? = {
            guard let session = currentVM.currentSession,
                  exIdx < session.exerciseLogs.count,
                  sIdx < session.exerciseLogs[exIdx].loggedSets.count
            else { return nil }
            return session.exerciseLogs[exIdx].loggedSets[sIdx].dropSegments.isEmpty ? editSetType : nil
        }()
        currentVM.updateSet(exerciseIndex: exIdx, setIndex: sIdx, weight: stored, reps: editReps, setType: typeArg)
        clearEditingSet()
    }

    private func clearEditingSet() {
        editingSetExerciseIndex = nil
        editingSetIndex = nil
        editingSetId = nil
    }

    private func clearEditingSetIfNeeded(setId: UUID) {
        if editingSetId == setId {
            clearEditingSet()
        }
    }

    // MARK: - Unresolved slots banner

    @ViewBuilder
    private var unresolvedSlotsBanner: some View {
        if let session = currentVM.currentSession {
            let unresolvedCount = session.exerciseLogs.filter { $0.workoutExercise.isSlotPlaceholder }.count
            if unresolvedCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text("\(unresolvedCount) slot\(unresolvedCount == 1 ? "" : "s") need\(unresolvedCount == 1 ? "s" : "") an exercise")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Resolve") {
                        if let first = session.exerciseLogs.first(where: { $0.workoutExercise.isSlotPlaceholder }) {
                            resolveSlotSelection = ResolveSlotWE(workoutExerciseId: first.workoutExercise.id, templateSlotId: first.workoutExercise.templateSlotId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }


    @ViewBuilder
    private var restCompleteNextUpBanner: some View {
        if let msg = restCompleteBannerMessage {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
            }
            .padding()
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func supersetLetter(for log: ExerciseLog) -> String? {
        guard let session = currentVM.currentSession,
              let id = log.workoutExercise.exerciseId,
              session.activeExerciseIds.count > 1,
              let idx = session.activeExerciseIds.firstIndex(of: id)
        else { return nil }
        let letters = Array("ABCDEFGHIJKLMN")
        guard idx < letters.count else { return "•" }
        return String(letters[idx])
    }

    private func setProgressIndicatorStrip(log: ExerciseLog) -> some View {
        let rec = log.workoutExercise.recommendedSets
        let done = log.loggedSets.count
        let slots = max(1, max(rec, done))
        return HStack(spacing: 10) {
            Text("Plan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 7) {
                ForEach(0..<slots, id: \.self) { i in
                    let filled = i < done
                    Circle()
                        .fill(filled ? Color.accentColor : Color.secondary.opacity(0.18))
                        .frame(width: 11, height: 11)
                        .contextMenu {
                            if i < log.loggedSets.count {
                                let s = log.loggedSets[i]
                                Text(s.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
                            }
                        }
                        .accessibilityLabel(filled ? "Set \(i + 1) logged" : "Set \(i + 1) pending")
                }
            }
        }
    }

    @ViewBuilder
    private func planAndCompletionRow(log: ExerciseLog) -> some View {
        HStack(spacing: 12) {
            setProgressIndicatorStrip(log: log)
            Spacer(minLength: 8)
            if let exId = log.workoutExercise.exerciseId {
                if isExerciseCompleted(log) {
                    Button {
                        currentVM.markExerciseNotCompleted(exerciseId: exId)
                    } label: {
                        Label("Undo done", systemImage: "arrow.uturn.backward.circle")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.orange)
                } else {
                    Button {
                        currentVM.markExerciseCompleted(exerciseId: exId)
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                }
            }
        }
    }

    @ViewBuilder
    private func currentAndPreviousSetsSection(
        exerciseIndex: Int,
        log: ExerciseLog,
        previousLog: ExerciseLog?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sets")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let previousLog {
                    matchOrBeatPreviousRow(
                        log: log,
                        exerciseIndex: exerciseIndex,
                        previousLog: previousLog,
                        includeListRowInsets: false
                    )
                }
            }

            currentLoggedSetsList(exerciseIndex: exerciseIndex, log: log)

            let chartSuggestion = inlineProgressionSuggestion(for: log)
            ExercisePerformanceChart(
                loggedSets: log.loggedSets,
                unit: userPreferences.weightDisplayUnit,
                suggestion: chartSuggestion
            )

            if let previousLog {
                previousSessionSummaryRow(previousLog: previousLog, includeListRowInsets: false)
            }
        }
    }

    @ViewBuilder
    private func currentLoggedSetsList(exerciseIndex: Int, log: ExerciseLog) -> some View {
        if log.loggedSets.isEmpty {
            Text("No sets logged yet")
                .foregroundStyle(.secondary)
                .italic()
        } else {
            VStack(spacing: 6) {
                ForEach(Array(log.loggedSets.enumerated()), id: \.element.id) { setIndex, set in
                    interactiveLoggedSetRow(
                        exerciseIndex: exerciseIndex,
                        setIndex: setIndex,
                        chronologicalSetNumber: setIndex + 1,
                        set: set,
                        workoutExercise: log.workoutExercise,
                        isHighlighted: set.id == highlightedLoggedSetId,
                        onDelete: {
                            deleteLoggedSet(
                                exerciseIndex: exerciseIndex,
                                setIndex: setIndex,
                                set: set
                            )
                        }
                    )
                }
            }
        }
    }

    private func matchOrBeatPreviousRow(
        log: ExerciseLog,
        exerciseIndex: Int,
        previousLog: ExerciseLog,
        includeListRowInsets: Bool = true
    ) -> some View {
        let content = HStack(spacing: 10) {
            Button("Match previous") {
                applyMatchPrevious(log: log, exerciseIndex: exerciseIndex, previousLog: previousLog)
            }
            .buttonStyle(.bordered)
            if let sug = dataVM.progressionSuggestion(for: log.workoutExercise), sug.direction == .increase {
                Button("Beat previous") {
                    applyBeatPrevious(log: log, exerciseIndex: exerciseIndex, suggestion: sug)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        return Group {
            if includeListRowInsets {
                content.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 4, trailing: 16))
            } else {
                content
            }
        }
    }

    private func applyMatchPrevious(log: ExerciseLog, exerciseIndex: Int, previousLog: ExerciseLog) {
        let lid = log.id
        let workingSets = previousLog.loggedSets
            .filter { $0.countsTowardLoadPRMetrics }
            .sorted { $0.timestamp < $1.timestamp }
        let nextIdx = currentVM.currentSession?.exerciseLogs[exerciseIndex].loggedSets.count ?? 0
        let target: LoggedSet? = {
            if nextIdx < workingSets.count { return workingSets[nextIdx] }
            return workingSets.last
        }()
        guard let t = target else { return }
        let unit = userPreferences.weightDisplayUnit
        let netDisplay = clampSignedNetDisplayForUser(
            WeightStoreConversion.displayValue(storedPounds: t.weight, unit: unit)
        )
        if netDisplay <= 0 {
            draftStore.bodyweightModeLogIds.insert(lid)
            draftStore.bodyweightAddedByLogId[lid] = 0
            draftStore.bodyweightAssistedByLogId[lid] = netDisplay < 0
                ? WeightStoreConversion.clampNonNegativeDisplay(-netDisplay, unit: unit)
                : 0
            draftStore.weightByLogId[lid] = 0
        } else {
            draftStore.bodyweightModeLogIds.remove(lid)
            draftStore.bodyweightAddedByLogId.removeValue(forKey: lid)
            draftStore.bodyweightAssistedByLogId.removeValue(forKey: lid)
            draftStore.weightByLogId[lid] = WeightStoreConversion.clampNonNegativeDisplay(netDisplay, unit: unit)
        }
        draftStore.repsByLogId[lid] = t.reps
        seedInlineText(for: lid)
        draftStore.initializedLogIds.insert(lid)
    }

    private func applyBeatPrevious(log: ExerciseLog, exerciseIndex: Int, suggestion: ProgressionSuggestion) {
        let lid = log.id
        let unit = userPreferences.weightDisplayUnit
        if let w = suggestion.suggestedWeight {
            let netDisplay = clampSignedNetDisplayForUser(
                WeightStoreConversion.displayValue(storedPounds: w, unit: unit)
            )
            if netDisplay <= 0 {
                draftStore.bodyweightModeLogIds.insert(lid)
                draftStore.bodyweightAddedByLogId[lid] = 0
                draftStore.bodyweightAssistedByLogId[lid] = netDisplay < 0
                    ? WeightStoreConversion.clampNonNegativeDisplay(-netDisplay, unit: unit)
                    : 0
                draftStore.weightByLogId[lid] = 0
            } else {
                draftStore.bodyweightModeLogIds.remove(lid)
                draftStore.bodyweightAddedByLogId.removeValue(forKey: lid)
                draftStore.bodyweightAssistedByLogId.removeValue(forKey: lid)
                draftStore.weightByLogId[lid] = WeightStoreConversion.clampNonNegativeDisplay(netDisplay, unit: unit)
            }
        }
        let reps = parseRepsTarget(suggestion.targetReps)
        if reps > 0 {
            draftStore.repsByLogId[lid] = reps
        }
        seedInlineText(for: lid)
        draftStore.initializedLogIds.insert(lid)
    }

    private func parseRepsTarget(_ text: String) -> Int {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = t.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }.compactMap { Int($0) }
        if parts.count >= 2 {
            return (parts[0] + parts[1]) / 2
        }
        if let n = parts.first { return n }
        return Int(t) ?? 0
    }

    private func triggerHighlightForLastSet(exerciseIndex: Int) {
        guard let logs = currentVM.currentSession?.exerciseLogs,
              exerciseIndex < logs.count,
              let id = logs[exerciseIndex].loggedSets.last?.id
        else { return }
        highlightedLoggedSetId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            if highlightedLoggedSetId == id {
                highlightedLoggedSetId = nil
            }
        }
    }

    /// Returns the most recent completed `ExerciseLog` for this exercise:
    /// - Prefer sessions from the same workout as the current session.
    /// - If none exist, fall back to any workout that includes the exercise.
    private func lastCompletedLog(for currentLog: ExerciseLog) -> ExerciseLog? {
        guard let currentWorkoutId = currentVM.currentSession?.workout.id else {
            return nil
        }
        let allSessions = dataVM.completedSessions

        let matchIds: Set<UUID> = {
            var s = Set<UUID>()
            if let eid = currentLog.workoutExercise.exerciseId { s.insert(eid) }
            if let sid = currentLog.workoutExercise.snapshot?.exerciseId { s.insert(sid) }
            return s
        }()
        guard !matchIds.isEmpty else { return nil }

        func logMatchesPastEntry(_ log: ExerciseLog) -> Bool {
            if let eid = log.workoutExercise.exerciseId, matchIds.contains(eid) { return true }
            if let sid = log.workoutExercise.snapshot?.exerciseId, matchIds.contains(sid) { return true }
            return false
        }

        func latestLog(in sessions: [WorkoutSession]) -> ExerciseLog? {
            var latest: (ExerciseLog, Date)?

            for session in sessions {
                for log in session.exerciseLogs where logMatchesPastEntry(log) {
                    // Only consider logs that actually have sets logged.
                    guard let lastSetTime = log.loggedSets.max(by: { $0.timestamp < $1.timestamp })?.timestamp else {
                        continue
                    }

                    if let existing = latest {
                        if lastSetTime > existing.1 {
                            latest = (log, lastSetTime)
                        }
                    } else {
                        latest = (log, lastSetTime)
                    }
                }
            }

            return latest?.0
        }

        // 1. Prefer sessions from the same workout template.
        let sameWorkoutSessions = allSessions.filter { $0.workout.id == currentWorkoutId }
        if let log = latestLog(in: sameWorkoutSessions) {
            return log
        }

        // 2. Fall back to any workout that includes this exercise.
        return latestLog(in: allSessions)
    }
    
    private func previousSessionSummaryRow(previousLog: ExerciseLog, includeListRowInsets: Bool = true) -> some View {
        let we = previousLog.workoutExercise
        let body = VStack(alignment: .leading, spacing: 6) {
            Text("Last time for this exercise")
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(previousLog.loggedSets.indices, id: \.self) { prevIndex in
                let prevSet = previousLog.loggedSets[prevIndex]
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Set \(prevIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let badge = prevSet.setTypeBadgeLabel {
                            Text(badge)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(chipColor(for: prevSet.setType).opacity(0.18))
                                .foregroundStyle(chipColor(for: prevSet.setType))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text(prevSet.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
                            .font(.caption)
                        Text("• \(prevSet.restTime)s rest")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !prevSet.configurationSummary(fieldNames: we.configurationFields).isEmpty {
                        Text(prevSet.configurationSummary(fieldNames: we.configurationFields))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))

        return Group {
            if includeListRowInsets {
                body.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else {
                body
            }
        }
    }

    private func setRow(set: LoggedSet, workoutExercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(
                    set.isCardioEntry
                        ? set.cardioDisplaySummary
                        : set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit)
                )
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let badge = set.setTypeBadgeLabel {
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(chipColor(for: set.setType).opacity(0.18))
                        .foregroundStyle(chipColor(for: set.setType))
                        .clipShape(Capsule())
                }
                Spacer()
                if let rpeLabel = loggedSetRpeLabel(set) {
                    Text(rpeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Rest: \(set.restTime)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !set.configurationSummary(fieldNames: workoutExercise.configurationFields).isEmpty {
                Text(set.configurationSummary(fieldNames: workoutExercise.configurationFields))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loggedSetRpeLabel(_ set: LoggedSet) -> String? {
        guard let r = set.rpe else { return nil }
        if abs(r.truncatingRemainder(dividingBy: 1)) < 0.001 {
            return "RPE \(Int(r))"
        }
        return String(format: "RPE %.1f", r)
    }

    /// Shows the recommended configuration for each set in this workout, if any.
    private func recommendedConfigurationRow(for workoutExercise: WorkoutExercise, includeListRowInsets: Bool = true) -> some View {
        let body = VStack(alignment: .leading, spacing: 6) {
            Text("Recommended configuration for this workout")
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(Array(0..<workoutExercise.recommendedSets), id: \.self) { setIndex in
                let summary = configurationSummaryForSet(workoutExercise: workoutExercise, setIndex: setIndex)
                HStack(alignment: .top, spacing: 8) {
                    Text("Set \(setIndex + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .leading)
                    if summary.isEmpty {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))

        return Group {
            if includeListRowInsets {
                body.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else {
                body
            }
        }
    }

    private func configurationSummaryForSet(workoutExercise: WorkoutExercise, setIndex: Int) -> String {
        guard setIndex < workoutExercise.recommendedConfigBySet.count else { return "" }
        let config = workoutExercise.recommendedConfigBySet[setIndex]
        guard !config.isEmpty else { return "" }
        let parts: [String] = workoutExercise.configurationFields.compactMap { (field: String) -> String? in
            guard let value = config[field], !value.isEmpty else { return nil }
            return "\(field): \(value)"
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Status helpers

    private func isExerciseActive(_ log: ExerciseLog) -> Bool {
        guard let session = currentVM.currentSession,
              let id = log.workoutExercise.exerciseId else { return false }
        return session.activeExerciseIds.contains(id)
    }

    private func isExerciseCompleted(_ log: ExerciseLog) -> Bool {
        guard let session = currentVM.currentSession,
              let id = log.workoutExercise.exerciseId else { return false }
        return session.completedExerciseIds.contains(id)
    }

    private func isPrimaryExercise(_ log: ExerciseLog) -> Bool {
        guard let session = currentVM.currentSession,
              let id = log.workoutExercise.exerciseId else { return false }
        return session.activeExerciseIds.first == id
    }

    private func statusDot(for log: ExerciseLog) -> some View {
        let color: Color
        if isExerciseCompleted(log) {
            color = .gray
        } else if isPrimaryExercise(log) {
            color = .green
        } else if isExerciseActive(log) {
            color = .blue
        } else if !log.loggedSets.isEmpty {
            color = .orange
        } else {
            color = .secondary
        }
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func chipColor(for setType: ExerciseSetType) -> Color {
        switch setType {
        case .warmup: return .orange
        case .dropSet: return .purple
        case .failure: return .red
        case .timed: return .cyan
        case .amrap: return FitlogPalette.highlight
        case .working: return .secondary
        case .intervalWork: return FitlogPalette.chartSecondary
        case .intervalRest: return FitlogPalette.caution
        case .steadyState: return FitlogPalette.success
        }
    }

    private func statusSupersetToggleTitle(for log: ExerciseLog) -> String {
        isExerciseActive(log) ? "Remove from superset" : "Add to superset"
    }
}

// MARK: - Finish guard dialogs (extracted for Swift type-checker)

private struct PullUpFinishGuardAlerts: ViewModifier {
    @Binding var showFinishConfirmation: Bool
    @Binding var showFinishEmptyConfirm: Bool
    let unresolvedExerciseNames: [String]
    let onProceedAfterUnresolved: () -> Void
    let onProceedAfterEmpty: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Finish workout?", isPresented: $showFinishConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Finish anyway", role: .destructive, action: onProceedAfterUnresolved)
            } message: {
                Text("These exercises have no sets logged: \(unresolvedExerciseNames.joined(separator: ", ")).")
            }
            .confirmationDialog(
                "Finish without logging any sets?",
                isPresented: $showFinishEmptyConfirm,
                titleVisibility: .visible
            ) {
                Button("Finish anyway", role: .destructive, action: onProceedAfterEmpty)
                Button("Cancel", role: .cancel) {}
            }
    }
}
