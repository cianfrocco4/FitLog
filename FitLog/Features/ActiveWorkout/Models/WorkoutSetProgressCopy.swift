//
//  WorkoutSetProgressCopy.swift
//  FitLog
//
//  Strings for set progress during an active workout.
//

import Foundation

/// "2/4" always means work sets. Warm-ups get their own marker so earlier sets
/// never look lost after they stop counting toward the target.
enum WorkoutSetProgressCopy {
    static func warmupMarker(count: Int) -> String {
        guard count > 0 else { return "" }
        return count == 1 ? "+1 warm-up" : "+\(count) warm-ups"
    }

    static func workSetProgressLabel(done: Int, target: Int, warmups: Int) -> String {
        var label = target > 0 ? "\(done) of \(target) work sets" : "\(done) work sets"
        if warmups > 0 {
            label += warmups == 1 ? ", plus 1 warm-up set" : ", plus \(warmups) warm-up sets"
        }
        return label
    }
}
