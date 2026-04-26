//
//  UserPreferences.swift
//  FitLog
//
//  App-wide UI preferences (weight units, onboarding, lightweight coach marks).
//

import Foundation
import Combine

enum WeightDisplayUnit: String, CaseIterable, Identifiable {
    case pounds
    case kilograms

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        }
    }
}

enum WeightStoreConversion {
    /// Storage and analytics use pounds; display may use kg.
    static let poundsPerKilogram = 2.2046226218

    static func displayValue(storedPounds: Double, unit: WeightDisplayUnit) -> Double {
        switch unit {
        case .pounds: return storedPounds
        case .kilograms: return storedPounds / poundsPerKilogram
        }
    }

    static func storedPounds(displayValue: Double, unit: WeightDisplayUnit) -> Double {
        switch unit {
        case .pounds: return displayValue
        case .kilograms: return displayValue * poundsPerKilogram
        }
    }

    static func displayRange(unit: WeightDisplayUnit) -> ClosedRange<Double> {
        switch unit {
        case .pounds: return 0...1100
        case .kilograms: return 0...500
        }
    }

    /// Same magnitude as `displayRange` but allows negative values (net load: added minus assisted).
    static func signedNetDisplayRange(unit: WeightDisplayUnit) -> ClosedRange<Double> {
        let u = displayRange(unit: unit).upperBound
        return -u...u
    }

    static func clampNonNegativeDisplay(_ w: Double, unit: WeightDisplayUnit) -> Double {
        guard w.isFinite else { return 0 }
        let r = displayRange(unit: unit)
        return min(r.upperBound, max(r.lowerBound, w))
    }

    static func clampSignedNetDisplay(_ w: Double, unit: WeightDisplayUnit) -> Double {
        guard w.isFinite else { return 0 }
        let r = signedNetDisplayRange(unit: unit)
        return min(r.upperBound, max(r.lowerBound, w))
    }

    static func stepperStep(unit: WeightDisplayUnit) -> Double {
        switch unit {
        case .pounds: return 5
        case .kilograms: return 2.5
        }
    }

    static func formatDisplay(_ value: Double) -> String {
        if value == floor(value) { return "\(Int(value))" }
        return String(format: "%.1f", value)
    }

    /// Chart / numeric volume from stored lb·rep product.
    static func volumeDisplayValue(lbRep: Double, unit: WeightDisplayUnit) -> Double {
        switch unit {
        case .pounds: return lbRep
        case .kilograms: return lbRep / poundsPerKilogram
        }
    }

    /// Formats stored analytics volume (lb·rep) for the chosen display unit.
    static func formatVolumeLbRep(_ lbRep: Double, unit: WeightDisplayUnit) -> String {
        switch unit {
        case .pounds:
            let v = lbRep
            let s = v == floor(v) ? "\(Int(v))" : String(format: "%.0f", v)
            return "\(s) lb·rep"
        case .kilograms:
            let kgRep = lbRep / poundsPerKilogram
            let s = kgRep == floor(kgRep) ? "\(Int(kgRep))" : String(format: "%.0f", kgRep)
            return "\(s) kg·rep"
        }
    }
}

extension LoggedSet {
    /// Like `weightRepsDisplaySummary(unit:)` but converts from stored pounds when showing kg.
    func weightRepsDisplaySummary(displayUnit: WeightDisplayUnit) -> String {
        let unitLabel = displayUnit.shortLabel
        func wStr(_ storedLb: Double) -> String {
            let d = WeightStoreConversion.displayValue(storedPounds: storedLb, unit: displayUnit)
            return WeightStoreConversion.formatDisplay(d)
        }
        func seg(_ storedLb: Double, _ r: Int) -> String {
            let rw = r == 1 ? "rep" : "reps"
            return "\(wStr(storedLb)) \(unitLabel) × \(r) \(rw)"
        }
        var parts = [seg(weight, reps)]
        for d in dropSegments {
            parts.append("→ " + seg(d.weight, d.reps))
        }
        return parts.joined(separator: " ")
    }
}

@MainActor
final class UserPreferences: ObservableObject {
    private enum Keys {
        static let weightUnit = "fitlog.weightDisplayUnit"
        static let onboarding = "fitlog.hasCompletedOnboarding"
        static let coachHome = "fitlog.coachMark.home.v1"
        static let coachPlan = "fitlog.coachMark.plan.v1"
        static let coachHistory = "fitlog.coachMark.history.v1"
        static let dismissedProgramAssignmentBanner = "fitlog.dismissedProgramAssignmentBanner"
    }

    private let defaults: UserDefaults

    @Published var weightDisplayUnit: WeightDisplayUnit {
        didSet { defaults.set(weightDisplayUnit.rawValue, forKey: Keys.weightUnit) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    @Published var coachMarkHomeDismissed: Bool {
        didSet { defaults.set(coachMarkHomeDismissed, forKey: Keys.coachHome) }
    }

    @Published var coachMarkPlanDismissed: Bool {
        didSet { defaults.set(coachMarkPlanDismissed, forKey: Keys.coachPlan) }
    }

    @Published var coachMarkHistoryDismissed: Bool {
        didSet { defaults.set(coachMarkHistoryDismissed, forKey: Keys.coachHistory) }
    }

    /// User hid the Home banner prompting them to assign workouts to the weekly program lineup.
    @Published var dismissedProgramAssignmentBanner: Bool {
        didSet { defaults.set(dismissedProgramAssignmentBanner, forKey: Keys.dismissedProgramAssignmentBanner) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.weightUnit),
           let u = WeightDisplayUnit(rawValue: raw) {
            _weightDisplayUnit = Published(initialValue: u)
        } else {
            _weightDisplayUnit = Published(initialValue: .pounds)
        }
        _hasCompletedOnboarding = Published(initialValue: defaults.bool(forKey: Keys.onboarding))
        _coachMarkHomeDismissed = Published(initialValue: defaults.bool(forKey: Keys.coachHome))
        _coachMarkPlanDismissed = Published(initialValue: defaults.bool(forKey: Keys.coachPlan))
        _coachMarkHistoryDismissed = Published(initialValue: defaults.bool(forKey: Keys.coachHistory))
        _dismissedProgramAssignmentBanner = Published(initialValue: defaults.bool(forKey: Keys.dismissedProgramAssignmentBanner))
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }

    /// UI tests: avoid blocking flows with onboarding or coach UI.
    func applyUITestDefaults() {
        hasCompletedOnboarding = true
        coachMarkHomeDismissed = true
        coachMarkPlanDismissed = true
        coachMarkHistoryDismissed = true
        dismissedProgramAssignmentBanner = true
    }
}
