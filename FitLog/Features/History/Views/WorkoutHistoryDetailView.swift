//
//  WorkoutHistoryDetailView.swift
//  FitLog
//

import SwiftUI
import Charts

struct WorkoutHistoryDetailView: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    @Environment(\.undoManager) private var undoManager
    @State private var pendingStartAgainReplace: PendingWorkoutReplace?
    let workoutId: UUID
    let workoutName: String

    private var sessionsForWorkout: [WorkoutSession] {
        dataVM.completedSessions.filter { $0.workout.id == workoutId }
    }

    private var sortedSessions: [WorkoutSession] {
        sessionsForWorkout.sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private var durationTrendPoints: [WorkoutDurationPoint] {
        sessionsForWorkout
            .sorted { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }
            .map { s in
                let end = s.endTime ?? s.startTime
                let sec = max(1, Int(end.timeIntervalSince(s.startTime)))
                return WorkoutDurationPoint(id: s.id, date: end, minutes: max(1, sec / 60))
            }
    }

    var body: some View {
        List {
            startThisWorkoutSection
            if durationTrendPoints.count >= 2 {
                Section {
                    HistoryChartCard(title: "Session duration trend") {
                        Chart(durationTrendPoints) { pt in
                            AreaMark(
                                x: .value("Date", pt.date),
                                y: .value("Minutes", pt.minutes)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [FitlogPalette.chartPrimary.opacity(0.3), FitlogPalette.chartPrimary.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Minutes", pt.minutes)
                            )
                            .foregroundStyle(FitlogPalette.chartPrimary)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, durationTrendPoints.count / 4))) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let m = v.as(Int.self) {
                                        Text("\(m)m")
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                        .accessibilityLabel("Session duration trend for \(workoutName)")
                    }
                }
            }
            ForEach(sortedSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)
                    .environment(dataVM)
                    .environment(currentVM)
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(HistoryView.formatDateStatic(session.endTime ?? session.startTime))
                                .font(.headline)
                            Text("\(session.exerciseLogs.count) exercise\(session.exerciseLogs.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(HistoryView.durationStringStatic(for: session))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
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
        .navigationTitle(workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartAgainReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
    }

    @ViewBuilder
    private var startThisWorkoutSection: some View {
        if let session = sortedSessions.first,
           HistoryStartFreshWorkout.sourceWorkout(session: session, library: dataVM.userWorkouts) != nil {
            Section {
                Button {
                    HistoryStartFreshWorkout.start(
                        from: session,
                        dataVM: dataVM,
                        currentVM: currentVM,
                        openCurrentWorkoutSheet: openCurrentWorkoutSheet,
                        setPendingReplace: { pendingStartAgainReplace = $0 }
                    )
                } label: {
                    Label("Start this workout", systemImage: "play.fill")
                }
                .accessibilityIdentifier(FitLogA11yID.historyStartThisWorkout)
                .accessibilityLabel("Start this workout")
                .accessibilityHint(
                    "Starts a new session from \(workoutName) so you can repeat it without going back to Home"
                )
                .accessibilityAddTraits(.isButton)
            } footer: {
                Text("Starts a new session from this workout. Finished logs stay in History.")
            }
        }
    }
}
