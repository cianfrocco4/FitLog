//
//  WorkoutCompletionSummary.swift
//  FitLog
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Summary model

struct WorkoutCompletionExerciseLine: Equatable, Identifiable {
    let id: UUID
    let exerciseName: String
    let workingSetCount: Int
    let volumePounds: Double
    /// Sets in this session where at least one new PR was detected for that set.
    let newPRSetCount: Int
    /// Non-nil for cardio rows (duration/distance summary instead of volume).
    let cardioSummary: String?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        workingSetCount: Int,
        volumePounds: Double,
        newPRSetCount: Int,
        cardioSummary: String? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.workingSetCount = workingSetCount
        self.volumePounds = volumePounds
        self.newPRSetCount = newPRSetCount
        self.cardioSummary = cardioSummary
    }
}

struct WorkoutCompletionSummary: Equatable, Identifiable {
    let id: UUID
    let workoutName: String
    let durationSeconds: Int
    let totalSets: Int
    let totalVolumePounds: Double
    let exercisesWithSets: Int
    let totalResolvedExercises: Int
    let personalRecordCount: Int
    /// Ordered like the workout; excludes empty and slot placeholders.
    let exerciseBreakdown: [WorkoutCompletionExerciseLine]
    /// Human-readable PR lines for this session (deduped by exercise + PR kind).
    let personalRecordHighlights: [String]
    let totalCardioDurationSeconds: Int
    let totalCardioDistanceMeters: Double
    let cardioSegmentCount: Int

    var durationFormatted: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        let s = durationSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    func shareLines(displayUnit: WeightDisplayUnit) -> String {
        let vol = WeightStoreConversion.displayValue(storedPounds: totalVolumePounds, unit: displayUnit)
        let unit = displayUnit.shortLabel
        var lines: [String] = [
            "\(AppBrand.name) — \(workoutName)",
            "Duration: \(durationFormatted)",
            "Working sets: \(totalSets)",
            "Volume: \(String(format: "%.0f", vol)) \(unit)",
            "Exercises: \(exercisesWithSets)/\(totalResolvedExercises)"
        ]
        if personalRecordCount > 0 {
            lines.append("Personal records (sets): \(personalRecordCount)")
        }
        if !personalRecordHighlights.isEmpty {
            lines.append("")
            lines.append("PR highlights:")
            for h in personalRecordHighlights.prefix(12) {
                lines.append("• \(h)")
            }
        }
        if !exerciseBreakdown.isEmpty {
            lines.append("")
            lines.append("By exercise:")
            for row in exerciseBreakdown {
                var part = "• \(row.exerciseName)"
                if let cardio = row.cardioSummary {
                    part += " — \(cardio)"
                } else {
                    let v = WeightStoreConversion.displayValue(storedPounds: row.volumePounds, unit: displayUnit)
                    let volStr = v == floor(v) ? "\(Int(v))" : String(format: "%.1f", v)
                    part += " — \(row.workingSetCount) sets · \(volStr) \(unit)"
                }
                if row.newPRSetCount > 0 {
                    part += " · \(row.newPRSetCount) PR set\(row.newPRSetCount == 1 ? "" : "s")"
                }
                lines.append(part)
            }
        }
        if cardioSegmentCount > 0 {
            lines.append("")
            lines.append(
                "Cardio: \(CardioMetricsCalculator.formatDuration(seconds: totalCardioDurationSeconds)) · \(CardioMetricsCalculator.formatDistance(meters: totalCardioDistanceMeters))"
            )
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Build summary

extension DataManager {
    /// Count PR-worthy events for sets in this session vs all prior history (completed sessions only).
    func countNewPersonalRecords(in session: WorkoutSession) -> Int {
        let priorSessions = completedSessions.filter { $0.id != session.id }
        var count = 0
        for log in session.exerciseLogs {
            guard let exId = log.workoutExercise.exerciseId else { continue }
            let name = displayName(for: log.workoutExercise)
            let priorFromHistory: [LoggedSet] = priorSessions
                .flatMap(\.exerciseLogs)
                .filter { $0.workoutExercise.exerciseId == exId }
                .flatMap(\.loggedSets)
            var priorAccumulated: [LoggedSet] = priorFromHistory
            let sortedSets = log.loggedSets.sorted { $0.timestamp < $1.timestamp }
            for set in sortedSets {
                let events = PersonalRecordDetector.detect(
                    newSet: set,
                    priorSets: priorAccumulated,
                    exerciseId: exId,
                    exerciseName: name,
                    timestamp: set.timestamp
                )
                if !events.isEmpty { count += 1 }
                priorAccumulated.append(set)
            }
        }
        return count
    }

    private func priorSetsFromHistory(exerciseId: UUID, excludingSessionId: UUID) -> [LoggedSet] {
        completedSessions
            .filter { $0.id != excludingSessionId }
            .flatMap(\.exerciseLogs)
            .filter { $0.workoutExercise.exerciseId == exerciseId }
            .flatMap(\.loggedSets)
    }

    /// Per-exercise stats and PR highlights for the completion card (session not yet in `completedSessions`).
    func buildWorkoutCompletionBreakdown(session: WorkoutSession) -> (
        lines: [WorkoutCompletionExerciseLine],
        highlights: [String]
    ) {
        var lines: [WorkoutCompletionExerciseLine] = []
        var highlights: [String] = []
        var seenHighlightKeys = Set<String>()

        for log in session.exerciseLogs {
            guard !log.workoutExercise.isSlotPlaceholder, !log.loggedSets.isEmpty else { continue }

            let name = displayName(for: log.workoutExercise)
            let workingSets = log.loggedSets.filter { $0.countsTowardVolumeTotals }
            let cardioSets = log.loggedSets.filter { $0.countsTowardCardioTotals }
            let volumeLb = workingSets.reduce(0.0) { $0 + max(0, $1.totalVolumeLoad) }

            if !cardioSets.isEmpty {
                let duration = cardioSets.compactMap(\.cardioMetrics?.durationSec).reduce(0, +)
                let distance = cardioSets.compactMap(\.cardioMetrics?.distanceM).reduce(0, +)
                var summaryParts: [String] = []
                if duration > 0 {
                    summaryParts.append(CardioMetricsCalculator.formatDuration(seconds: duration))
                }
                if distance > 0 {
                    summaryParts.append(CardioMetricsCalculator.formatDistance(meters: distance))
                }
                if !workingSets.isEmpty {
                    summaryParts.append("\(workingSets.count) strength sets")
                }

                var prSetCount = 0
                if let exId = log.workoutExercise.exerciseId {
                    var priorAccumulated = priorSetsFromHistory(exerciseId: exId, excludingSessionId: session.id)
                    let sortedSets = log.loggedSets.sorted { $0.timestamp < $1.timestamp }
                    for set in sortedSets {
                        let events = PersonalRecordDetector.detect(
                            newSet: set,
                            priorSets: priorAccumulated,
                            exerciseId: exId,
                            exerciseName: name,
                            timestamp: set.timestamp
                        )
                        if !events.isEmpty { prSetCount += 1 }
                        for ev in events {
                            let key = "\(ev.exerciseId.uuidString)|\(ev.kind.rawValue)"
                            if seenHighlightKeys.insert(key).inserted {
                                highlights.append("\(ev.exerciseName) — \(ev.title)")
                            }
                        }
                        priorAccumulated.append(set)
                    }
                }

                if workingSets.isEmpty {
                    lines.append(
                        WorkoutCompletionExerciseLine(
                            exerciseName: name,
                            workingSetCount: cardioSets.count,
                            volumePounds: 0,
                            newPRSetCount: prSetCount,
                            cardioSummary: summaryParts.isEmpty ? "\(cardioSets.count) segments" : summaryParts.joined(separator: " · ")
                        )
                    )
                    continue
                }

                lines.append(
                    WorkoutCompletionExerciseLine(
                        exerciseName: name,
                        workingSetCount: workingSets.count + cardioSets.count,
                        volumePounds: volumeLb,
                        newPRSetCount: prSetCount,
                        cardioSummary: summaryParts.isEmpty ? nil : summaryParts.joined(separator: " · ")
                    )
                )
                continue
            }

            guard let exId = log.workoutExercise.exerciseId else {
                lines.append(
                    WorkoutCompletionExerciseLine(
                        exerciseName: name,
                        workingSetCount: workingSets.count,
                        volumePounds: volumeLb,
                        newPRSetCount: 0
                    )
                )
                continue
            }

            var priorAccumulated = priorSetsFromHistory(exerciseId: exId, excludingSessionId: session.id)
            let sortedSets = log.loggedSets.sorted { $0.timestamp < $1.timestamp }
            var prSetCount = 0

            for set in sortedSets {
                let events = PersonalRecordDetector.detect(
                    newSet: set,
                    priorSets: priorAccumulated,
                    exerciseId: exId,
                    exerciseName: name,
                    timestamp: set.timestamp
                )
                if !events.isEmpty { prSetCount += 1 }
                for ev in events {
                    let key = "\(ev.exerciseId.uuidString)|\(ev.kind.rawValue)"
                    if seenHighlightKeys.insert(key).inserted {
                        highlights.append("\(ev.exerciseName) — \(ev.title)")
                    }
                }
                priorAccumulated.append(set)
            }

            lines.append(
                WorkoutCompletionExerciseLine(
                    exerciseName: name,
                    workingSetCount: workingSets.count,
                    volumePounds: volumeLb,
                    newPRSetCount: prSetCount
                )
            )
        }

        return (lines, Array(highlights.prefix(12)))
    }

    func buildWorkoutCompletionSummary(session: WorkoutSession, activeElapsedSeconds: Int? = nil) -> WorkoutCompletionSummary {
        let end = session.endTime ?? Date()
        let wallDuration = max(0, Int(end.timeIntervalSince(session.startTime)))
        let durationSeconds = max(0, activeElapsedSeconds ?? wallDuration)

        let resolvedLogs = session.exerciseLogs.filter { !$0.workoutExercise.isSlotPlaceholder }
        let totalResolved = resolvedLogs.count
        let withSets = resolvedLogs.filter { !$0.loggedSets.isEmpty }.count

        let workingSetsAll = session.exerciseLogs.flatMap(\.loggedSets).filter { $0.countsTowardVolumeTotals }
        let cardioSetsAll = session.exerciseLogs.flatMap(\.loggedSets).filter { $0.countsTowardCardioTotals }
        let totalSets = workingSetsAll.count
        let volume = workingSetsAll.reduce(0.0) { $0 + max(0, $1.totalVolumeLoad) }
        let cardioDuration = cardioSetsAll.compactMap(\.cardioMetrics?.durationSec).reduce(0, +)
        let cardioDistance = cardioSetsAll.compactMap(\.cardioMetrics?.distanceM).reduce(0, +)

        let prCount = countNewPersonalRecords(in: session)
        let breakdown = buildWorkoutCompletionBreakdown(session: session)

        return WorkoutCompletionSummary(
            id: session.id,
            workoutName: session.workout.name,
            durationSeconds: durationSeconds,
            totalSets: totalSets,
            totalVolumePounds: volume,
            exercisesWithSets: withSets,
            totalResolvedExercises: totalResolved,
            personalRecordCount: prCount,
            exerciseBreakdown: breakdown.lines,
            personalRecordHighlights: breakdown.highlights,
            totalCardioDurationSeconds: cardioDuration,
            totalCardioDistanceMeters: cardioDistance,
            cardioSegmentCount: cardioSetsAll.count
        )
    }
}

// MARK: - Share card (image)

private struct WorkoutCompletionShareCard: View {
    let summary: WorkoutCompletionSummary
    let displayUnit: WeightDisplayUnit

    private var volumeDisplay: Double {
        WeightStoreConversion.displayValue(storedPounds: summary.totalVolumePounds, unit: displayUnit)
    }

    private var unitLabel: String { displayUnit.shortLabel }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppBrand.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(summary.workoutName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                statPill(title: "Time", value: summary.durationFormatted)
                if summary.cardioSegmentCount > 0 && summary.totalSets == 0 {
                    statPill(
                        title: "Cardio",
                        value: CardioMetricsCalculator.formatDuration(seconds: summary.totalCardioDurationSeconds)
                    )
                    if summary.totalCardioDistanceMeters > 0 {
                        statPill(
                            title: "Distance",
                            value: CardioMetricsCalculator.formatDistance(meters: summary.totalCardioDistanceMeters)
                        )
                    }
                } else {
                    statPill(title: "Sets", value: "\(summary.totalSets)")
                    statPill(
                        title: "Volume",
                        value: {
                            let v = volumeDisplay
                            let num = v == floor(v) ? "\(Int(v))" : String(format: "%.1f", v)
                            return "\(num) \(unitLabel)"
                        }()
                    )
                    if summary.cardioSegmentCount > 0 {
                        statPill(
                            title: "Cardio",
                            value: CardioMetricsCalculator.formatDuration(seconds: summary.totalCardioDurationSeconds)
                        )
                    }
                }
            }

            if !summary.exerciseBreakdown.isEmpty {
                Divider().overlay(Color.white.opacity(0.25))
                Text("Exercises")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                ForEach(Array(summary.exerciseBreakdown.prefix(8))) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.exerciseName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if row.newPRSetCount > 0 {
                            Text("PR")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.yellow.opacity(0.95)))
                                .foregroundStyle(.black)
                        }
                        if let cardio = row.cardioSummary {
                            Text(cardio)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        } else {
                            let v = WeightStoreConversion.displayValue(storedPounds: row.volumePounds, unit: displayUnit)
                            let vStr = v == floor(v) ? "\(Int(v))" : String(format: "%.0f", v)
                            Text("\(row.workingSetCount)× · \(vStr)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                if summary.exerciseBreakdown.count > 8 {
                    Text("+ \(summary.exerciseBreakdown.count - 8) more")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(22)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.22),
                            Color(red: 0.06, green: 0.08, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}

#if canImport(UIKit)
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - UI

struct WorkoutCompletionSummaryView: View {
    let summary: WorkoutCompletionSummary
    var onDone: () -> Void
    @EnvironmentObject var userPreferences: UserPreferences
    #if canImport(UIKit)
    @State private var showImageShareSheet = false
    @State private var shareImageItems: [Any] = []
    #endif

    var body: some View {
        NavigationStack {
            List {
                if summary.cardioSegmentCount > 0 {
                    Section("Cardio") {
                        CardioCompletionRingView(
                            durationSeconds: summary.totalCardioDurationSeconds,
                            distanceMeters: summary.totalCardioDistanceMeters,
                            durationGoalSeconds: nil,
                            distanceGoalMeters: nil
                        )
                        LabeledContent("Segments", value: "\(summary.cardioSegmentCount)")
                    }
                }

                Section {
                    LabeledContent("Workout", value: summary.workoutName)
                    LabeledContent("Duration", value: summary.durationFormatted)
                    LabeledContent("Working sets", value: "\(summary.totalSets)")
                    let vol = WeightStoreConversion.displayValue(
                        storedPounds: summary.totalVolumePounds,
                        unit: userPreferences.weightDisplayUnit
                    )
                    LabeledContent(
                        "Volume",
                        value: "\(String(format: "%.0f", vol)) \(userPreferences.weightDisplayUnit.shortLabel)"
                    )
                    LabeledContent(
                        "Exercises logged",
                        value: "\(summary.exercisesWithSets) of \(summary.totalResolvedExercises)"
                    )
                    if summary.personalRecordCount > 0 {
                        LabeledContent("PR sets (this workout)", value: "\(summary.personalRecordCount)")
                    }
                }

                if !summary.personalRecordHighlights.isEmpty {
                    Section("PR highlights") {
                        ForEach(Array(summary.personalRecordHighlights.enumerated()), id: \.offset) { i, line in
                            Label(line, systemImage: "trophy.fill")
                                .id(i)
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }

                if !summary.exerciseBreakdown.isEmpty {
                    Section("By exercise") {
                        ForEach(summary.exerciseBreakdown) { row in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.exerciseName)
                                        .font(.body.weight(.medium))
                                    if let cardio = row.cardioSummary {
                                        Text(cardio)
                                            .font(.caption)
                                            .foregroundStyle(FitlogPalette.chartSecondary)
                                    } else {
                                        Text("\(row.workingSetCount) working sets")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                if row.newPRSetCount > 0 {
                                    Text("PR")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.orange.opacity(0.22)))
                                }
                                if let cardio = row.cardioSummary, row.volumePounds > 0 {
                                    let v = WeightStoreConversion.displayValue(
                                        storedPounds: row.volumePounds,
                                        unit: userPreferences.weightDisplayUnit
                                    )
                                    let unit = userPreferences.weightDisplayUnit.shortLabel
                                    let volStr = v == floor(v) ? "\(Int(v)) \(unit)" : String(format: "%.1f %@", v, unit)
                                    Text("\(volStr) · \(cardio)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                } else if row.cardioSummary != nil {
                                    Text("\(row.workingSetCount) segments")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                } else {
                                    let v = WeightStoreConversion.displayValue(
                                        storedPounds: row.volumePounds,
                                        unit: userPreferences.weightDisplayUnit
                                    )
                                    let unit = userPreferences.weightDisplayUnit.shortLabel
                                    Text(v == floor(v) ? "\(Int(v)) \(unit)" : String(format: "%.1f %@", v, unit))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        ShareLink(item: summary.shareLines(displayUnit: userPreferences.weightDisplayUnit)) {
                            Label("Text", systemImage: "square.and.arrow.up")
                        }
                        #if canImport(UIKit)
                        Button {
                            shareSummaryImage()
                        } label: {
                            Label("Image", systemImage: "photo")
                        }
                        #endif
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                        .accessibilityHint("Dismisses the workout summary")
                }
            }
            .onAppear {
                AccessibilityNotification.Announcement(
                    WorkoutCompletionAnnouncement.message(
                        summary: summary,
                        displayUnit: userPreferences.weightDisplayUnit
                    )
                ).post()
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showImageShareSheet) {
                ActivityShareSheet(items: shareImageItems)
                    .ignoresSafeArea()
            }
            #endif
        }
    }

    #if canImport(UIKit)
    @MainActor
    private func shareSummaryImage() {
        let card = WorkoutCompletionShareCard(summary: summary, displayUnit: userPreferences.weightDisplayUnit)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 340, height: 520)
        guard let uiImage = renderer.uiImage else { return }
        shareImageItems = [uiImage]
        showImageShareSheet = true
    }
    #endif
}
