//
//  LastSessionExerciseReviewCard.swift
//  FitLog
//
//  Last-time review for the focused exercise. Full setup before the first set,
//  recorded sets only once logging has started.
//

import SwiftUI

struct LastSessionExerciseReviewCard: View {
    let performance: PriorWorkoutPerformance
    let unit: WeightDisplayUnit
    /// Variant, swap, and shared setup. Off once this session has logged sets.
    let showsSetup: Bool
    var onSelectSet: ((LoggedSet) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PriorWorkoutPerformance.relativeTitle(for: performance.performedAt))
                .font(.subheadline.weight(.semibold))

            if showsSetup {
                if performance.wasSwapped {
                    Text("Swapped \(performance.plannedName ?? "the planned exercise") for \(performance.performedName)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(performance.performedName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let setup = performance.sharedSetupSummary {
                    Text("Setup · \(setup)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(Array(performance.sets.enumerated()), id: \.element.id) { index, set in
                setLine(index: index, set: set)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func setLine(index: Int, set: LoggedSet) -> some View {
        let summary = set.isCardioEntry
            ? set.cardioDisplaySummary
            : set.weightRepsDisplaySummary(displayUnit: unit)
        let config = set.configurationSummary(fieldNames: performance.configurationFields)
        let showsConfig = showsSetup && performance.sharedSetupSummary == nil && !config.isEmpty

        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Set \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let badge = set.setTypeBadgeLabel {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 8)
                Text(summary)
                    .font(.caption.weight(.medium))
            }
            if showsSetup {
                Text("Rest \(set.restTime)s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsConfig {
                Text(config)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        if let onSelectSet, !set.isCardioEntry {
            Button {
                onSelectSet(set)
            } label: {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Last time set \(index + 1), \(summary)")
            .accessibilityHint("Fills the next set with this weight and reps")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(lineLabel(index: index, set: set, summary: summary))
        }
    }

    private func lineLabel(index: Int, set: LoggedSet, summary: String) -> String {
        var parts = ["Set \(index + 1)"]
        if let badge = set.setTypeBadgeLabel {
            parts.append(badge)
        }
        parts.append(summary)
        return parts.joined(separator: ", ")
    }
}
