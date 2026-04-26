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

enum SplitBuilderSharedFactory {
    static func blankDays(count: Int) -> [SplitBuilderEditableDay] {
        (1...max(1, count)).map {
            SplitBuilderEditableDay(name: "Day \($0)", focus: "", slots: [])
        }
    }

    static func presetDays(
        preset: SplitBuilderManualPreset,
        count requestedCount: Int,
        library: [Exercise]
    ) -> [SplitBuilderEditableDay] {
        let count = min(max(1, requestedCount), 7)
        switch preset {
        case .blank:
            return blankDays(count: count)
        case .pushPullLegs:
            return repeatPattern([
                day(name: "Push", focus: "Chest, shoulders, triceps", focus: .push, library: library),
                day(name: "Pull", focus: "Back, biceps, rear delts", focus: .pull, library: library),
                day(name: "Legs", focus: "Quads, hamstrings, glutes, calves", focus: .legs, library: library)
            ], count: count)
        case .upperLower:
            return repeatPattern([
                day(name: "Upper", focus: "Balanced upper body", focus: .upper, library: library),
                day(name: "Lower", focus: "Squat, hinge, and lower accessories", focus: .lower, library: library)
            ], count: count)
        case .fullBody:
            return (1...count).map { idx in
                let source = day(
                    name: count == 1 ? "Full Body" : "Full Body \(idx)",
                    focus: "Compound full-body session",
                    focus: .fullBody,
                    library: library
                )
                var d = SplitBuilderEditableDay(
                    name: source.name,
                    focus: source.focus,
                    slots: freshSlots(from: source.slots)
                )
                if idx.isMultiple(of: 2) {
                    d.slots.reverse()
                }
                return d
            }
        case .broSplit:
            return repeatPattern([
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
                ])
            ], count: count)
        }
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
