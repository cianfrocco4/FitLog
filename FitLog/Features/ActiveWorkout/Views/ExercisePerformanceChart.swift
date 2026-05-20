//
//  ExercisePerformanceChart.swift
//  FitLog
//
//  Compact in-workout bar chart for set-to-set load (display weight × reps).
//

import SwiftUI

struct ExercisePerformanceChart: View {
    let loggedSets: [LoggedSet]
    let unit: WeightDisplayUnit
    let suggestion: InlineProgressionTarget?

    private var workingSets: [LoggedSet] {
        loggedSets.filter { $0.setType != .warmup }
    }

    var body: some View {
        let sets = Array(workingSets.suffix(8))
        if sets.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("This session")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 5) {
                    let maxDisplay = max(
                        sets.map { abs(WeightStoreConversion.displayValue(storedPounds: $0.weight, unit: unit)) }.max() ?? 1,
                        1
                    )
                    ForEach(sets) { set in
                        let displayW = abs(WeightStoreConversion.displayValue(storedPounds: set.weight, unit: unit))
                        let h = max(8, CGFloat(displayW / maxDisplay) * 52)
                        VStack(spacing: 3) {
                            Text("\(set.reps)")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barFill(for: set, displayW: displayW))
                                .frame(width: 22, height: h)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(WeightStoreConversion.formatDisplay(displayW)) \(unit.shortLabel), \(set.reps) reps")
                    }
                    if let sug = suggestion {
                        let displaySug = WeightStoreConversion.displayValue(storedPounds: sug.weight, unit: unit)
                        let h = max(8, CGFloat(displaySug / maxDisplay) * 52)
                        VStack(spacing: 3) {
                            Text("\(sug.reps)")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.tertiary)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.22))
                                .frame(width: 22, height: h)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.accentColor.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                )
                        }
                        .accessibilityLabel("Suggested \(WeightStoreConversion.formatDisplay(displaySug)) \(unit.shortLabel) for \(sug.reps) reps")
                    }
                }
                .frame(height: 64)
            }
            .padding(.top, 4)
        }
    }

    private func barFill(for set: LoggedSet, displayW: Double) -> Color {
        guard let sug = suggestion else {
            return FitlogPalette.chartPrimary.opacity(0.85)
        }
        let sugDisplay = WeightStoreConversion.displayValue(storedPounds: sug.weight, unit: unit)
        if displayW >= sugDisplay - 0.01 && set.reps >= sug.reps {
            return FitlogPalette.success.opacity(0.9)
        }
        if displayW >= sugDisplay * 0.92 {
            return FitlogPalette.chartSecondary.opacity(0.9)
        }
        return FitlogPalette.chartPrimary.opacity(0.55)
    }
}

#Preview {
    ExercisePerformanceChart(
        loggedSets: [
            LoggedSet(id: UUID(), weight: 135, reps: 10, restTime: 90, timestamp: Date(), setType: .working, configuration: [:], dropSegments: [], rpe: nil),
            LoggedSet(id: UUID(), weight: 155, reps: 8, restTime: 90, timestamp: Date(), setType: .working, configuration: [:], dropSegments: [], rpe: nil),
        ],
        unit: .pounds,
        suggestion: InlineProgressionTarget(weight: 165, reps: 8, rpe: 8, hint: "Test")
    )
    .padding()
}

#Preview("Dark") {
    ExercisePerformanceChart(
        loggedSets: [
            LoggedSet(id: UUID(), weight: 60, reps: 12, restTime: 60, timestamp: Date(), setType: .warmup, configuration: [:], dropSegments: [], rpe: nil),
            LoggedSet(id: UUID(), weight: 100, reps: 5, restTime: 90, timestamp: Date(), setType: .amrap, configuration: [:], dropSegments: [], rpe: nil),
        ],
        unit: .kilograms,
        suggestion: nil
    )
    .padding()
    .preferredColorScheme(.dark)
}
