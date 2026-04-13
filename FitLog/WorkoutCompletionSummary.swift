//
//  WorkoutCompletionSummary.swift
//  FitLog
//

import SwiftUI

struct WorkoutCompletionSummary: Equatable, Identifiable {
    let id: UUID
    let workoutName: String
    let durationSeconds: Int
    let totalSets: Int
    let totalVolumePounds: Double
    let exercisesWithSets: Int
    let totalResolvedExercises: Int
    let personalRecordCount: Int

    var durationFormatted: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        let s = durationSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    func shareLines(displayUnit: WeightDisplayUnit) -> String {
        let vol = WeightStoreConversion.displayValue(storedPounds: totalVolumePounds, unit: displayUnit)
        let unit = displayUnit.shortLabel
        var lines: [String] = [
            "FitLog — \(workoutName)",
            "Duration: \(durationFormatted)",
            "Sets: \(totalSets)",
            "Volume: \(String(format: "%.0f", vol)) \(unit)",
            "Exercises: \(exercisesWithSets)/\(totalResolvedExercises)"
        ]
        if personalRecordCount > 0 {
            lines.append("Personal records: \(personalRecordCount)")
        }
        return lines.joined(separator: "\n")
    }
}

extension DataManager {
    /// Count PR-worthy events for sets in this session vs all prior history (completed sessions only).
    func countNewPersonalRecords(in session: WorkoutSession) -> Int {
        let priorSessions = completedSessions.filter { $0.id != session.id }
        var count = 0
        for log in session.exerciseLogs {
            guard let exId = log.workoutExercise.exerciseId else { continue }
            let name = displayName(for: log.workoutExercise)
            let priorFromHistory: [LoggedSet] = priorSessions
                .flatMap(\.exerciseLogs)
                .filter { $0.workoutExercise.exerciseId == exId }
                .flatMap(\.loggedSets)
            var priorAccumulated: [LoggedSet] = priorFromHistory
            let sortedSets = log.loggedSets.sorted { $0.timestamp < $1.timestamp }
            for set in sortedSets {
                let events = PersonalRecordDetector.detect(
                    newSet: set,
                    priorSets: priorAccumulated,
                    exerciseId: exId,
                    exerciseName: name,
                    timestamp: set.timestamp
                )
                if !events.isEmpty { count += 1 }
                priorAccumulated.append(set)
            }
        }
        return count
    }

    func buildWorkoutCompletionSummary(session: WorkoutSession, activeElapsedSeconds: Int? = nil) -> WorkoutCompletionSummary {
        let end = session.endTime ?? Date()
        let wallDuration = max(0, Int(end.timeIntervalSince(session.startTime)))
        let durationSeconds = max(0, activeElapsedSeconds ?? wallDuration)

        let resolvedLogs = session.exerciseLogs.filter { !$0.workoutExercise.isSlotPlaceholder }
        let totalResolved = resolvedLogs.count
        let withSets = resolvedLogs.filter { !$0.loggedSets.isEmpty }.count
        let allSets = session.exerciseLogs.flatMap(\.loggedSets)
        let totalSets = allSets.count
        let volume = allSets.reduce(0.0) { $0 + $1.totalVolumeLoad }
        let prCount = countNewPersonalRecords(in: session)

        return WorkoutCompletionSummary(
            id: session.id,
            workoutName: session.workout.name,
            durationSeconds: durationSeconds,
            totalSets: totalSets,
            totalVolumePounds: volume,
            exercisesWithSets: withSets,
            totalResolvedExercises: totalResolved,
            personalRecordCount: prCount
        )
    }
}

struct WorkoutCompletionSummaryView: View {
    let summary: WorkoutCompletionSummary
    var onDone: () -> Void
    @EnvironmentObject var userPreferences: UserPreferences

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Workout", value: summary.workoutName)
                    LabeledContent("Duration", value: summary.durationFormatted)
                    LabeledContent("Total sets", value: "\(summary.totalSets)")
                    let vol = WeightStoreConversion.displayValue(
                        storedPounds: summary.totalVolumePounds,
                        unit: userPreferences.weightDisplayUnit
                    )
                    LabeledContent(
                        "Volume",
                        value: "\(String(format: "%.0f", vol)) \(userPreferences.weightDisplayUnit.shortLabel)"
                    )
                    LabeledContent(
                        "Exercises logged",
                        value: "\(summary.exercisesWithSets) of \(summary.totalResolvedExercises)"
                    )
                    if summary.personalRecordCount > 0 {
                        LabeledContent("Personal records", value: "\(summary.personalRecordCount)")
                    }
                }
            }
            .navigationTitle("Workout complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: summary.shareLines(displayUnit: userPreferences.weightDisplayUnit)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
