//
//  TrainingHeatmapView.swift
//  FitLog
//

import SwiftUI

struct TrainingHeatmapView: View {
    let days: [YearHeatmapDay]

    private var weekColumns: [[YearHeatmapDay]] {
        HistoryAggregator.yearHeatmapWeekColumns(from: days)
    }

    private var monthLabels: [String?] {
        HistoryAggregator.heatmapMonthLabels(for: weekColumns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Each square is a day; darker green means more sessions that day.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, label in
                            Text(label ?? " ")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .frame(width: 10, alignment: .leading)
                        }
                    }
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(weekColumns.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: 3) {
                                ForEach(week) { day in
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(cellColor(count: day.sessionCount))
                                        .frame(width: 10, height: 10)
                                        .accessibilityLabel(
                                            day.sessionCount == 0
                                                ? "No workout on \(day.date.formatted(date: .abbreviated, time: .omitted))"
                                                : "\(day.sessionCount) session\(day.sessionCount == 1 ? "" : "s") on \(day.date.formatted(date: .abbreviated, time: .omitted))"
                                        )
                                }
                                if week.count < 7 {
                                    ForEach(0..<(7 - week.count), id: \.self) { _ in
                                        Color.clear.frame(width: 10, height: 10)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            HStack(spacing: 8) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                ForEach([0, 1, 2, 3], id: \.self) { count in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(cellColor(count: count))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Training heatmap for the last 365 days")
    }

    private func cellColor(count: Int) -> Color {
        switch count {
        case 0: return Color.primary.opacity(0.07)
        case 1: return FitlogPalette.success.opacity(0.38)
        case 2: return FitlogPalette.success.opacity(0.58)
        default: return FitlogPalette.success.opacity(0.82)
        }
    }
}
