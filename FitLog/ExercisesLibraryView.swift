//
//  ExercisesLibraryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct ExercisesLibraryView: View {
    @EnvironmentObject var dataVM: DataManager
    @State private var showAddSheet = false
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty { return dataVM.globalExercises }
        return dataVM.globalExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredExercises) { ex in
                NavigationLink(destination: ExerciseDetailView(exercise: ex)) {
                    Text(ex.name)
                }
            }
            .navigationTitle("Exercise Library")
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                Button("Add New") { showAddSheet = true }
            }
            .sheet(isPresented: $showAddSheet) {
                NewExerciseSheet()
            }
        }
    }
}
