//
//  ProgramValidationBanner.swift
//  FitLog
//
//  Real-time validation for the unified program builder (blocking vs warnings).
//

import SwiftUI

struct ProgramValidationResult: Equatable, Sendable {
    var blockingIssues: [String]
    var warningIssues: [String]

    var canSaveToPlan: Bool { blockingIssues.isEmpty }

    static let empty = ProgramValidationResult(blockingIssues: [], warningIssues: [])

    static func evaluate(
        programName: String,
        program: DynamicProgram?,
        perBlockEditableDays: [[SplitBuilderEditableDay]],
        balanceWarnings: [SplitProposalProgramWarning],
        isManualMode: Bool = false
    ) -> ProgramValidationResult {
        var blocking: [String] = []
        var warnings: [String] = []

        let trimmedName = programName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            blocking.append("Add a program name in the Goals step before saving.")
        }

        guard let program else {
            blocking.append("Generate or build a program before saving.")
            return ProgramValidationResult(blockingIssues: blocking, warningIssues: warnings)
        }

        if program.blocks.isEmpty {
            blocking.append("Program has no training blocks.")
        }

        let totalWeeks = program.blocks.reduce(0) { $0 + max(1, $1.durationWeeks) }
        if totalWeeks <= 0 {
            blocking.append("Program length is invalid.")
        }

        let hasDeload = program.blocks.contains { $0.isDeloadBlock || $0.focus.kind == .deload }
        if totalWeeks >= 8, !hasDeload {
            warnings.append("Programs 8+ weeks often benefit from a planned deload phase.")
        }

        for (blockIndex, block) in program.blocks.enumerated() {
            let days: [SplitBuilderEditableDay] = {
                guard perBlockEditableDays.indices.contains(blockIndex) else { return [] }
                return perBlockEditableDays[blockIndex]
            }()

            if days.isEmpty {
                blocking.append("Block \(blockIndex + 1) (“\(block.name)”) has no rotation days.")
                continue
            }

            for (dayIndex, day) in days.enumerated() {
                let dayTitle = day.name.isEmpty ? "Day \(dayIndex + 1)" : day.name
                if day.slots.isEmpty {
                    let emptyDayMessage = "Block \(blockIndex + 1): “\(dayTitle)” has no exercise slots."
                    if isManualMode {
                        warnings.append(emptyDayMessage + " Add slots before saving.")
                    } else {
                        blocking.append(emptyDayMessage)
                    }
                }
                for slot in day.slots {
                    if let scheme = slot.setScheme, let msg = scheme.validationMessageIfInvalid() {
                        warnings.append("“\(dayTitle)” — \(slot.label): \(msg)")
                    }
                    if slot.suggestedExerciseOverrideId == nil,
                       (slot.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                       slot.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        warnings.append("“\(dayTitle)” has a slot with no label or exercise — assign before logging.")
                    }
                }
            }
        }

        for w in balanceWarnings {
            warnings.append(w.message)
        }

        return ProgramValidationResult(
            blockingIssues: blocking,
            warningIssues: Array(Set(warnings)).sorted()
        )
    }
}

struct ProgramValidationBanner: View {
    let result: ProgramValidationResult

    var body: some View {
        if result.blockingIssues.isEmpty, result.warningIssues.isEmpty {
            Label("All checks passed", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("All program checks passed. You can review and save to plan.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if !result.blockingIssues.isEmpty {
                    Label("Must fix before saving", systemImage: "xmark.octagon.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    ForEach(Array(result.blockingIssues.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                    }
                }
                if !result.warningIssues.isEmpty {
                    Label("Suggestions", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(Array(result.warningIssues.prefix(12).enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if result.warningIssues.count > 12 {
                        Text("…and \(result.warningIssues.count - 12) more.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        if !result.blockingIssues.isEmpty {
            parts.append("Blocking: " + result.blockingIssues.joined(separator: "; "))
        }
        if !result.warningIssues.isEmpty {
            parts.append("Warnings: " + result.warningIssues.joined(separator: "; "))
        }
        return parts.joined(separator: ". ")
    }
}

#Preview("Validation banner") {
    ProgramValidationBanner(
        result: ProgramValidationResult(
            blockingIssues: ["Add a program name."],
            warningIssues: ["Consider a deload week."]
        )
    )
    .padding()
}
