//
//  TrendChartCard.swift
//  FitLog
//

import SwiftUI
import Charts

enum HistoryTrendChartStyle {
    case bar(color: Color)
    case areaLine(areaGradient: [Color], lineColor: Color)
}

struct TrendChartCard: View {
    let title: String
    let style: HistoryTrendChartStyle
    let weekStarts: [Date]
    let values: [Double]
    let priorWeekStarts: [Date]
    let priorValues: [Double]
    let showComparison: Bool
    let average: Double?
    let averageLabel: String
    let yAxisFormatter: (Double) -> String
    let selectionAnnotation: (Date, Double) -> String
    let accessibilitySummary: String
    @Binding var selectedWeek: Date?

    var body: some View {
        HistoryChartCard(title: title) {
            Chart {
                chartMarks
                averageRule
                selectionRule
                priorMarks
            }
            .chartXSelection(value: $selectedWeek)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let n = value.as(Double.self) {
                            Text(yAxisFormatter(n))
                        }
                    }
                }
            }
            .frame(height: 196)
            .accessibilityChartDescriptor(
                TrendChartAXDescriptor(
                    title: title,
                    weekStarts: weekStarts,
                    values: values,
                    valueAxisTitle: "Value",
                    valueFormatter: yAxisFormatter
                )
            )
            .accessibilityLabel(accessibilitySummary)
        }
    }

    @ChartContentBuilder
    private var chartMarks: some ChartContent {
        ForEach(Array(zip(weekStarts, values)), id: \.0) { weekStart, value in
            switch style {
            case .bar(let color):
                BarMark(
                    x: .value("Week", weekStart),
                    y: .value("Value", value)
                )
                .foregroundStyle(color.gradient)
                .accessibilityLabel("Week of \(HistoryFormatters.formatMediumDate(weekStart))")
                .accessibilityValue(yAxisFormatter(value))
            case .areaLine(let gradientColors, let lineColor):
                AreaMark(
                    x: .value("Week", weekStart),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Week", weekStart),
                    y: .value("Value", value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                .accessibilityLabel("Week of \(HistoryFormatters.formatMediumDate(weekStart))")
                .accessibilityValue(yAxisFormatter(value))
            }
        }
    }

    @ChartContentBuilder
    private var priorMarks: some ChartContent {
        if showComparison {
            ForEach(Array(zip(priorWeekStarts, priorValues)), id: \.0) { weekStart, value in
                LineMark(
                    x: .value("Week", weekStart),
                    y: .value("Prior", value)
                )
                .foregroundStyle(Color.secondary.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    @ChartContentBuilder
    private var averageRule: some ChartContent {
        if let average {
            RuleMark(y: .value("Avg", average))
                .foregroundStyle(Color.secondary.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text(averageLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
        }
    }

    @ChartContentBuilder
    private var selectionRule: some ChartContent {
        if let selectedWeek,
           let week = HistoryAggregator.nearestWeekStart(selectedWeek, in: weekStarts),
           let index = weekStarts.firstIndex(of: week),
           index < values.count {
            RuleMark(x: .value("Selected", week))
                .foregroundStyle(Color.accentColor.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .annotation(position: .top, spacing: 4) {
                    Text(selectionAnnotation(week, values[index]))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
        }
    }
}

struct CardioTrendChartCard: View {
    let weeklyCardio: [WeekCardioData]
    let priorWeeklyCardio: [WeekCardioData]
    let showComparison: Bool
    let average: Double?
    @Binding var selectedWeek: Date?

    var body: some View {
        HistoryChartCard(title: "Cardio volume") {
            if weeklyCardio.isEmpty {
                CardioEmptyStateView(
                    title: "No cardio in this range",
                    message: "Complete a cardio or hybrid workout to see weekly minutes and distance here.",
                    primaryTitle: "Build cardio workout",
                    onPrimary: {
                        NotificationCenter.default.post(
                            name: .fitlogPresentNewWorkout,
                            object: NewWorkoutLaunchHint.cardioFirst
                        )
                    },
                    secondaryTitle: nil,
                    onSecondary: nil
                )
            } else {
                Chart {
                    ForEach(weeklyCardio) { row in
                        BarMark(
                            x: .value("Week", row.weekStart),
                            y: .value("Minutes", row.minutes)
                        )
                        .foregroundStyle(FitlogPalette.chartSecondary.gradient)
                        .annotation(position: .top, spacing: 2) {
                            if row.distanceKm >= 0.1 {
                                Text(String(format: "%.1f km", row.distanceKm))
                                    .font(.caption2)
                                    .foregroundStyle(FitlogPalette.success)
                            }
                        }
                    }
                    if showComparison {
                        ForEach(priorWeeklyCardio) { row in
                            LineMark(
                                x: .value("Week", row.weekStart),
                                y: .value("Prior minutes", row.minutes)
                            )
                            .foregroundStyle(Color.secondary.opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        }
                    }
                    if let average {
                        RuleMark(y: .value("Avg minutes", average))
                            .foregroundStyle(Color.secondary.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("avg \(Int(average.rounded()))m")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                    if let selectedWeek,
                       let week = HistoryAggregator.nearestWeekStart(selectedWeek, in: weeklyCardio.map(\.weekStart)),
                       let row = weeklyCardio.first(where: { Calendar.current.isDate($0.weekStart, equalTo: week, toGranularity: .weekOfYear) }) {
                        RuleMark(x: .value("Selected", week))
                            .foregroundStyle(Color.accentColor.opacity(0.35))
                            .annotation(position: .top, spacing: 4) {
                                Text("Week of \(HistoryFormatters.formatMediumDate(week)): \(Int(row.minutes.rounded()))m")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                    }
                }
                .chartXSelection(value: $selectedWeek)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let m = value.as(Double.self) {
                                Text("\(Int(m))m")
                            }
                        }
                    }
                }
                .frame(height: 196)
                .accessibilityChartDescriptor(CardioTrendChartAXDescriptor(weeklyCardio: weeklyCardio))
                .accessibilityLabel("Weekly cardio minutes with distance labels")
            }
        }
    }
}
