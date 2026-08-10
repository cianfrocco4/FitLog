//
//  ProgramBlockSummaryCard.swift
//  FitLog
//
//  Compact summary card for a program block in the review step.
//

import SwiftUI

struct ProgramBlockSummaryCard: View {
    let block: ProgramBlock
    let blockIndex: Int
    let stats: ProgramBlockSummarySupport.BlockStats
    let warnings: [SplitProposalProgramWarning]
    let isSelected: Bool
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(block.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if isSelected {
                            Text("Editing")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        }
                    }
                    Text(block.focus.displayTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("\(block.durationWeeks) wk")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(block.name), \(block.durationWeeks) weeks, \(block.focus.displayTitle)")

            if !warnings.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("\(warnings.count) balance note\(warnings.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("\(warnings.count) balance warnings for this block")
            }

            if !stats.topExercisePreview.isEmpty {
                Text(stats.topExercisePreview)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isSelected {
                Button("Edit this block", action: onSelect)
                    .font(.caption.weight(.semibold))
                    .accessibilityHint("Selects this block for template editing")
            }

            Button(action: onToggleExpanded) {
                HStack(spacing: 6) {
                    Text(isExpanded ? "Hide workouts" : "Show workouts (\(stats.dayCount))")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide workouts" : "Show workouts")
            .accessibilityHint(isExpanded ? "Collapses the workout list for this block" : "Expands the workout list for this block")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    private var summaryLine: String {
        var parts = ["\(stats.dayCount) day\(stats.dayCount == 1 ? "" : "s")", "\(stats.strengthSetCount) strength sets"]
        if stats.cardioSlotCount > 0 {
            parts.append("\(stats.cardioSlotCount) cardio slot\(stats.cardioSlotCount == 1 ? "" : "s")")
        }
        if stats.estimatedCardioMinutes > 0 {
            parts.append("~\(stats.estimatedCardioMinutes) min cardio/wk")
        }
        if !stats.dayNamesLine.isEmpty, stats.dayNamesLine != "No days" {
            parts.append(stats.dayNamesLine)
        }
        return parts.joined(separator: " · ")
    }
}
