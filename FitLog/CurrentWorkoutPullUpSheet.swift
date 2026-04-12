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

struct CurrentWorkoutPullUpSheet: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.dismiss) var dismiss
    
    @State private var expandedExerciseIndex: Int? = nil
    @State private var logSetSheetSelection: LogSetSheetSelection?
    @State private var resolveSlotSelection: ResolveSlotWE?
    @State private var showFinishConfirmation = false
    @State private var showDiscardWorkoutConfirmation = false
    @State private var showQuickAddExercise = false
    @State private var showFullAddExercise = false
    @State private var showPRBanner = false
    @State private var exerciseListEditMode = EditMode.inactive

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
                // Rest Timer Card
                if currentVM.remainingRestTime > 0 {
                    VStack(spacing: 12) {
                        Text("Rest Time Remaining")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("\(currentVM.remainingRestTime)s")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        
                        Button("Cancel Rest") {
                            currentVM.cancelRestTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
                    .padding(.horizontal)
                    .padding(.vertical, 12)
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

                if let session = currentVM.currentSession, session.activeExerciseIds.count > 1 {
                    Text("Superset active — rest is handled automatically based on round position.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                unresolvedSlotsBanner
                prBanner
                restCompleteBanner

                exerciseNavigationBar

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
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(dataVM.displayName(for: log.workoutExercise))
                                                        .font(.headline)
                                                    HStack(spacing: 6) {
                                                        statusDot(for: log)
                                                        Text(statusText(for: log))
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    Text("Rec: \(log.workoutExercise.recommendedSets) \u{00d7} \(log.workoutExercise.recommendedReps)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                Text("\(log.loggedSets.count)/\(log.workoutExercise.recommendedSets) sets")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.primary)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button("Remove", role: .destructive) {
                                                removeExerciseAtListIndex(index, rowId: log.workoutExercise.id)
                                            }
                                        }
                                    }
                                    if isExpanded && !log.workoutExercise.isSlotPlaceholder {
                                        if !log.workoutExercise.configurationFields.isEmpty {
                                            recommendedConfigurationRow(for: log.workoutExercise)
                                        }
                                        if let previousLog = lastCompletedLog(for: log) {
                                            previousSessionSummaryRow(previousLog: previousLog)
                                        }
                                        TextField("Notes for this exercise", text: Binding(
                                            get: { currentVM.currentSession?.exerciseLogs[index].notes ?? "" },
                                            set: { currentVM.setExerciseLogNotes(at: index, notes: $0) }
                                        ), axis: .vertical)
                                        .lineLimit(2...5)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.subheadline)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        HStack(spacing: 12) {
                                            Button("Add New Set") {
                                                logSetSheetSelection = LogSetSheetSelection(exerciseIndex: index)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.blue)

                                            Button("Repeat Last") {
                                                currentVM.repeatLastSet(exerciseIndex: index)
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
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        if log.loggedSets.isEmpty {
                                            Text("No sets logged yet")
                                                .foregroundStyle(.secondary)
                                                .italic()
                                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        } else {
                                            ForEach(log.loggedSets.indices, id: \.self) { setIndex in
                                                setRow(set: log.loggedSets[setIndex], workoutExercise: log.workoutExercise)
                                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                        Button("Delete", role: .destructive) {
                                                            currentVM.deleteSet(exerciseIndex: index, setIndex: setIndex)
                                                        }
                                                    }
                                            }
                                        }
                                    }
                                }
                                .id(log.id)
                            }
                            .onMove { source, destination in
                                let logs = currentVM.currentSession?.exerciseLogs ?? []
                                let expandedId = expandedExerciseIndex.flatMap { logs.indices.contains($0) ? logs[$0].id : nil }
                                let logSheetId = logSetSheetSelection.flatMap { sel in
                                    logs.indices.contains(sel.exerciseIndex) ? logs[sel.exerciseIndex].id : nil
                                }
                                currentVM.moveExerciseLogs(fromOffsets: source, toOffset: destination)
                                guard let newLogs = currentVM.currentSession?.exerciseLogs else { return }
                                if let eid = expandedId, let ni = newLogs.firstIndex(where: { $0.id == eid }) {
                                    expandedExerciseIndex = ni
                                }
                                if let lid = logSheetId, let ni = newLogs.firstIndex(where: { $0.id == lid }) {
                                    logSetSheetSelection = LogSetSheetSelection(exerciseIndex: ni)
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
                    .onChange(of: expandedExerciseIndex) { _, newValue in
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
                    Button(exerciseListEditMode == .active ? "Done" : "Reorder") {
                        withAnimation {
                            exerciseListEditMode = exerciseListEditMode == .active ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showQuickAddExercise = true
                        } label: {
                            Label("Quick add exercise", systemImage: "plus")
                        }
                        Button {
                            showFullAddExercise = true
                        } label: {
                            Label("Custom sets & fields…", systemImage: "slider.horizontal.3")
                        }
                        if isFlexibleLibrarySession {
                            Button {
                                currentVM.appendSlotToFlexibleLibrarySession()
                            } label: {
                                Label("Add template slot", systemImage: "square.dashed")
                            }
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle")
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
                LogSetView(sessionVM: currentVM, exerciseIndex: selection.exerciseIndex)
                    .environmentObject(dataVM)
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
                    SessionQuickAddExerciseSheet(workout: w, currentVM: currentVM, dataVM: dataVM)
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
        currentVM.stopWorkout()
        dismiss()
    }

    private func removeExerciseAtListIndex(_ index: Int, rowId: UUID) {
        if resolveSlotSelection?.workoutExerciseId == rowId {
            resolveSlotSelection = nil
        }

        let oldLogSel = logSetSheetSelection
        if oldLogSel?.exerciseIndex == index {
            logSetSheetSelection = nil
        } else if let sel = oldLogSel, sel.exerciseIndex > index {
            logSetSheetSelection = LogSetSheetSelection(exerciseIndex: sel.exerciseIndex - 1)
        }

        currentVM.removeExerciseFromSession(exerciseLogIndex: index)

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

    private func navigateAdjacentExercise(delta: Int) {
        guard let logs = currentVM.currentSession?.exerciseLogs, !logs.isEmpty,
              let idx = expandedExerciseIndex else { return }
        let newIdx = idx + delta
        guard logs.indices.contains(newIdx) else { return }
        expandedExerciseIndex = newIdx
        if let exId = logs[newIdx].workoutExercise.exerciseId {
            currentVM.setPrimaryExercise(exerciseId: exId)
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
    private var restCompleteBanner: some View {
        if currentVM.showRestCompleteAlert {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                Text("Rest over — time for your next set.")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Button("Continue") {
                    currentVM.showRestCompleteAlert = false
                    advanceToNextExerciseAfterRestIfNeeded()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
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
    private var exerciseNavigationBar: some View {
        if let idx = expandedExerciseIndex,
           let logs = currentVM.currentSession?.exerciseLogs,
           !logs.isEmpty,
           idx < logs.count {
            HStack(spacing: 16) {
                Button {
                    navigateAdjacentExercise(delta: -1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .labelStyle(.titleAndIcon)
                .disabled(idx <= 0)

                Spacer()

                Text("\(idx + 1) of \(logs.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    navigateAdjacentExercise(delta: 1)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .labelStyle(.titleAndIcon)
                .disabled(idx >= logs.count - 1)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 6)
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

        guard let exerciseId = currentLog.workoutExercise.exerciseId else { return nil }

        func latestLog(in sessions: [WorkoutSession], for exerciseId: UUID) -> ExerciseLog? {
            var latest: (ExerciseLog, Date)?

            for session in sessions {
                for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
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
        if let log = latestLog(in: sameWorkoutSessions, for: exerciseId) {
            return log
        }

        // 2. Fall back to any workout that includes this exercise.
        return latestLog(in: allSessions, for: exerciseId)
    }
    
    private func previousSessionSummaryRow(previousLog: ExerciseLog) -> some View {
        let we = previousLog.workoutExercise
        return VStack(alignment: .leading, spacing: 6) {
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
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
        .padding(10)
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
    private func recommendedConfigurationRow(for workoutExercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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

    private func statusText(for log: ExerciseLog) -> String {
        if isExerciseCompleted(log) {
            return "Completed"
        }
        if isPrimaryExercise(log) {
            return "Current"
        }
        if isExerciseActive(log) {
            return "Superset"
        }
        if !log.loggedSets.isEmpty {
            return "In progress"
        }
        return "Not started"
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
