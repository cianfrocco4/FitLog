//
//  HomeStartWorkoutFAB.swift
//  FitLog
//
//  Sticky primary action to start a workout from Home.
//

import SwiftUI

struct HomeStartWorkoutFAB: View {
    let isWorkoutActive: Bool
    let onTap: () -> Void

    @State private var tapSerial = 0

    var body: some View {
        if !isWorkoutActive {
            Button {
                tapSerial += 1
                onTap()
            } label: {
                Label("Start workout", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 4)
            .accessibilityIdentifier(FitLogA11yID.startWorkout)
            .accessibilityHint("Opens options to start a workout")
            .sensoryFeedback(.impact(weight: .medium), trigger: tapSerial)
        }
    }
}
