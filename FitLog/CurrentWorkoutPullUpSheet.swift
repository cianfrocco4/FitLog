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
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
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
                    score = TemplateSwapExerciseSimilarity.score(
                        candidate: ex,
                        baseline: b,
                        slotMuscleMatch: matchesSlot(ex)
                    )
                } else if let s = slot {
                    score = TemplateSwapExerciseSimilarity.scoreFromSlotOnly(
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
            let tier = TemplateSwapExerciseSimilarity.tierLabel(score: pair.score)
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
                Text(TemplateSwapExerciseSimilarity.matchSummary(
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

// MARK: - Swap similarity (template session)

private enum TemplateSwapExerciseSimilarity {
    static func score(candidate: Exercise, baseline: Exercise, slotMuscleMatch: Bool) -> Int {
        var s = 0
        switch (baseline.movementPattern, candidate.movementPattern) {
        case let (b?, c?) where b == c:
            s += 100
        case (nil, nil):
            s += 8
        default:
            break
        }
        if candidate.exerciseRole == baseline.exerciseRole {
            s += 50
        }
        let bM = Set(baseline.targetedMuscles)
        let cM = Set(candidate.targetedMuscles)
        let overlap = bM.intersection(cM)
        s += min(overlap.count * 18, 72)
        if let bf = baseline.targetedMuscles.first, let cf = candidate.targetedMuscles.first, bf == cf {
            s += 38
        }
        if slotMuscleMatch {
            s += 45
        }
        return s
    }

    static func scoreFromSlotOnly(candidate: Exercise, slot: TemplateSlot, slotMuscleMatch: Bool) -> Int {
        var s = 0
        if slotMuscleMatch { s += 55 }
        if let sp = slot.movementPattern, let cp = candidate.movementPattern, sp == cp {
            s += 100
        }
        if let sr = slot.exerciseRole, candidate.exerciseRole == sr {
            s += 50
        }
        let sM = Set(slot.targetedMuscles)
        let cM = Set(candidate.targetedMuscles)
        s += min(sM.intersection(cM).count * 18, 72)
        if let sf = slot.targetedMuscles.first, let cf = candidate.targetedMuscles.first, sf == cf {
            s += 38
        }
        return s
    }

    static func tierLabel(score: Int) -> String {
        switch score {
        case 165...:
            return "Strong matches"
        case 98..<165:
            return "Good matches"
        case 42..<98:
            return "Partial matches"
        default:
            return "Weaker matches"
        }
    }

    static func matchSummary(
        candidate: Exercise,
        baseline: Exercise?,
        slot: TemplateSlot?,
        slotMuscleMatch: Bool
    ) -> String {
        var parts: [String] = []
        if let b = baseline {
            if let bp = b.movementPattern, let cp = candidate.movementPattern, bp == cp {
                parts.append("Same pattern (\(bp.rawValue))")
            }
            if b.exerciseRole == candidate.exerciseRole {
                parts.append("Same role (\(b.exerciseRole.rawValue))")
            }
            let shared = Set(b.targetedMuscles).intersection(Set(candidate.targetedMuscles))
            if !shared.isEmpty {
                let names = shared.map(\.rawValue).sorted().joined(separator: ", ")
                parts.append("Shared muscles: \(names)")
            }
        } else if let slot {
            if let sp = slot.movementPattern, let cp = candidate.movementPattern, sp == cp {
                parts.append("Matches slot pattern (\(sp.rawValue))")
            }
            if let sr = slot.exerciseRole, candidate.exerciseRole == sr {
                parts.append("Matches slot role (\(sr.rawValue))")
            }
            let shared = Set(slot.targetedMuscles).intersection(Set(candidate.targetedMuscles))
            if !shared.isEmpty {
                let names = shared.map(\.rawValue).sorted().joined(separator: ", ")
                parts.append("Overlaps slot muscles: \(names)")
            }
        }
        if slotMuscleMatch {
            parts.append("Fits slot muscle filter")
        }
        if parts.isEmpty {
            return "Different movement profile — listed as a broader option"
        }
        return parts.joined(separator: " · ")
    }
}

private enum PullUpNumericFieldFocus: Hashable {
    case inlineWeight(UUID)
    case inlineReps(UUID)
    case editWeight
    case editReps
}

struct CurrentWorkoutPullUpSheet: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.dismiss) var dismiss
    @Environment(\.undoManager) private var undoManager

    @FocusState private var numericFieldFocus: PullUpNumericFieldFocus?
    
    @State private var expandedExerciseIndex: Int? = nil
    @State private var logSetSheetSelection: LogSetSheetSelection?
    @State private var resolveSlotSelection: ResolveSlotWE?
    @State private var showFinishConfirmation = false
    @State private var showDiscardWorkoutConfirmation = false
    @State private var showQuickAddExercise = false
    @State private var showFullAddExercise = false
    @State private var showPRBanner = false
    @State private var exerciseListEditMode = EditMode.inactive

    /// Inline quick-log draft per exercise log (stable across reorder).
    @State private var inlineWeightByLogId: [UUID: Double] = [:]
    @State private var inlineRepsByLogId: [UUID: Int] = [:]
    @State private var inlineInitializedLogIds: Set<UUID> = []

    /// Inline edit for an existing set (array indices; stable until list mutates).
    @State private var editingSetExerciseIndex: Int?
    @State private var editingSetIndex: Int?
    @State private var editingSetId: UUID?
    @State private var editWeightDisplay: Double = 0
    @State private var editReps: Int = 0

    /// Shown briefly after auto-advance when rest completes.
    @State private var restCompleteBannerMessage: String?

    /// Brief highlight on the most recently logged set (chronological list).
    @State private var highlightedLoggedSetId: UUID?
    /// Optional RPE 6–10 for inline quick log (absent key = not recorded).
    @State private var inlineRpeByLogId: [UUID: Double] = [:]
    @State private var inlineRpeExpandedLogIds: Set<UUID> = []
    /// Collapsed by default so the expanded exercise shows a simple “log next set → sets” flow first.
    @State private var exerciseDetailMoreExpandedLogId: UUID?

    private var activeSessionWorkout: Workout? {
        currentVM.currentSession?.workout
    }

    private var isFlexibleLibrarySession: Bool {
        guard let origin = currentVM.currentSession?.sessionPlanOrigin,
              case .workout(let libraryId) = origin,
              let lib = dataVM.workout(id: libraryId) else { return false }
        return lib.hasFlexibleSlots
    }

    private var isReorderModeActive: Bool {
        exerciseListEditMode == .active
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Rest timer — compact strip
                if currentVM.remainingRestTime > 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .foregroundStyle(.orange)
                        Text("Rest")
                            .font(.subheadline.weight(.semibold))
                        Text("\(currentVM.remainingRestTime)s")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Skip") {
                            currentVM.cancelRestTimer()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Workout name + timer + pause/play
                if let session = currentVM.currentSession {
                    VStack(spacing: 10) {
                        Text(session.workout.name)
                            .font(.title2.bold())
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(currentVM.workoutElapsedFormatted)
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.medium)
                            }
                            Button {
                                if currentVM.isWorkoutPaused {
                                    currentVM.resumeWorkout()
                                } else {
                                    currentVM.pauseWorkout()
                                }
                            } label: {
                                Label(currentVM.isWorkoutPaused ? "Resume" : "Pause", systemImage: currentVM.isWorkoutPaused ? "play.fill" : "pause.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(currentVM.isWorkoutPaused ? .green : .orange)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, currentVM.remainingRestTime > 0 ? 0 : 16)
                    .padding(.horizontal)

                    TextField("Workout notes (optional)", text: Binding(
                        get: { currentVM.currentSession?.sessionNotes ?? "" },
                        set: { currentVM.setSessionNotes($0) }
                    ), axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .padding(.horizontal)
                }

                unresolvedSlotsBanner
                prBanner
                restCompleteNextUpBanner

                exercisePillStrip

                ScrollViewReader { scrollProxy in
                    List {
                        Section {
                            Button {
                                showQuickAddExercise = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add exercise")
                                            .font(.headline)
                                        Text("Suggestions match muscles you're already doing; favorites and recent are one tap away.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }

                        if let exerciseLogs = currentVM.currentSession?.exerciseLogs, !exerciseLogs.isEmpty {
                            ForEach(Array(exerciseLogs.enumerated()), id: \.element.id) { index, log in
                                let isExpanded = expandedExerciseIndex == index

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
                                                removeExerciseAtListIndex(index, rowId: log.workoutExercise.id)
                                            }
                                        }
                                    } else {
                                        Button {
                                            guard !isReorderModeActive else { return }
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                expandedExerciseIndex = isExpanded ? nil : index
                                            }
                                        } label: {
                                            exerciseCollapsedHeader(log: log, isExpanded: isExpanded)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.primary)
                                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                            if let slotId = currentVM.currentSession?.workout.templateSlotId(forWorkoutExerciseRow: log.workoutExercise.id),
                                               log.workoutExercise.exerciseId != nil {
                                                Button {
                                                    resolveSlotSelection = ResolveSlotWE(
                                                        workoutExerciseId: log.workoutExercise.id,
                                                        templateSlotId: slotId,
                                                        isSwapExercise: true
                                                    )
                                                } label: {
                                                    Label("Swap", systemImage: "arrow.triangle.2.circlepath")
                                                }
                                                .tint(.indigo)
                                            }
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button("Remove", role: .destructive) {
                                                removeExerciseAtListIndex(index, rowId: log.workoutExercise.id)
                                            }
                                        }
                                    }
                                    if isExpanded && !log.workoutExercise.isSlotPlaceholder && !isReorderModeActive {
                                        setProgressIndicatorStrip(log: log)
                                            .moveDisabled(true)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                                        inlineSetEntryRow(exerciseIndex: index, log: log)
                                            .moveDisabled(true)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                                        if log.loggedSets.isEmpty {
                                            Text("No sets logged yet")
                                                .moveDisabled(true)
                                                .foregroundStyle(.secondary)
                                                .italic()
                                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        } else {
                                            ForEach(Array(log.loggedSets.enumerated()), id: \.element.id) { setIndex, set in
                                                interactiveLoggedSetRow(
                                                    exerciseIndex: index,
                                                    setIndex: setIndex,
                                                    chronologicalSetNumber: setIndex + 1,
                                                    set: set,
                                                    workoutExercise: log.workoutExercise,
                                                    isHighlighted: set.id == highlightedLoggedSetId
                                                )
                                                .moveDisabled(true)
                                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                    Button("Delete", role: .destructive) {
                                                        clearEditingSetIfNeeded(setId: set.id)
                                                        currentVM.deleteSet(exerciseIndex: index, setIndex: setIndex)
                                                    }
                                                }
                                            }
                                        }

                                        DisclosureGroup(isExpanded: Binding(
                                            get: { exerciseDetailMoreExpandedLogId == log.id },
                                            set: { exerciseDetailMoreExpandedLogId = $0 ? log.id : nil }
                                        )) {
                                            VStack(alignment: .leading, spacing: 12) {
                                                if let previousLog = lastCompletedLog(for: log) {
                                                    matchOrBeatPreviousRow(
                                                        log: log,
                                                        exerciseIndex: index,
                                                        previousLog: previousLog,
                                                        includeListRowInsets: false
                                                    )
                                                    previousSessionSummaryRow(previousLog: previousLog, includeListRowInsets: false)
                                                }

                                                if !log.workoutExercise.configurationFields.isEmpty {
                                                    recommendedConfigurationRow(for: log.workoutExercise, includeListRowInsets: false)
                                                }

                                                TextField("Notes for this exercise", text: Binding(
                                                    get: {
                                                        guard let logs = currentVM.currentSession?.exerciseLogs,
                                                              logs.indices.contains(index)
                                                        else { return "" }
                                                        return logs[index].notes
                                                    },
                                                    set: { newText in
                                                        guard let logs = currentVM.currentSession?.exerciseLogs,
                                                              logs.indices.contains(index)
                                                        else { return }
                                                        currentVM.setExerciseLogNotes(at: index, notes: newText)
                                                    }
                                                ), axis: .vertical)
                                                .lineLimit(2...4)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.subheadline)

                                                HStack(spacing: 12) {
                                                    Button("Repeat last") {
                                                        currentVM.repeatLastSet(exerciseIndex: index)
                                                        syncInlineDraftAfterLog(for: log.id, exerciseIndex: index)
                                                        triggerHighlightForLastSet(exerciseIndex: index)
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
                                                            removeExerciseAtListIndex(index, rowId: log.workoutExercise.id)
                                                        }
                                                    } label: {
                                                        Label("More", systemImage: "ellipsis.circle")
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.vertical, 4)
                                        } label: {
                                            Label("History, notes, and actions", systemImage: "text.alignleft")
                                                .font(.subheadline.weight(.medium))
                                        }
                                        .moveDisabled(true)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                                    }
                                }
                                .id(log.id)
                            }
                            .onMove { source, destination in
                                let logs = currentVM.currentSession?.exerciseLogs ?? []
                                guard !logs.isEmpty else { return }
                                let safeSource = IndexSet(source.filter { $0 >= 0 && $0 < logs.count })
                                guard !safeSource.isEmpty else { return }
                                let safeDestination = min(max(0, destination), logs.count)
                                let expandedId = expandedExerciseIndex.flatMap { logs.indices.contains($0) ? logs[$0].id : nil }
                                let logSheetId = logSetSheetSelection.flatMap { sel in
                                    logs.indices.contains(sel.exerciseIndex) ? logs[sel.exerciseIndex].id : nil
                                }
                                DispatchQueue.main.async {
                                    currentVM.moveExerciseLogs(fromOffsets: safeSource, toOffset: safeDestination)
                                    guard let newLogs = currentVM.currentSession?.exerciseLogs else { return }
                                    if let eid = expandedId, let ni = newLogs.firstIndex(where: { $0.id == eid }) {
                                        expandedExerciseIndex = ni
                                    }
                                    if let lid = logSheetId, let ni = newLogs.firstIndex(where: { $0.id == lid }) {
                                        logSetSheetSelection = LogSetSheetSelection(exerciseIndex: ni)
                                    }
                                }
                            }
                        } else {
                            Section {
                                Text("No exercises in current session")
                                    .foregroundStyle(.secondary)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }
                    }
                    .environment(\.editMode, $exerciseListEditMode)
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                    .keyboardDismissToolbar()
                    .onChange(of: expandedExerciseIndex) { _, newValue in
                        exerciseDetailMoreExpandedLogId = nil
                        initializeInlineDraftIfNeeded(forExpandedIndex: newValue)
                        guard let idx = newValue,
                              let logs = currentVM.currentSession?.exerciseLogs,
                              idx < logs.count else { return }
                        let targetId = logs[idx].id
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scrollProxy.scrollTo(targetId, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: exerciseListEditMode) { _, mode in
                        guard mode == .active else { return }
                        expandedExerciseIndex = nil
                        exerciseDetailMoreExpandedLogId = nil
                        logSetSheetSelection = nil
                    }
                }
            }
            .navigationTitle("Current Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard") {
                        showDiscardWorkoutConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(exerciseListEditMode == .active ? "Done" : "Reorder") {
                        withAnimation {
                            if exerciseListEditMode != .active {
                                expandedExerciseIndex = nil
                                logSetSheetSelection = nil
                                exerciseDetailMoreExpandedLogId = nil
                                fitlogDismissKeyboard()
                                numericFieldFocus = nil
                            }
                            exerciseListEditMode = exerciseListEditMode == .active ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        if resolvedExercisesWithNoSets.isEmpty {
                            finishWorkout()
                        } else {
                            showFinishConfirmation = true
                        }
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
                    prefillReps: selection.prefillReps
                )
                .environmentObject(dataVM)
                .environmentObject(userPreferences)
            }
            .sheet(item: $resolveSlotSelection) { sel in
                NavigationStack {
                    ResolveSlotExerciseSheet(
                        workoutExerciseId: sel.workoutExerciseId,
                        templateSlotId: sel.templateSlotId,
                        isSwapExercise: sel.isSwapExercise
                    )
                    .environmentObject(dataVM)
                    .environmentObject(currentVM)
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
            .sheet(isPresented: $showFullAddExercise) {
                if let w = activeSessionWorkout {
                    AddExerciseSheet(workout: w, currentVM: currentVM)
                        .environmentObject(dataVM)
                        .environmentObject(aiService)
                }
            }
            .alert("Finish workout?", isPresented: $showFinishConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Finish anyway", role: .destructive) {
                    finishWorkout()
                }
            } message: {
                Text("These exercises have no sets logged: \(resolvedExercisesWithNoSets.joined(separator: ", ")).")
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
                guard newValue != nil else {
                    showPRBanner = false
                    return
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showPRBanner = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showPRBanner = false
                    }
                }
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
        }
    }

    private var resolvedExercisesWithNoSets: [String] {
        guard let logs = currentVM.currentSession?.exerciseLogs else { return [] }
        return logs.compactMap { log in
            guard !log.workoutExercise.isSlotPlaceholder, log.loggedSets.isEmpty else { return nil }
            return dataVM.displayName(for: log.workoutExercise)
        }
    }

    private func finishWorkout() {
        currentVM.stopWorkout(showCompletionSummary: true)
        dismiss()
    }

    private func removeExerciseAtListIndex(_ index: Int, rowId: UUID) {
        if let session = currentVM.currentSession, session.exerciseLogs.indices.contains(index) {
            let lid = session.exerciseLogs[index].id
            inlineWeightByLogId.removeValue(forKey: lid)
            inlineRepsByLogId.removeValue(forKey: lid)
            inlineInitializedLogIds.remove(lid)
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

    /// Auto-advance focus when rest hits zero; show a short banner then clear VM alert flag.
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
        guard !inlineInitializedLogIds.contains(lid) else { return }
        let (w, r) = prefillInlineWeightReps(for: log)
        inlineWeightByLogId[lid] = w
        inlineRepsByLogId[lid] = r
        inlineInitializedLogIds.insert(lid)
    }

    private func clampDisplayWeightForUser(_ w: Double) -> Double {
        let r = WeightStoreConversion.displayRange(unit: userPreferences.weightDisplayUnit)
        guard w.isFinite else { return 0 }
        return min(r.upperBound, max(r.lowerBound, w))
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
        let r = inlineRepsByLogId[logId] ?? 0
        guard r > 0 else { return }

        let restBase = suggestedRestSecondsForNextSet(exerciseLog: exerciseLog, exerciseIndex: exerciseIndex)
        let effectiveRest = supersetRestAppliesAfterThisSet(exerciseIndex: exerciseIndex) ? restBase : 0

        let unit = userPreferences.weightDisplayUnit
        let wDisplay = inlineWeightByLogId[logId] ?? 0
        let stored = WeightStoreConversion.storedPounds(
            displayValue: clampDisplayWeightForUser(wDisplay),
            unit: unit
        )
        let rpeVal: Double? = inlineRpeByLogId[logId]

        currentVM.logSet(
            exerciseIndex: exerciseIndex,
            weight: stored,
            reps: r,
            restTime: effectiveRest,
            isWarmup: false,
            configuration: inlineConfiguration(for: exerciseLog),
            dropSegments: [],
            rpe: rpeVal
        )
        syncInlineDraftAfterLog(for: logId, exerciseIndex: exerciseIndex)
        triggerHighlightForLastSet(exerciseIndex: exerciseIndex)
    }

    private func syncInlineDraftAfterLog(for logId: UUID, exerciseIndex: Int) {
        guard let logs = currentVM.currentSession?.exerciseLogs,
              exerciseIndex < logs.count,
              logs[exerciseIndex].id == logId,
              let last = logs[exerciseIndex].loggedSets.last
        else { return }
        let unit = userPreferences.weightDisplayUnit
        inlineWeightByLogId[logId] = clampDisplayWeightForUser(
            WeightStoreConversion.displayValue(storedPounds: last.weight, unit: unit)
        )
        inlineRepsByLogId[logId] = last.reps
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
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func inlineSetEntryRow(exerciseIndex: Int, log: ExerciseLog) -> some View {
        let logId = log.id
        let unit = userPreferences.weightDisplayUnit
        let unitLabel = unit.shortLabel
        let weightBinding = Binding<Double>(
            get: { inlineWeightByLogId[logId] ?? 0 },
            set: { inlineWeightByLogId[logId] = clampDisplayWeightForUser($0) }
        )
        let repsBinding = Binding<Int>(
            get: { inlineRepsByLogId[logId] ?? 0 },
            set: { inlineRepsByLogId[logId] = min(50, max(0, $0)) }
        )
        /// Single compact row: ~44pt tall fields without stacking actions underneath.
        let fieldPadding = EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)

        VStack(alignment: .leading, spacing: 6) {
            Text("Next set")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 6) {
                TextField("Wt", value: weightBinding, format: .number.precision(.fractionLength(0...2)))
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
                TextField("Reps", value: repsBinding, format: .number)
                    .keyboardType(.numberPad)
                    .focused($numericFieldFocus, equals: .inlineReps(logId))
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 44, minHeight: 36)
                    .padding(fieldPadding)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("Log") {
                    fitlogDismissKeyboard()
                    numericFieldFocus = nil
                    inlineQuickLog(exerciseIndex: exerciseIndex, logId: logId)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled((inlineRepsByLogId[logId] ?? 0) <= 0)
                Menu {
                    Button("Full log (RPE, drops…)", systemImage: "slider.horizontal.3") {
                        fitlogDismissKeyboard()
                        numericFieldFocus = nil
                        logSetSheetSelection = LogSetSheetSelection(
                            exerciseIndex: exerciseIndex,
                            prefillDisplayWeight: inlineWeightByLogId[logId],
                            prefillReps: inlineRepsByLogId[logId]
                        )
                    }
                    if inlineRpeExpandedLogIds.contains(logId) {
                        Button("Hide quick RPE", systemImage: "gauge.with.dots.needle.67percent") {
                            inlineRpeExpandedLogIds.remove(logId)
                        }
                    } else {
                        Button("Quick RPE (6–10)", systemImage: "gauge.with.dots.needle.67percent") {
                            inlineRpeExpandedLogIds.insert(logId)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 36, minHeight: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More logging options")
            }
            if inlineRpeExpandedLogIds.contains(logId) {
                HStack(spacing: 6) {
                    Button("Clear RPE") {
                        var next = inlineRpeByLogId
                        next.removeValue(forKey: logId)
                        inlineRpeByLogId = next
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption2)
                    ForEach((6...10).reversed(), id: \.self) { n in
                        let d = Double(n)
                        let selected = inlineRpeByLogId[logId] == d
                        Button("\(n)") {
                            var next = inlineRpeByLogId
                            if selected {
                                next.removeValue(forKey: logId)
                            } else {
                                next[logId] = d
                            }
                            inlineRpeByLogId = next
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selected ? .blue : .secondary)
                        .font(.caption.weight(.semibold))
                    }
                }
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
            case .inlineWeight(let id) where id == logId:
                fitlogDismissKeyboard()
                numericFieldFocus = nil
            case .inlineReps(let id) where id == logId:
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
    private func interactiveLoggedSetRow(
        exerciseIndex: Int,
        setIndex: Int,
        chronologicalSetNumber: Int,
        set: LoggedSet,
        workoutExercise: WorkoutExercise,
        isHighlighted: Bool
    ) -> some View {
        if editingSetId == set.id,
           editingSetExerciseIndex == exerciseIndex,
           editingSetIndex == setIndex {
            let fieldPadding = EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)
            VStack(alignment: .leading, spacing: 6) {
                Text("Edit set \(chronologicalSetNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Wt", value: Binding(
                        get: { editWeightDisplay },
                        set: { editWeightDisplay = clampDisplayWeightForUser($0) }
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
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(isHighlighted ? 0.22 : 0))
            )
            .animation(.easeOut(duration: 0.45), value: isHighlighted)
        }
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
        editWeightDisplay = clampDisplayWeightForUser(
            WeightStoreConversion.displayValue(storedPounds: set.weight, unit: unit)
        )
        editReps = set.reps
    }

    private func confirmEditingSet() {
        guard let exIdx = editingSetExerciseIndex, let sIdx = editingSetIndex else { return }
        guard editReps > 0 else { return }
        let unit = userPreferences.weightDisplayUnit
        let stored = WeightStoreConversion.storedPounds(
            displayValue: clampDisplayWeightForUser(editWeightDisplay),
            unit: unit
        )
        currentVM.updateSet(exerciseIndex: exIdx, setIndex: sIdx, weight: stored, reps: editReps)
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
    private var prBanner: some View {
        if showPRBanner, let event = currentVM.recentPersonalRecordEvent {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
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

    @ViewBuilder
    private var exercisePillStrip: some View {
        if let logs = currentVM.currentSession?.exerciseLogs, logs.count >= 2 {
            VStack(spacing: 4) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                                exercisePill(index: index, log: log)
                                    .id(log.id)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: expandedExerciseIndex) { _, newIdx in
                        guard let idx = newIdx,
                              let liveLogs = currentVM.currentSession?.exerciseLogs,
                              idx < liveLogs.count else { return }
                        let targetId = liveLogs[idx].id
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                    }
                }
                if let session = currentVM.currentSession, session.activeExerciseIds.count > 1 {
                    Text("Blue pills = superset. Rest starts after the last exercise in the group.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func exercisePill(index: Int, log: ExerciseLog) -> some View {
        let isSelected = expandedExerciseIndex == index
        let name = abbreviatedName(for: log.workoutExercise)
        let rec = log.workoutExercise.recommendedSets
        let done = log.loggedSets.count
        let isPlaceholder = log.workoutExercise.isSlotPlaceholder
        let isCompleted = isExerciseCompleted(log)
        let inSuperset = isExerciseActive(log)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedExerciseIndex = isSelected ? nil : index
            }
        } label: {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if isPlaceholder {
                    Image(systemName: "square.dashed")
                        .font(.caption2)
                } else if rec > 0 {
                    Text("\(done)/\(rec)")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                } else if done > 0 {
                    Text("\(done)")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pillBackground(isSelected: isSelected, inSuperset: inSuperset))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(inSuperset && !isSelected ? Color.blue.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
            .opacity(isCompleted ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }

    private func pillBackground(isSelected: Bool, inSuperset: Bool) -> Color {
        if isSelected { return Color.accentColor }
        if inSuperset { return Color.blue.opacity(0.12) }
        return Color(.systemGray5)
    }

    private func abbreviatedName(for we: WorkoutExercise) -> String {
        let full = dataVM.displayName(for: we)
        if full.count <= 14 { return full }
        return String(full.prefix(12)) + "…"
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
            .filter { !$0.isWarmup && $0.reps > 0 }
            .sorted { $0.timestamp < $1.timestamp }
        let nextIdx = currentVM.currentSession?.exerciseLogs[exerciseIndex].loggedSets.count ?? 0
        let target: LoggedSet? = {
            if nextIdx < workingSets.count { return workingSets[nextIdx] }
            return workingSets.last
        }()
        guard let t = target else { return }
        let unit = userPreferences.weightDisplayUnit
        inlineWeightByLogId[lid] = clampDisplayWeightForUser(
            WeightStoreConversion.displayValue(storedPounds: t.weight, unit: unit)
        )
        inlineRepsByLogId[lid] = t.reps
        inlineInitializedLogIds.insert(lid)
    }

    private func applyBeatPrevious(log: ExerciseLog, exerciseIndex: Int, suggestion: ProgressionSuggestion) {
        let lid = log.id
        let unit = userPreferences.weightDisplayUnit
        if let w = suggestion.suggestedWeight {
            inlineWeightByLogId[lid] = clampDisplayWeightForUser(
                WeightStoreConversion.displayValue(storedPounds: w, unit: unit)
            )
        }
        let reps = parseRepsTarget(suggestion.targetReps)
        if reps > 0 {
            inlineRepsByLogId[lid] = reps
        }
        inlineInitializedLogIds.insert(lid)
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
                        if prevSet.isWarmup {
                            Text("Warm-up")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
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
                Text(set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if set.isWarmup {
                    Text("Warm-up")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
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

    private func statusSupersetToggleTitle(for log: ExerciseLog) -> String {
        isExerciseActive(log) ? "Remove from superset" : "Add to superset"
    }
}
