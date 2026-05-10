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
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(DataManager.self) var dataVM
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
    @State private var showExerciseReorderSheet = false
    @State private var plateCalculatorInlinePick: PlateCalculatorInlinePick?

    /// Inline quick-log draft per exercise log (stable across reorder).
    @State private var inlineWeightByLogId: [UUID: Double] = [:]
    @State private var inlineRepsByLogId: [UUID: Int] = [:]
    @State private var inlineWeightTextByLogId: [UUID: String] = [:]
    @State private var inlineRepsTextByLogId: [UUID: String] = [:]
    @State private var inlineInitializedLogIds: Set<UUID> = []
    /// Reps-first logging: optional added load minus assisted (display units); persisted as signed net stored weight.
    @State private var inlineBodyweightModeLogIds: Set<UUID> = []
    @State private var inlineBodyweightAddedByLogId: [UUID: Double] = [:]
    @State private var inlineBodyweightAssistedByLogId: [UUID: Double] = [:]
    @State private var inlineBodyweightAddedTextByLogId: [UUID: String] = [:]
    @State private var inlineBodyweightAssistedTextByLogId: [UUID: String] = [:]

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
    /// Optional RPE 6–10 for inline quick log (absent key = not recorded).
    @State private var inlineRpeByLogId: [UUID: Double] = [:]
    @State private var inlineRpeExpandedLogIds: Set<UUID> = []
    /// Collapsed by default so the expanded exercise shows a simple “log next set → sets” flow first.
    @State private var exerciseDetailMoreExpandedLogId: UUID?
    /// After a set is logged, show a transient "Add drop set" affordance for ~5 seconds.
    @State private var dropPromptLogId: UUID?
    @State private var dropPromptExerciseIndex: Int?
    /// Quick exercise swap sheet (long-press on exercise card header).
    @State private var swapSheetExerciseIndex: Int?
    /// PR celebration overlay (replaces the simple in-list banner).
    @State private var celebratedPREvent: PersonalRecordEvent?

    private var activeSessionWorkout: Workout? {
        currentVM.currentSession?.workout
    }

    private var isFlexibleLibrarySession: Bool {
        guard let origin = currentVM.currentSession?.sessionPlanOrigin,
              case .workout(let libraryId) = origin,
              let lib = dataVM.workout(id: libraryId) else { return false }
        return lib.hasFlexibleSlots
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
                        Button("−15") {
                            currentVM.adjustRestCountdown(by: -15)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .font(.caption.weight(.semibold))
                        Button("+15") {
                            currentVM.adjustRestCountdown(by: 15)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .font(.caption.weight(.semibold))
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
                
                // Compact workout header: name, elapsed, and pause/resume in one row.
                if let session = currentVM.currentSession {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.workout.name)
                                .font(.headline.weight(.semibold))
                                .lineLimit(1)
                            HStack(spacing: 5) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(currentVM.workoutElapsedFormatted)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Button {
                            if currentVM.isWorkoutPaused {
                                currentVM.resumeWorkout()
                            } else {
                                currentVM.pauseWorkout()
                            }
                        } label: {
                            Label(currentVM.isWorkoutPaused ? "Resume" : "Pause", systemImage: currentVM.isWorkoutPaused ? "play.fill" : "pause.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(currentVM.isWorkoutPaused ? .green : .orange)
                        .accessibilityLabel(currentVM.isWorkoutPaused ? "Resume workout" : "Pause workout")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, currentVM.remainingRestTime > 0 ? 0 : 16)
                    .padding(.horizontal)

                    sessionRunningStatsStrip(session: session)

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
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    expandedExerciseIndex = isExpanded ? nil : index
                                                }
                                            } label: {
                                                exerciseCollapsedHeader(log: log, isExpanded: isExpanded)
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(.primary)
                                            .contextMenu {
                                                if log.workoutExercise.exerciseId != nil {
                                                    Button("Quick swap exercise", systemImage: "arrow.left.arrow.right") {
                                                        swapSheetExerciseIndex = index
                                                    }
                                                }
                                                if let exId = log.workoutExercise.exerciseId {
                                                    Button(statusSupersetToggleTitle(for: log), systemImage: "bolt.horizontal") {
                                                        currentVM.toggleSupersetExercise(exerciseId: exId)
                                                    }
                                                    Button("Mark completed", systemImage: "checkmark.circle") {
                                                        currentVM.markExerciseCompleted(exerciseId: exId)
                                                    }
                                                }
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                                if let exId = log.workoutExercise.exerciseId, !isExerciseCompleted(log) {
                                                    Button {
                                                        currentVM.markExerciseCompleted(exerciseId: exId)
                                                    } label: {
                                                        Label("Mark done", systemImage: "checkmark.circle.fill")
                                                    }
                                                    .tint(.green)
                                                }
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
                                                if let exId = log.workoutExercise.exerciseId, isExerciseCompleted(log) {
                                                    Button {
                                                        currentVM.markExerciseNotCompleted(exerciseId: exId)
                                                    } label: {
                                                        Label("Undo done", systemImage: "arrow.uturn.backward")
                                                    }
                                                    .tint(.orange)
                                                }
                                                Button("Remove", role: .destructive) {
                                                    removeExerciseAtListIndex(index, rowId: log.workoutExercise.id)
                                                }
                                            }
                                        }
                                        if isExpanded && !log.workoutExercise.isSlotPlaceholder {
                                            planAndCompletionRow(log: log)
                                                .moveDisabled(true)
                                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                                            inlineSetEntryRow(exerciseIndex: index, log: log)
                                                .moveDisabled(true)
                                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                                            currentAndPreviousSetsSection(
                                                exerciseIndex: index,
                                                log: log,
                                                previousLog: lastCompletedLog(for: log)
                                            )
                                            .moveDisabled(true)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))

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
                                                        .textInputAutocapitalization(.sentences)
                                                        // Dictation mic — uses standard keyboard dictation (no extra permission needed)
                                                        Button {
                                                            // Trigger keyboard dictation by toggling focus; the keyboard dictation
                                                            // button remains accessible to the user while the field is focused.
                                                        } label: {
                                                            Image(systemName: "mic.fill")
                                                                .foregroundStyle(.tint)
                                                                .frame(width: 36, height: 36)
                                                        }
                                                        .accessibilityLabel("Dictate note")
                                                        .accessibilityHint("Tap the microphone key on the keyboard to start dictation")
                                                    }

                                                    sessionRestOverrideEditor(exerciseIndex: index, log: log)

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
                                                                Button("Quick swap exercise", systemImage: "arrow.left.arrow.right") {
                                                                        swapSheetExerciseIndex = index
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
                                                Label("Config, notes, and actions", systemImage: "text.alignleft")
                                                    .font(.subheadline.weight(.medium))
                                            }
                                            .moveDisabled(true)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                                        }
                                }
                                .id(log.id)
                            }
                        } else {
                            Section {
                                Text("No exercises in current session")
                                    .foregroundStyle(.secondary)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }
                    }
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
                    Button {
                        showExerciseReorderSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Reorder exercises")
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
                    prefillReps: selection.prefillReps,
                    prefillBodyweightMode: selection.prefillBodyweightMode
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
                if let event = celebratedPREvent {
                    PRCelebrationOverlay(
                        event: event,
                        unit: userPreferences.weightDisplayUnit,
                        onDismiss: { celebratedPREvent = nil }
                    )
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
                        displayNames: dataVM.exerciseLocalDisplayNames
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
                        if inlineBodyweightModeLogIds.contains(pick.logId) {
                            inlineBodyweightAddedByLogId[pick.logId] = clamped
                            inlineBodyweightAssistedByLogId[pick.logId] = 0
                            inlineBodyweightAddedTextByLogId[pick.logId] = formattedInlineWeight(clamped)
                            inlineBodyweightAssistedTextByLogId[pick.logId] = ""
                        } else {
                            inlineWeightByLogId[pick.logId] = clamped
                            inlineWeightTextByLogId[pick.logId] = formattedInlineWeight(clamped)
                        }
                    }
                )
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
        inlineWeightByLogId.removeValue(forKey: logId)
        inlineRepsByLogId.removeValue(forKey: logId)
        inlineWeightTextByLogId.removeValue(forKey: logId)
        inlineRepsTextByLogId.removeValue(forKey: logId)
        inlineInitializedLogIds.remove(logId)
        inlineRpeByLogId.removeValue(forKey: logId)
        inlineRpeExpandedLogIds.remove(logId)
        inlineBodyweightModeLogIds.remove(logId)
        inlineBodyweightAddedByLogId.removeValue(forKey: logId)
        inlineBodyweightAssistedByLogId.removeValue(forKey: logId)
        inlineBodyweightAddedTextByLogId.removeValue(forKey: logId)
        inlineBodyweightAssistedTextByLogId.removeValue(forKey: logId)
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
        inlineRepsByLogId[lid] = r
        let unit = userPreferences.weightDisplayUnit
        if let last = log.loggedSets.last {
            let net = WeightStoreConversion.displayValue(storedPounds: last.weight, unit: unit)
            let netClamped = clampSignedNetDisplayForUser(net)
            if netClamped <= 0 {
                inlineBodyweightModeLogIds.insert(lid)
                inlineBodyweightAddedByLogId[lid] = 0
                inlineBodyweightAssistedByLogId[lid] = netClamped < 0
                    ? WeightStoreConversion.clampNonNegativeDisplay(-netClamped, unit: unit)
                    : 0
                inlineWeightByLogId[lid] = 0
            } else {
                inlineWeightByLogId[lid] = WeightStoreConversion.clampNonNegativeDisplay(netClamped, unit: unit)
            }
        } else {
            inlineWeightByLogId[lid] = w
            if w == 0 {
                inlineBodyweightModeLogIds.insert(lid)
                inlineBodyweightAddedByLogId[lid] = 0
                inlineBodyweightAssistedByLogId[lid] = 0
            }
        }
        seedInlineText(for: lid)
        inlineInitializedLogIds.insert(lid)
    }

    private func clampDisplayWeightForUser(_ w: Double) -> Double {
        WeightStoreConversion.clampNonNegativeDisplay(w, unit: userPreferences.weightDisplayUnit)
    }

    private func clampSignedNetDisplayForUser(_ w: Double) -> Double {
        WeightStoreConversion.clampSignedNetDisplay(w, unit: userPreferences.weightDisplayUnit)
    }

    private func inlineNetDisplayWeight(for logId: UUID) -> Double {
        if inlineBodyweightModeLogIds.contains(logId) {
            let added = WeightStoreConversion.clampNonNegativeDisplay(
                inlineBodyweightAddedByLogId[logId] ?? 0,
                unit: userPreferences.weightDisplayUnit
            )
            let assisted = WeightStoreConversion.clampNonNegativeDisplay(
                inlineBodyweightAssistedByLogId[logId] ?? 0,
                unit: userPreferences.weightDisplayUnit
            )
            return clampSignedNetDisplayForUser(added - assisted)
        }
        return clampDisplayWeightForUser(inlineWeightByLogId[logId] ?? 0)
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
        inlineWeightTextByLogId[logId] = formattedInlineWeight(inlineWeightByLogId[logId] ?? 0)
        inlineRepsTextByLogId[logId] = formattedInlineReps(inlineRepsByLogId[logId] ?? 0)
        inlineBodyweightAddedTextByLogId[logId] = formattedInlineWeight(inlineBodyweightAddedByLogId[logId] ?? 0)
        inlineBodyweightAssistedTextByLogId[logId] = formattedInlineWeight(inlineBodyweightAssistedByLogId[logId] ?? 0)
    }

    private func inlineWeightTextBinding(logId: UUID) -> Binding<String> {
        Binding(
            get: { inlineWeightTextByLogId[logId] ?? "" },
            set: { raw in
                inlineWeightTextByLogId[logId] = raw
                if let value = parseInlineDouble(raw) {
                    inlineWeightByLogId[logId] = clampDisplayWeightForUser(value)
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inlineWeightByLogId[logId] = 0
                }
            }
        )
    }

    private func inlineRepsTextBinding(logId: UUID) -> Binding<String> {
        Binding(
            get: { inlineRepsTextByLogId[logId] ?? "" },
            set: { raw in
                inlineRepsTextByLogId[logId] = raw
                if let value = parseInlineInt(raw) {
                    inlineRepsByLogId[logId] = min(50, max(0, value))
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inlineRepsByLogId[logId] = 0
                }
            }
        )
    }

    private func inlineBodyweightAddedTextBinding(logId: UUID, unit: WeightDisplayUnit) -> Binding<String> {
        Binding(
            get: { inlineBodyweightAddedTextByLogId[logId] ?? "" },
            set: { raw in
                inlineBodyweightAddedTextByLogId[logId] = raw
                if let value = parseInlineDouble(raw) {
                    inlineBodyweightAddedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(value, unit: unit)
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inlineBodyweightAddedByLogId[logId] = 0
                }
            }
        )
    }

    private func inlineBodyweightAssistedTextBinding(logId: UUID, unit: WeightDisplayUnit) -> Binding<String> {
        Binding(
            get: { inlineBodyweightAssistedTextByLogId[logId] ?? "" },
            set: { raw in
                inlineBodyweightAssistedTextByLogId[logId] = raw
                if let value = parseInlineDouble(raw) {
                    inlineBodyweightAssistedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(value, unit: unit)
                } else if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inlineBodyweightAssistedByLogId[logId] = 0
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
        let r = inlineRepsByLogId[logId] ?? 0
        guard r > 0 else { return }

        let restBase = suggestedRestSecondsForNextSet(exerciseLog: exerciseLog, exerciseIndex: exerciseIndex)
        let effectiveRest = supersetRestAppliesAfterThisSet(exerciseIndex: exerciseIndex) ? restBase : 0

        let unit = userPreferences.weightDisplayUnit
        let wDisplay = inlineNetDisplayWeight(for: logId)
        let stored = WeightStoreConversion.storedPounds(
            displayValue: wDisplay,
            unit: unit
        )
        let rpeVal: Double? = inlineRpeByLogId[logId]

        currentVM.logSet(
            exerciseIndex: exerciseIndex,
            weight: stored,
            reps: r,
            restTime: effectiveRest,
            setType: .working,
            configuration: inlineConfiguration(for: exerciseLog),
            dropSegments: [],
            rpe: rpeVal
        )
        syncInlineDraftAfterLog(for: logId, exerciseIndex: exerciseIndex)
        triggerHighlightForLastSet(exerciseIndex: exerciseIndex)
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
        if inlineBodyweightModeLogIds.contains(logId) {
            let clampedNet = clampSignedNetDisplayForUser(netDisplay)
            if clampedNet >= 0 {
                inlineBodyweightAddedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(clampedNet, unit: unit)
                inlineBodyweightAssistedByLogId[logId] = 0
            } else {
                inlineBodyweightAddedByLogId[logId] = 0
                inlineBodyweightAssistedByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(-clampedNet, unit: unit)
            }
            inlineWeightByLogId[logId] = WeightStoreConversion.clampNonNegativeDisplay(max(0, clampedNet), unit: unit)
        } else {
            inlineWeightByLogId[logId] = clampDisplayWeightForUser(netDisplay)
        }
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

    @ViewBuilder
    private func inlineSetEntryRow(exerciseIndex: Int, log: ExerciseLog) -> some View {
        let logId = log.id
        let unit = userPreferences.weightDisplayUnit
        let unitLabel = unit.shortLabel
        let bwMode = inlineBodyweightModeLogIds.contains(logId)
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
        let draftReps = inlineRepsByLogId[logId] ?? 0
        let progressionSuggestion: InlineProgressionTarget? = exId.flatMap { id in
            ProgressionAdvisor.suggest(
                for: log,
                lastWorkingSets: lastWorkingSets,
                exerciseRole: dataVM.globalExercises.first(where: { $0.id == id })?.exerciseRole ?? .accessory
            )
        }
        let prevSessionSets = lastWorkingSets.filter { $0.countsTowardLoadPRMetrics }.prefix(3).map { $0 }

        VStack(alignment: .leading, spacing: 6) {
            // Suggested target chip
            if let suggestion: InlineProgressionTarget = progressionSuggestion, !lastWorkingSets.isEmpty {
                SuggestedTargetChip(
                    suggestion: suggestion,
                    lastWeight: lastWorkingSets.first?.weight,
                    lastReps: lastWorkingSets.first?.reps,
                    effortStyle: userPreferences.effortInputStyle,
                    unit: unit
                ) {
                    // Pre-fill the inline fields from the suggestion
                    let displayW = WeightStoreConversion.displayValue(storedPounds: suggestion.weight, unit: unit)
                    inlineWeightByLogId[logId] = displayW
                    inlineWeightTextByLogId[logId] = WeightStoreConversion.formatDisplay(displayW)
                    inlineRepsByLogId[logId] = suggestion.reps
                    inlineRepsTextByLogId[logId] = "\(suggestion.reps)"
                    if let rpe = suggestion.rpe {
                        inlineRpeByLogId[logId] = userPreferences.effortInputStyle.toRPE(rpe)
                        inlineRpeExpandedLogIds.insert(logId)
                    }
                }
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
            Toggle("Bodyweight mode", isOn: Binding(
                get: { inlineBodyweightModeLogIds.contains(logId) },
                set: { on in
                    if on {
                        inlineBodyweightModeLogIds.insert(logId)
                        let w = inlineWeightByLogId[logId] ?? 0
                        inlineBodyweightAddedByLogId[logId] = w
                        inlineBodyweightAssistedByLogId[logId] = 0
                        inlineWeightByLogId[logId] = 0
                        inlineBodyweightAddedTextByLogId[logId] = formattedInlineWeight(w)
                        inlineBodyweightAssistedTextByLogId[logId] = ""
                        inlineWeightTextByLogId[logId] = ""
                    } else {
                        inlineBodyweightModeLogIds.remove(logId)
                        let added = inlineBodyweightAddedByLogId[logId] ?? 0
                        let assisted = inlineBodyweightAssistedByLogId[logId] ?? 0
                        inlineWeightByLogId[logId] = clampDisplayWeightForUser(max(0, added - assisted))
                        inlineBodyweightAddedByLogId.removeValue(forKey: logId)
                        inlineBodyweightAssistedByLogId.removeValue(forKey: logId)
                        inlineWeightTextByLogId[logId] = formattedInlineWeight(inlineWeightByLogId[logId] ?? 0)
                        inlineBodyweightAddedTextByLogId.removeValue(forKey: logId)
                        inlineBodyweightAssistedTextByLogId.removeValue(forKey: logId)
                    }
                }
            ))
            .font(.caption)
            .tint(.secondary)
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
                    .disabled((inlineRepsByLogId[logId] ?? 0) <= 0)
                    .accessibilityLabel("Log set")
                    Menu {
                        Button("Full log (RPE, drops…)", systemImage: "slider.horizontal.3") {
                            fitlogDismissKeyboard()
                            numericFieldFocus = nil
                            logSetSheetSelection = LogSetSheetSelection(
                                exerciseIndex: exerciseIndex,
                                prefillDisplayWeight: inlineNetDisplayWeight(for: logId),
                                prefillReps: inlineRepsByLogId[logId],
                                prefillBodyweightMode: true
                            )
                        }
                        Button("Plate calculator", systemImage: "scalemass") {
                            fitlogDismissKeyboard()
                            numericFieldFocus = nil
                            plateCalculatorInlinePick = PlateCalculatorInlinePick(logId: logId)
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
                    .disabled((inlineRepsByLogId[logId] ?? 0) <= 0)
                    .accessibilityLabel("Log set")
                    Menu {
                        Button("Full log (RPE, drops…)", systemImage: "slider.horizontal.3") {
                            fitlogDismissKeyboard()
                            numericFieldFocus = nil
                            logSetSheetSelection = LogSetSheetSelection(
                                exerciseIndex: exerciseIndex,
                                prefillDisplayWeight: inlineWeightByLogId[logId],
                                prefillReps: inlineRepsByLogId[logId],
                                prefillBodyweightMode: false
                            )
                        }
                        Button("Plate calculator", systemImage: "scalemass") {
                            fitlogDismissKeyboard()
                            numericFieldFocus = nil
                            plateCalculatorInlinePick = PlateCalculatorInlinePick(logId: logId)
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
            }
            // RPE / RIR quick chip row (respects effortInputStyle)
            if inlineRpeExpandedLogIds.contains(logId) {
                let effortLabel = userPreferences.effortInputStyle.label
                let clearLabel = "Clear \(effortLabel)"
                HStack(spacing: 6) {
                    Button(clearLabel) {
                        var next = inlineRpeByLogId
                        next.removeValue(forKey: logId)
                        inlineRpeByLogId = next
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption2)
                    // Show 10 down to 6 — for RIR these map to 0..4 RIR (displayed inverted)
                    ForEach((6...10).reversed(), id: \.self) { n in
                        let rpeVal = Double(n)
                        let displayVal = userPreferences.effortInputStyle.displayValue(fromRPE: rpeVal)
                        let selected = inlineRpeByLogId[logId] == rpeVal
                        Button("\(Int(displayVal))") {
                            var next = inlineRpeByLogId
                            if selected { next.removeValue(forKey: logId) } else { next[logId] = rpeVal }
                            inlineRpeByLogId = next
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selected ? .blue : .secondary)
                        .font(.caption.weight(.semibold))
                    }
                }
            }
            // Drop-set prompt (visible ~5 s after tapping ✓)
            if dropPromptLogId == logId {
                Button {
                    dropPromptLogId = nil
                    // Open full log pre-filled as a drop set for the just-logged weight
                    if let lastSet = currentVM.currentSession?.exerciseLogs[exerciseIndex].loggedSets.last {
                        let displayW = WeightStoreConversion.displayValue(storedPounds: lastSet.weight, unit: unit)
                        logSetSheetSelection = LogSetSheetSelection(
                            exerciseIndex: exerciseIndex,
                            prefillDisplayWeight: displayW * 0.8,
                            prefillReps: lastSet.reps
                        )
                    }
                } label: {
                    Label("Add drop set", systemImage: "arrow.down.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(response: 0.3), value: dropPromptLogId)
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
                if set.dropSegments.isEmpty {
                    Picker("Type", selection: $editSetType) {
                        Text(ExerciseSetType.working.logPickerLabel).tag(ExerciseSetType.working)
                        Text(ExerciseSetType.warmup.logPickerLabel).tag(ExerciseSetType.warmup)
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
                        isHighlighted: set.id == highlightedLoggedSetId
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) {
                            clearEditingSetIfNeeded(setId: set.id)
                            currentVM.deleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                        }
                    }
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
            inlineBodyweightModeLogIds.insert(lid)
            inlineBodyweightAddedByLogId[lid] = 0
            inlineBodyweightAssistedByLogId[lid] = netDisplay < 0
                ? WeightStoreConversion.clampNonNegativeDisplay(-netDisplay, unit: unit)
                : 0
            inlineWeightByLogId[lid] = 0
        } else {
            inlineBodyweightModeLogIds.remove(lid)
            inlineBodyweightAddedByLogId.removeValue(forKey: lid)
            inlineBodyweightAssistedByLogId.removeValue(forKey: lid)
            inlineWeightByLogId[lid] = WeightStoreConversion.clampNonNegativeDisplay(netDisplay, unit: unit)
        }
        inlineRepsByLogId[lid] = t.reps
        seedInlineText(for: lid)
        inlineInitializedLogIds.insert(lid)
    }

    private func applyBeatPrevious(log: ExerciseLog, exerciseIndex: Int, suggestion: ProgressionSuggestion) {
        let lid = log.id
        let unit = userPreferences.weightDisplayUnit
        if let w = suggestion.suggestedWeight {
            let netDisplay = clampSignedNetDisplayForUser(
                WeightStoreConversion.displayValue(storedPounds: w, unit: unit)
            )
            if netDisplay <= 0 {
                inlineBodyweightModeLogIds.insert(lid)
                inlineBodyweightAddedByLogId[lid] = 0
                inlineBodyweightAssistedByLogId[lid] = netDisplay < 0
                    ? WeightStoreConversion.clampNonNegativeDisplay(-netDisplay, unit: unit)
                    : 0
                inlineWeightByLogId[lid] = 0
            } else {
                inlineBodyweightModeLogIds.remove(lid)
                inlineBodyweightAddedByLogId.removeValue(forKey: lid)
                inlineBodyweightAssistedByLogId.removeValue(forKey: lid)
                inlineWeightByLogId[lid] = WeightStoreConversion.clampNonNegativeDisplay(netDisplay, unit: unit)
            }
        }
        let reps = parseRepsTarget(suggestion.targetReps)
        if reps > 0 {
            inlineRepsByLogId[lid] = reps
        }
        seedInlineText(for: lid)
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
                Text(set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
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
        case .working: return .secondary
        }
    }

    private func statusSupersetToggleTitle(for log: ExerciseLog) -> String {
        isExerciseActive(log) ? "Remove from superset" : "Add to superset"
    }
}
