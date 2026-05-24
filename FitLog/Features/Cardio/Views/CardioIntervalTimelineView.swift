//
//  CardioIntervalTimelineView.swift
//  FitLog
//

import SwiftUI

struct CardioIntervalTimelineView: View {
    let loggedSets: [LoggedSet]

    private var intervalSets: [LoggedSet] {
        loggedSets.filter { $0.setType == .intervalWork || $0.setType == .intervalRest || $0.isCardioEntry }
    }

    var body: some View {
        if intervalSets.isEmpty {
            Text("Intervals will appear here as you log work and rest segments.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(intervalSets.enumerated()), id: \.element.id) { index, set in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(chipColor(for: set.setType))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(set.setTypeBadgeLabel ?? "Cardio")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(chipColor(for: set.setType))
                                Spacer()
                                Text("#\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(set.cardioDisplaySummary)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(intervalAccessibilityLabel(index: index, set: set))
                }
            }
        }
    }

    private func intervalAccessibilityLabel(index: Int, set: LoggedSet) -> String {
        let phase: String = {
            switch set.setType {
            case .intervalWork: return "work interval"
            case .intervalRest: return "rest interval"
            case .steadyState: return "steady segment"
            default: return "cardio segment"
            }
        }()
        return "\(phase) \(index + 1), \(set.cardioDisplaySummary)"
    }

    private func chipColor(for type: ExerciseSetType) -> Color {
        switch type {
        case .intervalWork, .steadyState: return FitlogPalette.chartSecondary
        case .intervalRest: return Color.secondary
        default: return FitlogPalette.chartSecondary
        }
    }
}
