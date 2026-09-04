//
//  CardioWorkoutBuilderView.swift
//  FitLog
//
//  List-based cardio workout builder with templates, reorder, and prescription editing.
//

import SwiftUI

struct CardioWorkoutBuilderView: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet

    @State private var viewModel: CardioWorkoutBuilderViewModel
    @State private var showTemplatePicker = false
    @State private var showExercisePicker = false
    @State private var editingRow: CardioRowEditItem?
    @State private var pendingTemplate: CardioWorkoutTemplate?
    @State private var pendingStartFreshReplace: PendingWorkoutReplace?
    @State private var startFreshTrigger = 0

    private struct CardioRowEditItem: Identifiable {
        let id: UUID
        let exerciseName: String
        var prescription: CardioPrescription
    }

    init(workoutId: UUID, dataManager: DataManager) {
        _viewModel = State(initialValue: CardioWorkoutBuilderViewModel(workoutId: workoutId, dataManager: dataManager))
    }

    var body: some View {
        @Bindable var vm = viewModel
        List {
            Section {
                TextField("Workout name", text: $vm.workoutName)
                    .onSubmit { viewModel.renameWorkout() }
                if let kind = viewModel.workout?.workoutKind {
                    LabeledContent("Type", value: kind.displayName)
                }
            } header: {
                Text("Workout")
            } footer: {
                Text("Add cardio exercises and configure targets. Strength rows can be added from the workout plan after saving.")
                    .font(.caption)
            }

            if lastSessionRecap != nil || canStartCurrentWorkout {
                Section {
                    if let recap = lastSessionRecap {
                        HubLastSessionRecapBlock(
                            recap: recap,
                            startTitle: "Start this workout",
                            recapIdentifier: FitLogA11yID.cardioBuilderLastSession,
                            startIdentifier: FitLogA11yID.cardioBuilderStartWorkout,
                            startProminent: true,
                            onStart: canStartCurrentWorkout ? { startCurrentWorkout() } : nil
                        )
                    } else if canStartCurrentWorkout {
                        Button {
                            startCurrentWorkout()
                        } label: {
                            Label("Start this workout", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Start this workout")
                        .accessibilityHint("Starts a new session from this cardio workout and opens logging.")
                        .accessibilityIdentifier(FitLogA11yID.cardioBuilderStartWorkout)
                        .accessibilityAddTraits(.isButton)
                    }
                } header: {
                    Text("Last time")
                } footer: {
                    Text("Starts a new session from this cardio workout. History stays saved.")
                }
            }

            Section {
                if viewModel.rows.isEmpty {
                    ContentUnavailableView(
                        "No cardio exercises",
                        systemImage: "figure.run",
                        description: Text("Choose a template or add exercises from your cardio library.")
                    )
                } else {
                    ForEach(viewModel.rows) { row in
                        cardioBuilderRow(row)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteRow(rowId: viewModel.rows[index].id)
                        }
                    }
                    .onMove { from, to in
                        viewModel.moveRow(from: from, to: to)
                    }
                }
            } header: {
                Text("Exercises")
            }
        }
        .navigationTitle("Cardio Builder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    viewModel.renameWorkout()
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Menu {
                    Button {
                        showTemplatePicker = true
                    } label: {
                        Label("Apply template…", systemImage: "doc.on.doc")
                    }
                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add exercise…", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Builder actions")
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            NavigationStack {
                CardioTemplatePickerView(templates: CardioTemplateLibrary.all) { template in
                    if viewModel.rows.isEmpty {
                        viewModel.applyTemplate(template, replaceExisting: true)
                    } else {
                        pendingTemplate = template
                        viewModel.replaceTemplateWarning =
                            "This workout already has exercises. Applying the template will replace them."
                    }
                }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            CardioExercisePickerSheet { exercise in
                viewModel.addExercise(exercise)
            }
            .environment(dataVM)
        }
        .sheet(item: $editingRow) { item in
            CardioRowPrescriptionEditorSheet(
                workoutId: viewModel.workoutId,
                rowId: item.id,
                exerciseName: item.exerciseName,
                prescription: item.prescription
            )
            .environment(dataVM)
        }
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartFreshReplace,
            onAfterReplace: {
                dismiss()
                openCurrentWorkoutSheet?()
            }
        )
        .sensoryFeedback(.impact, trigger: startFreshTrigger)
        .alert("Replace exercises?", isPresented: Binding(
            get: { viewModel.replaceTemplateWarning != nil },
            set: { if !$0 { viewModel.replaceTemplateWarning = nil } }
        )) {
            Button("Replace", role: .destructive) {
                if let template = pendingTemplate {
                    viewModel.confirmReplaceAndApplyTemplate(template)
                    pendingTemplate = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingTemplate = nil
                viewModel.replaceTemplateWarning = nil
            }
        } message: {
            Text(viewModel.replaceTemplateWarning ?? "")
        }
    }

    @ViewBuilder
    private func cardioBuilderRow(_ row: WorkoutExercise) -> some View {
        let exercise = row.exerciseId.flatMap { id in dataVM.globalExercises.first { $0.id == id } }
        let prescription = row.effectiveCardioPrescription ?? CardioPrescription()
        Button {
            editingRow = CardioRowEditItem(
                id: row.id,
                exerciseName: dataVM.displayName(for: row),
                prescription: prescription
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(dataVM.displayName(for: row))
                    .font(.headline)
                    .foregroundStyle(.primary)
                CardioPrescriptionRowView(prescription: prescription, exercise: exercise)
                Text("Tap to edit prescription")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHint("Opens prescription editor")
    }

    private var lastSessionRecap: HubLastSessionWorkingCopy.Recap? {
        HubLastSessionWorkingCopy.recap(
            forLibraryWorkoutId: viewModel.workoutId,
            sessions: dataVM.completedSessions,
            weightUnit: userPreferences.weightDisplayUnit
        )
    }

    private var canStartCurrentWorkout: Bool {
        guard let workout = dataVM.workout(id: viewModel.workoutId) else { return false }
        return !workout.exercises.isEmpty
    }

    private func startCurrentWorkout() {
        guard let workout = dataVM.workout(id: viewModel.workoutId),
              !workout.exercises.isEmpty else { return }
        startFreshTrigger += 1
        HubLastSessionWorkingCopy.startLibraryWorkout(
            workout,
            dataVM: dataVM,
            currentVM: currentVM,
            originHint: .workout(workout.id),
            openCurrentWorkoutSheet: {
                dismiss()
                openCurrentWorkoutSheet?()
            },
            setPendingReplace: { pendingStartFreshReplace = $0 }
        )
    }
}
