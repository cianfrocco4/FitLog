//
//  CoachRecommendationCard.swift
//  FitLog
//
//  Expandable recommendation card for Guided Coach phase 2.
//

import SwiftUI

struct CoachRecommendationCard: View {
    let recommendation: CoachRecommendation
    let onAccept: () -> Void
    let onAdjust: (String) -> Void
    let onDiscuss: () -> Void

    @State private var isExpanded = false
    @State private var isAdjusting = false
    @State private var adjustedValue: String

    init(
        recommendation: CoachRecommendation,
        onAccept: @escaping () -> Void,
        onAdjust: @escaping (String) -> Void,
        onDiscuss: @escaping () -> Void
    ) {
        self.recommendation = recommendation
        self.onAccept = onAccept
        self.onAdjust = onAdjust
        self.onDiscuss = onDiscuss
        _adjustedValue = State(initialValue: recommendation.finalValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: recommendation.topic.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(recommendation.isAccepted ? FitlogPalette.success : FitlogPalette.chartPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(FitlogPalette.subtleFill))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(recommendation.topic.title)
                                .font(.subheadline.weight(.semibold))
                            if recommendation.isAccepted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(FitlogPalette.success)
                                    .accessibilityLabel("Accepted")
                            }
                        }
                        Text(recommendation.finalValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        if recommendation.userChangedFromRecommendation {
                            Text("Coach suggested: \(recommendation.recommendedValue)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(recommendation.topic.title). \(recommendation.finalValue)")

            if isExpanded {
                Text(recommendation.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isAdjusting {
                    adjustmentControls
                } else if !recommendation.isAccepted {
                    actionRow
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(recommendation.isAccepted ? FitlogPalette.success.opacity(0.08) : FitlogPalette.subtleFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(recommendation.isAccepted ? FitlogPalette.success.opacity(0.25) : Color.clear, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var adjustmentControls: some View {
        switch recommendation.topic {
        case .split:
            Picker("Split", selection: $adjustedValue) {
                ForEach(CoachSplitPick.allCases) { pick in
                    Text(pick.rawValue).tag(pick.rawValue)
                }
            }
            .pickerStyle(.menu)
        case .programLength:
            Picker("Length", selection: $adjustedValue) {
                ForEach(CoachProgramLengthPick.allCases) { pick in
                    Text(pick.label).tag(pick.label)
                }
            }
            .pickerStyle(.menu)
        case .cardio:
            Picker("Cardio", selection: $adjustedValue) {
                ForEach(CoachCardioPick.allCases) { pick in
                    Text(pick.rawValue).tag(pick.rawValue)
                }
            }
            .pickerStyle(.menu)
        case .periodization:
            Picker("Phases", selection: $adjustedValue) {
                Text("One continuous phase").tag("One continuous phase")
                Text("Two phases — build, then peak").tag("Two phases — build, then peak")
                Text("Three phases — build, peak, recover").tag("Three phases — build, peak, recover")
            }
            .pickerStyle(.menu)
        case .programName:
            TextField("Program name", text: $adjustedValue)
                .textFieldStyle(.roundedBorder)
        default:
            Text(adjustedValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        HStack {
            Button("Cancel") { isAdjusting = false }
            Spacer()
            Button("Apply") {
                onAdjust(adjustedValue)
                isAdjusting = false
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button("Accept", action: onAccept)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Accept this recommendation")

            if recommendation.isAdjustable {
                Button("Adjust") {
                    isAdjusting = true
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Change this recommendation")
            }

            Button("Discuss", action: onDiscuss)
                .buttonStyle(.bordered)
                .accessibilityHint("Ask the coach about this recommendation")
        }
        .font(.caption.weight(.semibold))
    }
}

struct CoachRecommendationCardsSection: View {
    let recommendations: [CoachRecommendation]
    let onAccept: (CoachRecommendationTopic) -> Void
    let onAdjust: (CoachRecommendationTopic, String) -> Void
    let onDiscuss: (CoachRecommendationTopic) -> Void
    let onAcceptAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(recommendations) { rec in
                CoachRecommendationCard(
                    recommendation: rec,
                    onAccept: { onAccept(rec.topic) },
                    onAdjust: { onAdjust(rec.topic, $0) },
                    onDiscuss: { onDiscuss(rec.topic) }
                )
            }

            Button("Accept all recommendations", action: onAcceptAll)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Accept every recommendation and continue to review")
        }
    }
}

#Preview {
    ScrollView {
        CoachRecommendationCard(
            recommendation: CoachRecommendation(
                topic: .split,
                recommendedValue: "Upper / Lower",
                rationale: "With 4 days and your muscle-building goal, Upper/Lower hits everything twice a week."
            ),
            onAccept: {},
            onAdjust: { _ in },
            onDiscuss: {}
        )
        .padding()
    }
}
