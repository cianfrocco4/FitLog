//
//  ProgramCalendarPreviewView.swift
//  FitLog
//
//  Multi-week calendar grid with block-colored training days and optional volume strip.
//

import SwiftUI

struct ProgramCalendarPreviewView: View {
    let program: DynamicProgram
    let anchorDate: Date
    /// Per-block weekly set totals (all templates), for a subtle heat strip.
    let weeklySetTotalsByBlock: [Int]

    private var calendar: Calendar { .current }

    private var previewState: DynamicProgramState {
        DynamicProgramState(program: program, anchorDate: calendar.startOfDay(for: anchorDate))
    }

    private var totalProgramDays: Int {
        program.blocks.reduce(0) { partial, block in
            partial + max(1, block.durationWeeks) * 7
        }
    }

    private var engine: PeriodizationEngine { PeriodizationEngine(calendar: calendar) }

    var body: some View {
        let state = previewState
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0 ..< totalProgramDays, id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: anchorDate)) ?? anchorDate
                    cell(for: day, offset: offset, state: state)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Program calendar, \(totalProgramDays) days from start")

            if !weeklySetTotalsByBlock.isEmpty {
                volumeLegend
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(for date: Date, offset: Int, state: DynamicProgramState) -> some View {
        let placement = engine.blockPlacement(on: date, state: state)
        let resolved = engine.resolvedTemplateDay(on: date, state: state)
        let dayNum = calendar.component(.day, from: date)

        let title: String = {
            switch resolved {
            case .training(let t), .flex(let t):
                return t.dayName
            case .rest, .unscheduled:
                return ""
            }
        }()

        let isTraining: Bool = {
            switch resolved {
            case .training, .flex:
                return true
            case .rest, .unscheduled:
                return false
            }
        }()

        let blockColor: Color = {
            guard let idx = placement?.index else { return Color(.tertiarySystemFill) }
            return Self.palette[idx % Self.palette.count]
        }()

        VStack(spacing: 2) {
            Text("\(dayNum)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isTraining ? .primary : .secondary)
            if isTraining {
                Text(title)
                    .font(.system(size: 7))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            } else {
                Text("—")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(blockColor.opacity(isTraining ? 0.55 : 0.18))
        )
        .overlay(alignment: .bottom) {
            if let idx = placement?.index, weeklySetTotalsByBlock.indices.contains(idx) {
                let sets = weeklySetTotalsByBlock[idx]
                let heat = min(1.0, Double(sets) / 120.0)
                Capsule()
                    .fill(Color.accentColor.opacity(0.15 + heat * 0.55))
                    .frame(height: 3)
                    .padding(.horizontal, 2)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDayLabel(date: date, isTraining: isTraining, title: title, placement: placement))
    }

    private func accessibilityDayLabel(
        date: Date,
        isTraining: Bool,
        title: String,
        placement: (index: Int, block: ProgramBlock, weekInBlock: Int)?
    ) -> String {
        let f = Self.dayFormatter.string(from: date)
        if isTraining {
            let blockName = placement?.block.name ?? "program"
            return "\(f), training, block \(blockName), template \(title)"
        }
        return "\(f), rest or off day"
    }

    private var volumeLegend: some View {
        HStack(spacing: 6) {
            Text("Volume strip")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Capsule()
                .fill(Color.accentColor.opacity(0.35))
                .frame(width: 28, height: 4)
            Text("darker = more weekly sets in block templates")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityHidden(true)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .brown,
    ]
}

extension ProgramCalendarPreviewView {
    /// Sums sets across all templates in each block (coarse volume proxy for the heat strip).
    static func weeklySetTotalsPerBlock(program: DynamicProgram) -> [Int] {
        program.blocks.map { block in
            block.weeklyTemplates.reduce(0) { partial, day in
                partial + day.slots.reduce(0) { $0 + max(0, $1.sets) }
            }
        }
    }
}
