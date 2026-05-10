//
//  SuggestedTargetChip.swift
//  FitLog
//
//  One-line progression chip shown above the quick-log row.
//  Displays "Last: 185 × 8 → try 190 × 8 @ RPE 8" and pre-fills on tap.
//

import SwiftUI

struct SuggestedTargetChip: View {
    let suggestion: InlineProgressionTarget
    let lastWeight: Double?         // stored lb of most-recent working set
    let lastReps: Int?
    let effortStyle: EffortInputStyle
    let unit: WeightDisplayUnit
    /// Called when the user taps the chip to pre-fill the log row.
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(.tint)
                    .imageScale(.small)

                Group {
                    if let lw = lastWeight, let lr = lastReps {
                        Text("Last: \(displayWeight(lw)) × \(lr)")
                            .foregroundStyle(.secondary)
                        Text("→")
                            .foregroundStyle(.secondary)
                    }
                    Text("Try \(displayWeight(suggestion.weight)) × \(suggestion.reps)")
                        .fontWeight(.semibold)
                    if let rpe = suggestion.rpe {
                        let effortVal = effortStyle.displayValue(fromRPE: rpe)
                        Text("@ \(effortStyle.label) \(Int(effortVal))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.tint.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.tint.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Double-tap to pre-fill this target")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Private

    private func displayWeight(_ storedLb: Double) -> String {
        let display = WeightStoreConversion.displayValue(storedPounds: storedLb, unit: unit)
        return "\(WeightStoreConversion.formatDisplay(display)) \(unit.shortLabel)"
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let lw = lastWeight, let lr = lastReps {
            parts.append("Last: \(displayWeight(lw)) for \(lr) reps")
        }
        parts.append("Suggested: \(displayWeight(suggestion.weight)) for \(suggestion.reps) reps")
        if let rpe = suggestion.rpe {
            let ev = effortStyle.displayValue(fromRPE: rpe)
            parts.append("at \(effortStyle.label) \(Int(ev))")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Light") {
    SuggestedTargetChip(
        suggestion: InlineProgressionTarget(weight: 190, reps: 8, rpe: 8, hint: "Linear +5 lb"),
        lastWeight: 185,
        lastReps: 8,
        effortStyle: .rpe,
        unit: .pounds,
        onTap: {}
    )
    .padding()
}

#Preview("RIR mode") {
    SuggestedTargetChip(
        suggestion: InlineProgressionTarget(weight: 190, reps: 8, rpe: 8, hint: "Linear +5 lb"),
        lastWeight: 185,
        lastReps: 8,
        effortStyle: .rir,
        unit: .kilograms,
        onTap: {}
    )
    .padding()
}
