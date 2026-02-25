//
//  NewExerciseSheet.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/25/26.
//

import SwiftUI

struct NewExerciseSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var muscles = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                    TextField("Muscles (comma separated)", text: $muscles)
                }
            }
            .navigationTitle("Add New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let muscleList = muscles.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        dataVM.addNewExercise(name: name, description: description, muscles: muscleList)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
