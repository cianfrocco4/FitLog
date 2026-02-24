//
//  ExerciseDetailView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise
    var body: some View {
        ScrollView { VStack { Text(exercise.name).font(.largeTitle); Text(exercise.description); Text(exercise.targetedMuscles.joined(separator: ", ")) } }
    }
}
