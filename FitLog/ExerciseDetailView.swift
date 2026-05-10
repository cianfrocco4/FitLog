//
//  ExerciseDetailView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct ExerciseDetailView: View {
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) var dismiss
    let exerciseId: UUID
    @State private var showEditSheet = false
    @State private var showLocalRenameSheet = false
    @State private var formTipsResult: Result<[String], Error>?
    @State private var formTipsLoading = false

    private var exercise: Exercise? {
        dataVM.globalExercises.first { $0.id == exerciseId }
    }

    private var displayedFormTips: [String] {
        switch formTipsResult {
        case .success(let tips): return tips
        case .failure: return []
        case .none: return []
        }
    }

    var body: some View {
        Group {
            if let ex = exercise {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dataVM.resolvedDisplayName(for: ex))
                                .font(.largeTitle)
                            if dataVM.hasLocalDisplayName(for: ex.id) {
                                Text("Standard name: \(ex.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(ex.description)
                                .foregroundStyle(.secondary)
                            Text(ex.targetedMuscles.map(\.rawValue).joined(separator: ", "))
                                .font(.subheadline)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Form tips & cues")
                                .font(.headline)
                            if formTipsLoading {
                                ProgressView()
                                    .padding(.vertical, 4)
                            } else if case .failure(let error) = formTipsResult {
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                ForEach(heuristicFormTips(for: ex), id: \.self) { tip in
                                    Text("• \(tip)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text("(Showing default tips)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else if !displayedFormTips.isEmpty {
                                ForEach(displayedFormTips, id: \.self) { tip in
                                    Text("• \(tip)")
                                        .font(.subheadline)
                                }
                            } else {
                                ForEach(heuristicFormTips(for: ex), id: \.self) { tip in
                                    Text("• \(tip)")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .task(id: ex.id) {
                    await loadFormTips(for: ex)
                }
                .onAppear {
                    ExercisePickerPersistence.recordRecent(exerciseId: ex.id)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if ex.isCustom {
                            Button("Edit") {
                                showEditSheet = true
                            }
                        } else {
                            Menu {
                                Button("Rename locally") {
                                    showLocalRenameSheet = true
                                }
                                Button("Configuration options") {
                                    showEditSheet = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    if let ex = exercise {
                        EditExerciseSheet(exercise: ex)
                    }
                }
                .sheet(isPresented: $showLocalRenameSheet) {
                    if let ex = exercise {
                        LocalExerciseRenameSheet(
                            exercise: ex,
                            initialDisplayName: dataVM.resolvedDisplayName(for: ex)
                        )
                        .environment(dataVM)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Exercise removed",
                    systemImage: "trash",
                    description: Text("This exercise was deleted from the library.")
                )
                .onAppear { dismiss() }
            }
        }
    }

    private func loadFormTips(for ex: Exercise) async {
        guard aiService.isConfigured else {
            formTipsResult = .success(heuristicFormTips(for: ex))
            return
        }
        formTipsLoading = true
        formTipsResult = nil
        defer { formTipsLoading = false }
        do {
            let tips = try await aiService.fetchFormTips(for: ex)
            formTipsResult = .success(tips)
        } catch {
            formTipsResult = .failure(error)
        }
    }
}

// MARK: - Heuristic fallback form tips
private func heuristicFormTips(for exercise: Exercise) -> [String] {
    let name = exercise.name.lowercased()
    let muscles = exercise.targetedMuscles
    
    // Simple pattern-based suggestions by exercise type.
    if name.contains("squat") {
        return [
            "Keep your chest up and ribs stacked over your hips throughout the movement.",
            "Push your knees in line with your toes and sit between your hips, not forward into your knees.",
            "Maintain a braced core and neutral spine; think \"big breath, then squat\".",
            "Drive up by pushing the floor away and leading with your hips and chest together."
        ]
    } else if name.contains("bench") || name.contains("press") && muscles.contains(.chest) {
        return [
            "Keep your shoulder blades retracted and pinned to the bench for a stable base.",
            "Lower the bar under control to around lower chest / nipple line, with elbows ~45° from your torso.",
            "Plant your feet firmly and use leg drive without lifting your hips off the bench.",
            "Pause briefly on the chest (or keep the bar under control) before pressing back up in a slight arc."
        ]
    } else if name.contains("deadlift") {
        return [
            "Set up with the bar over mid-foot, shins close but not pushed far forward.",
            "Brace your core, flatten your back, and pull the slack out of the bar before initiating the lift.",
            "Push the floor away and keep the bar close to your body the entire time.",
            "Lock out by driving your hips through and standing tall, not by leaning back."
        ]
    } else if name.contains("row") {
        return [
            "Keep your torso stable and avoid excessive swinging; pull with your back, not momentum.",
            "Lead with your elbows, aiming them toward your hips rather than straight back.",
            "Squeeze your shoulder blades together at the top and control the negative.",
            "Keep your neck neutral and avoid shrugging your shoulders toward your ears."
        ]
    } else if name.contains("curl") {
        return [
            "Keep your elbows close to your sides and avoid swinging your upper arms.",
            "Control the eccentric; take 2–3 seconds to lower the weight.",
            "Squeeze at the top without letting your wrists collapse backward.",
            "Use a full range of motion without letting your shoulders roll forward."
        ]
    } else if muscles.contains(.quads) && name.contains("leg press") {
        return [
            "Place your feet so your knees track in line with your toes and don’t collapse inward.",
            "Lower the sled until your thighs are at least parallel without your lower back lifting off the pad.",
            "Keep constant tension; avoid locking out your knees hard at the top.",
            "Grip the handles and keep your hips and low back glued to the seat."
        ]
    }
    
    // Generic fallback tips.
    return [
        "Use a controlled tempo and full range of motion appropriate for the joint.",
        "Keep your core lightly braced and avoid painful joint positions.",
        "Start with a lighter weight to groove technique before pushing close to failure.",
        "Stop a set if form breaks down rather than forcing sloppy reps."
    ]
}
