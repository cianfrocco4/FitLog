//
//  PlateCalculator.swift
//  FitLog
//

import Foundation

enum PlateCalculator {
    /// Per-side plate sizes (one side of the bar), largest first.
    static func standardPlatesPerSide(unit: WeightDisplayUnit) -> [Double] {
        switch unit {
        case .pounds:
            return [45, 35, 25, 10, 5, 2.5]
        case .kilograms:
            return [25, 20, 15, 10, 5, 2.5, 1.25]
        }
    }

    static func defaultBarWeight(unit: WeightDisplayUnit) -> Double {
        switch unit {
        case .pounds: return 45
        case .kilograms: return 20
        }
    }

    /// Each entry is plate size × count on **one** side of the bar.
    static func platesPerSide(
        targetTotalDisplay: Double,
        barDisplay: Double,
        unit: WeightDisplayUnit
    ) -> [(size: Double, count: Int)] {
        let plates = standardPlatesPerSide(unit: unit)
        let perSide = max(0, (targetTotalDisplay - barDisplay) / 2)
        var remaining = perSide
        var result: [(Double, Int)] = []
        for p in plates {
            guard p > 0 else { continue }
            let n = Int((remaining / p).rounded(.down))
            if n > 0 {
                result.append((p, n))
                remaining -= Double(n) * p
            }
        }
        return result
    }

    static func totalBarbellDisplay(
        barDisplay: Double,
        platesPerSide: [(size: Double, count: Int)]
    ) -> Double {
        let sideLoad = platesPerSide.reduce(0.0) { $0 + $1.size * Double($1.count) }
        return barDisplay + 2 * sideLoad
    }

    static func remainderDisplay(
        targetTotalDisplay: Double,
        barDisplay: Double,
        unit: WeightDisplayUnit
    ) -> Double {
        let plan = Self.platesPerSide(
            targetTotalDisplay: targetTotalDisplay,
            barDisplay: barDisplay,
            unit: unit
        )
        let achieved = totalBarbellDisplay(barDisplay: barDisplay, platesPerSide: plan)
        return targetTotalDisplay - achieved
    }
}
