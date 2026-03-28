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

    private var slotMuscles: Set<MuscleGroup> {
        guard let slotId = templateSlotId,
              let origin = currentVM.currentSession?.sessionPlanOrigin,
              case .slotTemplate(let templateId) = origin,
              let template = dataVM.slotTemplate(id: templateId),
              let slot = template.slots.first(where: { $0.id == slotId })
        else { return [] }
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

    var body: some View {
        List {
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
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle(isSwapExercise ? "Swap exercise" : "Choose exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
}

struct CurrentWorkoutPullUpSheet: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var expandedExerciseIndex: Int? = nil
    @State private var logSetSheetSelection: LogSetSheetSelection?
    @State private var resolveSlotSelection: ResolveSlotWE?
    @State private var showFinishConfirmation = false
    
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

                ScrollViewReader { scrollProxy in
                    List {
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
                                    }
                                    if isExpanded && !log.workoutExercise.isSlotPlaceholder {
                                        if !log.workoutExercise.configurationFields.isEmpty {
                                            recommendedConfigurationRow(for: log.workoutExercise)
                                        }
                                        if let previousLog = lastCompletedLog(for: log) {
                                            previousSessionSummaryRow(previousLog: previousLog)
                                        }
                                        HStack(spacing: 12) {
                                            Button("Add New Set") {
                                                logSetSheetSelection = LogSetSheetSelection(exerciseIndex: index)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.blue)

                                            Button {
                                                currentVM.repeatLastSet(exerciseIndex: index)
                                            } label: {
                                                Label("Repeat last", systemImage: "arrow.counterclockwise")
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
                        } else {
                            Section {
                                Text("No exercises in current session")
                                    .foregroundStyle(.secondary)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }
                    }
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
            .alert(
                "Rest over",
                isPresented: Binding(
                    get: { currentVM.showRestCompleteAlert },
                    set: { newValue in
                        currentVM.showRestCompleteAlert = newValue
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    currentVM.showRestCompleteAlert = false
                    advanceToNextExerciseAfterRestIfNeeded()
                }
            } message: {
                Text("Time for your next set.")
            }
            .alert("Finish workout?", isPresented: $showFinishConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Finish anyway", role: .destructive) {
                    finishWorkout()
                }
            } message: {
                Text("These exercises have no sets logged: \(resolvedExercisesWithNoSets.joined(separator: ", ")).")
            }
            .onAppear {
                if resolveSlotSelection == nil,
                   let first = currentVM.currentSession?.exerciseLogs.first(where: { $0.workoutExercise.isSlotPlaceholder }) {
                    resolveSlotSelection = ResolveSlotWE(workoutExerciseId: first.workoutExercise.id, templateSlotId: first.workoutExercise.templateSlotId)
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
                        Text(prevSet.weightRepsDisplaySummary(unit: "lbs"))
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
                Text(set.weightRepsDisplaySummary(unit: "lbs"))
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
