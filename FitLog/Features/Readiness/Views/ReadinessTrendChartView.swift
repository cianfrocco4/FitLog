//
//  ReadinessTrendChartView.swift
//  FitLog
//

import SwiftUI
import Charts

struct ReadinessTrendChartView: View {
    let scores: [ReadinessScore]
    /// Last working load or last cardio duration from the newest completed session.
    var lastLoadCaption: String? = nil

    var body: some View {
        if scores.isEmpty {
            ContentUnavailableView(
                "No trend data yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Daily readiness snapshots appear here after a few days of use.")
            )
            .frame(height: 180)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let lastLoadCaption, !lastLoadCaption.isEmpty {
                    Text(lastLoadCaption)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal)
                        .accessibilityIdentifier(FitLogA11yID.readinessTrend.lastLoad)
                        .accessibilityLabel(lastLoadCaption)
                        .accessibilityHint("Last working set or last cardio duration from a completed session")
                }
                Chart(scores) { item in
                    LineMark(
                        x: .value("Day", item.dayKey),
                        y: .value("Score", item.score)
                    )
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Day", item.dayKey),
                        y: .value("Score", item.score)
                    )
                }
                .chartYScale(domain: 0...100)
                .frame(height: 200)
                .padding()
                .accessibilityLabel(chartAccessibilityLabel)
                .accessibilityValue("\(scores.count) daily scores")
            }
        }
    }

    private var chartAccessibilityLabel: String {
        if let lastLoadCaption, !lastLoadCaption.isEmpty {
            return "Readiness trend chart, \(lastLoadCaption)"
        }
        return "Readiness trend chart"
    }
}

#Preview("Trend — light") {
    ReadinessTrendChartView(
        scores: [
            ReadinessScore(id: UUID(), dayKey: "2026-06-20", computedAt: Date(), score: 62, band: .moderate, summary: "", components: []),
            ReadinessScore(id: UUID(), dayKey: "2026-06-21", computedAt: Date(), score: 68, band: .good, summary: "", components: []),
            ReadinessScore(id: UUID(), dayKey: "2026-06-22", computedAt: Date(), score: 74, band: .good, summary: "", components: [])
        ],
        lastLoadCaption: "Last 185 lb × 8 reps"
    )
}

#Preview("Trend — dark") {
    ReadinessTrendChartView(
        scores: [
            ReadinessScore(id: UUID(), dayKey: "2026-06-20", computedAt: Date(), score: 62, band: .moderate, summary: "", components: []),
            ReadinessScore(id: UUID(), dayKey: "2026-06-21", computedAt: Date(), score: 68, band: .good, summary: "", components: []),
            ReadinessScore(id: UUID(), dayKey: "2026-06-22", computedAt: Date(), score: 74, band: .good, summary: "", components: [])
        ],
        lastLoadCaption: "Last 45:00"
    )
    .preferredColorScheme(.dark)
}
