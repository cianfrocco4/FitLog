//
//  HomeLibraryView.swift
//  FitLog
//

import SwiftUI

enum HomeLibraryKind {
    case workouts
    case templates
}

/// `.all` = full library. `.notInSplit` = saved items not listed in the Plan rotation (`cycleEntries`).
enum HomeLibraryScope: Hashable {
    case all
    case notInSplit
}

private enum LibraryWorkoutSortMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case smart = "Smart"
    var id: String { rawValue }
}

struct HomeLibraryView: View {
    let kind: HomeLibraryKind
    var scope: HomeLibraryScope = .all

    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel

    @State private var searchText = ""
    @State private var workoutSortMode: LibraryWorkoutSortMode = .manual
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?
    @State private var workoutToRename: Workout?
    @State private var renameWorkoutText = ""
    @State private var templateToRename: WorkoutTemplate?
    @State private var renameTemplateText = ""

    private var scheduleEngine: TrainingScheduleEngine { TrainingScheduleEngine(calendar: .current) }

    private var todayConcretePlanId: UUID? {
        if case .workout(.concreteWorkout(let id)) = scheduleEngine.resolve(date: Date(), program: dataVM.trainingProgram) {
            return id
        }
        return nil
    }

    private var todayTemplatePlanId: UUID? {
        if case .workout(.slotTemplate(let id)) = scheduleEngine.resolve(date: Date(), program: dataVM.trainingProgram) {
            return id
        }
        return nil
    }

    private var splitConcreteIds: Set<UUID> {
        HomeListOrdering.splitConcreteWorkoutIds(from: dataVM.trainingProgram)
    }

    private var splitTemplateIds: Set<UUID> {
        HomeListOrdering.splitTemplateIds(from: dataVM.trainingProgram)
    }

    private var workoutPool: [Workout] {
        switch scope {
        case .all:
            return dataVM.userWorkouts
        case .notInSplit:
            return dataVM.userWorkouts.filter { !splitConcreteIds.contains($0.id) }
        }
    }

    private var templatePool: [WorkoutTemplate] {
        switch scope {
        case .all:
            return dataVM.userWorkoutTemplates
        case .notInSplit:
            return dataVM.userWorkoutTemplates.filter { !splitTemplateIds.contains($0.id) }
        }
    }

    private var displayedWorkouts: [Workout] {
        let base: [Workout]
        switch workoutSortMode {
        case .manual:
            base = workoutPool
        case .smart:
            base = HomeListOrdering.orderWorkouts(workoutPool, program: dataVM.trainingProgram, sessions: dataVM.completedSessions)
        }
        return filterBySearch(base, keyPath: \.name)
    }

    private var displayedTemplates: [WorkoutTemplate] {
        let base = HomeListOrdering.orderTemplates(
            templatePool,
            program: dataVM.trainingProgram,
            sessions: dataVM.completedSessions
        )
        return filterBySearch(base, keyPath: \.name)
    }

    private var canReorderWorkouts: Bool {
        scope == .all
            && workoutSortMode == .manual
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var navigationTitle: String {
        switch (kind, scope) {
        case (.workouts, .all): return "All workouts"
        case (.workouts, .notInSplit): return "Other workouts"
        case (.templates, .all): return "All templates"
        case (.templates, .notInSplit): return "Other templates"
        }
    }

    private func filterBySearch<T>(_ items: [T], keyPath: KeyPath<T, String>) -> [T] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0[keyPath: keyPath].lowercased().contains(q) }
    }

    var body: some View {
        Group {
            switch kind {
            case .workouts:
                workoutList
            case .templates:
                templateList
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: kind == .workouts ? "Search workouts" : "Search templates")
        .toolbar {
            if kind == .workouts {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Sort", selection: $workoutSortMode) {
                        ForEach(LibraryWorkoutSortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if canReorderWorkouts {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
        }
        .alert("Rename Workout", isPresented: Binding(
            get: { workoutToRename != nil },
            set: { if !$0 { workoutToRename = nil } }
        )) {
            TextField("New name", text: $renameWorkoutText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let w = workoutToRename {
                    dataVM.renameWorkout(w, newName: renameWorkoutText)
                }
            }
        }
        .alert("Rename Template", isPresented: Binding(
            get: { templateToRename != nil },
            set: { if !$0 { templateToRename = nil } }
        )) {
            TextField("New name", text: $renameTemplateText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let t = templateToRename {
                    dataVM.renameSlotTemplate(t, newName: renameTemplateText)
                }
            }
        }
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingWorkoutReplace,
            onAfterReplace: {},
            onCancelReplace: {}
        )
    }

    private var workoutList: some View {
        List {
            if canReorderWorkouts {
                ForEach(displayedWorkouts) { workout in
                    workoutRow(workout)
                }
                .onMove(perform: dataVM.moveWorkout)
            } else {
                ForEach(displayedWorkouts) { workout in
                    workoutRow(workout)
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func workoutRow(_ workout: Workout) -> some View {
        NavigationLink {
            if let binding = $dataVM.userWorkouts[workout.id] {
                WorkoutPlanView(workout: binding)
            } else {
                Text("Workout not found")
                    .foregroundStyle(.red)
            }
        } label: {
            HomeWorkoutRowLabel(
                title: workout.name,
                subtitle: "Saved workout",
                isScheduledToday: workout.id == todayConcretePlanId,
                isInProgram: splitConcreteIds.contains(workout.id),
                isPinned: workout.isPinned
            )
        }
        .contextMenu {
            Button {
                currentVM.startWorkoutResolvingConflict(workout, sessionPlanOrigin: .concreteWorkout(workout.id)) {
                    pendingWorkoutReplace = $0
                }
            } label: {
                Label("Start workout", systemImage: "play.fill")
            }
            Button {
                dataVM.setWorkoutPinned(workout, pinned: !workout.isPinned)
            } label: {
                Label(workout.isPinned ? "Unpin" : "Pin", systemImage: workout.isPinned ? "pin.slash" : "pin")
            }
            Button {
                workoutToRename = workout
                renameWorkoutText = workout.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button("Delete", role: .destructive) {
                dataVM.deleteWorkout(workout)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                dataVM.deleteWorkout(workout)
            }
            Button("Rename") {
                workoutToRename = workout
                renameWorkoutText = workout.name
            }
            .tint(.blue)
        }
    }

    private var templateList: some View {
        List {
            Section {
                ForEach(displayedTemplates) { template in
                    templateRow(template)
                }
            } footer: {
                Text("Long-press for actions, or swipe right to start.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func templateRow(_ template: WorkoutTemplate) -> some View {
        NavigationLink {
            SlotTemplatePlanView(templateId: template.id)
                .environmentObject(dataVM)
                .environmentObject(currentVM)
        } label: {
            HomeWorkoutRowLabel(
                title: template.name,
                subtitle: "Template · \(template.slots.count) exercise\(template.slots.count == 1 ? "" : "s")",
                isScheduledToday: template.id == todayTemplatePlanId,
                isInProgram: splitTemplateIds.contains(template.id),
                isPinned: template.isPinned
            )
        }
        .contextMenu {
            Button {
                startFromTemplate(template)
            } label: {
                Label("Start workout", systemImage: "play.fill")
            }
            .disabled(template.slots.isEmpty)
            Button {
                dataVM.setTemplatePinned(template, pinned: !template.isPinned)
            } label: {
                Label(template.isPinned ? "Unpin" : "Pin", systemImage: template.isPinned ? "pin.slash" : "pin")
            }
            Button {
                templateToRename = template
                renameTemplateText = template.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button("Delete", role: .destructive) {
                dataVM.deleteSlotTemplate(template)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !template.slots.isEmpty {
                Button {
                    startFromTemplate(template)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                dataVM.deleteSlotTemplate(template)
            }
        }
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        guard !template.slots.isEmpty else { return }
        let sessionWorkout = dataVM.instantiateWorkout(from: template)
        currentVM.startWorkoutResolvingConflict(sessionWorkout, sessionPlanOrigin: .slotTemplate(template.id)) {
            pendingWorkoutReplace = $0
        }
    }
}

// MARK: - Shared row chrome

struct HomeWorkoutRowLabel: View {
    let title: String
    let subtitle: String
    let isScheduledToday: Bool
    let isInProgram: Bool
    let isPinned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.headline)
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                if isScheduledToday {
                    Text("Today")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                if isInProgram {
                    Text("In split")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
