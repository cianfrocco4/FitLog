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

enum ExerciseLibraryFilter: String, CaseIterable {
    case all = "All"
    case custom = "Custom"
    case builtIn = "Built-in"
}

struct ExercisesLibraryView: View {
    @EnvironmentObject var dataVM: DataManager
    @State private var showAddSheet = false
    @State private var exerciseToEdit: EditableExerciseItem?
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
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                                Text(ex.name)
                                Spacer(minLength: 8)
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
                .contextMenu {
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
            .navigationTitle("Exercise Library")
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                Button("Add New") { showAddSheet = true }
            }
            .sheet(isPresented: $showAddSheet) {
                NewExerciseSheet()
            }
            .sheet(item: $exerciseToEdit, onDismiss: { exerciseToEdit = nil }) { item in
                EditExerciseSheet(exercise: item.exercise)
            }
        }
    }
}
