//
//  CurrentWorkoutCollapsedBar.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct CurrentWorkoutCollapsedBar: View {
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(DataManager.self) var dataVM
    @Environment(\.openCurrentWorkoutSheet) private var openSheet

    private var primaryExerciseLog: ExerciseLog? {
        guard let session = currentVM.currentSession,
              let primaryId = currentVM.primaryActiveExerciseId else { return nil }
        return session.exerciseLogs.first { $0.workoutExercise.exerciseId == primaryId }
    }

    private var primaryExerciseLine: String {
        guard let log = primaryExerciseLog else { return "" }
        return dataVM.displayName(for: log.workoutExercise)
    }

    private var primarySetProgressLine: String? {
        guard let log = primaryExerciseLog else { return nil }
        return "\(log.loggedSets.count)/\(log.workoutExercise.recommendedSets) sets"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                currentVM.pendingPullUpFocus = nil
                openSheet?()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentVM.currentSession?.workout.name ?? "")
                        Text(primaryExerciseLine)
                            .foregroundStyle(.secondary)
                        if let progress = primarySetProgressLine {
                            Text(progress)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    if currentVM.remainingRestTime > 0 {
                        Text("\(currentVM.remainingRestTime)s")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    } else {
                        Text("Now")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text(currentVM.workoutElapsedFormatted)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .minimumScaleFactor(0.8)
                Button {
                    if currentVM.isWorkoutPaused {
                        currentVM.resumeWorkout()
                    } else {
                        currentVM.pauseWorkout()
                    }
                } label: {
                    Image(systemName: currentVM.isWorkoutPaused ? "play.fill" : "pause.fill")
                        .font(.body)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal)
    }
}
