//
//  WorkoutFinishReadyBanner.swift
//  FitLog
//
//  Prompts Finish when every prescribed row is in so the session is saved
//  before the next workout starts.
//

import SwiftUI

struct WorkoutFinishReadyBanner: View {
    let onFinish: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(FitlogPalette.success)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(WorkoutFinishReadyPolicy.bannerTitle)
                    .font(.subheadline.weight(.semibold))
                Text(WorkoutFinishReadyPolicy.bannerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Finish", action: onFinish)
                .buttonStyle(.borderedProminent)
                .tint(FitlogPalette.success)
                .controlSize(.small)
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Starts finish checks; saves to History if you confirm")
        }
        .padding()
        .background(FitlogPalette.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WorkoutFinishReadyPolicy.bannerAccessibilityLabel)
    }
}

#Preview("Light") {
    WorkoutFinishReadyBanner(onFinish: {})
        .padding(.vertical)
        .background(Color(.systemBackground))
}

#Preview("Dark") {
    WorkoutFinishReadyBanner(onFinish: {})
        .padding(.vertical)
        .background(Color(.systemBackground))
        .preferredColorScheme(.dark)
}

#Preview("Large Type") {
    WorkoutFinishReadyBanner(onFinish: {})
        .padding(.vertical)
        .background(Color(.systemBackground))
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
