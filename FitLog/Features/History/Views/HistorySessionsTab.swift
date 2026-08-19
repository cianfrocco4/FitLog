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
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
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
                    emptySessionsContent
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
    private var emptySessionsContent: some View {
        let isSearchEmpty = viewModel.sessionsSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isSearchEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.dayRange.emptySessionsMessage)
                    .foregroundStyle(.secondary)
                Text("Start a workout from Home to build your history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let tab = rootTabSelection {
                    Button("Start Workout") {
                        tab.wrappedValue = .home
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Start Workout")
                    .accessibilityHint("Switches to Home so you can begin a workout")
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("No sessions match your search")
                .foregroundStyle(.secondary)
        }
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
