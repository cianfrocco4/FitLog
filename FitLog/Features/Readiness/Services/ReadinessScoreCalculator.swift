//
//  ReadinessScoreCalculator.swift
//  FitLog
//
//  Pure, transparent readiness scoring from HealthKit + training load inputs.
//

import Foundation

enum ReadinessScoreCalculator {
    private static let componentWeights: [ReadinessComponentKind: Double] = [
        .hrv: 0.35,
        .restingHeartRate: 0.20,
        .sleep: 0.30,
        .trainingLoad: 0.15
    ]

    static func calculate(inputs: ReadinessInputs, dayKey: String, now: Date = Date()) -> ReadinessScore {
        var components: [ReadinessComponent] = []
        var weightedSum = 0.0
        var weightTotal = 0.0

        if let hrv = scoreHRV(current: inputs.hrvSDNNMs, baseline: inputs.hrvBaselineMs) {
            components.append(hrv)
            if hrv.isAvailable {
                weightedSum += hrv.weightedContribution
                weightTotal += hrv.weight
            }
        }

        if let rhr = scoreRestingHR(current: inputs.restingHeartRateBpm, baseline: inputs.restingHeartRateBaselineBpm) {
            components.append(rhr)
            if rhr.isAvailable {
                weightedSum += rhr.weightedContribution
                weightTotal += rhr.weight
            }
        }

        if let sleep = scoreSleep(hours: inputs.sleepHours, restorativeFraction: inputs.restorativeSleepFraction) {
            components.append(sleep)
            if sleep.isAvailable {
                weightedSum += sleep.weightedContribution
                weightTotal += sleep.weight
            }
        }

        if let load = scoreTrainingLoad(recent: inputs.recentHardSets, typical: inputs.typicalHardSets72h) {
            components.append(load)
            if load.isAvailable {
                weightedSum += load.weightedContribution
                weightTotal += load.weight
            }
        }

        let rawScore: Double
        if weightTotal > 0 {
            rawScore = weightedSum / weightTotal
        } else {
            rawScore = 55
        }

        let clamped = Int(min(100, max(0, rawScore.rounded())))
        let band = band(for: clamped)
        let summary = buildSummary(score: clamped, band: band, components: components)

        return ReadinessScore(
            id: UUID(),
            dayKey: dayKey,
            computedAt: now,
            score: clamped,
            band: band,
            summary: summary,
            components: components
        )
    }

    static func band(for score: Int) -> ReadinessBand {
        switch score {
        case ..<45: return .low
        case 45..<65: return .moderate
        case 65..<80: return .good
        default: return .optimal
        }
    }

    private static func scoreHRV(current: Double?, baseline: Double?) -> ReadinessComponent? {
        let weight = componentWeights[.hrv, default: 0]
        guard let current, current > 0 else {
            return ReadinessComponent(kind: .hrv, score: 0, weight: weight, detail: "No HRV data from Apple Health yet.", isAvailable: false)
        }
        guard let baseline, baseline > 0 else {
            let neutral = ReadinessComponent(kind: .hrv, score: 65, weight: weight, detail: "HRV \(formatMs(current)) — building your baseline.", isAvailable: true)
            return neutral
        }
        let deltaPct = ((current - baseline) / baseline) * 100
        let score = clampScore(50 + deltaPct * 1.5)
        let detail: String
        if deltaPct >= 5 {
            detail = "HRV \(formatMs(current)) is \(formatPct(deltaPct)) above your 28-day baseline."
        } else if deltaPct <= -5 {
            detail = "HRV \(formatMs(current)) is \(formatPct(abs(deltaPct))) below your 28-day baseline."
        } else {
            detail = "HRV \(formatMs(current)) is near your 28-day baseline."
        }
        return ReadinessComponent(kind: .hrv, score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private static func scoreRestingHR(current: Double?, baseline: Double?) -> ReadinessComponent? {
        let weight = componentWeights[.restingHeartRate, default: 0]
        guard let current, current > 0 else {
            return ReadinessComponent(kind: .restingHeartRate, score: 0, weight: weight, detail: "No resting heart rate data yet.", isAvailable: false)
        }
        guard let baseline, baseline > 0 else {
            return ReadinessComponent(kind: .restingHeartRate, score: 65, weight: weight, detail: "Resting HR \(formatBpm(current)) — building your baseline.", isAvailable: true)
        }
        let delta = current - baseline
        let score = clampScore(70 - delta * 4)
        let detail: String
        if delta >= 3 {
            detail = "Resting HR \(formatBpm(current)) is elevated vs your baseline (+ \(formatBpm(delta)))."
        } else if delta <= -2 {
            detail = "Resting HR \(formatBpm(current)) is lower than baseline — a good recovery sign."
        } else {
            detail = "Resting HR \(formatBpm(current)) is near your baseline."
        }
        return ReadinessComponent(kind: .restingHeartRate, score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private static func scoreSleep(hours: Double?, restorativeFraction: Double?) -> ReadinessComponent? {
        let weight = componentWeights[.sleep, default: 0]
        guard let hours, hours > 0 else {
            return ReadinessComponent(kind: .sleep, score: 0, weight: weight, detail: "No sleep data from Apple Health yet.", isAvailable: false)
        }
        let durationScore: Double
        switch hours {
        case ..<5: durationScore = 35
        case 5..<6: durationScore = 50
        case 6..<7: durationScore = 65
        case 7..<8.5: durationScore = 85
        default: durationScore = 75
        }
        let qualityBoost = (restorativeFraction ?? 0.35) * 20
        let score = clampScore(durationScore * 0.75 + qualityBoost)
        let detail: String
        if hours >= 7 {
            detail = "You slept \(formatHours(hours)) — solid recovery duration."
        } else {
            detail = "You slept \(formatHours(hours)) — shorter than the 7–8h target for lifters."
        }
        return ReadinessComponent(kind: .sleep, score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private static func scoreTrainingLoad(recent: Int, typical: Double) -> ReadinessComponent? {
        let weight = componentWeights[.trainingLoad, default: 0]
        let typicalSafe = max(typical, 1)
        let ratio = Double(recent) / typicalSafe
        let score: Double
        let detail: String
        switch ratio {
        case ..<0.5:
            score = 85
            detail = "Light recent training load (\(recent) hard sets in 72h)."
        case 0.5..<1.2:
            score = 75
            detail = "Normal training load (\(recent) hard sets in 72h)."
        case 1.2..<1.8:
            score = 55
            detail = "Elevated training load (\(recent) hard sets in 72h) — fatigue may linger."
        default:
            score = 35
            detail = "High training load (\(recent) hard sets in 72h) — prioritize recovery."
        }
        return ReadinessComponent(kind: .trainingLoad, score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private static func buildSummary(score: Int, band: ReadinessBand, components: [ReadinessComponent]) -> String {
        let available = components.filter(\.isAvailable)
        if available.isEmpty {
            return "Connect Apple Health to calculate readiness from sleep, HRV, and resting heart rate."
        }
        if let top = available.max(by: { $0.score < $1.score }),
           let bottom = available.min(by: { $0.score < $1.score }),
           top.kind != bottom.kind,
           top.score - bottom.score >= 25 {
            return "\(band.displayTitle) (\(score)/100). \(top.kind.displayTitle) is strong; watch \(bottom.kind.displayTitle.lowercased())."
        }
        return "\(band.displayTitle) (\(score)/100). \(band.coachingHint)"
    }

    private static func clampScore(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private static func formatMs(_ value: Double) -> String {
        "\(Int(value.rounded())) ms"
    }

    private static func formatBpm(_ value: Double) -> String {
        "\(Int(value.rounded())) bpm"
    }

    private static func formatPct(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static func formatHours(_ value: Double) -> String {
        let hours = Int(value)
        let minutes = Int((value - Double(hours)) * 60)
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}
