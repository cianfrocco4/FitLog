//
//  ExercisesLibraryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct ExercisesLibraryView: View {
    @EnvironmentObject var dataVM: DataManager
    @State private var showRequest = false
    
    var body: some View {
        NavigationStack {
            List(dataVM.globalExercises) { ex in NavigationLink(destination: ExerciseDetailView(exercise: ex)) { Text(ex.name) } }
            .navigationTitle("Exercise Library")
            .toolbar { Button("Request New") { showRequest = true } }
            .sheet(isPresented: $showRequest) { Text("Request form (mock)").navigationTitle("Request Exercise") }
        }
    }
}
