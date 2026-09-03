//
//  LastCompletedSessionRecapBlock.swift
//  FitLog
//
//  Compact last-session recap + Start this workout. Used by History and Home
//  week-in-review — not Home workout rows or History Sessions swipe (other nightlies).
//

import SwiftUI

struct LastCompletedSessionRecapBlock: View {
    let recap: LastCompletedSessionWorkingCopy.Recap
    var startTitle: String = "Start this workout"
    var recapIdentifier: String = FitLogA11yID.historyTabLastSession
    var startIdentifier: String = FitLogA11yID.historyTabStartThisWorkout
    var startProminent: Bool = true
    var onStart: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Last session")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .accessibilityHidden(true)
                Text(recap.workoutName)
                    .font(.headline)
                Text(recap.subtitleLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(recap.accessibilityLabel)
            .accessibilityIdentifier(recapIdentifier)
            if let onStart {
                startButton(onStart)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func startButton(_ action: @escaping () -> Void) -> some View {
        let label = Label(startTitle, systemImage: "play.fill")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        Group {
            if startProminent {
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.bordered)
            }
        }
        .accessibilityLabel(startTitle)
        .accessibilityHint("Starts a new session from \(recap.workoutName) and opens logging. Your History entry stays saved.")
        .accessibilityIdentifier(startIdentifier)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Light") {
    LastCompletedSessionRecapBlock(
        recap: LastCompletedSessionWorkingCopy.Recap(
            workoutName: "Push A",
            lastDoneLine: "Last done yesterday",
            loadLine: "185 lb × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        ),
        onStart: {}
    )
    .padding()
}

#Preview("Dark") {
    LastCompletedSessionRecapBlock(
        recap: LastCompletedSessionWorkingCopy.Recap(
            workoutName: "Zone 2",
            lastDoneLine: "Last done today",
            loadLine: "45 min",
            exerciseName: nil,
            endedAt: Date()
        ),
        startProminent: false,
        onStart: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Large Type") {
    LastCompletedSessionRecapBlock(
        recap: LastCompletedSessionWorkingCopy.Recap(
            workoutName: "Legs A",
            lastDoneLine: "Last done 3d ago",
            loadLine: "225 lb × 5 reps",
            exerciseName: "Back Squat (High Bar)",
            endedAt: Date()
        ),
        onStart: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Locale DE") {
    LastCompletedSessionRecapBlock(
        recap: LastCompletedSessionWorkingCopy.Recap(
            workoutName: "Push A",
            lastDoneLine: "Last done yesterday",
            loadLine: "85 kg × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        ),
        onStart: {}
    )
    .padding()
    .environment(\.locale, Locale(identifier: "de_DE"))
}
