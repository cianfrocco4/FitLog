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
    /// When set, shows a one-tap control that pre-fills and logs immediately.
    var onLogNow: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: suggestion.suggestsPRAttempt ? "trophy.fill" : "arrow.up.right.circle.fill")
                        .foregroundStyle(suggestion.suggestsPRAttempt ? Color.orange : Color.accentColor)
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

            if let onLogNow {
                Button(action: onLogNow) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(FitlogPalette.success, Color.primary.opacity(0.35))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log suggested set now")
                .accessibilityHint("Logs this weight and reps in one step")
            }
        }
    }

    // MARK: - Private

    private func displayWeight(_ storedLb: Double) -> String {
        let display = WeightStoreConversion.displayValue(storedPounds: storedLb, unit: unit)
        return "\(WeightStoreConversion.formatDisplay(display)) \(unit.shortLabel)"
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if suggestion.suggestsPRAttempt {
            parts.append("Possible personal record attempt")
        }
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
