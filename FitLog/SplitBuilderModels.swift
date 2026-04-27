//
//  SplitBuilderModels.swift
//  FitLog
//
//  Shared editable split-builder state used by manual and AI-adjacent flows.
//

import Foundation

struct SplitBuilderEditableSlot: Identifiable, Equatable {
    let id: UUID
    var label: String
    var targetMuscleNames: [String]
    var sets: Int
    var reps: String
    var suggestedExerciseName: String?
    var suggestedExerciseOverrideId: UUID?

    init(
        id: UUID = UUID(),
        label: String,
        targetMuscleNames: [String],
        sets: Int,
        reps: String,
        suggestedExerciseName: String? = nil,
        suggestedExerciseOverrideId: UUID? = nil
    ) {
        self.id = id
        self.label = label
        self.targetMuscleNames = targetMuscleNames
        self.sets = sets
        self.reps = reps
        self.suggestedExerciseName = suggestedExerciseName
        self.suggestedExerciseOverrideId = suggestedExerciseOverrideId
    }
}

struct SplitBuilderEditableDay: Identifiable, Equatable {
    let id: UUID
    var name: String
    var focus: String
    var slots: [SplitBuilderEditableSlot]

    init(id: UUID = UUID(), name: String, focus: String, slots: [SplitBuilderEditableSlot]) {
        self.id = id
        self.name = name
        self.focus = focus
        self.slots = slots
    }
}

extension SplitBuilderEditableDay {
    init(from proposalDay: WorkoutSplitProposalDay) {
        self.id = UUID()
        self.name = proposalDay.name
        self.focus = proposalDay.focus ?? ""
        if !proposalDay.slots.isEmpty {
            self.slots = proposalDay.slots.map {
                SplitBuilderEditableSlot(
                    label: $0.label,
                    targetMuscleNames: $0.targetMuscleNames,
                    sets: $0.sets,
                    reps: $0.reps,
                    suggestedExerciseName: $0.suggestedExerciseName,
                    suggestedExerciseOverrideId: $0.suggestedExerciseOverrideId
                )
            }
        } else {
            self.slots = proposalDay.exercises.map {
                SplitBuilderEditableSlot(
                    label: $0.name,
                    targetMuscleNames: [MuscleGroup.other.rawValue],
                    sets: $0.sets,
                    reps: $0.reps,
                    suggestedExerciseName: $0.name,
                    suggestedExerciseOverrideId: $0.libraryExerciseOverrideId
                )
            }
        }
    }

    func toProposalDay() -> WorkoutSplitProposalDay {
        WorkoutSplitProposalDay(
            name: name,
            focus: focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focus,
            exercises: [],
            slots: slots.map {
                WorkoutSplitProposalSlotItem(
                    label: $0.label,
                    targetMuscleNames: $0.targetMuscleNames,
                    sets: $0.sets,
                    reps: $0.reps,
                    suggestedExerciseName: $0.suggestedExerciseName,
                    suggestedExerciseOverrideId: $0.suggestedExerciseOverrideId
                )
            }
        )
    }
}

enum SplitBuilderManualPreset: String, CaseIterable, Identifiable {
    case blank = "Blank"
    case pushPullLegs = "Push / Pull / Legs"
    case upperLower = "Upper / Lower"
    case fullBody = "Full Body"
    case broSplit = "Muscle Group Split"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .blank: return "Start with empty days and add your own slots."
        case .pushPullLegs: return "Push, Pull, Legs rotation for 3-6 training days."
        case .upperLower: return "Balanced upper/lower rotation for 2-4 days."
        case .fullBody: return "Repeatable full-body sessions for 1-4 days."
        case .broSplit: return "Muscle-focused days for higher-frequency plans."
        }
    }
}

enum SplitBuilderVariationMode: String, CaseIterable, Identifiable, Equatable {
    case simple = "Simple rotation"
    case balanced = "Balanced variation"
    case high = "High variety"
    case custom = "Custom"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .simple:
            return "Use about as many templates as training days."
        case .balanced:
            return "Add A/B style templates when it improves coverage."
        case .high:
            return "Use more exercise and emphasis variety across the cycle."
        case .custom:
            return "Choose the number of templates in the rotation."
        }
    }

    func targetRotationLength(
        sessionsPerWeek: Int,
        splitPreferenceText: String,
        customCount: Int? = nil
    ) -> Int {
        let sessions = min(max(1, sessionsPerWeek), 7)
        let sp = splitPreferenceText.lowercased()
        let isPPL = sp.contains("ppl") || (sp.contains("push") && sp.contains("pull") && sp.contains("leg"))
        let isUpperLower = sp.contains("upper") && sp.contains("lower")
        let isFullBody = sp.contains("full")
        let isBro = sp.contains("bro") || sp.contains("muscle")

        switch self {
        case .simple:
            if isPPL { return min(sessions, 3) }
            if isUpperLower { return min(sessions, 2) }
            if isFullBody { return 1 }
            return min(max(1, sessions), 6)
        case .balanced:
            if isPPL { return 6 }
            if isUpperLower { return 4 }
            if isFullBody { return min(max(2, sessions), 3) }
            if isBro { return min(max(4, sessions), 6) }
            return min(max(sessions, 3), 6)
        case .high:
            if isPPL { return 6 }
            if isUpperLower { return min(max(4, sessions), 6) }
            if isFullBody { return min(max(3, sessions), 5) }
            if isBro { return 6 }
            return min(max(sessions + 1, 4), 6)
        case .custom:
            return min(max(1, customCount ?? sessions), 7)
        }
    }

    func rotationSummary(
        sessionsPerWeek: Int,
        splitPreferenceText: String,
        customCount: Int? = nil
    ) -> String {
        let target = targetRotationLength(
            sessionsPerWeek: sessionsPerWeek,
            splitPreferenceText: splitPreferenceText,
            customCount: customCount
        )
        if target == sessionsPerWeek {
            return "This creates \(target) template\(target == 1 ? "" : "s") for \(sessionsPerWeek) workout\(sessionsPerWeek == 1 ? "" : "s") per week."
        }
        if target < sessionsPerWeek {
            return "This creates \(target) template\(target == 1 ? "" : "s") repeated across \(sessionsPerWeek) workout\(sessionsPerWeek == 1 ? "" : "s") per week."
        }
        return "This creates a \(target)-workout rotation for \(sessionsPerWeek) workout\(sessionsPerWeek == 1 ? "" : "s") per week, so variation cycles across weeks."
    }
}

enum SplitBuilderSharedFactory {
    static func blankDays(count: Int) -> [SplitBuilderEditableDay] {
        (1...max(1, count)).map {
            SplitBuilderEditableDay(name: "Day \($0)", focus: "", slots: [])
        }
    }

    static func presetDays(
        preset: SplitBuilderManualPreset,
        count requestedCount: Int,
        variationMode: SplitBuilderVariationMode = .simple,
        customRotationLength: Int? = nil,
        library: [Exercise]
    ) -> [SplitBuilderEditableDay] {
        let requested = min(max(1, requestedCount), 7)
        let count = variationMode.targetRotationLength(
            sessionsPerWeek: requested,
            splitPreferenceText: preset.rawValue,
            customCount: customRotationLength
        )
        switch preset {
        case .blank:
            return blankDays(count: count)
        case .pushPullLegs:
            if variationMode != .simple || count >= 6 {
                return repeatPattern(pplABDays(library: library), count: count)
            }
            return repeatPattern([
                day(name: "Push", focus: "Chest, shoulders, triceps", focus: .push, library: library),
                day(name: "Pull", focus: "Back, biceps, rear delts", focus: .pull, library: library),
                day(name: "Legs", focus: "Quads, hamstrings, glutes, calves", focus: .legs, library: library)
            ], count: count)
        case .upperLower:
            if variationMode != .simple || count >= 4 {
                return repeatPattern(upperLowerABDays(library: library), count: count)
            }
            return repeatPattern([
                day(name: "Upper", focus: "Balanced upper body", focus: .upper, library: library),
                day(name: "Lower", focus: "Squat, hinge, and lower accessories", focus: .lower, library: library)
            ], count: count)
        case .fullBody:
            if variationMode == .simple {
                return repeatPattern([
                    day(name: "Full Body", focus: "Compound full-body session", focus: .fullBody, library: library)
                ], count: count)
            }
            return repeatPattern(fullBodyVariationDays(library: library), count: count)
        case .broSplit:
            return repeatPattern(broVariationDays(library: library), count: count)
        }
    }

    private static func pplABDays(library: [Exercise]) -> [SplitBuilderEditableDay] {
        [
            simpleDay("Push A", focus: "Chest-heavy horizontal press", slots: [
                slot("Horizontal press", muscles: [.chest], defaultName: "Barbell Bench Press", sets: 4, reps: "6-10", library: library),
                slot("Incline press", muscles: [.upperChest], defaultName: "Incline Dumbbell Press", library: library),
                slot("Lateral delts", muscles: [.sideDelts], defaultName: "Lateral Raise", library: library),
                slot("Triceps", muscles: [.triceps], defaultName: "Tricep Pushdown", library: library)
            ]),
            simpleDay("Pull A", focus: "Vertical pull and lats", slots: [
                slot("Vertical pull", muscles: [.lats], defaultName: "Pull-Up", sets: 4, reps: "6-10", library: library),
                slot("Lat pulldown", muscles: [.lats], defaultName: "Lat Pulldown (Wide Grip)", library: library),
                slot("Upper back row", muscles: [.upperBack], defaultName: "Seated Cable Row", library: library),
                slot("Biceps", muscles: [.biceps], defaultName: "Barbell Bicep Curl", library: library)
            ]),
            simpleDay("Legs A", focus: "Squat and quad emphasis", slots: [
                slot("Squat", muscles: [.quads, .glutes], defaultName: "Back Squat (High Bar)", sets: 4, reps: "6-10", library: library),
                slot("Leg press", muscles: [.quads], defaultName: "Leg Press", library: library),
                slot("Quad isolation", muscles: [.quads], defaultName: "Leg Extension", library: library),
                slot("Calves", muscles: [.calves], defaultName: "Standing Calf Raise", library: library)
            ]),
            simpleDay("Push B", focus: "Shoulder and incline emphasis", slots: [
                slot("Vertical press", muscles: [.frontDelts, .triceps], defaultName: "Overhead Barbell Press", sets: 4, reps: "6-10", library: library),
                slot("Incline press", muscles: [.upperChest], defaultName: "Incline Dumbbell Press", library: library),
                slot("Dips / close press", muscles: [.triceps, .chest], defaultName: "Dips (Chest/Triceps)", library: library),
                slot("Lateral delts", muscles: [.sideDelts], defaultName: "Lateral Raise", library: library)
            ]),
            simpleDay("Pull B", focus: "Rows, upper back, rear delts", slots: [
                slot("Barbell row", muscles: [.upperBack, .midBack], defaultName: "Bent-Over Barbell Row", sets: 4, reps: "6-10", library: library),
                slot("Cable row", muscles: [.midBack], defaultName: "Seated Cable Row", library: library),
                slot("Rear delts", muscles: [.rearDelts], defaultName: "Face Pull", library: library),
                slot("Biceps", muscles: [.biceps], defaultName: "Barbell Bicep Curl", library: library)
            ]),
            simpleDay("Legs B", focus: "Hinge, glutes, hamstrings", slots: [
                slot("Hinge", muscles: [.hamstrings, .glutes], defaultName: "Romanian Deadlift", sets: 4, reps: "6-10", library: library),
                slot("Single-leg", muscles: [.glutes, .quads], defaultName: "Bulgarian Split Squat", library: library),
                slot("Leg curl", muscles: [.hamstrings], defaultName: "Lying Leg Curl", library: library),
                slot("Calves", muscles: [.calves], defaultName: "Standing Calf Raise", library: library)
            ])
        ]
    }

    private static func upperLowerABDays(library: [Exercise]) -> [SplitBuilderEditableDay] {
        [
            simpleDay("Upper A", focus: "Horizontal push and row", slots: [
                slot("Horizontal press", muscles: [.chest], defaultName: "Barbell Bench Press", sets: 4, reps: "6-10", library: library),
                slot("Horizontal row", muscles: [.upperBack], defaultName: "Bent-Over Barbell Row", sets: 4, reps: "6-10", library: library),
                slot("Vertical pull", muscles: [.lats], defaultName: "Lat Pulldown (Wide Grip)", library: library),
                slot("Delts / arms", muscles: [.sideDelts, .triceps], defaultName: "Lateral Raise", library: library)
            ]),
            simpleDay("Lower A", focus: "Squat and quad emphasis", slots: [
                slot("Squat", muscles: [.quads, .glutes], defaultName: "Back Squat (High Bar)", sets: 4, reps: "6-10", library: library),
                slot("Leg press", muscles: [.quads], defaultName: "Leg Press", library: library),
                slot("Leg curl", muscles: [.hamstrings], defaultName: "Lying Leg Curl", library: library),
                slot("Calves", muscles: [.calves], defaultName: "Standing Calf Raise", library: library)
            ]),
            simpleDay("Upper B", focus: "Vertical push and pull", slots: [
                slot("Vertical press", muscles: [.frontDelts, .triceps], defaultName: "Overhead Barbell Press", sets: 4, reps: "6-10", library: library),
                slot("Vertical pull", muscles: [.lats], defaultName: "Pull-Up", sets: 4, reps: "6-10", library: library),
                slot("Cable row", muscles: [.midBack], defaultName: "Seated Cable Row", library: library),
                slot("Arms", muscles: [.biceps, .triceps], defaultName: "Barbell Bicep Curl", library: library)
            ]),
            simpleDay("Lower B", focus: "Hinge and posterior chain", slots: [
                slot("Hinge", muscles: [.hamstrings, .glutes], defaultName: "Romanian Deadlift", sets: 4, reps: "6-10", library: library),
                slot("Single-leg", muscles: [.glutes, .quads], defaultName: "Bulgarian Split Squat", library: library),
                slot("Hamstrings", muscles: [.hamstrings], defaultName: "Lying Leg Curl", library: library),
                slot("Core / calves", muscles: [.calves, .core], defaultName: "Standing Calf Raise", library: library)
            ])
        ]
    }

    private static func fullBodyVariationDays(library: [Exercise]) -> [SplitBuilderEditableDay] {
        [
            simpleDay("Full Body A", focus: "Squat, horizontal push, row", slots: [
                slot("Squat", muscles: [.quads, .glutes], defaultName: "Back Squat (High Bar)", sets: 3, reps: "6-10", library: library),
                slot("Horizontal press", muscles: [.chest], defaultName: "Barbell Bench Press", library: library),
                slot("Row", muscles: [.upperBack], defaultName: "Bent-Over Barbell Row", library: library),
                slot("Core / calves", muscles: [.core, .calves], defaultName: "Standing Calf Raise", library: library)
            ]),
            simpleDay("Full Body B", focus: "Hinge, vertical push, vertical pull", slots: [
                slot("Hinge", muscles: [.hamstrings, .glutes], defaultName: "Romanian Deadlift", sets: 3, reps: "6-10", library: library),
                slot("Vertical press", muscles: [.frontDelts, .triceps], defaultName: "Overhead Barbell Press", library: library),
                slot("Vertical pull", muscles: [.lats], defaultName: "Pull-Up", library: library),
                slot("Arms / delts", muscles: [.sideDelts, .biceps], defaultName: "Lateral Raise", library: library)
            ]),
            simpleDay("Full Body C", focus: "Single-leg, incline push, cable row", slots: [
                slot("Single-leg", muscles: [.glutes, .quads], defaultName: "Bulgarian Split Squat", sets: 3, reps: "8-10", library: library),
                slot("Incline press", muscles: [.upperChest], defaultName: "Incline Dumbbell Press", library: library),
                slot("Cable row", muscles: [.midBack], defaultName: "Seated Cable Row", library: library),
                slot("Hamstrings", muscles: [.hamstrings], defaultName: "Lying Leg Curl", library: library)
            ])
        ]
    }

    private static func broVariationDays(library: [Exercise]) -> [SplitBuilderEditableDay] {
        [
            simpleDay("Chest", focus: "Chest emphasis", slots: [
                slot("Press", muscles: [.chest], defaultName: "Barbell Bench Press", library: library),
                slot("Incline press", muscles: [.upperChest], defaultName: "Incline Dumbbell Press", library: library),
                slot("Chest accessory", muscles: [.chest], defaultName: "Incline Dumbbell Press", library: library),
                slot("Triceps", muscles: [.triceps], defaultName: "Tricep Pushdown", library: library)
            ]),
            simpleDay("Back", focus: "Back and rear delts", slots: [
                slot("Vertical pull", muscles: [.lats], defaultName: "Pull-Up", library: library),
                slot("Row", muscles: [.upperBack], defaultName: "Bent-Over Barbell Row", library: library),
                slot("Cable row", muscles: [.midBack], defaultName: "Seated Cable Row", library: library),
                slot("Rear delts", muscles: [.rearDelts], defaultName: "Face Pull", library: library)
            ]),
            simpleDay("Legs", focus: "Lower body", slots: [
                slot("Squat", muscles: [.quads, .glutes], defaultName: "Back Squat (High Bar)", sets: 4, reps: "6-10", library: library),
                slot("Hinge", muscles: [.hamstrings, .glutes], defaultName: "Romanian Deadlift", library: library),
                slot("Leg curl", muscles: [.hamstrings], defaultName: "Lying Leg Curl", library: library),
                slot("Calves", muscles: [.calves], defaultName: "Standing Calf Raise", library: library)
            ]),
            simpleDay("Shoulders & Arms", focus: "Delts, biceps, triceps", slots: [
                slot("Overhead press", muscles: [.frontDelts, .triceps], defaultName: "Overhead Barbell Press", library: library),
                slot("Lateral raise", muscles: [.sideDelts], defaultName: "Lateral Raise", library: library),
                slot("Biceps", muscles: [.biceps], defaultName: "Barbell Bicep Curl", library: library),
                slot("Triceps", muscles: [.triceps], defaultName: "Tricep Pushdown", library: library)
            ]),
            simpleDay("Back B", focus: "Rows, traps, rear delts", slots: [
                slot("Heavy row", muscles: [.upperBack, .midBack], defaultName: "Bent-Over Barbell Row", sets: 4, reps: "6-10", library: library),
                slot("Vertical pull", muscles: [.lats], defaultName: "Lat Pulldown (Wide Grip)", library: library),
                slot("Rear delts", muscles: [.rearDelts], defaultName: "Face Pull", library: library),
                slot("Biceps", muscles: [.biceps], defaultName: "Barbell Bicep Curl", library: library)
            ]),
            simpleDay("Legs B", focus: "Posterior chain", slots: [
                slot("Hinge", muscles: [.hamstrings, .glutes], defaultName: "Romanian Deadlift", sets: 4, reps: "6-10", library: library),
                slot("Single-leg", muscles: [.glutes, .quads], defaultName: "Bulgarian Split Squat", library: library),
                slot("Hamstrings", muscles: [.hamstrings], defaultName: "Lying Leg Curl", library: library),
                slot("Calves", muscles: [.calves], defaultName: "Standing Calf Raise", library: library)
            ])
        ]
    }

    private static func repeatPattern(_ pattern: [SplitBuilderEditableDay], count: Int) -> [SplitBuilderEditableDay] {
        guard !pattern.isEmpty else { return blankDays(count: count) }
        return (0..<count).map { idx in
            let source = pattern[idx % pattern.count]
            if count > pattern.count {
                let round = idx / pattern.count + 1
                return SplitBuilderEditableDay(
                    name: "\(source.name) \(round)",
                    focus: source.focus,
                    slots: freshSlots(from: source.slots)
                )
            } else {
                return SplitBuilderEditableDay(
                    name: source.name,
                    focus: source.focus,
                    slots: freshSlots(from: source.slots)
                )
            }
        }
    }

    private static func freshSlots(from slots: [SplitBuilderEditableSlot]) -> [SplitBuilderEditableSlot] {
        slots.map {
            SplitBuilderEditableSlot(
                id: UUID(),
                label: $0.label,
                targetMuscleNames: $0.targetMuscleNames,
                sets: $0.sets,
                reps: $0.reps,
                suggestedExerciseName: $0.suggestedExerciseName,
                suggestedExerciseOverrideId: $0.suggestedExerciseOverrideId
            )
        }
    }

    private static func day(name: String, focus: String, focus creationFocus: WorkoutCreationFocus, library: [Exercise]) -> SplitBuilderEditableDay {
        let slots = WorkoutStarterResolution.resolvedStarters(focus: creationFocus, library: library).map {
            SplitBuilderEditableSlot(
                id: UUID(),
                label: $0.exercise.name,
                targetMuscleNames: $0.exercise.targetedMuscles.map(\.rawValue),
                sets: $0.sets,
                reps: $0.reps,
                suggestedExerciseName: $0.exercise.name,
                suggestedExerciseOverrideId: $0.exercise.id
            )
        }
        return SplitBuilderEditableDay(name: name, focus: focus, slots: slots)
    }

    private static func simpleDay(_ name: String, focus: String, slots: [SplitBuilderEditableSlot]) -> SplitBuilderEditableDay {
        SplitBuilderEditableDay(name: name, focus: focus, slots: slots)
    }

    private static func slot(
        _ label: String,
        muscles: [MuscleGroup],
        defaultName: String,
        sets: Int = 3,
        reps: String = "8-12",
        library: [Exercise]
    ) -> SplitBuilderEditableSlot {
        let resolved = ExerciseNameResolution.resolve(planName: defaultName, library: library)
        let linked: Exercise? = {
            if case .linked(let ex) = resolved { return ex }
            return nil
        }()
        return SplitBuilderEditableSlot(
            id: UUID(),
            label: label,
            targetMuscleNames: (linked?.targetedMuscles ?? muscles).map(\.rawValue),
            sets: sets,
            reps: reps,
            suggestedExerciseName: linked?.name ?? defaultName,
            suggestedExerciseOverrideId: linked?.id
        )
    }
}
