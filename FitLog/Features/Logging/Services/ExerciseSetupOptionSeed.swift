//
//  ExerciseSetupOptionSeed.swift
//  FitLog
//
//  Default per-set setup options for bundled machines and cable stations.
//

import Foundation

/// Bundled exercises shipped with no setup options, so the per-set configuration feature had
/// nothing to show. These seeds cover the machines where the usual variable is how you set up
/// (grip, attachment, foot position) rather than which movement you picked.
enum ExerciseSetupOptionSeed {
    static let completedUserDefaultsKey = "fitlog.exerciseSetupOptions.seeded.v1"

    private static let gripWidths = ["Wide", "Medium", "Narrow"]
    private static let footPositions = ["Low", "Middle", "High"]

    static let optionsByExerciseName: [String: [ExerciseConfigurationOption]] = [
        "T-Bar Row": [
            ExerciseConfigurationOption(name: "Grip", choices: gripWidths + ["Neutral"])
        ],
        "Seated Cable Row": [
            ExerciseConfigurationOption(name: "Grip", choices: gripWidths + ["Neutral"]),
            ExerciseConfigurationOption(name: "Attachment", choices: ["V-handle", "Straight bar", "Wide bar", "Rope"])
        ],
        "Lat Pulldown (Wide Grip)": [
            ExerciseConfigurationOption(name: "Attachment", choices: ["Wide bar", "Straight bar"])
        ],
        "Lat Pulldown (Neutral Grip)": [
            ExerciseConfigurationOption(name: "Attachment", choices: ["V-handle", "Neutral bar", "Single handles"])
        ],
        "Leg Press": [
            ExerciseConfigurationOption(name: "Foot position", choices: footPositions),
            ExerciseConfigurationOption(name: "Seat", choices: [])
        ],
        "Hack Squat": [
            ExerciseConfigurationOption(name: "Foot position", choices: footPositions)
        ],
        "Leg Extension": [
            ExerciseConfigurationOption(name: "Seat", choices: [])
        ],
        "Lying Leg Curl": [
            ExerciseConfigurationOption(name: "Pad position", choices: [])
        ],
        "Seated Leg Curl": [
            ExerciseConfigurationOption(name: "Seat", choices: [])
        ],
        "Cable Crossover": [
            ExerciseConfigurationOption(name: "Pulley height", choices: ["Low", "Mid", "High"]),
            ExerciseConfigurationOption(name: "Attachment", choices: ["D-handle", "Rope"])
        ],
        "Tricep Pushdown": [
            ExerciseConfigurationOption(name: "Attachment", choices: ["Rope", "Straight bar", "V-bar"]),
            ExerciseConfigurationOption(name: "Grip", choices: ["Overhand", "Underhand"])
        ],
        "Cable Bicep Curl": [
            ExerciseConfigurationOption(name: "Attachment", choices: ["Straight bar", "EZ bar", "Rope"])
        ],
        "Face Pull": [
            ExerciseConfigurationOption(name: "Pulley height", choices: ["Mid", "High"])
        ],
        "Standing Calf Raise": [
            ExerciseConfigurationOption(name: "Foot angle", choices: ["Toes in", "Neutral", "Toes out"])
        ],
        "Seated Calf Raise": [
            ExerciseConfigurationOption(name: "Foot angle", choices: ["Toes in", "Neutral", "Toes out"])
        ],
        "Pull-Up": [
            ExerciseConfigurationOption(name: "Grip", choices: gripWidths)
        ],
        "Chin-Up": [
            ExerciseConfigurationOption(name: "Grip", choices: gripWidths)
        ]
    ]

    /// Fills empty option lists only, so a user's own options and deletions are never overwritten.
    /// Returns true when anything changed.
    @discardableResult
    static func merge(into exercises: inout [Exercise]) -> Bool {
        var changed = false
        for index in exercises.indices {
            guard exercises[index].configurationOptions.isEmpty,
                  let seeded = optionsByExerciseName[exercises[index].name]
            else { continue }
            exercises[index].configurationOptions = seeded
            changed = true
        }
        return changed
    }
}
