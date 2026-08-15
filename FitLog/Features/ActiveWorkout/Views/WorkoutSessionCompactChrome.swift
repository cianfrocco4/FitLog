//
//  WorkoutSessionCompactChrome.swift
//  FitLog
//
//  Collapsible session header to maximize vertical space for set logging.
//

import SwiftUI

struct WorkoutSessionCompactChrome: View {
    let workoutName: String
    let elapsedFormatted: String
    let isPaused: Bool
    let setsLogged: Int
    let volumeSummary: String
    @Binding var detailsExpanded: Bool
    let sessionNotes: Binding<String>
    let onPauseResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        detailsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workoutName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Label(elapsedFormatted, systemImage: "timer")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text("\(setsLogged) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !volumeSummary.isEmpty {
                                    Text("·")
                                        .foregroundStyle(.tertiary)
                                    Text(volumeSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: detailsExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    WorkoutSessionCompactChromeAccessibility.detailsToggleLabel(
                        detailsExpanded: detailsExpanded
                    )
                )
                .accessibilityValue(
                    WorkoutSessionCompactChromeAccessibility.detailsToggleValue(
                        workoutName: workoutName,
                        elapsedFormatted: elapsedFormatted,
                        setsLogged: setsLogged,
                        volumeSummary: volumeSummary
                    )
                )
                .accessibilityHint(
                    WorkoutSessionCompactChromeAccessibility.detailsToggleHint(
                        detailsExpanded: detailsExpanded
                    )
                )

                Button(action: onPauseResume) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(isPaused ? .green : .orange)
                .accessibilityLabel(
                    WorkoutSessionCompactChromeAccessibility.pauseResumeLabel(isPaused: isPaused)
                )
                .accessibilityHint(
                    WorkoutSessionCompactChromeAccessibility.pauseResumeHint(isPaused: isPaused)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if detailsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Workout notes (optional)", text: sessionNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
