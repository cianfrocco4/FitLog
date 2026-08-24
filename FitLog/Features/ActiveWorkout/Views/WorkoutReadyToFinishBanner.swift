//
//  WorkoutReadyToFinishBanner.swift
//  FitLog
//
//  Persistent CTA after every planned set is logged so finish is obvious.
//

import SwiftUI

struct WorkoutReadyToFinishBanner: View {
    var onFinish: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(FitlogPalette.success)
                .accessibilityHidden(true)
            Text(HomeActiveWorkoutProgress.readyToFinishMessage())
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Finish", action: onFinish)
                .fontWeight(.semibold)
                .buttonStyle(.borderedProminent)
                .tint(FitlogPalette.success)
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Starts finish checks; saves to history if you confirm")
        }
        .padding()
        .background(FitlogPalette.success.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(FitLogA11yID.readyToFinishBanner)
    }
}

#Preview("Light") {
    WorkoutReadyToFinishBanner(onFinish: {})
        .padding(.vertical)
}

#Preview("Dark") {
    WorkoutReadyToFinishBanner(onFinish: {})
        .padding(.vertical)
        .preferredColorScheme(.dark)
}
