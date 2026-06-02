//
//  StrengthExerciseMetadataCatalog.swift
//  FitLog
//
//  Movement pattern and role metadata for built-in strength exercises (swap ranking).
//

import Foundation

enum StrengthExerciseMetadataCatalog {
    typealias Metadata = (role: ExerciseRole, pattern: MovementPattern)

    static let byName: [String: Metadata] = [
        "Barbell Bench Press": (.compound, .horizontalPush),
        "Incline Barbell Bench Press": (.compound, .horizontalPush),
        "Decline Barbell Bench Press": (.compound, .horizontalPush),
        "Dumbbell Bench Press": (.compound, .horizontalPush),
        "Incline Dumbbell Press": (.compound, .horizontalPush),
        "Dumbbell Flies": (.isolation, .horizontalPush),
        "Cable Crossover": (.isolation, .horizontalPush),
        "Overhead Barbell Press": (.compound, .verticalPush),
        "Seated Dumbbell Press": (.compound, .verticalPush),
        "Arnold Press": (.compound, .verticalPush),
        "Lateral Raise": (.isolation, .verticalPush),
        "Front Raise": (.isolation, .verticalPush),
        "Rear Delt Fly": (.isolation, .horizontalPull),
        "Tricep Pushdown": (.isolation, .horizontalPush),
        "Overhead Tricep Extension": (.isolation, .verticalPush),
        "Skull Crushers": (.isolation, .horizontalPush),
        "Close-Grip Bench Press": (.compound, .horizontalPush),
        "Dips (Chest/Triceps)": (.compound, .horizontalPush),
        "Pull-Up": (.compound, .verticalPull),
        "Chin-Up": (.compound, .verticalPull),
        "Lat Pulldown (Wide Grip)": (.compound, .verticalPull),
        "Lat Pulldown (Neutral Grip)": (.compound, .verticalPull),
        "Bent-Over Barbell Row": (.compound, .horizontalPull),
        "Pendlay Row": (.compound, .horizontalPull),
        "Seated Cable Row": (.compound, .horizontalPull),
        "Single-Arm Dumbbell Row": (.compound, .horizontalPull),
        "T-Bar Row": (.compound, .horizontalPull),
        "Face Pull": (.accessory, .horizontalPull),
        "Deadlift (Conventional)": (.compound, .hinge),
        "Romanian Deadlift": (.compound, .hinge),
        "Barbell Shrug": (.accessory, .hinge),
        "Back Squat (High Bar)": (.compound, .squat),
        "Low-Bar Back Squat": (.compound, .squat),
        "Front Squat": (.compound, .squat),
        "Leg Press": (.compound, .squat),
        "Hack Squat": (.compound, .squat),
        "Bulgarian Split Squat": (.compound, .lunge),
        "Walking Lunges": (.compound, .lunge),
        "Leg Extension": (.isolation, .squat),
        "Lying Leg Curl": (.isolation, .hinge),
        "Seated Leg Curl": (.isolation, .hinge),
        "Standing Calf Raise": (.isolation, .squat),
        "Seated Calf Raise": (.isolation, .squat),
        "Barbell Bicep Curl": (.isolation, .horizontalPull),
        "EZ-Bar Curl": (.isolation, .horizontalPull),
        "Dumbbell Hammer Curl": (.isolation, .horizontalPull),
        "Concentration Curl": (.isolation, .horizontalPull),
        "Cable Bicep Curl": (.isolation, .horizontalPull),
        "Plank": (.accessory, .rotation),
        "Hanging Leg Raise": (.accessory, .rotation),
        "Ab Wheel Rollout": (.accessory, .rotation),
        "Russian Twist": (.accessory, .rotation),
        "Cable Crunch": (.accessory, .rotation),
    ]

    static func apply(to exercise: inout Exercise) {
        guard exercise.modality == .strength,
              let meta = byName[exercise.name] else { return }
        exercise.exerciseRole = meta.role
        exercise.movementPattern = meta.pattern
    }
}
