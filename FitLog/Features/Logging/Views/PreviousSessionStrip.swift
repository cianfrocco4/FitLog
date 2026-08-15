//
//  PreviousSessionStrip.swift
//  FitLog
//
//  Compact strip showing the last 3 working sets from the previous session,
//  with delta arrows vs the set being entered. Tapping a pill prefills the draft.
//

import SwiftUI

struct PreviousSessionStrip: View {
    /// Last 3 working sets from the prior session (most-recent set first).
    let sets: [LoggedSet]
    /// Current draft weight/reps for delta comparison (stored lb).
    let draftWeight: Double
    let draftReps: Int
    let unit: WeightDisplayUnit
    /// When set, each pill becomes a button that prefills weight/reps.
    var onSelectSet: ((LoggedSet) -> Void)? = nil

    @State private var prefillHapticTick = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sets.prefix(3)) { set in
                    if let onSelectSet {
                        Button {
                            onSelectSet(set)
                            prefillHapticTick += 1
                        } label: {
                            PrevSetPill(
                                set: set,
                                draftWeight: draftWeight,
                                draftReps: draftReps,
                                unit: unit
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(pillAccessibilityLabel(for: set))
                        .accessibilityHint(PreviousSessionPrefillAccessibility.pillHint)
                        .accessibilityAddTraits(.isButton)
                    } else {
                        PrevSetPill(
                            set: set,
                            draftWeight: draftWeight,
                            draftReps: draftReps,
                            unit: unit
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .sensoryFeedback(.selection, trigger: prefillHapticTick)
        .modifier(PreviousSessionStripAccessibilityModifier(
            isInteractive: onSelectSet != nil,
            combinedLabel: accessibilityText
        ))
    }

    private func pillAccessibilityLabel(for set: LoggedSet) -> String {
        let display = WeightStoreConversion.displayValue(storedPounds: set.weight, unit: unit)
        return PreviousSessionPrefillAccessibility.pillLabel(
            weightDisplay: WeightStoreConversion.formatDisplay(display),
            unitLabel: unit.shortLabel,
            reps: set.reps
        )
    }

    private var accessibilityText: String {
        let parts = sets.prefix(3).map { set -> String in
            let display = WeightStoreConversion.displayValue(storedPounds: set.weight, unit: unit)
            return "\(WeightStoreConversion.formatDisplay(display)) \(unit.shortLabel) × \(set.reps)"
        }
        return "Previous sets: " + parts.joined(separator: ", ")
    }
}

private struct PreviousSessionStripAccessibilityModifier: ViewModifier {
    let isInteractive: Bool
    let combinedLabel: String

    func body(content: Content) -> some View {
        if isInteractive {
            content
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(combinedLabel)
        }
    }
}

// MARK: - Pill subview

private struct PrevSetPill: View {
    let set: LoggedSet
    let draftWeight: Double
    let draftReps: Int
    let unit: WeightDisplayUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(weightLabel)
                    .fontWeight(.medium)
                if let delta = weightDelta {
                    DeltaLabel(value: delta, suffix: unit.shortLabel)
                }
            }
            HStack(spacing: 4) {
                Text("\(set.reps) reps")
                if let delta = repsDelta {
                    DeltaLabel(value: Double(delta), suffix: "")
                }
            }
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var weightLabel: String {
        let d = WeightStoreConversion.displayValue(storedPounds: set.weight, unit: unit)
        return "\(WeightStoreConversion.formatDisplay(d)) \(unit.shortLabel)"
    }

    private var weightDelta: Double? {
        guard draftWeight > 0 else { return nil }
        let diff = WeightStoreConversion.displayValue(storedPounds: draftWeight - set.weight, unit: unit)
        guard abs(diff) > 0.01 else { return nil }
        return diff
    }

    private var repsDelta: Int? {
        guard draftReps > 0 else { return nil }
        let diff = draftReps - set.reps
        guard diff != 0 else { return nil }
        return diff
    }
}

private struct DeltaLabel: View {
    let value: Double
    let suffix: String

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: value > 0 ? "arrow.up" : "arrow.down")
            Text(formatted)
        }
        .font(.caption2)
        .foregroundStyle(value > 0 ? Color.green : Color.red)
    }

    private var formatted: String {
        let abs = Swift.abs(value)
        let s = abs == floor(abs) ? "\(Int(abs))" : String(format: "%.1f", abs)
        return suffix.isEmpty ? s : "\(s) \(suffix)"
    }
}

#Preview {
    VStack(alignment: .leading) {
        Text("Previous sets").font(.caption2).foregroundStyle(.secondary)
        PreviousSessionStrip(
            sets: [
                LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90,
                          timestamp: Date(), setType: .working, configuration: [:], dropSegments: [], rpe: 8),
                LoggedSet(id: UUID(), weight: 185, reps: 7, restTime: 90,
                          timestamp: Date(), setType: .working, configuration: [:], dropSegments: [], rpe: nil),
                LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90,
                          timestamp: Date(), setType: .working, configuration: [:], dropSegments: [], rpe: 8),
            ],
            draftWeight: 190,
            draftReps: 8,
            unit: .pounds,
            onSelectSet: { _ in }
        )
    }
    .padding()
}
