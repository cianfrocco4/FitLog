//
//  CurrentWorkoutCollapsedBar.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct CurrentWorkoutCollapsedBar: View {
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @State private var showPullUp = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button { showPullUp = true } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(currentVM.currentSession?.workout.name ?? "")
                        Text(currentVM.currentSession?.exerciseLogs.first?.workoutExercise.exercise.name ?? "")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Now")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            
            // Workout timer + pause/play
            HStack(spacing: 8) {
                Text(currentVM.workoutElapsedFormatted)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .minimumScaleFactor(0.8)
                Button {
                    if currentVM.isWorkoutPaused {
                        currentVM.resumeWorkout()
                    } else {
                        currentVM.pauseWorkout()
                    }
                } label: {
                    Image(systemName: currentVM.isWorkoutPaused ? "play.fill" : "pause.fill")
                        .font(.body)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal)
        .sheet(isPresented: $showPullUp) {
            CurrentWorkoutPullUpSheet()
                .environmentObject(currentVM)
        }
    }
}
