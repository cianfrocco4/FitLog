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
    @Environment(\.workoutChromeMetrics) private var chromeMetrics
    @Environment(\.openCurrentWorkoutSheet) private var openSheet

    @State private var showSwipeHint = true

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
        VStack(spacing: 6) {
            Capsule()
                .fill(FitlogPalette.success.opacity(0.55))
                .frame(width: 36, height: 4)

            if showSwipeHint {
                Text("Swipe up to log sets")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 12) {
                Button {
                    dismissSwipeHint()
                    currentVM.pendingPullUpFocus = nil
                    openSheet?()
                } label: {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(FitlogPalette.success)
                            .frame(width: 4)

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
                                    .background(FitlogPalette.caution)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            } else {
                                Text("Now")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(FitlogPalette.success)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding()
                    }
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open workout logging")
                .accessibilityHint("Swipe up or tap to open exercise logging")

                HStack(spacing: 8) {
                    Text(currentVM.workoutElapsedFormatted)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .minimumScaleFactor(0.8)
                    Button {
                        dismissSwipeHint()
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
                    .accessibilityLabel(currentVM.isWorkoutPaused ? "Resume workout" : "Pause workout")
                    .accessibilityHint(currentVM.isWorkoutPaused ? "Resumes the workout timer" : "Pauses the workout timer")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(FitlogPalette.success.opacity(0.45), lineWidth: 1.5)
                }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: -2)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            if height > 0 {
                chromeMetrics.collapsedBarHeight = height
            }
        }
        .onAppear {
            showSwipeHint = true
            scheduleSwipeHintDismissal()
        }
    }

    private func dismissSwipeHint() {
        guard showSwipeHint else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            showSwipeHint = false
        }
    }

    private func scheduleSwipeHintDismissal() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            dismissSwipeHint()
        }
    }
}
