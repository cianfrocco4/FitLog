//
//  ExercisesLibraryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

/// Wrapper so we can use `sheet(item:)` with an optional exercise and avoid blank sheet content.
private struct EditableExerciseItem: Identifiable {
    let exercise: Exercise
    var id: UUID { exercise.id }
}

private struct LocalRenameExerciseItem: Identifiable {
    let exercise: Exercise
    var id: UUID { exercise.id }
}

enum ExerciseLibraryFilter: String, CaseIterable {
    case all = "All"
    case custom = "Custom"
    case builtIn = "Built-in"
}

struct ExercisesLibraryView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject private var aiService: AIService
    @State private var showAddSheet = false
    @State private var exerciseToEdit: EditableExerciseItem?
    @State private var exerciseToRenameLocally: LocalRenameExerciseItem?
    @State private var searchText = ""
    @State private var libraryFilter: ExerciseLibraryFilter = .all

    private var filteredExercises: [Exercise] {
        var list = dataVM.globalExercises
        switch libraryFilter {
        case .all: break
        case .custom: list = list.filter { $0.isCustom }
        case .builtIn: list = list.filter { !$0.isCustom }
        }
        if !searchText.isEmpty {
            let q = searchText
            list = list.filter { ex in
                dataVM.resolvedDisplayName(for: ex).localizedCaseInsensitiveContains(q)
                    || ex.name.localizedCaseInsensitiveContains(q)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $libraryFilter) {
                        ForEach(ExerciseLibraryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(filteredExercises) { ex in
                        NavigationLink(destination: ExerciseDetailView(exerciseId: ex.id)) {
                            HStack(spacing: 8) {
                                Text(dataVM.resolvedDisplayName(for: ex))
                                Spacer(minLength: 8)
                                HStack(spacing: 6) {
                                    if dataVM.hasLocalDisplayName(for: ex.id) {
                                        Text("Renamed")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.quaternary, in: Capsule())
                                    }
                                    if ex.isCustom {
                                        Text("Custom")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.quaternary, in: Capsule())
                                    }
                                }
                            }
                        }
                .contextMenu {
                    if !ex.isCustom {
                        Button {
                            exerciseToRenameLocally = LocalRenameExerciseItem(exercise: ex)
                        } label: {
                            Label("Rename locally", systemImage: "textformat")
                        }
                    }
                    Button {
                        exerciseToEdit = EditableExerciseItem(exercise: ex)
                    } label: {
                        Label(ex.isCustom ? "Edit" : "Configuration options", systemImage: "pencil")
                    }
                }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .fitlogWorkoutBarContentInset()
            .navigationTitle("Exercise Library")
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                Button("Add New") { showAddSheet = true }
            }
            .sheet(isPresented: $showAddSheet) {
                NewExerciseSheet()
                    .environmentObject(dataVM)
                    .environmentObject(aiService)
            }
            .sheet(item: $exerciseToRenameLocally) { item in
                LocalExerciseRenameSheet(
                    exercise: item.exercise,
                    initialDisplayName: dataVM.resolvedDisplayName(for: item.exercise)
                )
                .environmentObject(dataVM)
            }
            .sheet(item: $exerciseToEdit, onDismiss: { exerciseToEdit = nil }) { item in
                EditExerciseSheet(exercise: item.exercise)
            }
        }
    }
}
