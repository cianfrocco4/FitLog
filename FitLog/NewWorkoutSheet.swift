//
//  NewWorkoutSheet.swift
//  FitLog
//
//  Guided workout creation: quick templates, focus presets, optional starter exercises.
//

import SwiftUI

extension Notification.Name {
    /// Posted to open the new-workout sheet from onboarding. `userInfo["launch"]` as `String`: `templatesFirst` | `buildOwnFirst`.
    static let fitlogPresentNewWorkout = Notification.Name("fitlogPresentNewWorkout")
}

/// How `NewWorkoutSheet` should open (e.g. from onboarding deep link).
enum NewWorkoutLaunchHint: String {
    case templatesFirst
    case buildOwnFirst
    case cardioFirst
}

struct NewWorkoutSheet: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) var dismiss

    /// Set when presenting from Home (e.g. after onboarding).
    var launchHint: NewWorkoutLaunchHint?

    @State private var workoutName = ""
    @State private var focus: WorkoutCreationFocus = .custom
    @State private var createdWorkoutId: UUID?
    @State private var cardioBuilderWorkoutId: UUID?
    @State private var pendingStarterReview: PendingStarterReview?
    @State private var kindTab: NewWorkoutKindTab = .strength

    private enum NewWorkoutKindTab: String, CaseIterable, Identifiable {
        case strength
        case cardio
        var id: String { rawValue }
    }

    private struct PendingStarterReview: Identifiable {
        let id = UUID()
        let workoutId: UUID
        let resolved: [(exercise: Exercise, sets: Int, reps: String)]
    }

    var body: some View {
        @Bindable var dm = dataVM
        return NavigationStack {
            Group {
                if let cardioId = cardioBuilderWorkoutId {
                    CardioWorkoutBuilderView(workoutId: cardioId, dataManager: dataVM)
                        .environment(dataVM)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                            }
                        }
                } else if let id = createdWorkoutId, let binding = $dm.userWorkouts[id] {
                    WorkoutPlanView(workout: binding, creationFlowOnDone: { dismiss() }, currentVM: currentVM)
                        .environment(dataVM)
                        .environmentObject(aiService)
                } else if let pending = pendingStarterReview {
                    starterReviewView(pending)
                } else {
                    guidedForm
                }
            }
        }
        .onAppear {
            if let hint = launchHint {
                switch hint {
                case .templatesFirst:
                    kindTab = .strength
                    focus = .push
                case .buildOwnFirst:
                    kindTab = .strength
                    focus = .custom
                case .cardioFirst:
                    kindTab = .cardio
                }
            }
        }
    }

    private var guidedForm: some View {
        Form {
            Section {
                Picker("Workout type", selection: $kindTab) {
                    Text("Strength").tag(NewWorkoutKindTab.strength)
                    Text("Cardio").tag(NewWorkoutKindTab.cardio)
                }
                .pickerStyle(.segmented)
                .accessibilityHint("Switch between strength and cardio workout creation")

                Text(
                    kindTab == .strength
                        ? "Pick a template for a fast start, or name your workout and choose a focus for suggested exercises."
                        : "Start from a cardio template, or open the builder to add intervals and steady work."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if kindTab == .strength {
                strengthTemplateSection
                buildYourOwnSection
            } else {
                cardioTemplateSection
                Section {
                    Button {
                        startEmptyCardioBuilder()
                    } label: {
                        Label("Build cardio workout…", systemImage: "figure.run.circle.fill")
                    }
                    .accessibilityHint("Opens the cardio workout builder on a new empty workout")
                }
            }
        }
        .navigationTitle("New workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if kindTab == .strength {
                    Button("Create") { createFromForm() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreateFromForm)
                }
            }
        }
        .keyboardDismissToolbar()
    }

    private var strengthTemplateSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WorkoutQuickStartTemplate.all) { tpl in
                        Button {
                            applyQuickTemplate(tpl)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tpl.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(tpl.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(width: 132, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } header: {
            Text("Quick start templates")
        } footer: {
            Text("Creates a saved workout with common movements from your library. You can edit everything next.")
                .font(.caption)
        }
    }

    private var buildYourOwnSection: some View {
        Section {
            TextField("Workout name", text: $workoutName, prompt: Text("e.g. Push Day, Legs"))
                .textFieldStyle(.roundedBorder)

            Picker("Focus", selection: $focus) {
                ForEach(WorkoutCreationFocus.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
        } header: {
            Text("Build your own")
        } footer: {
            Text("Non-custom focuses offer optional starter exercises after you tap Create.")
                .font(.caption)
        }
    }

    private var cardioTemplateSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CardioTemplateLibrary.quickStart) { tpl in
                        Button {
                            applyCardioTemplate(tpl)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.run")
                                        .font(.caption.weight(.semibold))
                                    Text(tpl.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                Text(tpl.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(width: 148, alignment: .leading)
                            .padding(12)
                            .background(FitlogPalette.chartSecondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } header: {
            Text("Cardio quick start")
        } footer: {
            Text("Creates a cardio workout from a template. Edit prescriptions in the builder.")
                .font(.caption)
        }
    }

    private var canCreateFromForm: Bool {
        let trimmed = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        if focus == .custom { return !trimmed.isEmpty }
        return true
    }

    private func effectiveNameForForm() -> String {
        let trimmed = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return focus.suggestedWorkoutName
    }

    private func createFromForm() {
        let name = dataVM.uniqueWorkoutName(effectiveNameForForm())
        let id = dataVM.createWorkout(name: name)
        if focus == .custom {
            createdWorkoutId = id
            return
        }
        let resolved = WorkoutStarterResolution.resolvedStarters(focus: focus, library: dataVM.globalExercises)
        if resolved.isEmpty {
            createdWorkoutId = id
            return
        }
        pendingStarterReview = PendingStarterReview(workoutId: id, resolved: resolved)
    }

    private func startEmptyCardioBuilder() {
        let name = dataVM.uniqueWorkoutName(
            workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Cardio Workout"
                : workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        cardioBuilderWorkoutId = dataVM.createCardioWorkout(name: name, kind: .cardio)
    }

    private func applyCardioTemplate(_ template: CardioWorkoutTemplate) {
        let name = dataVM.uniqueWorkoutName(template.name)
        let id = dataVM.createCardioWorkout(name: name, kind: template.workoutKind)
        guard var w = dataVM.workout(id: id) else {
            cardioBuilderWorkoutId = id
            return
        }
        let resolved = CardioTemplateLibrary.resolveRows(template.rows, library: dataVM.globalExercises)
        for item in resolved {
            guard let fresh = dataVM.workout(id: id) else { break }
            _ = dataVM.addCardioExercise(to: fresh, exercise: item.exercise, prescription: item.prescription)
            w = fresh
        }
        dataVM.setWorkoutKind(w, kind: template.workoutKind)
        createdWorkoutId = id
    }

    private func applyQuickTemplate(_ tpl: WorkoutQuickStartTemplate) {
        let name = dataVM.uniqueWorkoutName(tpl.defaultWorkoutName)
        let id = dataVM.createWorkout(name: name)
        let resolved = WorkoutStarterResolution.resolvedTemplate(tpl, library: dataVM.globalExercises)
        guard let w = dataVM.workout(id: id) else {
            createdWorkoutId = id
            return
        }
        if resolved.isEmpty {
            createdWorkoutId = id
            return
        }
        populateWorkout(w, with: resolved)
        createdWorkoutId = id
    }

    private func populateWorkout(_ workout: Workout, with items: [(exercise: Exercise, sets: Int, reps: String)]) {
        for item in items {
            let sets = min(max(1, item.sets), 10)
            let reps = item.reps.trimmingCharacters(in: .whitespacesAndNewlines)
            let repsFinal = reps.isEmpty ? "8-12" : reps
            guard let fresh = dataVM.workout(id: workout.id) else { break }
            _ = dataVM.addExercise(
                to: fresh,
                exercise: item.exercise,
                recommendedSets: sets,
                recommendedReps: repsFinal,
                configurationFields: [],
                recommendedConfigBySet: Array(repeating: [:], count: sets)
            )
        }
    }

    @ViewBuilder
    private func starterReviewView(_ pending: PendingStarterReview) -> some View {
        let names = pending.resolved.map { dataVM.resolvedDisplayName(for: $0.exercise) }
        Form {
            Section {
                Text("Add \(pending.resolved.count) starter exercises to this workout? You can reorder or remove them next.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Preview") {
                ForEach(Array(names.enumerated()), id: \.offset) { _, n in
                    Text("• \(n)")
                        .font(.subheadline)
                }
            }
            Section {
                Button("Add exercises") {
                    if let w = dataVM.workout(id: pending.workoutId) {
                        populateWorkout(w, with: pending.resolved)
                    }
                    pendingStarterReview = nil
                    createdWorkoutId = pending.workoutId
                }
                .buttonStyle(.borderedProminent)

                Button("Start empty", role: .cancel) {
                    pendingStarterReview = nil
                    createdWorkoutId = pending.workoutId
                }
            }
        }
        .navigationTitle("Suggested exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if let w = dataVM.workout(id: pending.workoutId) {
                        dataVM.deleteWorkout(w)
                    }
                    pendingStarterReview = nil
                }
            }
        }
    }
}
