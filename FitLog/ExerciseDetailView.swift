//
//  ExerciseDetailView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct ExerciseDetailView: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) var dismiss
    let exerciseId: UUID
    @State private var showEditSheet = false

    private var exercise: Exercise? {
        dataVM.globalExercises.first { $0.id == exerciseId }
    }

    var body: some View {
        Group {
            if let ex = exercise {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ex.name)
                            .font(.largeTitle)
                        Text(ex.description)
                            .foregroundStyle(.secondary)
                        Text(ex.targetedMuscles.map(\.rawValue).joined(separator: ", "))
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .toolbar {
                    if ex.isCustom {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Edit") {
                                showEditSheet = true
                            }
                        }
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    EditExerciseSheet(exercise: ex)
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
}
