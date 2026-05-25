//
//  HomeProgramSummaryCard.swift
//  FitLog
//
//  Consolidated active program card for the Home tab.
//

import SwiftUI

struct HomeProgramSummaryCard: View {
    @Environment(DataManager.self) var dataVM

    let state: DynamicProgramState
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenDetail: () -> Void
    let onBuildNew: () -> Void

    var body: some View {
        let cal = Calendar.current
        let pe = PeriodizationEngine(calendar: cal)
        let today = cal.startOfDay(for: Date())
        let placement = pe.blockPlacement(on: today, state: state)
        let sessionProgress = dataVM.dynamicProgramBlockSessionProgress(calendar: cal)

        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpenDetail) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.program.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        if let placement {
                            Text(blockWeekLine(placement: placement, blockCount: state.program.blocks.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Starts \(state.anchorDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if let pr = sessionProgress, pr.planned > 0 {
                        sessionProgressRing(completed: pr.completed, planned: pr.planned)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your active program details")

            if isExpanded {
                if let nextLine = nextBlockLine(placement: placement, state: state) {
                    Text(nextLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Button("Build a new program", action: onBuildNew)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("Opens the program builder to create a different program")
            }

            Button(action: onToggleExpanded) {
                Label(isExpanded ? "Show less" : "Show more", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .homeCardTier(.tertiary)
        .accessibilityElement(children: .contain)
    }

    private func blockWeekLine(placement: (index: Int, block: ProgramBlock, weekInBlock: Int), blockCount: Int) -> String {
        if blockCount > 1 {
            return "Block \(placement.index + 1) of \(blockCount) · Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks)"
        }
        return "\(placement.block.name) · Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks)"
    }

    private func nextBlockLine(placement: (index: Int, block: ProgramBlock, weekInBlock: Int)?, state: DynamicProgramState) -> String? {
        guard let placement else { return nil }
        let nextIdx = placement.index + 1
        guard state.program.blocks.indices.contains(nextIdx) else { return nil }
        let nb = state.program.blocks[nextIdx]
        return "Up next: \(nb.name) (\(nb.durationWeeks) wk)"
    }

    private func sessionProgressRing(completed: Int, planned: Int) -> some View {
        let total = max(1, planned)
        let frac = min(1, max(0, Double(completed) / Double(total)))
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.22), lineWidth: 5)
            Circle()
                .trim(from: 0, to: frac)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(completed)/\(planned)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(2)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("\(completed) of \(planned) sessions completed in this block")
    }
}

struct HomeBuildProgramCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build a program")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Goals, phases, schedule, then save to Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .homeCardTier(.tertiary)
        .accessibilityHint("Opens the program builder")
    }
}
