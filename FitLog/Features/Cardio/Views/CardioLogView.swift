//
//  CardioLogView.swift
//  FitLog
//

import SwiftUI

/// In-workout cardio logging: steady timer, interval timer, and manual entry.
struct CardioLogView: View {
    let exerciseIndex: Int
    let sessionVM: CurrentWorkoutSessionViewModel
    @Environment(DataManager.self) private var dataVM

    @State private var manualMinutes: String = ""
    @State private var manualSeconds: String = ""
    @State private var manualDistanceKm: String = ""
    @State private var manualHeartRate: String = ""
    @State private var manualCalories: String = ""
    @State private var manualDistanceM: Double = 0
    @State private var showManualSection = false
    @State private var intervalHapticTrigger = 0
    @State private var intervalCompleteCooldown = false

    private var exerciseLog: ExerciseLog? {
        guard let session = sessionVM.currentSession,
              exerciseIndex < session.exerciseLogs.count
        else { return nil }
        return session.exerciseLogs[exerciseIndex]
    }

    private var workoutExercise: WorkoutExercise? { exerciseLog?.workoutExercise }

    private var workoutExerciseId: UUID? { workoutExercise?.id }

    private var prescription: CardioPrescription? {
        workoutExercise?.effectiveCardioPrescription
    }

    private var resolvedExercise: Exercise? {
        guard let we = workoutExercise else { return nil }
        return CardioWorkoutExerciseHelpers.resolvedExercise(for: we, exercises: dataVM.globalExercises)
    }

    private var isIntervalPrescription: Bool {
        prescription?.kind == .intervals
    }

    private var intervalSpec: CardioIntervalSpec? {
        prescription?.intervals.first
    }

    private var loggedSets: [LoggedSet] {
        exerciseLog?.loggedSets ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let rx = prescription {
                CardioPrescriptionRowView(prescription: rx, exercise: resolvedExercise)
            }

            activeTimerSection

            CardioIntervalTimelineView(loggedSets: loggedSets)

            manualEntrySection
        }
        .sensoryFeedback(.success, trigger: intervalHapticTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cardio logging for \(resolvedExercise?.name ?? "exercise")")
    }

    @ViewBuilder
    private var activeTimerSection: some View {
        let _ = sessionVM.cardioTimerTick

        if let session = sessionVM.currentSession,
           let rowId = workoutExerciseId,
           let steady = sessionVM.cardioSteadyTimer,
           steady.resolvedWorkoutExerciseId(in: session) == rowId {
            steadyTimerControls(steady: steady)
        } else if let session = sessionVM.currentSession,
                  let rowId = workoutExerciseId,
                  let interval = sessionVM.cardioIntervalTimer,
                  interval.resolvedWorkoutExerciseId(in: session) == rowId {
            intervalTimerControls(interval: interval)
        } else {
            startTimerSection
        }
    }

    @ViewBuilder
    private var startTimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            if isIntervalPrescription, let spec = intervalSpec {
                Button {
                    sessionVM.startCardioIntervalTimer(exerciseIndex: exerciseIndex, spec: spec)
                    intervalHapticTrigger += 1
                } label: {
                    Label("Start interval timer", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FitlogPalette.chartSecondary)
                .accessibilityHint("Starts work and rest intervals from your prescription")
            } else {
                Button {
                    sessionVM.startCardioSteadyTimer(exerciseIndex: exerciseIndex)
                    intervalHapticTrigger += 1
                } label: {
                    Label("Start steady timer", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FitlogPalette.chartSecondary)
                .accessibilityHint("Starts a live elapsed timer for this cardio exercise")
            }
        }
    }

    private func steadyTimerControls(steady: CardioSteadyTimerState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CardioLiveMetricsStrip(
                elapsedSeconds: sessionVM.steadyElapsedSeconds(for: steady),
                phaseLabel: "Steady state",
                roundLabel: nil,
                isPaused: steady.isPaused || sessionVM.isWorkoutPaused
            )
            HStack(spacing: 10) {
                if steady.isPaused {
                    Button("Resume") { sessionVM.resumeCardioSteadyTimer() }
                        .buttonStyle(.bordered)
                        .disabled(sessionVM.isWorkoutPaused)
                        .accessibilityHint(sessionVM.isWorkoutPaused ? "Resume the workout first" : "Resumes the steady timer")
                } else {
                    Button("Pause") { sessionVM.pauseCardioSteadyTimer() }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Pauses the steady timer")
                }
                Button("Save segment") {
                    _ = sessionVM.stopCardioSteadyTimerAndLog(
                        exerciseIndex: exerciseIndex,
                        distanceM: manualDistanceM > 0 ? manualDistanceM : nil,
                        heartRate: parsedHeartRate,
                        calories: parsedCalories
                    )
                    intervalHapticTrigger += 1
                }
                .buttonStyle(.borderedProminent)
                .tint(FitlogPalette.success)
            }
            Button("Cancel timer", role: .destructive) {
                sessionVM.cancelCardioTimers(for: exerciseIndex)
            }
            .font(.caption)
        }
    }

    private func intervalTimerControls(interval: CardioIntervalTimerState) -> some View {
        let remaining = sessionVM.intervalPhaseRemainingSeconds(for: interval)
        let phaseLabel = interval.phase == .work ? "Work" : "Rest"
        let roundLabel = "Round \(interval.currentRound) of \(max(1, interval.spec.repeatCount))"

        return VStack(alignment: .leading, spacing: 10) {
            CardioLiveMetricsStrip(
                elapsedSeconds: interval.phaseDurationSec - remaining,
                phaseLabel: phaseLabel,
                roundLabel: roundLabel,
                isPaused: interval.isPaused || sessionVM.isWorkoutPaused
            )
            HStack(spacing: 10) {
                Button("Complete \(phaseLabel.lowercased())") {
                    guard !intervalCompleteCooldown else { return }
                    intervalCompleteCooldown = true
                    _ = sessionVM.completeCardioInterval(exerciseIndex: exerciseIndex)
                    intervalHapticTrigger += 1
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        intervalCompleteCooldown = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(interval.phase == .work ? FitlogPalette.chartSecondary : Color.secondary)
                .disabled(intervalCompleteCooldown)
                .accessibilityHint("Logs this interval segment and advances to the next phase")
                Button("Stop", role: .destructive) {
                    sessionVM.cancelCardioTimers(for: exerciseIndex)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var manualEntrySection: some View {
        DisclosureGroup(isExpanded: $showManualSection) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Min", text: $manualMinutes)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Duration minutes")
                    TextField("Sec", text: $manualSeconds)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Duration seconds")
                }
                TextField("Distance (km)", text: $manualDistanceKm)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Distance in kilometers")
                TextField("Avg heart rate", text: $manualHeartRate)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Average heart rate")
                TextField("Calories", text: $manualCalories)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Calories burned")

                Button {
                    logManualEntry()
                } label: {
                    Label("Log manually", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FitlogPalette.chartSecondary)
                .disabled(parsedDurationSeconds == nil)
                .accessibilityHint("Saves duration and optional distance without using the timer")
            }
            .padding(.top, 6)
        } label: {
            Text("Manual entry")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var parsedDurationSeconds: Int? {
        let m = Int(manualMinutes.trimmingCharacters(in: .whitespaces)) ?? 0
        let s = Int(manualSeconds.trimmingCharacters(in: .whitespaces)) ?? 0
        let total = m * 60 + s
        return total > 0 ? total : nil
    }

    private var parsedHeartRate: Int? {
        let v = Int(manualHeartRate.trimmingCharacters(in: .whitespaces)) ?? 0
        return v > 0 ? v : nil
    }

    private var parsedCalories: Double? {
        let v = Double(manualCalories.trimmingCharacters(in: .whitespaces)) ?? 0
        return v > 0 ? v : nil
    }

    private func logManualEntry() {
        guard let duration = parsedDurationSeconds else { return }
        let km = Double(manualDistanceKm.replacingOccurrences(of: ",", with: ".")) ?? 0
        let distanceM = km > 0 ? km * 1000 : nil
        manualDistanceM = distanceM ?? 0
        let setType: ExerciseSetType = isIntervalPrescription ? .intervalWork : .steadyState
        sessionVM.logCardioSet(
            exerciseIndex: exerciseIndex,
            durationSec: duration,
            distanceM: distanceM,
            heartRate: parsedHeartRate,
            calories: parsedCalories,
            setType: setType,
            source: .manual
        )
        manualMinutes = ""
        manualSeconds = ""
        manualDistanceKm = ""
        manualHeartRate = ""
        manualCalories = ""
        intervalHapticTrigger += 1
    }
}
