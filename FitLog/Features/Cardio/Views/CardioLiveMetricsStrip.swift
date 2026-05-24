//
//  CardioLiveMetricsStrip.swift
//  FitLog
//

import SwiftUI

struct CardioLiveMetricsStrip: View {
    let elapsedSeconds: Int
    let phaseLabel: String?
    let roundLabel: String?
    let isPaused: Bool

    private var combinedAccessibilityLabel: String {
        var parts = ["Elapsed \(CardioMetricsCalculator.spokenDuration(seconds: elapsedSeconds))"]
        if let phaseLabel { parts.append(phaseLabel) }
        if let roundLabel { parts.append(roundLabel) }
        if isPaused { parts.append("paused") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPaused ? "pause.circle.fill" : "timer")
                .font(.title3)
                .foregroundStyle(FitlogPalette.chartSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(CardioMetricsCalculator.formatDuration(seconds: elapsedSeconds))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    if let phaseLabel {
                        Text(phaseLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FitlogPalette.chartSecondary)
                    }
                    if let roundLabel {
                        Text(roundLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if isPaused {
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(FitlogPalette.chartSecondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityAddTraits(isPaused ? [] : [.updatesFrequently])
    }
}
