//
//  HistoryChartAccessibility.swift
//  FitLog
//

import Accessibility
import SwiftUI

struct TrendChartAXDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let weekStarts: [Date]
    let values: [Double]
    let valueAxisTitle: String
    let valueFormatter: (Double) -> String

    func makeChartDescriptor() -> AXChartDescriptor {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let categories = weekStarts.map { dateFormatter.string(from: $0) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Week", categoryOrder: categories)

        let numericValues = values
        let yMin = numericValues.min() ?? 0
        let yMax = max(numericValues.max() ?? 1, yMin + 1)
        let yAxis = AXNumericDataAxisDescriptor(
            title: valueAxisTitle,
            range: ClosedRange(uncheckedBounds: (lower: yMin, upper: yMax)),
            gridlinePositions: []
        ) { value in
            valueFormatter(value)
        }

        let dataPoints = zip(weekStarts, values).map { week, value in
            AXDataPoint(
                x: dateFormatter.string(from: week),
                y: value,
                label: "\(valueFormatter(value)) on week of \(dateFormatter.string(from: week))"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: title,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

struct CardioTrendChartAXDescriptor: AXChartDescriptorRepresentable {
    let weeklyCardio: [WeekCardioData]

    func makeChartDescriptor() -> AXChartDescriptor {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let categories = weeklyCardio.map { dateFormatter.string(from: $0.weekStart) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Week", categoryOrder: categories)

        let minutes = weeklyCardio.map(\.minutes)
        let yMin = minutes.min() ?? 0
        let yMax = max(minutes.max() ?? 1, yMin + 1)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Minutes",
            range: ClosedRange(uncheckedBounds: (lower: yMin, upper: yMax)),
            gridlinePositions: []
        ) { value in
            "\(Int(value.rounded())) minutes"
        }

        let dataPoints = weeklyCardio.map { row in
            AXDataPoint(
                x: dateFormatter.string(from: row.weekStart),
                y: row.minutes,
                label: "\(Int(row.minutes.rounded())) minutes, \(String(format: "%.1f", row.distanceKm)) km"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: "Cardio volume",
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: "Cardio volume",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

struct MuscleVolumeChartAXDescriptor: AXChartDescriptorRepresentable {
    let rows: [MuscleVolumeRow]
    let valueFormatter: (Double) -> String

    func makeChartDescriptor() -> AXChartDescriptor {
        let categories = rows.map(\.name)
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Muscle", categoryOrder: categories)

        let volumes = rows.map(\.volume)
        let yMin = volumes.min() ?? 0
        let yMax = max(volumes.max() ?? 1, yMin + 1)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Volume",
            range: ClosedRange(uncheckedBounds: (lower: yMin, upper: yMax)),
            gridlinePositions: []
        ) { value in
            valueFormatter(value)
        }

        let dataPoints = rows.map { row in
            AXDataPoint(
                x: row.name,
                y: row.volume,
                label: "\(row.name): \(valueFormatter(row.volume))"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: "Volume by muscle",
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: "Volume by muscle",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
