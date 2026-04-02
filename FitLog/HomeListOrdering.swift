//
//  HomeListOrdering.swift
//  FitLog
//

import Foundation

/// Derives plan references and display ordering for Home / Library without mutating stored workout bodies.
enum HomeListOrdering {

    /// IDs of concrete workouts that appear in the training **rotation** (`cycleEntries` only).
    /// Calendar overrides are excluded so “in split” matches what the user set on the Plan tab rotation.
    static func splitConcreteWorkoutIds(from program: TrainingProgramState) -> Set<UUID> {
        concreteWorkoutIds(in: Set(program.cycleEntries))
    }

    /// Template IDs in the rotation only.
    static func splitTemplateIds(from program: TrainingProgramState) -> Set<UUID> {
        slotTemplateIds(in: Set(program.cycleEntries))
    }

    /// Concrete workouts that exist in `userWorkouts`, ordered by first appearance in `cycleEntries` (deduped).
    static func workoutsInSplitDisplayOrder(_ workouts: [Workout], program: TrainingProgramState) -> [Workout] {
        let byId = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var result: [Workout] = []
        for ref in program.cycleEntries {
            guard case .concreteWorkout(let id) = ref else { continue }
            guard !seen.contains(id), let w = byId[id] else { continue }
            seen.insert(id)
            result.append(w)
        }
        return result
    }

    /// Templates in rotation order (deduped).
    static func templatesInSplitDisplayOrder(_ templates: [WorkoutTemplate], program: TrainingProgramState) -> [WorkoutTemplate] {
        let byId = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var result: [WorkoutTemplate] = []
        for ref in program.cycleEntries {
            guard case .slotTemplate(let id) = ref else { continue }
            guard !seen.contains(id), let t = byId[id] else { continue }
            seen.insert(id)
            result.append(t)
        }
        return result
    }

    static func collectPlanRefs(from program: TrainingProgramState) -> Set<WorkoutPlanRef> {
        var refs = Set(program.cycleEntries)
        for override in program.dayOverrides.values where override.intent == .workout {
            if let r = override.planRef { refs.insert(r) }
        }
        for week in program.weekOverrides.values {
            for override in week.weekdayOverrides.values where override.intent == .workout {
                if let r = override.planRef { refs.insert(r) }
            }
        }
        return refs
    }

    static func concreteWorkoutIds(in refs: Set<WorkoutPlanRef>) -> Set<UUID> {
        Set(refs.compactMap { ref -> UUID? in
            if case .concreteWorkout(let id) = ref { return id }
            return nil
        })
    }

    static func slotTemplateIds(in refs: Set<WorkoutPlanRef>) -> Set<UUID> {
        Set(refs.compactMap { ref -> UUID? in
            if case .slotTemplate(let id) = ref { return id }
            return nil
        })
    }

    /// Latest session end time per saved workout id (concrete definition id).
    static func lastSessionEndByWorkoutId(sessions: [WorkoutSession]) -> [UUID: Date] {
        var map: [UUID: Date] = [:]
        for s in sessions {
            guard let end = s.endTime else { continue }
            let id = s.workout.id
            if let prev = map[id] {
                if end > prev { map[id] = end }
            } else {
                map[id] = end
            }
        }
        return map
    }

    /// Latest completed session end per slot template (from session plan origin).
    static func lastSessionEndByTemplateId(sessions: [WorkoutSession]) -> [UUID: Date] {
        var map: [UUID: Date] = [:]
        for s in sessions {
            guard let end = s.endTime else { continue }
            guard case .slotTemplate(let tid)? = s.sessionPlanOrigin else { continue }
            if let prev = map[tid] {
                if end > prev { map[tid] = end }
            } else {
                map[tid] = end
            }
        }
        return map
    }

    static func orderWorkouts(
        _ workouts: [Workout],
        program: TrainingProgramState,
        sessions: [WorkoutSession]
    ) -> [Workout] {
        let inPlan = splitConcreteWorkoutIds(from: program)
        let lastUse = lastSessionEndByWorkoutId(sessions: sessions)
        let pinned = workouts.filter(\.isPinned)
        let unpinned = workouts.filter { !$0.isPinned }
        let sortedUnpinned = unpinned.sorted { a, b in
            let aPlan = inPlan.contains(a.id)
            let bPlan = inPlan.contains(b.id)
            if aPlan != bPlan { return aPlan && !bPlan }
            let ad = lastUse[a.id] ?? .distantPast
            let bd = lastUse[b.id] ?? .distantPast
            if ad != bd { return ad > bd }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return pinned + sortedUnpinned
    }

    static func orderTemplates(
        _ templates: [WorkoutTemplate],
        program: TrainingProgramState,
        sessions: [WorkoutSession]
    ) -> [WorkoutTemplate] {
        let inPlan = splitTemplateIds(from: program)
        let lastUse = lastSessionEndByTemplateId(sessions: sessions)
        let pinned = templates.filter(\.isPinned)
        let unpinned = templates.filter { !$0.isPinned }
        let sortedUnpinned = unpinned.sorted { a, b in
            let aPlan = inPlan.contains(a.id)
            let bPlan = inPlan.contains(b.id)
            if aPlan != bPlan { return aPlan && !bPlan }
            let ad = lastUse[a.id] ?? .distantPast
            let bd = lastUse[b.id] ?? .distantPast
            if ad != bd { return ad > bd }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return pinned + sortedUnpinned
    }
}
