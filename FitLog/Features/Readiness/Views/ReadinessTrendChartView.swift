//
//  ReadinessTrendChartView.swift
//  FitLog
//

import SwiftUI
import Charts

struct ReadinessTrendChartView: View {
    let scores: [ReadinessScore]

    var body: some View {
        if scores.isEmpty {
            ContentUnavailableView(
                "No trend data yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Daily readiness snapshots appear here after a few days of use.")
            )
            .frame(height: 180)
        } else {
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
            .accessibilityLabel("Readiness trend chart")
            .accessibilityValue("\(scores.count) daily scores")
        }
    }
}

#Preview {
    ReadinessTrendChartView(scores: [
        ReadinessScore(id: UUID(), dayKey: "2026-06-20", computedAt: Date(), score: 62, band: .moderate, summary: "", components: []),
        ReadinessScore(id: UUID(), dayKey: "2026-06-21", computedAt: Date(), score: 68, band: .good, summary: "", components: []),
        ReadinessScore(id: UUID(), dayKey: "2026-06-22", computedAt: Date(), score: 74, band: .good, summary: "", components: [])
    ])
}
