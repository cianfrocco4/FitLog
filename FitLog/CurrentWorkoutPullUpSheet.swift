//
//  CurrentWorkoutPullUpSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import Foundation

struct CurrentWorkoutPullUpSheet: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var expandedExerciseIndex: Int? = nil
    @State private var selectedExerciseIndex: Int? = nil
    @State private var showLogSetSheet = false
    
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
                
                // One List with Section per exercise so expanded content is full-height and each set row is swipeable
                List {
                    if let exerciseLogs = currentVM.currentSession?.exerciseLogs, !exerciseLogs.isEmpty {
                        ForEach(exerciseLogs.indices, id: \.self) { index in
                            let log = exerciseLogs[index]
                            let isExpanded = expandedExerciseIndex == index
                            
                            Section {
                                // Exercise name as first row so it uses normal list text color (not section header gray)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedExerciseIndex = isExpanded ? nil : index
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(log.workoutExercise.exercise.name)
                                                .font(.headline)
                                            Text("Rec: \(log.workoutExercise.recommendedSets) × \(log.workoutExercise.recommendedReps)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text("\(log.loggedSets.count) sets")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.primary)
                                if isExpanded {
                                    if let previousLog = lastCompletedLog(for: log) {
                                        previousSessionSummaryRow(previousLog: previousLog)
                                    }
                                    Button("Add New Set") {
                                        selectedExerciseIndex = index
                                        showLogSetSheet = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                    .frame(maxWidth: .infinity)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    if log.loggedSets.isEmpty {
                                        Text("No sets logged yet")
                                            .foregroundStyle(.secondary)
                                            .italic()
                                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    } else {
                                        ForEach(log.loggedSets.indices, id: \.self) { setIndex in
                                            setRow(set: log.loggedSets[setIndex], exercise: log.workoutExercise.exercise)
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
            }
            .navigationTitle("Current Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        currentVM.stopWorkout()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
                }
            }
            // Open LogSetView when adding a set
            .sheet(isPresented: $showLogSetSheet) {
                if let idx = selectedExerciseIndex {
                    LogSetView(exerciseIndex: idx)
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
                }
            } message: {
                Text("Time for your next set.")
            }
        }
    }

    /// Returns the most recent completed `ExerciseLog` for this exercise:
    /// - Prefer sessions from the same workout as the current session.
    /// - If none exist, fall back to any workout that includes the exercise.
    private func lastCompletedLog(for currentLog: ExerciseLog) -> ExerciseLog? {
        guard
            let currentWorkoutId = currentVM.currentSession?.workout.id,
            let data = UserDefaults.standard.data(forKey: "completedSessions"),
            let allSessions = try? JSONDecoder().decode([WorkoutSession].self, from: data)
        else {
            return nil
        }

        let exerciseId = currentLog.workoutExercise.exercise.id

        // Helper to find the latest log for a given set of sessions.
        func latestLog(in sessions: [WorkoutSession], for exerciseId: UUID) -> ExerciseLog? {
            var latest: (ExerciseLog, Date)?

            for session in sessions {
                for log in session.exerciseLogs where log.workoutExercise.exercise.id == exerciseId {
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
        let ex = previousLog.workoutExercise.exercise
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
                        Text("\(prevSet.weight, specifier: "%.1f") lbs × \(prevSet.reps)")
                            .font(.caption)
                        Text("• \(prevSet.restTime)s rest")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !prevSet.configurationSummary(options: ex.configurationOptions).isEmpty {
                        Text(prevSet.configurationSummary(options: ex.configurationOptions))
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

    private func setRow(set: LoggedSet, exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(set.weight, specifier: "%.1f") lbs × \(set.reps)")
                    .font(.body)
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
            if !set.configurationSummary(options: exercise.configurationOptions).isEmpty {
                Text(set.configurationSummary(options: exercise.configurationOptions))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
