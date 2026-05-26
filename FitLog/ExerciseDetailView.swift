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
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(ExerciseFormGuideService.self) private var formGuideService
    @Environment(\.dismiss) var dismiss
    let exerciseId: UUID
    @State private var showEditSheet = false
    @State private var showLocalRenameSheet = false
    @State private var formTipsResult: Result<[String], Error>?
    @State private var formTipsLoading = false
    @State private var showFormGuideSheet = false

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

                        if ex.modality == .strength || ex.modality == .hybrid {
                            ExerciseFormGuideCompactView(exercise: ex, formTips: displayedFormTips) {
                                showFormGuideSheet = true
                            }

                            if formGuideService.isConfigured {
                                Button {
                                    showFormGuideSheet = true
                                } label: {
                                    Label("Open full form guide", systemImage: "arrow.up.left.and.arrow.down.right")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                            }
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
                                ForEach(ExerciseFormHeuristicTips.tips(for: ex), id: \.self) { tip in
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
                                ForEach(ExerciseFormHeuristicTips.tips(for: ex), id: \.self) { tip in
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
                .sheet(isPresented: $showFormGuideSheet) {
                    ExerciseFormGuideSheet(exercise: ex)
                        .environment(formGuideService)
                        .environmentObject(aiService)
                        .environmentObject(userPreferences)
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
            formTipsResult = .success(ExerciseFormHeuristicTips.tips(for: ex))
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
