//
//  PersonalRecordsView.swift
//  FitLog
//

import SwiftUI

struct PersonalRecordsView: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet

    @State private var pendingWorkoutReplace: PendingWorkoutReplace?

    private var records: [ArchivedPersonalRecord] {
        dataVM.allTimePersonalRecords()
    }

    /// First PR row per exercise so last-working recap and Start aren't repeated.
    private var firstRecordIdByExercise: [UUID: UUID] {
        var seen: [UUID: UUID] = [:]
        for row in records where seen[row.exerciseId] == nil {
            seen[row.exerciseId] = row.id
        }
        return seen
    }

    var body: some View {
        List {
            if records.isEmpty {
                Section {
                    Text("Log workouts to build your PR timeline. Records include heaviest load, estimated 1RM, and set volume per exercise.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("Each entry is the first time you beat your previous best for that exercise and metric.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.exerciseName)
                                    .font(.headline)
                                Spacer()
                                Text(row.kind.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text(valueLabel(row))
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(HistoryView.formatDateStatic(row.achievedAt))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        if firstRecordIdByExercise[row.exerciseId] == row.id {
                            personalRecordStartRecap(for: row)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .contain)
                }
            }
        }
        .navigationTitle("Personal records")
        .navigationBarTitleDisplayMode(.inline)
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingWorkoutReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
    }

    @ViewBuilder
    private func personalRecordStartRecap(for row: ArchivedPersonalRecord) -> some View {
        let recap = LibraryWorkoutLastSessionCopy.recap(
            forExerciseId: row.exerciseId,
            sessions: dataVM.completedSessions,
            weightUnit: userPreferences.weightDisplayUnit
        )
        let workout = LibraryWorkoutLastSessionCopy.libraryWorkoutToStart(
            forExerciseId: row.exerciseId,
            library: dataVM.userWorkouts,
            sessions: dataVM.completedSessions
        )
        if let recap {
            LibraryWorkoutLastSessionRecapView(
                recap: recap,
                startTitle: workout.map { "Start \($0.name)" },
                startAccessibilityIdentifier: FitLogA11yID.personalRecordStartWorkout,
                onStart: workout == nil ? nil : {
                    if let workout {
                        startLibraryWorkout(workout)
                    }
                }
            )
        } else if let workout {
            Button("Start \(workout.name)") {
                startLibraryWorkout(workout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityHint("Starts this saved workout and opens logging")
            .accessibilityIdentifier(FitLogA11yID.personalRecordStartWorkout)
        }
    }

    private func startLibraryWorkout(_ workout: Workout) {
        startLibraryWorkoutOpeningLogSheet(
            workout,
            dataVM: dataVM,
            currentVM: currentVM,
            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
            setPendingReplace: { pendingWorkoutReplace = $0 }
        )
    }

    private func valueLabel(_ row: ArchivedPersonalRecord) -> String {
        let unit = userPreferences.weightDisplayUnit
        switch row.kind {
        case .maxWeight, .estimatedOneRM:
            let d = WeightStoreConversion.displayValue(storedPounds: row.value, unit: unit)
            let s = d == floor(d) ? "\(Int(d))" : String(format: "%.1f", d)
            return "\(s) \(unit.shortLabel)"
        case .maxVolumeSet:
            return WeightStoreConversion.formatVolumeLbRep(row.value, unit: unit)
        case .maxDistance:
            return row.value >= 1000
                ? String(format: "%.2f km", row.value / 1000)
                : String(format: "%.0f m", row.value)
        case .bestPace:
            let total = Int(row.value.rounded())
            return String(format: "%d:%02d /km", total / 60, total % 60)
        case .longestDuration:
            let total = Int(row.value.rounded())
            return String(format: "%d:%02d", total / 60, total % 60)
        case .maxCalories:
            return "\(Int(row.value.rounded())) kcal"
        }
    }
}
