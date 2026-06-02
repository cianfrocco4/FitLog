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
        if setType == .timed {
            let sec = max(0, reps)
            let m = sec / 60
            let s = sec % 60
            let timeStr = m > 0 ? String(format: "%d:%02d hold", m, s) : "\(s)s hold"
            let load = wStr(weight)
            return load == "0" ? timeStr : "\(load) \(unitLabel) · \(timeStr)"
        }
        var parts = [seg(weight, reps)]
        for d in dropSegments {
            parts.append("→ " + seg(d.weight, d.reps))
        }
        return parts.joined(separator: " ")
    }
}

/// Whether effort is expressed as RPE (subjective intensity, 1–10 scale, where 10 = max effort)
/// or RIR (reps in reserve, 0 = failure, 4+ = plenty left).
enum EffortInputStyle: String, CaseIterable, Identifiable, Codable {
    case rpe
    case rir

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rpe: return "RPE"
        case .rir: return "RIR"
        }
    }

    var pickerLabel: String {
        switch self {
        case .rpe: return "RPE (Rate of Perceived Exertion)"
        case .rir: return "RIR (Reps in Reserve)"
        }
    }

    /// Convert a stored RPE value to its RIR equivalent (10 − RPE).
    func displayValue(fromRPE rpe: Double) -> Double {
        switch self {
        case .rpe: return rpe
        case .rir: return max(0, 10 - rpe)
        }
    }

    /// Convert a user-entered value back to RPE for storage.
    func toRPE(_ input: Double) -> Double {
        switch self {
        case .rpe: return input
        case .rir: return max(0, 10 - input)
        }
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
        static let dismissedCardioGetStartedBanner = "fitlog.dismissedCardioGetStartedBanner"
        static let effortInputStyle = "fitlog.effortInputStyle"
        static let formGuideGender = "fitlog.formGuideGender"
        static let formGuideAngle = "fitlog.formGuideAngle"
        static let formGuideMuscleWikiOverrides = "fitlog.formGuideMuscleWikiOverrides"
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

    /// User dismissed the Home cardio get-started card.
    @Published var dismissedCardioGetStartedBanner: Bool {
        didSet { defaults.set(dismissedCardioGetStartedBanner, forKey: Keys.dismissedCardioGetStartedBanner) }
    }

    /// Whether the inline log row shows effort as RPE or RIR.
    @Published var effortInputStyle: EffortInputStyle {
        didSet { defaults.set(effortInputStyle.rawValue, forKey: Keys.effortInputStyle) }
    }

    @Published var formGuideGender: FormGuideGender {
        didSet { defaults.set(formGuideGender.rawValue, forKey: Keys.formGuideGender) }
    }

    @Published var formGuideAngle: FormGuideAngle {
        didSet { defaults.set(formGuideAngle.rawValue, forKey: Keys.formGuideAngle) }
    }

    /// User-selected MuscleWiki exercise id per FitLog exercise (wrong-video corrections).
    private var formGuideMuscleWikiOverridesStorage: [String: Int] {
        didSet { defaults.set(formGuideMuscleWikiOverridesStorage, forKey: Keys.formGuideMuscleWikiOverrides) }
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
        _dismissedCardioGetStartedBanner = Published(initialValue: defaults.bool(forKey: Keys.dismissedCardioGetStartedBanner))
        if let raw = defaults.string(forKey: Keys.effortInputStyle),
           let style = EffortInputStyle(rawValue: raw) {
            _effortInputStyle = Published(initialValue: style)
        } else {
            _effortInputStyle = Published(initialValue: .rpe)
        }
        if let raw = defaults.string(forKey: Keys.formGuideGender),
           let gender = FormGuideGender(rawValue: raw) {
            _formGuideGender = Published(initialValue: gender)
        } else {
            _formGuideGender = Published(initialValue: .male)
        }
        if let raw = defaults.string(forKey: Keys.formGuideAngle),
           let angle = FormGuideAngle(rawValue: raw) {
            _formGuideAngle = Published(initialValue: angle)
        } else {
            _formGuideAngle = Published(initialValue: .front)
        }
        let overrideDict = defaults.dictionary(forKey: Keys.formGuideMuscleWikiOverrides) as? [String: Int] ?? [:]
        formGuideMuscleWikiOverridesStorage = overrideDict
    }

    func formGuideMuscleWikiOverride(for exerciseId: UUID) -> Int? {
        formGuideMuscleWikiOverridesStorage[exerciseId.uuidString]
    }

    func setFormGuideMuscleWikiOverride(_ muscleWikiId: Int?, for exerciseId: UUID) {
        var copy = formGuideMuscleWikiOverridesStorage
        if let muscleWikiId {
            copy[exerciseId.uuidString] = muscleWikiId
        } else {
            copy.removeValue(forKey: exerciseId.uuidString)
        }
        formGuideMuscleWikiOverridesStorage = copy
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
        dismissedCardioGetStartedBanner = true
        effortInputStyle = .rpe
    }
}
