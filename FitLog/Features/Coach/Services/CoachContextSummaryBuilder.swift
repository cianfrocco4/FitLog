//
//  CoachContextSummaryBuilder.swift
//  FitLog
//
//  Builds a user-visible summary of what the Coach can see in its data snapshot.
//

import Foundation

@MainActor
enum CoachContextSummaryBuilder {
    static func build(dataVM: DataManager, maxCharacters: Int = 14_000) -> CoachContextSummary {
        let cal = Calendar.current
        let engine = TrainingScheduleEngine(calendar: cal)
        let resolved = engine.resolve(date: Date(), program: dataVM.trainingProgram)

        let todayPlan: String = {
            switch resolved {
            case .rest: return "Rest day"
            case .unscheduled: return "No workout scheduled"
            case .workout(let ref): return dataVM.planLabel(for: ref)
            }
        }()

        let programSummary: String = {
            if dataVM.trainingProgram.cycleEntries.isEmpty {
                return "No split cycle configured"
            }
            let names = dataVM.trainingProgram.cycleEntries.map { dataVM.planLabel(for: $0) }
            return "\(dataVM.trainingProgram.sessionsPerWeek) sessions/week · \(names.joined(separator: " → "))"
        }()

        let recentCount = min(12, dataVM.completedSessions.filter(\.isCompleted).count)
        let fullSnapshot = dataVM.coachDataContextSnapshot(maxCharacters: maxCharacters)
        let wasTruncated = fullSnapshot.contains("… (snapshot truncated)")

        return CoachContextSummary(
            todayPlan: todayPlan,
            programSummary: programSummary,
            workoutCount: dataVM.userWorkouts.count,
            recentSessionCount: recentCount,
            sessionsThisWeek: dataVM.workoutsThisWeek,
            wasTruncated: wasTruncated
        )
    }
}
