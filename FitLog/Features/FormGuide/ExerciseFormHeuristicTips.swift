//
//  ExerciseFormHeuristicTips.swift
//  FitLog
//
//  Offline fallback form tips when AI / MuscleWiki content is unavailable.
//

import Foundation

enum ExerciseFormHeuristicTips {
    static func tips(for exercise: Exercise) -> [String] {
        let name = exercise.name.lowercased()
        let muscles = exercise.targetedMuscles

        if name.contains("squat") {
            return [
                "Keep your chest up and ribs stacked over your hips throughout the movement.",
                "Push your knees in line with your toes and sit between your hips, not forward into your knees.",
                "Maintain a braced core and neutral spine; think \"big breath, then squat\".",
                "Drive up by pushing the floor away and leading with your hips and chest together."
            ]
        } else if (name.contains("bench") || name.contains("press")) && muscles.contains(.chest) {
            return [
                "Keep your shoulder blades retracted and pinned to the bench for a stable base.",
                "Lower the bar under control to around lower chest / nipple line, with elbows ~45° from your torso.",
                "Plant your feet firmly and use leg drive without lifting your hips off the bench.",
                "Pause briefly on the chest (or keep the bar under control) before pressing back up in a slight arc."
            ]
        } else if name.contains("deadlift") {
            return [
                "Set up with the bar over mid-foot, shins close but not pushed far forward.",
                "Brace your core, flatten your back, and pull the slack out of the bar before initiating the lift.",
                "Push the floor away and keep the bar close to your body the entire time.",
                "Lock out by driving your hips through and standing tall, not by leaning back."
            ]
        } else if name.contains("row") {
            return [
                "Keep your torso stable and avoid excessive swinging; pull with your back, not momentum.",
                "Lead with your elbows, aiming them toward your hips rather than straight back.",
                "Squeeze your shoulder blades together at the top and control the negative.",
                "Keep your neck neutral and avoid shrugging your shoulders toward your ears."
            ]
        } else if name.contains("curl") {
            return [
                "Keep your elbows close to your sides and avoid swinging your upper arms.",
                "Control the eccentric; take 2–3 seconds to lower the weight.",
                "Squeeze at the top without letting your wrists collapse backward.",
                "Use a full range of motion without letting your shoulders roll forward."
            ]
        } else if muscles.contains(.quads) && name.contains("leg press") {
            return [
                "Place your feet so your knees track in line with your toes and don’t collapse inward.",
                "Lower the sled until your thighs are at least parallel without your lower back lifting off the pad.",
                "Keep constant tension; avoid locking out your knees hard at the top.",
                "Grip the handles and keep your hips and low back glued to the seat."
            ]
        }

        return [
            "Use a controlled tempo and full range of motion appropriate for the joint.",
            "Keep your core lightly braced and avoid painful joint positions.",
            "Start with a lighter weight to groove technique before pushing close to failure.",
            "Stop a set if form breaks down rather than forcing sloppy reps."
        ]
    }
}
