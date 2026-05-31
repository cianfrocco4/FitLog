//
//  CoachBlueprintSummary.swift
//  FitLog
//
//  Final blueprint review card for Guided Coach.
//

import SwiftUI

struct CoachBlueprintSummary: View {
    let blueprint: CoachBlueprint
    let onBuild: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your program blueprint")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            summaryRow(title: "Program", value: blueprint.programName)
            summaryRow(title: "Schedule", value: "\(blueprint.sessionsPerWeek) days/week")
            summaryRow(title: "Split", value: blueprint.splitPreference, coachValue: blueprint.recommendation(for: .split)?.recommendedValue)
            summaryRow(title: "Length", value: "\(blueprint.totalWeeks) weeks", coachValue: blueprint.recommendation(for: .programLength)?.recommendedValue)
            summaryRow(title: "Cardio", value: cardioLine, coachValue: blueprint.recommendation(for: .cardio)?.recommendedValue)
            summaryRow(title: "Phases", value: phaseLine, coachValue: blueprint.recommendation(for: .periodization)?.recommendedValue)

            if !blueprint.changes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Changes you made")
                        .font(.subheadline.weight(.semibold))
                    ForEach(blueprint.changes) { change in
                        Label(change.diffDescription, systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !blueprint.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.subheadline.weight(.semibold))
                    ForEach(blueprint.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(FitlogPalette.caution)
                    }
                }
            }

            blockTimeline

            Button(action: onBuild) {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Building your program…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Build My Program")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .accessibilityLabel(isLoading ? "Building your program" : "Build my program")
            .accessibilityHint("Generate your training program from this blueprint")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitlogPalette.subtleFill)
        )
    }

    private var cardioLine: String {
        if blueprint.cardioConfiguration.preference == .none {
            return "Strength only"
        }
        return blueprint.cardioConfiguration.preference.rawValue
    }

    private var phaseLine: String {
        if blueprint.isPeriodized {
            return blueprint.blockSpecs.map { "\($0.title) · \($0.durationWeeks) wk" }.joined(separator: "\n")
        }
        return "One phase · \(blueprint.totalWeeks) weeks"
    }

    private var blockTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(blueprint.blockSpecs.indices, id: \.self) { index in
                        let block = blueprint.blockSpecs[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                            Text("\(block.durationWeeks) wk")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(block.focus.displayTitle)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .frame(width: 120, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor.opacity(index == 0 ? 0.12 : 0.06))
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Program timeline")
    }

    private func summaryRow(title: String, value: String, coachValue: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
            if let coachValue, coachValue != value {
                Text("Coach suggested: \(coachValue)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    CoachBlueprintSummary(
        blueprint: CoachRecommendationEngine.buildBlueprint(from: CoachIntakeSnapshot(
            primaryGoal: "Build muscle & size",
            experienceLevel: "Intermediate",
            sessionsPerWeek: 4
        )),
        onBuild: {},
        isLoading: false
    )
    .padding()
}
