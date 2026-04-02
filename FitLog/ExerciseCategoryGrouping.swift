//
//  ExerciseCategoryGrouping.swift
//  FitLog
//

import Foundation

extension MuscleGroup {
    /// Broad bucket for library / exercise picker (Push, Pull, Legs, Core, Other).
    var exerciseBucket: String {
        switch self {
        case .chest, .upperChest, .lowerChest, .frontDelts, .sideDelts, .rearDelts, .triceps: return "Push"
        case .lats, .upperBack, .midBack, .rhomboids, .traps, .biceps: return "Pull"
        case .quads, .hamstrings, .glutes, .calves, .soleus, .hipFlexors, .adductors, .abductors: return "Legs"
        case .abs, .lowerAbs, .obliques, .core: return "Core"
        default: return "Other"
        }
    }
}

enum ExerciseCategoryGrouping {
    static let bucketOrder = ["Push", "Pull", "Legs", "Core", "Other"]

    /// Subgrouped: (bucketName, [(muscle, [Exercise])]) in bucket order.
    static func bucketedSections(
        exercises: [Exercise],
        displayName: (Exercise) -> String
    ) -> [(String, [(MuscleGroup, [Exercise])])] {
        let grouped = Dictionary(grouping: exercises) { ex in
            ex.targetedMuscles.first ?? .other
        }
        var result: [(String, [(MuscleGroup, [Exercise])])] = []
        for bucket in bucketOrder {
            let musclesInBucket = MuscleGroup.displayOrder.filter { $0.exerciseBucket == bucket }
            let pairs = musclesInBucket.compactMap { muscle -> (MuscleGroup, [Exercise])? in
                let list = (grouped[muscle] ?? []).sorted {
                    displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending
                }
                return list.isEmpty ? nil : (muscle, list)
            }
            if !pairs.isEmpty { result.append((bucket, pairs)) }
        }
        return result
    }
}
