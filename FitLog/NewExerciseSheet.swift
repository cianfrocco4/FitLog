//
//  NewExerciseSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/25/26.
//

import SwiftUI

private struct ExerciseReviewPayload: Identifiable {
    let id = UUID()
    let review: NewExerciseAIReview
}

struct NewExerciseSheet: View {
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject private var aiService: AIService
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) var dismiss

    /// When set (e.g. from Add Exercise to workout), called with the new exercise after save.
    var onCreated: ((Exercise) -> Void)?

    init(onCreated: ((Exercise) -> Void)? = nil) {
        self.onCreated = onCreated
    }

    @State private var creationKind: ExerciseCreationKind = .strength
    @State private var name = ""
    @State private var description = ""
    @State private var selectedMuscles: [MuscleGroup] = []
    @State private var showMusclePicker = false

    @State private var cardioModality: ExerciseModality = .cardio
    @State private var cardioActivityKind: CardioActivityKind = .run
    @State private var cardioPrimaryMetric: CardioPrimaryMetric = .time
    @State private var cardioEquipment: CardioEquipment = .none
    @State private var cardioSupportsIntervals = true
    @State private var cardioEstimatedMETsText = ""

    @State private var isCheckingWithAI = false
    @State private var reviewPayload: ExerciseReviewPayload?
    @State private var reviewEditedName = ""
    @State private var reviewEditedMuscles: [MuscleGroup] = []
    @State private var reviewEditedDescription = ""

    @State private var showExactNameConflict = false
    @State private var showAIFailureAlert = false
    @State private var aiFailureMessage = ""
    @State private var showNameTakenInReview = false
    @State private var muscleSuggestionWasAppliedInReview = false
    @State private var showInvalidMETsAlert = false

    private enum ExerciseCreationKind: String, CaseIterable, Identifiable {
        case strength
        case cardio

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .strength: return "Strength"
            case .cardio: return "Cardio"
            }
        }
    }

    private var availableMuscles: [MuscleGroup] {
        MuscleGroup.displayOrder.filter { !selectedMuscles.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Exercise type", selection: $creationKind) {
                        ForEach(ExerciseCreationKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Exercise type")
                }

                if creationKind == .strength {
                    Section("Exercise Info") {
                        TextField("Name", text: $name)
                        TextField("Description", text: $description, axis: .vertical)
                    }
                    Section("Muscle Groups (up to 3, in order of applicability)") {
                        ForEach(selectedMuscles.indices, id: \.self) { index in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text(selectedMuscles[index].rawValue)
                                Spacer()
                                Button(role: .destructive) {
                                    selectedMuscles.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                            }
                        }
                        if selectedMuscles.count < 3 {
                            Button {
                                showMusclePicker = true
                            } label: {
                                Label("Add muscle group", systemImage: "plus.circle")
                            }
                        }
                    }
                } else {
                    CardioExerciseFormView(
                        name: $name,
                        description: $description,
                        modality: $cardioModality,
                        activityKind: $cardioActivityKind,
                        primaryMetric: $cardioPrimaryMetric,
                        equipment: $cardioEquipment,
                        supportsIntervals: $cardioSupportsIntervals,
                        estimatedMETsText: $cardioEstimatedMETsText
                    )
                }
                if creationKind == .strength, !aiService.isConfigured {
                    Section {
                        Text("Set OPENAI_API_KEY or FITLOG_AI_BASE_URL in your scheme or Info.plist to get a one-time duplicate and muscle check when you save.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isCheckingWithAI {
                        ProgressView()
                    } else {
                        Button("Save", action: saveTapped)
                            .disabled(trimmedDisplayName(name).isEmpty)
                    }
                }
            }
            .keyboardDismissToolbar()
            .sheet(isPresented: $showMusclePicker) {
                NavigationStack {
                    List(availableMuscles) { mg in
                        Button(mg.rawValue) {
                            selectedMuscles.append(mg)
                            showMusclePicker = false
                        }
                    }
                    .navigationTitle("Muscle Group")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showMusclePicker = false }
                        }
                    }
                }
            }
            .sheet(item: $reviewPayload) { payload in
                reviewSheet(for: payload.review)
            }
            .alert("Name already in library", isPresented: $showExactNameConflict) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("An exercise with this name already exists. Choose a different name to save a new custom exercise.")
            }
            .alert("Couldn’t verify with AI", isPresented: $showAIFailureAlert) {
                Button("Save anyway") {
                    finalizeSave(
                        displayName: trimmedDisplayName(name),
                        muscles: selectedMuscles,
                        description: trimmedDisplayName(description)
                    )
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(aiFailureMessage)
            }
            .alert("That name is taken", isPresented: $showNameTakenInReview) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Another exercise already uses this name. Change the name and try again.")
            }
            .alert("Invalid METs value", isPresented: $showInvalidMETsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enter a positive number for estimated METs, or leave the field empty.")
            }
        }
    }

    @ViewBuilder
    private func reviewSheet(for review: NewExerciseAIReview) -> some View {
        NavigationStack {
            Form {
                if let match = review.matchingLibraryName {
                    Section("Possible duplicate") {
                        if !review.duplicateNote.isEmpty {
                            Text(review.duplicateNote)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Library exercise:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(match)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        TextField("Your exercise name", text: $reviewEditedName)
                        Text("You can keep your wording or rename—this only affects how the exercise appears for you.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !review.musclesCorrect {
                    Section("Muscle groups") {
                        if !review.muscleNote.isEmpty {
                            Text(review.muscleNote)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !review.suggestedMuscles.isEmpty {
                            Text("Suggested order: \(review.suggestedMuscles.map(\.rawValue).joined(separator: " → "))")
                                .font(.subheadline)
                            if muscleSuggestionWasAppliedInReview {
                                Label("Applied to this exercise", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            } else {
                                Button("Apply suggestion") {
                                    reviewEditedMuscles = review.suggestedMuscles
                                    muscleSuggestionWasAppliedInReview = true
                                }
                            }
                        } else {
                            Text("Review your muscle list on the previous screen, or save with what you have.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let suggested = review.suggestedDescription {
                    Section("Description") {
                        Text("You didn’t add a description. Here’s a suggested one—edit it or clear it before saving.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Description", text: $reviewEditedDescription, axis: .vertical)
                            .lineLimit(3...8)
                        Button("Reset to suggestion") {
                            reviewEditedDescription = suggested
                        }
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        muscleSuggestionWasAppliedInReview = false
                        reviewPayload = nil
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save exercise") {
                        commitAfterReview()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedDisplayName(reviewEditedName).isEmpty)
                }
            }
            .keyboardDismissToolbar()
        }
    }

    private func trimmedDisplayName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nameAlreadyInLibrary(_ n: String) -> Bool {
        dataVM.globalExercises.contains { $0.name.caseInsensitiveCompare(n) == .orderedSame }
    }

    private func saveTapped() {
        let trimmedName = trimmedDisplayName(name)
        guard !trimmedName.isEmpty else { return }

        if nameAlreadyInLibrary(trimmedName) {
            showExactNameConflict = true
            return
        }

        if creationKind == .cardio {
            guard let metadata = CardioExerciseFormView.buildMetadata(
                activityKind: cardioActivityKind,
                primaryMetric: cardioPrimaryMetric,
                equipment: cardioEquipment,
                supportsIntervals: cardioSupportsIntervals,
                estimatedMETsText: cardioEstimatedMETsText
            ) else {
                showInvalidMETsAlert = true
                return
            }
            finalizeCardioSave(
                displayName: trimmedName,
                description: trimmedDisplayName(description),
                modality: cardioModality,
                metadata: metadata
            )
            return
        }

        if !entitlementStore.hasAccess(to: .aiExerciseReview) || !aiService.isConfigured {
            finalizeSave(displayName: trimmedName, muscles: selectedMuscles, description: trimmedDisplayName(description))
            return
        }

        isCheckingWithAI = true
        Task {
            let desc = trimmedDisplayName(description)
            let muscles = selectedMuscles
            let names = dataVM.globalExercises.map(\.name)
            do {
                let review = try await aiService.reviewNewExerciseDraft(
                    name: trimmedName,
                    description: desc,
                    muscles: muscles,
                    existingExerciseNames: names
                )
                await MainActor.run {
                    isCheckingWithAI = false
                    if review.needsReviewSheet {
                        muscleSuggestionWasAppliedInReview = false
                        reviewEditedName = trimmedName
                        reviewEditedMuscles = muscles
                        let descEmpty = desc.isEmpty
                        reviewEditedDescription = descEmpty ? (review.suggestedDescription ?? "") : desc
                        reviewPayload = ExerciseReviewPayload(review: review)
                    } else {
                        finalizeSave(displayName: trimmedName, muscles: muscles, description: desc)
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingWithAI = false
                    aiFailureMessage = error.localizedDescription
                    showAIFailureAlert = true
                }
            }
        }
    }

    private func commitAfterReview() {
        let trimmed = trimmedDisplayName(reviewEditedName)
        guard !trimmed.isEmpty else { return }
        if nameAlreadyInLibrary(trimmed) {
            showNameTakenInReview = true
            return
        }
        muscleSuggestionWasAppliedInReview = false
        reviewPayload = nil
        finalizeSave(
            displayName: trimmed,
            muscles: reviewEditedMuscles,
            description: trimmedDisplayName(reviewEditedDescription)
        )
    }

    private func finalizeSave(displayName: String, muscles: [MuscleGroup], description: String) {
        let created = dataVM.addNewExercise(name: displayName, description: description, muscles: muscles)
        onCreated?(created)
        dismiss()
    }

    private func finalizeCardioSave(
        displayName: String,
        description: String,
        modality: ExerciseModality,
        metadata: CardioExerciseMetadata
    ) {
        let created = dataVM.addNewCardioExercise(
            name: displayName,
            description: description,
            modality: modality,
            metadata: metadata
        )
        onCreated?(created)
        dismiss()
    }
}
