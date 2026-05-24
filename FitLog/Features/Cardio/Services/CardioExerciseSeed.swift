//
//  CardioExerciseSeed.swift
//  FitLog
//
//  Bundled cardio exercise catalog (50+ rows) with stable UUIDs for idempotent merge.
//

import Foundation

enum CardioExerciseSeed {
    static let completedUserDefaultsKey = "FitLog.seed.cardio.v1.done"

    /// Stable IDs for merge-by-id; do not change after release.
    private static func id(_ index: UInt16) -> UUID {
        UUID(uuidString: String(format: "C4E80000-%04X-4000-8000-000000000001", index))!
    }

    static var builtInNames: Set<String> {
        Set(allExercises().map(\.name))
    }

    /// Looks up a seeded exercise by stable index in the global library (or bundled catalog).
    static func exercise(seedIndex: UInt16, library: [Exercise]) -> Exercise? {
        let targetId = id(seedIndex)
        if let match = library.first(where: { $0.id == targetId }) { return match }
        return allExercises().first { $0.id == targetId }
    }

    /// Merges seed rows missing from `exercises` by stable `id`. Returns whether any row was added.
    @discardableResult
    static func merge(into exercises: inout [Exercise]) -> Bool {
        let existingIds = Set(exercises.map(\.id))
        var added = false
        for row in allExercises() where !existingIds.contains(row.id) {
            exercises.append(row)
            added = true
        }
        return added
    }

    static func allExercises() -> [Exercise] {
        [
            // MARK: Running (8)
            make(index: 1, name: "Outdoor Easy Run", description: "Conversational pace outdoor run.", activity: .run, metric: .distance, equipment: .outdoor, mets: 9.8),
            make(index: 2, name: "Outdoor Tempo Run", description: "Sustained threshold pace run.", activity: .run, metric: .distance, equipment: .outdoor, mets: 11.5, supportsIntervals: true),
            make(index: 3, name: "Outdoor Interval Run", description: "Repeating hard/easy run intervals.", activity: .run, metric: .distance, equipment: .outdoor, mets: 12.0),
            make(index: 4, name: "Treadmill Run", description: "Indoor treadmill running.", activity: .run, metric: .distance, equipment: .treadmill, mets: 10.0),
            make(index: 5, name: "Treadmill Incline Walk", description: "Incline walking on treadmill.", activity: .run, metric: .time, equipment: .treadmill, mets: 6.5, supportsIntervals: false),
            make(index: 6, name: "Trail Run", description: "Uneven terrain trail running.", activity: .run, metric: .distance, equipment: .outdoor, mets: 10.5),
            make(index: 7, name: "Track Intervals", description: "Track-based speed intervals.", activity: .run, metric: .distance, equipment: .outdoor, mets: 12.5),
            make(index: 8, name: "5K Time Trial", description: "All-out 5 kilometer effort.", activity: .run, metric: .distance, equipment: .outdoor, mets: 11.0, supportsIntervals: false),

            // MARK: Walking (6)
            make(index: 9, name: "Brisk Walk", description: "Moderate pace walking.", activity: .walk, metric: .steps, equipment: .outdoor, mets: 4.3, supportsIntervals: false),
            make(index: 10, name: "Treadmill Walk", description: "Flat treadmill walking.", activity: .walk, metric: .time, equipment: .treadmill, mets: 3.8, supportsIntervals: false),
            make(index: 11, name: "Hiking", description: "Outdoor hiking with elevation.", activity: .walk, metric: .distance, equipment: .outdoor, mets: 6.0),
            make(index: 12, name: "Rucking", description: "Weighted pack walking.", activity: .walk, metric: .distance, equipment: .outdoor, mets: 7.0),
            make(index: 13, name: "Incline Treadmill Walk", description: "Steady incline walking.", activity: .walk, metric: .time, equipment: .treadmill, mets: 5.5, supportsIntervals: false),
            make(index: 14, name: "Recovery Walk", description: "Easy cooldown walking.", activity: .walk, metric: .time, equipment: .outdoor, mets: 3.0, supportsIntervals: false),

            // MARK: Cycling (7)
            make(index: 15, name: "Outdoor Cycling", description: "Road or path cycling outdoors.", activity: .cycle, metric: .distance, equipment: .outdoor, mets: 8.0),
            make(index: 16, name: "Indoor Cycling", description: "Stationary bike steady ride.", activity: .cycle, metric: .time, equipment: .bike, mets: 7.5),
            make(index: 17, name: "Spin Class", description: "Instructor-led indoor cycling.", activity: .cycle, metric: .time, equipment: .bike, mets: 9.0),
            make(index: 18, name: "Assault Bike", description: "Air bike intervals or steady work.", activity: .cycle, metric: .calories, equipment: .machine, mets: 12.0),
            make(index: 19, name: "Bike Intervals", description: "Hard/easy cycling repeats.", activity: .cycle, metric: .time, equipment: .bike, mets: 10.5),
            make(index: 20, name: "Zone 2 Bike", description: "Low-intensity aerobic cycling.", activity: .cycle, metric: .time, equipment: .bike, mets: 6.5, supportsIntervals: false),
            make(index: 21, name: "Mountain Biking", description: "Off-road cycling.", activity: .cycle, metric: .distance, equipment: .outdoor, mets: 9.5),

            // MARK: Rowing (6)
            make(index: 22, name: "Rowing Machine Steady", description: "Continuous erg rowing.", activity: .row, metric: .distance, equipment: .rower, mets: 9.0),
            make(index: 23, name: "Rowing 2K Test", description: "2000m row time trial.", activity: .row, metric: .distance, equipment: .rower, mets: 10.5, supportsIntervals: false),
            make(index: 24, name: "Rowing Intervals", description: "Work/rest erg intervals.", activity: .row, metric: .distance, equipment: .rower, mets: 11.0),
            make(index: 25, name: "Ski Erg", description: "Ski ergometer conditioning.", activity: .row, metric: .distance, equipment: .machine, mets: 10.0),
            make(index: 26, name: "Rowing Sprint Sets", description: "Short max-effort erg sprints.", activity: .row, metric: .strokes, equipment: .rower, mets: 12.0),
            make(index: 27, name: "Rowing Cooldown", description: "Easy pace rowing flush.", activity: .row, metric: .time, equipment: .rower, mets: 5.0, supportsIntervals: false),

            // MARK: Swimming (5)
            make(index: 28, name: "Pool Swim", description: "Lap swimming in a pool.", activity: .swim, metric: .laps, equipment: .pool, mets: 8.5),
            make(index: 29, name: "Open Water Swim", description: "Swimming in open water.", activity: .swim, metric: .distance, equipment: .outdoor, mets: 9.0),
            make(index: 30, name: "Swim Intervals", description: "Repeat swim intervals with rest.", activity: .swim, metric: .laps, equipment: .pool, mets: 10.0),
            make(index: 31, name: "Kickboard Sets", description: "Kick-focused pool work.", activity: .swim, metric: .laps, equipment: .pool, mets: 7.0),
            make(index: 32, name: "Swim Technique Drills", description: "Low-intensity drill swimming.", activity: .swim, metric: .time, equipment: .pool, mets: 6.0, supportsIntervals: false),

            // MARK: Elliptical (4)
            make(index: 33, name: "Elliptical", description: "Elliptical trainer steady session.", activity: .elliptical, metric: .time, equipment: .machine, mets: 7.0),
            make(index: 34, name: "Cross Trainer", description: "Cross-trainer machine work.", activity: .elliptical, metric: .time, equipment: .machine, mets: 7.5),
            make(index: 35, name: "Elliptical Intervals", description: "Resistance/speed intervals.", activity: .elliptical, metric: .time, equipment: .machine, mets: 9.0),
            make(index: 36, name: "Elliptical HIIT", description: "High-intensity elliptical bursts.", activity: .elliptical, metric: .calories, equipment: .machine, mets: 10.0),

            // MARK: Stair climber (4)
            make(index: 37, name: "Stair Climber", description: "Stepmill or stair machine.", activity: .stairClimber, metric: .time, equipment: .machine, mets: 9.0),
            make(index: 38, name: "Stair Intervals", description: "Hard/easy stair intervals.", activity: .stairClimber, metric: .time, equipment: .machine, mets: 10.5),
            make(index: 39, name: "Stadium Stairs", description: "Outdoor stadium step repeats.", activity: .stairClimber, metric: .time, equipment: .outdoor, mets: 11.0),
            make(index: 40, name: "StepMill Endurance", description: "Long steady stair climbing.", activity: .stairClimber, metric: .time, equipment: .machine, mets: 8.0, supportsIntervals: false),

            // MARK: Jump rope (4)
            make(index: 41, name: "Jump Rope", description: "Continuous jump rope.", activity: .jumpRope, metric: .time, equipment: .none, mets: 11.0),
            make(index: 42, name: "Jump Rope Intervals", description: "Timed jump rope intervals.", activity: .jumpRope, metric: .time, equipment: .none, mets: 12.0),
            make(index: 43, name: "Double Under Practice", description: "Skill work for double unders.", activity: .jumpRope, metric: .time, equipment: .none, mets: 10.0),
            make(index: 44, name: "Jump Rope Finisher", description: "Short high-intensity rope finisher.", activity: .jumpRope, metric: .calories, equipment: .none, mets: 12.5),

            // MARK: HIIT / circuits (8)
            make(index: 45, name: "Battle Ropes", description: "Wave intervals with battle ropes.", activity: .hiit, metric: .time, equipment: .none, mets: 11.5),
            make(index: 46, name: "Burpee Circuit", description: "Bodyweight burpee conditioning.", activity: .hiit, metric: .time, equipment: .none, mets: 12.0),
            make(index: 47, name: "Tabata Cardio", description: "20s on / 10s off intervals.", activity: .hiit, metric: .time, equipment: .none, mets: 13.0),
            make(index: 48, name: "Cardio Circuit", description: "Mixed-modality cardio circuit.", activity: .hiit, metric: .time, equipment: .none, mets: 10.0),
            make(index: 49, name: "Sled Push Conditioning", description: "Sled push intervals.", activity: .hiit, metric: .distance, equipment: .outdoor, mets: 11.0),
            make(index: 50, name: "Kettlebell Conditioning", description: "Swing and carry conditioning.", activity: .hiit, metric: .time, equipment: .none, mets: 10.5),
            make(index: 51, name: "AMRAP Cardio", description: "As-many-rounds-as-possible cardio block.", activity: .hiit, metric: .time, equipment: .none, mets: 11.0),
            make(index: 52, name: "EMOM Cardio", description: "Every-minute-on-the-minute cardio.", activity: .hiit, metric: .time, equipment: .none, mets: 10.5),

            // MARK: Generic / misc (4)
            make(index: 53, name: "Cardio Warm-Up", description: "General warm-up cardio.", activity: .generic, metric: .time, equipment: .none, mets: 4.0, supportsIntervals: false),
            make(index: 54, name: "Cardio Cooldown", description: "Easy cooldown cardio.", activity: .generic, metric: .time, equipment: .none, mets: 3.5, supportsIntervals: false),
            make(index: 55, name: "Mixed Modal Cardio", description: "Unspecified mixed cardio.", activity: .generic, metric: .time, equipment: .none, mets: 8.0),
            make(index: 56, name: "Active Recovery", description: "Very easy recovery session.", activity: .generic, metric: .time, equipment: .none, mets: 3.0, supportsIntervals: false),

            // MARK: Hybrid examples (3)
            make(index: 57, name: "Run + Mobility", description: "Short run with mobility finisher.", activity: .run, metric: .distance, equipment: .outdoor, mets: 8.5, modality: .hybrid),
            make(index: 58, name: "Bike + Core", description: "Cycling with core circuit.", activity: .cycle, metric: .time, equipment: .bike, mets: 8.0, modality: .hybrid),
            make(index: 59, name: "Row + Strength Finisher", description: "Rowing with strength accessory work.", activity: .row, metric: .distance, equipment: .rower, mets: 9.5, modality: .hybrid),
        ]
    }

    private static func make(
        index: UInt16,
        name: String,
        description: String,
        activity: CardioActivityKind,
        metric: CardioPrimaryMetric,
        equipment: CardioEquipment,
        mets: Double?,
        supportsIntervals: Bool = true,
        modality: ExerciseModality = .cardio
    ) -> Exercise {
        let metadata = CardioExerciseMetadata(
            activityKind: activity,
            primaryMetric: metric,
            equipment: equipment,
            estimatedMETs: mets,
            supportsIntervals: supportsIntervals,
            hkActivityTypeRaw: activity.rawValue
        )
        return Exercise(
            id: id(index),
            name: name,
            description: description,
            targetedMuscles: [.other],
            isCustom: false,
            configurationOptions: [],
            exerciseRole: .accessory,
            movementPattern: nil,
            modality: modality,
            cardioMetadata: metadata
        )
    }
}
