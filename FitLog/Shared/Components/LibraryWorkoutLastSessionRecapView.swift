//
//  LibraryWorkoutLastSessionRecapView.swift
//  FitLog
//
//  Compact last-session recap with an optional Start control.
//

import SwiftUI

struct LibraryWorkoutLastSessionRecapView: View {
    let recap: LibraryWorkoutLastSessionCopy.Recap
    var startTitle: String? = nil
    var startAccessibilityIdentifier: String? = nil
    var onStart: (() -> Void)? = nil

    @State private var startFeedbackSerial = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recap.lastDoneLine)
                .font(.subheadline.weight(.semibold))
            if let name = recap.exerciseName, !name.isEmpty {
                Text("\(name) · \(recap.loadLine)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(recap.loadLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let startTitle, let onStart {
                Button {
                    startFeedbackSerial += 1
                    onStart()
                } label: {
                    Text(startTitle)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .sensoryFeedback(.impact, trigger: startFeedbackSerial)
                .accessibilityLabel(startTitle)
                .accessibilityHint("Starts this saved workout and opens logging")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(startAccessibilityIdentifier ?? FitLogA11yID.personalRecordStartWorkout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(FitLogA11yID.libraryWorkoutLastSession)
        .modifier(LibraryWorkoutLastSessionRecapA11y(recap: recap, combinesChildren: onStart == nil))
    }
}

private struct LibraryWorkoutLastSessionRecapA11y: ViewModifier {
    let recap: LibraryWorkoutLastSessionCopy.Recap
    let combinesChildren: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if combinesChildren {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(recap.accessibilityLabel)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Strength recap") {
    LibraryWorkoutLastSessionRecapView(
        recap: LibraryWorkoutLastSessionCopy.Recap(
            lastDoneLine: "Last done yesterday",
            loadLine: "185 lb × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        )
    )
    .padding()
}

#Preview("Cardio recap with Start") {
    LibraryWorkoutLastSessionRecapView(
        recap: LibraryWorkoutLastSessionCopy.Recap(
            lastDoneLine: "Last done today",
            loadLine: "45 min",
            exerciseName: nil,
            endedAt: Date()
        ),
        startTitle: "Start Zone 2",
        onStart: {}
    )
    .padding()
}

#Preview("Dark") {
    LibraryWorkoutLastSessionRecapView(
        recap: LibraryWorkoutLastSessionCopy.Recap(
            lastDoneLine: "Last done 3d ago",
            loadLine: "225 lb × 5 reps",
            exerciseName: "Back Squat",
            endedAt: Date()
        ),
        startTitle: "Start Legs A",
        onStart: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
#endif
