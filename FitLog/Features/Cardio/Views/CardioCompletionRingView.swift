//
//  CardioCompletionRingView.swift
//  FitLog
//

import SwiftUI

/// Dual progress rings for cardio duration and distance on the workout completion screen.
struct CardioCompletionRingView: View {
    let durationSeconds: Int
    let distanceMeters: Double
    let durationGoalSeconds: Int?
    let distanceGoalMeters: Double?

    private var hasDurationGoal: Bool {
        guard let goal = durationGoalSeconds, goal > 0 else { return false }
        return true
    }

    private var hasDistanceGoal: Bool {
        guard let goal = distanceGoalMeters, goal > 0 else { return false }
        return true
    }

    var body: some View {
        HStack(spacing: 24) {
            ring(
                title: "Time",
                value: CardioMetricsCalculator.formatDuration(seconds: durationSeconds),
                progress: durationProgress,
                hasGoal: hasDurationGoal,
                color: FitlogPalette.chartSecondary
            )
            ring(
                title: "Distance",
                value: distanceMeters > 0 ? CardioMetricsCalculator.formatDistance(meters: distanceMeters) : "—",
                progress: distanceProgress,
                hasGoal: hasDistanceGoal,
                color: FitlogPalette.success
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let timeSpoken = CardioMetricsCalculator.spokenDuration(seconds: durationSeconds)
        let distanceText = distanceMeters > 0
            ? CardioMetricsCalculator.formatDistance(meters: distanceMeters)
            : "not recorded"
        var parts = ["Cardio totals, time \(timeSpoken), distance \(distanceText)"]
        if hasDurationGoal, let goal = durationGoalSeconds {
            let pct = Int(durationProgress * 100)
            parts.append("time \(pct) percent of \(CardioMetricsCalculator.spokenDuration(seconds: goal)) goal")
        }
        if hasDistanceGoal, let goal = distanceGoalMeters {
            let pct = Int(distanceProgress * 100)
            parts.append("distance \(pct) percent of \(CardioMetricsCalculator.formatDistance(meters: goal)) goal")
        }
        return parts.joined(separator: ", ")
    }

    private var durationProgress: Double {
        guard let goal = durationGoalSeconds, goal > 0 else { return 1 }
        return min(1, Double(durationSeconds) / Double(goal))
    }

    private var distanceProgress: Double {
        guard let goal = distanceGoalMeters, goal > 0 else { return 1 }
        return min(1, distanceMeters / goal)
    }

    private func ring(title: String, value: String, progress: Double, hasGoal: Bool, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 10)
                if hasGoal {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                } else {
                    Circle()
                        .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                }
                VStack(spacing: 2) {
                    Text(value)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .multilineTextAlignment(.center)
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)
        }
        .accessibilityHidden(true)
    }
}
