//
//  HistorySessionsTab.swift
//  FitLog
//

import SwiftUI

struct HistorySessionsTab: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    @Environment(\.undoManager) private var undoManager
    @Bindable var viewModel: HistoryViewModel

    @State private var pendingStartAgainReplace: PendingWorkoutReplace?

    var body: some View {
        let sessions = viewModel.filteredSessionsForSessionsTab
        let sections = viewModel.sessionsSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? viewModel.sessionSections
            : [HistorySessionSection(id: "search", title: "Results", sessions: sessions)]

        Group {
            if sessions.isEmpty {
                Section {
                    Text(
                        viewModel.sessionsSearch.isEmpty
                            ? viewModel.dayRange.emptySessionsMessage
                            : "No sessions match your search"
                    )
                    .foregroundStyle(.secondary)
                }
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.sessions) { session in
                            sessionRow(session)
                        }
                    } header: {
                        Text(section.title)
                    }
                }
            }
        }
        .onAppear {
            viewModel.ensureSessionsData(dataVM: dataVM)
        }
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartAgainReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
    }

    @ViewBuilder
    private func sessionRow(_ session: WorkoutSession) -> some View {
        NavigationLink(destination: SessionDetailView(session: session)
            .environment(dataVM)
            .environment(currentVM)
        ) {
            HistorySessionRow(
                session: session,
                summary: viewModel.sessionSummary(for: session),
                volumeUnit: userPreferences.weightDisplayUnit
            )
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if completedSessionIsSameCalendarDay(session) {
                Button {
                    startAgainFromCompletedSession(
                        session,
                        currentVM: currentVM,
                        openCurrentWorkoutSheet: openCurrentWorkoutSheet,
                        setPendingReplace: { pendingStartAgainReplace = $0 }
                    )
                } label: {
                    Label("Continue", systemImage: "arrow.clockwise.circle.fill")
                }
                .tint(FitlogPalette.success)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                fitlogDeleteCompletedSessionWithUndo(session, dataVM: dataVM, undoManager: undoManager)
            }
        }
    }
}
