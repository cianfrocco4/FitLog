//
//  SplitApplyConfirmationView.swift
//  FitLog
//
//  Confirmation screen before applying a split, with anchor date picker,
//  calendar preview, and conflict diff (Task 22).
//

import SwiftUI

struct SplitApplyConfirmationView: View {
    let days: [SplitBuilderEditableDay]
    let sessionsPerWeek: Int
    let preferredWeekdays: [Int]
    let rationale: String
    let updateTrainingProgram: Bool
    let dataVM: DataManager
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void

    @State private var anchorDate: Date = Date()
    @State private var conflict: SplitConflictDiff?

    private var proposalDays: [WorkoutSplitProposalDay] {
        days.map { $0.toProposalDay() }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summarySection
                    anchorDateSection
                    conflictDiffSection
                    calendarPreviewSection
                }
                .padding()
            }
            .navigationTitle("Apply Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: confirmApply)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                computeConflict()
                setDefaultAnchorDate()
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Split Summary")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("\(days.count) workout template\(days.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
            Text("\(sessionsPerWeek) session\(sessionsPerWeek == 1 ? "" : "s") per week")
                .foregroundStyle(.secondary)

            if updateTrainingProgram {
                Label("Your Plan tab will follow this cycle", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            } else {
                Label("Plan calendar unchanged; templates added to your list", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var anchorDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Date")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            DatePicker(
                "Anchor Date",
                selection: $anchorDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .accessibilityLabel("Select start date for the training program")
        }
    }

    @ViewBuilder
    private var conflictDiffSection: some View {
        if let c = conflict {
            VStack(alignment: .leading, spacing: 8) {
                Text("What Will Change")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if c.willReplaceCycle {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                        Text("Will replace current \(c.currentCycleCount)-workout cycle")
                            .font(.subheadline)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                    Text("Will create \(c.newTemplatesCreated) new template\(c.newTemplatesCreated == 1 ? "" : "s")")
                        .font(.subheadline)
                }

                if c.existingTemplatesKept > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("\(c.existingTemplatesKept) existing template\(c.existingTemplatesKept == 1 ? "" : "s") will be reused")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var calendarPreviewSection: some View {
        let cycleEntries = proposalDays.map { WorkoutPlanRef.slotBlueprint($0.name) }
        SplitCalendarPreview(
            cycleEntries: cycleEntries,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            anchorDate: anchorDate,
            workouts: [:]
        )
    }

    private func confirmApply() {
        onConfirm(anchorDate)
    }

    private func computeConflict() {
        conflict = ProgramConflictDiffer.diff(
            proposedDays: days,
            currentProgram: dataVM.trainingProgram,
            currentWorkouts: dataVM.userWorkouts
        )
    }

    private func setDefaultAnchorDate() {
        // Default to next preferred weekday
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if preferredWeekdays.isEmpty {
            anchorDate = today
            return
        }

        for dayOffset in 0..<7 {
            guard let candidate = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let wd = cal.component(.weekday, from: candidate)
            if preferredWeekdays.contains(wd) {
                anchorDate = candidate
                return
            }
        }
        anchorDate = today
    }
}

#Preview {
    let dataVM = DataManager.preview
    SplitApplyConfirmationView(
        days: [
            SplitBuilderEditableDay(id: UUID(), name: "Push", focus: "Chest, Shoulders, Triceps", slots: []),
            SplitBuilderEditableDay(id: UUID(), name: "Pull", focus: "Back, Biceps", slots: []),
            SplitBuilderEditableDay(id: UUID(), name: "Legs", focus: "Quads, Hamstrings, Glutes", slots: [])
        ],
        sessionsPerWeek: 3,
        preferredWeekdays: [2, 4, 6],
        rationale: "Push/Pull/Legs split",
        updateTrainingProgram: true,
        dataVM: dataVM,
        onConfirm: { _ in },
        onCancel: {}
    )
}
