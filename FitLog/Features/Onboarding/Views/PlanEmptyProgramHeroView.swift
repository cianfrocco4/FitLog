//
//  PlanEmptyProgramHeroView.swift
//  FitLog
//
//  Empty Plan calendar when the user has no program or weekly lineup yet.
//

import SwiftUI

struct PlanEmptyProgramHeroView: View {
    var onBuildProgram: () -> Void
    var onNewWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No program yet")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Build a weekly program to fill this calendar, or create a workout first and assign it later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button {
                    onBuildProgram()
                } label: {
                    Label("Build a weekly program", systemImage: "calendar.badge.clock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("planEmpty.buildProgram")
                .accessibilityHint("Opens the program builder without leaving Plan")

                Button {
                    onNewWorkout()
                } label: {
                    Label("Create a workout", systemImage: "plus.rectangle.on.folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("planEmpty.newWorkout")
                .accessibilityHint("Opens Home to create a workout")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .accessibilityIdentifier("planEmpty.hero")
    }
}

#Preview("Light") {
    PlanEmptyProgramHeroView(onBuildProgram: {}, onNewWorkout: {})
        .padding()
}

#Preview("Dark") {
    PlanEmptyProgramHeroView(onBuildProgram: {}, onNewWorkout: {})
        .padding()
        .preferredColorScheme(.dark)
}
