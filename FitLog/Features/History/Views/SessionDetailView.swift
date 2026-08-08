//
//  SessionDetailView.swift
//  FitLog
//

import SwiftUI

struct SessionDetailView: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    @Environment(\.undoManager) private var undoManager
    let session: WorkoutSession

    @State private var confirmDeleteSession = false
    @State private var pendingStartAgainReplace: PendingWorkoutReplace?
    @State private var prKindsBySetId: [UUID: [PersonalRecordEvent.Kind]] = [:]

    private var endDate: Date { session.endTime ?? session.startTime }

    private var canStartAgainToday: Bool {
        completedSessionIsSameCalendarDay(session)
    }

    private var sessionPlanLine: String {
        switch session.sessionPlanOrigin {
        case nil:
            return "Not recorded (older log)"
        case .workout(let id):
            if let w = dataVM.workout(id: id) {
                return "\(w.name) (\(w.listDetailSubtitle))"
            }
            return "Plan workout (removed from library)"
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(HistoryView.formatDateStatic(endDate))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(HistoryView.durationStringStatic(for: session))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Session plan")
                    Spacer()
                    Text(sessionPlanLine)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            if !session.sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Workout notes") {
                    Text(session.sessionNotes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if canStartAgainToday {
                Section {
                    Button {
                        startAgainFromCompletedSession(
                            session,
                            currentVM: currentVM,
                            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
                            setPendingReplace: { pendingStartAgainReplace = $0 }
                        )
                    } label: {
                        Label("Continue session", systemImage: "arrow.clockwise.circle.fill")
                    }
                } footer: {
                    Text("Continues this session with the same logged sets and progress. This finished entry stays in your history until you complete the new run.")
                }
            }
            let sessionCardio = CardioSessionAggregatesCalculator.aggregates(
                for: session,
                exercises: dataVM.globalExercises
            )
            if sessionCardio.hasCardio {
                Section("Cardio summary") {
                    CardioCompletionRingView(
                        durationSeconds: sessionCardio.durationSeconds,
                        distanceMeters: sessionCardio.distanceMeters,
                        durationGoalSeconds: nil,
                        distanceGoalMeters: nil
                    )
                    LabeledContent("Segments", value: "\(sessionCardio.segmentCount)")
                }
            }

            ForEach(session.exerciseLogs) { log in
                Section {
                    let showCardioTimeline = log.loggedSets.contains(where: { $0.isCardioEntry })
                        && log.loggedSets.allSatisfy { $0.isCardioEntry || $0.countsTowardCardioTotals }
                    if showCardioTimeline {
                        CardioIntervalTimelineView(loggedSets: log.loggedSets)
                            .padding(.vertical, 4)
                    }
                    let listedSets = showCardioTimeline
                        ? log.loggedSets.filter { !$0.isCardioEntry }
                        : log.loggedSets
                    ForEach(listedSets) { set in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(
                                    set.isCardioEntry
                                        ? set.cardioDisplaySummary
                                        : set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit)
                                )
                                if let badge = set.setTypeBadgeLabel {
                                    Text(badge)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                if let rpe = set.rpe {
                                    Text(HistoryFormatters.rpeLabel(rpe))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                if let kinds = prKindsBySetId[set.id], !kinds.isEmpty {
                                    ForEach(kinds, id: \.self) { k in
                                        Text(historySessionPRBadgeLabel(k))
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(FitlogPalette.highlight)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(FitlogPalette.highlight.opacity(0.15), in: Capsule())
                                    }
                                }
                                Spacer()
                            }
                            let summary = set.configurationSummary(fieldNames: log.workoutExercise.configurationFields)
                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dataVM.displayName(for: log.workoutExercise))
                        if let slotLabel = HistoryView.templateSlotCaption(for: log, session: session, dataVM: dataVM) {
                            Text("From plan: \(slotLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !log.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(log.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", role: .destructive) {
                    confirmDeleteSession = true
                }
            }
        }
        .confirmationDialog(
            "Remove this workout from your history? You can undo from the navigation bar.",
            isPresented: $confirmDeleteSession,
            titleVisibility: .visible
        ) {
            Button("Delete from history", role: .destructive) {
                fitlogDeleteCompletedSessionWithUndo(session, dataVM: dataVM, undoManager: undoManager)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartAgainReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
        .onAppear {
            rebuildSessionDetailPRMap()
        }
    }

    private func rebuildSessionDetailPRMap() {
        var map: [UUID: [PersonalRecordEvent.Kind]] = [:]
        for log in session.exerciseLogs {
            for set in log.loggedSets {
                let kinds = dataVM.personalRecordKindsForHistoricalSet(set: set, log: log, session: session)
                if !kinds.isEmpty {
                    map[set.id] = kinds
                }
            }
        }
        prKindsBySetId = map
    }
}
