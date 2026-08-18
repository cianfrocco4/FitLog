//
//  FitLogSimulatedUserReviewer.swift
//  FitLog
//
//  Turns a persona's real SwiftData store into likes, dislikes, bugs, and improvements.
//  Launch with `-fitlog-ui-write-review` (typically after a daily living tick).
//

import Foundation

enum FitLogSimulatedUserReviewer {

    /// Build a report from the current store and optionally append it to Documents JSONL.
    @discardableResult
    @MainActor
    static func run(
        _ persona: FitLogSimulatedUserPersona,
        into dataVM: DataManager,
        tickOutcome: FitLogSimulatedUserLivingDay.Outcome?,
        now: Date = Date(),
        calendar: Calendar = .current,
        isAIConfigured: Bool = OpenAIConfig.isConfigured,
        writeFiles: Bool = true
    ) -> FitLogSimulatedUserReview {
        let review = makeReview(
            persona,
            dataVM: dataVM,
            tickOutcome: tickOutcome,
            now: now,
            calendar: calendar,
            isAIConfigured: isAIConfigured
        )
        if writeFiles {
            write(review)
        }
        return review
    }

    @MainActor
    static func makeReview(
        _ persona: FitLogSimulatedUserPersona,
        dataVM: DataManager,
        tickOutcome: FitLogSimulatedUserLivingDay.Outcome?,
        now: Date = Date(),
        calendar: Calendar = .current,
        isAIConfigured: Bool = OpenAIConfig.isConfigured
    ) -> FitLogSimulatedUserReview {
        let dayKey = TrainingProgramState.dayKey(for: now, calendar: calendar)
        let sessions = dataVM.completedSessions
        let last = sessions.max {
            ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime)
        }
        let oldestEnd = sessions.compactMap(\.endTime).min()
        let oldestDays: Int? = oldestEnd.map { end in
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: end),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
        }
        let cardioSessionCount = sessions.filter { $0.workout.workoutKind == .cardio }.count
        let todayPlanned = dataVM.trainingProgram.dayOverrides[dayKey]?.intent == .workout

        var likes: [FitLogSimulatedUserReviewNote] = []
        var dislikes: [FitLogSimulatedUserReviewNote] = []
        var bugs: [FitLogSimulatedUserReviewNote] = []
        var improvements: [FitLogSimulatedUserReviewNote] = []

        if dataVM.userWorkouts.contains(where: { $0.name.localizedCaseInsensitiveContains("Push A") }) {
            likes.append(
                note(
                    "like.library.templates",
                    area: "Home",
                    detail: "I like that a template like Push A becomes a real saved workout I can start again without rebuilding it."
                )
            )
        }
        if !dataVM.userWorkouts.isEmpty, persona != .newFree || sessions.count > 0 {
            likes.append(
                note(
                    "like.home.start_recent",
                    area: "Home",
                    detail: "Once I have a library, starting from a saved workout is faster than creating one from scratch every session."
                )
            )
        }
        if tickOutcome == .logged, last != nil {
            likes.append(
                note(
                    "like.history.logged",
                    area: "History",
                    detail: "Today's workout showed up in History as soon as it was saved. That loop (log → History) feels complete."
                )
            )
        }
        if tickOutcome == .restDay {
            likes.append(
                note(
                    "like.rest.no_nag",
                    area: "Workflow",
                    detail: "Rest days stay quiet — the app didn't invent a workout or duplicate yesterday just because I opened it."
                )
            )
        }
        if tickOutcome == .alreadyLoggedToday {
            likes.append(
                note(
                    "like.idempotent.no_duplicate",
                    area: "Workflow",
                    detail: "Re-opening the app today didn't log a second copy of the same session."
                )
            )
            improvements.append(
                note(
                    "improve.home.already_trained",
                    area: "Home",
                    detail: "Home could say more clearly that I already trained today, instead of looking like I still need to start something."
                )
            )
        }
        if persona.isPremium, !sessions.isEmpty {
            likes.append(
                note(
                    "like.history.unlimited",
                    area: "History",
                    detail: "As a Premium user I expect History not to stop at 14 days. Older sessions should stay on the default charts."
                )
            )
        }
        if dataVM.userWorkouts.contains(where: { $0.workoutKind == .cardio }) {
            likes.append(
                note(
                    "like.cardio.library",
                    area: "Home",
                    detail: "I like having a Zone 2 (or other cardio) workout sitting in the library next to strength days."
                )
            )
        }
        if todayPlanned {
            likes.append(
                note(
                    "like.plan.today",
                    area: "Plan",
                    detail: "Today is assigned on the Plan calendar, so I don't have to pick a workout from a blank Home."
                )
            )
        }

        if !persona.isPremium, (oldestDays ?? 0) > 14 {
            dislikes.append(
                note(
                    "dislike.history.14_day_cap",
                    area: "History",
                    detail: "I still have sessions older than 14 days, but free History clamps to 14. Those older days vanish from the default range unless I pay."
                )
            )
            improvements.append(
                note(
                    "improve.history.free_peek",
                    area: "History",
                    detail: "Let free users open an older session from a list even if charts stay locked at 14 days — I know the workout happened."
                )
            )
        }
        if !persona.isPremium {
            dislikes.append(
                note(
                    "dislike.coach.premium_gate",
                    area: "Coach",
                    detail: "Coach is a tab I can open, then it stops me. I'd rather see a short local tip than a paywall as the first thing in that tab."
                )
            )
            dislikes.append(
                note(
                    "dislike.more.subscription_buried",
                    area: "More",
                    detail: "Subscription status lives under More. After hitting a Premium gate I have to remember which tab holds the upgrade."
                )
            )
        }
        if persona.isPremium, !isAIConfigured {
            dislikes.append(
                note(
                    "dislike.coach.ai_unconfigured",
                    area: "Coach",
                    detail: "I have Premium, but Coach still says AI isn't configured. Paying didn't make the chat usable."
                )
            )
        }
        if persona == .newFree, dataVM.userWorkouts.count <= 1 {
            dislikes.append(
                note(
                    "dislike.home.few_templates",
                    area: "Home",
                    detail: "After the first template, Home doesn't push me toward a second workout (Pull/Legs). Easy to stall on a single Push A."
                )
            )
            improvements.append(
                note(
                    "improve.home.empty_vs_template",
                    area: "Home",
                    detail: "Empty Home should spell out New workout vs From template in one line. I almost didn't know templates existed."
                )
            )
        }
        if persona == .cardioHobbyist, !persona.isPremium {
            dislikes.append(
                note(
                    "dislike.cardio.no_trends",
                    area: "History",
                    detail: "Cardio days pile up, but longer trends and readiness charts sit behind Premium. Volume over weeks is what I actually care about."
                )
            )
            improvements.append(
                note(
                    "improve.cardio.home_duration",
                    area: "Home",
                    detail: "Show last Zone 2 duration on Home so I don't have to open History to see yesterday's minutes."
                )
            )
        }
        if persona.isPremium, !sessions.isEmpty {
            improvements.append(
                note(
                    "improve.home.last_weight",
                    area: "Home",
                    detail: "Surface last working weight on the Home workout row. I shouldn't dig into History to know where I left off."
                )
            )
        }
        if persona == .planFollower, todayPlanned {
            improvements.append(
                note(
                    "improve.plan.checkmark",
                    area: "Plan",
                    detail: "After I log the planned workout, the calendar should check off today more obviously so the week looks done."
                )
            )
        }
        if sessions.count >= 3 {
            improvements.append(
                note(
                    "improve.history.quick_log",
                    area: "History",
                    detail: "Quick-log from the widget is useful; repeating yesterday from History would save a round trip through Home."
                )
            )
        }

        if tickOutcome == .skippedEmptyLibrary || (persona.isTrainingDay(on: now, calendar: calendar) && dataVM.userWorkouts.isEmpty) {
            bugs.append(
                note(
                    "bug.library.empty_on_training_day",
                    area: "Home",
                    detail: "It's a training day and my library is empty, so nothing logged. Bootstrap or templates failed silently."
                )
            )
        }
        if persona == .planFollower, persona.isTrainingDay(on: now, calendar: calendar), !todayPlanned, !dataVM.userWorkouts.isEmpty {
            bugs.append(
                note(
                    "bug.plan.missing_today",
                    area: "Plan",
                    detail: "I'm a plan follower on a training day, but today has no workout assignment on the calendar."
                )
            )
        }
        if persona == .cardioHobbyist, !dataVM.userWorkouts.contains(where: { $0.workoutKind == .cardio }) {
            bugs.append(
                note(
                    "bug.cardio.missing_library",
                    area: "Home",
                    detail: "Cardio hobbyist with no cardio workout in the library."
                )
            )
        } else if persona == .cardioHobbyist, cardioSessionCount == 0, !sessions.isEmpty {
            bugs.append(
                note(
                    "bug.cardio.no_cardio_sessions",
                    area: "History",
                    detail: "I have completed sessions but none of them are cardio, even though that's how I train."
                )
            )
        } else if persona == .cardioHobbyist, cardioSessionCount == 0, tickOutcome == .logged {
            bugs.append(
                note(
                    "bug.cardio.no_cardio_sessions",
                    area: "History",
                    detail: "Today logged as a training day but History still has no cardio session."
                )
            )
        }

        let workflow = workflowSummary(
            persona: persona,
            tickOutcome: tickOutcome,
            sessionCount: sessions.count,
            lastName: last?.workout.name,
            isTrainingDay: persona.isTrainingDay(on: now, calendar: calendar)
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return FitLogSimulatedUserReview(
            persona: persona.rawValue,
            displayName: persona.displayName,
            dayKey: dayKey,
            generatedAt: formatter.string(from: now),
            isPremium: persona.isPremium,
            isTrainingDay: persona.isTrainingDay(on: now, calendar: calendar),
            tickOutcome: tickOutcome?.rawValue,
            sessionCount: sessions.count,
            libraryCount: dataVM.userWorkouts.count,
            lastWorkoutName: last?.workout.name,
            oldestSessionDaysAgo: oldestDays,
            likes: likes,
            dislikes: dislikes,
            bugs: bugs,
            improvements: improvements,
            workflow: workflow
        )
    }

    static func reviewsLogURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appending(path: "fitlog-living-reviews.jsonl")
    }

    static func latestMarkdownURL(
        persona: FitLogSimulatedUserPersona,
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appending(path: "fitlog-living-review-\(persona.rawValue).md")
    }

    private static func note(_ id: String, area: String, detail: String) -> FitLogSimulatedUserReviewNote {
        FitLogSimulatedUserReviewNote(id: id, area: area, detail: detail)
    }

    private static func workflowSummary(
        persona: FitLogSimulatedUserPersona,
        tickOutcome: FitLogSimulatedUserLivingDay.Outcome?,
        sessionCount: Int,
        lastName: String?,
        isTrainingDay: Bool
    ) -> String {
        let outcomeText = switch tickOutcome {
        case .logged:
            "Logged \(lastName ?? "a workout") today."
        case .alreadyLoggedToday:
            "Opened the app; today's session was already there."
        case .restDay:
            "Rest day — no new session."
        case .skippedEmptyLibrary:
            "Wanted to train but the library was empty."
        case nil:
            "Opened the app without a living-day tick."
        }
        return "\(persona.displayName): \(outcomeText) History now has \(sessionCount) completed session(s). Training day: \(isTrainingDay ? "yes" : "no")."
    }

    private static func write(_ review: FitLogSimulatedUserReview) {
        guard let jsonURL = reviewsLogURL(),
              let data = try? JSONEncoder().encode(review),
              var line = String(data: data, encoding: .utf8)
        else { return }
        line.append("\n")
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            guard let handle = try? FileHandle(forWritingTo: jsonURL) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: jsonURL, atomically: true, encoding: .utf8)
        }
        if let persona = FitLogSimulatedUserPersona(rawValue: review.persona),
           let mdURL = latestMarkdownURL(persona: persona) {
            try? review.markdown().write(to: mdURL, atomically: true, encoding: .utf8)
        }
    }
}
