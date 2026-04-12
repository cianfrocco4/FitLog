//
//  HistoryView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 3/8/26.
//

import SwiftUI
import Charts

private enum HistorySessionOriginFilter: String, CaseIterable, Identifiable {
    case all
    case fixedRoutine
    case openSlotPlan

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .all: return "All"
        case .fixedRoutine: return "No open slots"
        case .openSlotPlan: return "Has open slots"
        }
    }

    var footerExplanation: String {
        switch self {
        case .all:
            return "Analytics use every completed session in the time range."
        case .fixedRoutine:
            return "Sessions whose library workout had no open slots (every row has a default exercise), plus older logs without plan tracking."
        case .openSlotPlan:
            return "Sessions started from a library workout that included at least one open slot (no default exercise)."
        }
    }

    func includes(_ session: WorkoutSession, dataVM: DataManager) -> Bool {
        switch self {
        case .all: return true
        case .fixedRoutine:
            switch session.sessionPlanOrigin {
            case nil: return true
            case .workout(let id):
                guard let w = dataVM.workout(id: id) else { return true }
                return !w.hasOpenSlots
            }
        case .openSlotPlan:
            guard case .workout(let id) = session.sessionPlanOrigin,
                  let w = dataVM.workout(id: id) else { return false }
            return w.hasOpenSlots
        }
    }
}

// MARK: - Time range & main tab

private enum HistoryDayRange: Hashable, Identifiable, CaseIterable {
    case d7, d14, d30, d90, ytd

    var id: Self { self }

    var menuLabel: String {
        switch self {
        case .d7: return "Last 7 days"
        case .d14: return "Last 14 days"
        case .d30: return "Last 30 days"
        case .d90: return "Last 90 days"
        case .ytd: return "Year to date"
        }
    }

    func cutoff(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .d7: return now.addingTimeInterval(-7 * 86400)
        case .d14: return now.addingTimeInterval(-14 * 86400)
        case .d30: return now.addingTimeInterval(-30 * 86400)
        case .d90: return now.addingTimeInterval(-90 * 86400)
        case .ytd:
            return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
    }

    /// Window immediately before the current range, same length (for compare).
    func priorWindow(from now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date)? {
        switch self {
        case .d7, .d14, .d30, .d90:
            let days: Double = {
                switch self {
                case .d7: return 7
                case .d14: return 14
                case .d30: return 30
                case .d90: return 90
                case .ytd: return 0
                }
            }()
            let currentStart = now.addingTimeInterval(-days * 86400)
            let priorStart = now.addingTimeInterval(-2 * days * 86400)
            return (priorStart, currentStart)
        case .ytd:
            guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return nil }
            let len = now.timeIntervalSince(startOfYear)
            let priorEnd = startOfYear
            let priorStart = priorEnd.addingTimeInterval(-len)
            return (priorStart, priorEnd)
        }
    }
}

private enum HistoryMainTab: String, CaseIterable, Identifiable {
    case overview, sessions, explore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .sessions: return "Sessions"
        case .explore: return "Explore"
        }
    }
}

private struct HistoryChartCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct HistoryKPIs {
    let sessions: Int
    let totalSets: Int
    let totalVolume: Double
    let avgSessionSeconds: Int
}

private func historyFormatCompact(_ value: Double) -> String {
    let n = abs(value)
    if n >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    }
    if n >= 10_000 {
        return String(format: "%.1fk", value / 1000)
    }
    if n >= 1000 {
        return String(format: "%.2fk", value / 1000)
    }
    if value == floor(value) {
        return "\(Int(value))"
    }
    return String(format: "%.1f", value)
}

private func historyFormatCompactInt(_ value: Int) -> String {
    historyFormatCompact(Double(value))
}

private func historyEpleyEst1RM(weight: Double, reps: Int) -> Double {
    guard reps > 0 else { return weight }
    return weight * (1 + Double(reps) / 30)
}

private func completedSessionIsSameCalendarDay(_ session: WorkoutSession, as reference: Date = Date(), calendar: Calendar = .current) -> Bool {
    guard let end = session.endTime else { return false }
    return calendar.isDate(end, inSameDayAs: reference)
}

private func startAgainFromCompletedSession(
    _ session: WorkoutSession,
    currentVM: CurrentWorkoutSessionViewModel,
    openCurrentWorkoutSheet: (() -> Void)?,
    setPendingReplace: @escaping (PendingWorkoutReplace?) -> Void
) {
    currentVM.startWorkoutResumingFromCompleted(session) {
        setPendingReplace($0)
    }
    if currentVM.isInProgress {
        openCurrentWorkoutSheet?()
    }
}

struct HistoryView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    @State private var pendingStartAgainReplace: PendingWorkoutReplace?
    @State private var dayRange: HistoryDayRange = .d7
    @State private var sessionOriginFilter: HistorySessionOriginFilter = .all
    @State private var mainTab: HistoryMainTab = .overview
    @State private var comparePriorPeriod = false
    @State private var exploreSearch = ""
    @State private var selectedWorkoutsWeek: Date?
    @State private var selectedVolumeWeek: Date?
    @State private var selectedSetsWeek: Date?

    private var periodCutoff: Date {
        dayRange.cutoff(from: Date(), calendar: Calendar.current)
    }

    private var rangeDescription: String {
        switch dayRange {
        case .d7: return "last 7 days"
        case .d14: return "last 14 days"
        case .d30: return "last 30 days"
        case .d90: return "last 90 days"
        case .ytd: return "year to date"
        }
    }

    private var emptySessionsInRangeMessage: String {
        switch dayRange {
        case .ytd: return "No workouts completed year to date"
        default: return "No workouts completed in the \(rangeDescription)"
        }
    }

    private var sessionsInDateRange: [WorkoutSession] {
        let cutoff = periodCutoff
        return dataVM.completedSessions.filter { ($0.endTime ?? Date()) >= cutoff }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    private var filteredSessions: [WorkoutSession] {
        sessionsInDateRange.filter { sessionOriginFilter.includes($0, dataVM: dataVM) }
    }

    /// Completed sessions matching the session-source filter (no date window), newest first.
    private var originFilteredAllSessionsSorted: [WorkoutSession] {
        dataVM.completedSessions
            .filter { sessionOriginFilter.includes($0, dataVM: dataVM) }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    private var priorFilteredSessions: [WorkoutSession] {
        guard let (ps, pe) = dayRange.priorWindow() else { return [] }
        return dataVM.completedSessions.filter { s in
            let d = s.endTime ?? s.startTime
            return d >= ps && d < pe && sessionOriginFilter.includes(s, dataVM: dataVM)
        }
    }

    private var currentKPIs: HistoryKPIs { computeKPIs(filteredSessions) }
    private var priorKPIs: HistoryKPIs { computeKPIs(priorFilteredSessions) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Section", selection: $mainTab) {
                        ForEach(HistoryMainTab.allCases) { tab in
                            Text(tab.label).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Time range", selection: $dayRange) {
                        ForEach(HistoryDayRange.allCases) { r in
                            Text(r.menuLabel).tag(r)
                        }
                    }

                    Picker("Session source", selection: $sessionOriginFilter) {
                        ForEach(HistorySessionOriginFilter.allCases) { f in
                            Text(f.shortLabel).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Compare to prior period", isOn: $comparePriorPeriod)
                        .disabled(dayRange.priorWindow() == nil)
                } header: {
                    Text("History")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sessionOriginFilter.footerExplanation)
                            .font(.caption2)
                        if !filteredSessions.isEmpty {
                            Text("Showing data for \(rangeDescription).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                switch mainTab {
                case .overview:
                    kpiSection
                    consistencySection
                    yearTrainingHeatmapSection
                    trendsChartsSection
                    muscleBalanceSection
                case .sessions:
                    workoutsCompletedSection
                case .explore:
                    exploreContent
                }
            }
            .fitlogWorkoutBarContentInset()
            .navigationTitle("History & Analytics")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $exploreSearch, prompt: "Search workouts & exercises")
            .onAppear {
                dataVM.refreshCompletedSessions()
            }
            .onChange(of: mainTab) { _, newTab in
                if newTab != .explore {
                    exploreSearch = ""
                }
            }
            .workoutReplaceConflictConfirmation(
                currentVM: currentVM,
                pending: $pendingStartAgainReplace,
                onAfterReplace: { openCurrentWorkoutSheet?() }
            )
        }
    }

    @ViewBuilder
    private var exploreContent: some View {
        workoutAnalyticsSection
        exerciseAnalyticsSection
        muscleGroupAnalyticsSection
    }

    // MARK: - KPIs
    private var kpiSection: some View {
        Section {
            if filteredSessions.isEmpty {
                emptyOverviewMessage
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    kpiTile(
                        title: "Sessions",
                        value: "\(currentKPIs.sessions)",
                        deltaLine: comparePriorPeriod ? deltaLine(current: currentKPIs.sessions, prior: priorKPIs.sessions, invert: false) : nil,
                        systemImage: "figure.strengthtraining.traditional"
                    )
                    kpiTile(
                        title: "Total sets",
                        value: historyFormatCompactInt(currentKPIs.totalSets),
                        deltaLine: comparePriorPeriod ? deltaLine(current: currentKPIs.totalSets, prior: priorKPIs.totalSets, invert: false) : nil,
                        systemImage: "square.stack.3d.up.fill"
                    )
                    kpiTile(
                        title: "Volume",
                        value: "\(historyFormatCompact(currentKPIs.totalVolume)) lb·rep",
                        deltaLine: comparePriorPeriod ? deltaLine(current: Int(currentKPIs.totalVolume.rounded()), prior: Int(priorKPIs.totalVolume.rounded()), invert: false) : nil,
                        systemImage: "scalemass.fill"
                    )
                    kpiTile(
                        title: "Avg session",
                        value: formatAvgDuration(currentKPIs.avgSessionSeconds),
                        deltaLine: comparePriorPeriod ? deltaLine(current: currentKPIs.avgSessionSeconds, prior: priorKPIs.avgSessionSeconds, invert: true) : nil,
                        systemImage: "clock.fill"
                    )
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("At a glance")
        }
    }

    private func kpiTile(title: String, value: String, deltaLine: (String, Color)?, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            if let deltaLine {
                Text(deltaLine.0)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(deltaLine.1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
    }

    private func deltaLine(current: Int, prior: Int, invert: Bool) -> (String, Color) {
        if prior == 0 {
            if current == 0 { return ("No prior data", .secondary) }
            return ("New vs prior", .green)
        }
        let p = Int(round(Double(current - prior) / Double(prior) * 100))
        let sign = p > 0 ? "+" : ""
        let color = kpiDeltaColor(percent: p, invert: invert)
        return ("\(sign)\(p)% vs prior", color)
    }

    private func kpiDeltaColor(percent: Int, invert: Bool) -> Color {
        let p = invert ? -percent : percent
        if p > 0 { return .green }
        if p < 0 { return .orange }
        return .secondary
    }

    private func formatAvgDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let m = seconds / 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return "\(h)h \(mm)m"
        }
        return "\(m)m"
    }

    private func computeKPIs(_ sessions: [WorkoutSession]) -> HistoryKPIs {
        var sets = 0
        var vol = 0.0
        var durSum = 0
        for s in sessions {
            sets += s.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
            vol += s.exerciseLogs.flatMap(\.loggedSets).reduce(0) { $0 + $1.totalVolumeLoad }
            let end = s.endTime ?? s.startTime
            durSum += max(0, Int(end.timeIntervalSince(s.startTime)))
        }
        let avg = sessions.isEmpty ? 0 : durSum / sessions.count
        return HistoryKPIs(sessions: sessions.count, totalSets: sets, totalVolume: vol, avgSessionSeconds: avg)
    }

    @ViewBuilder
    private var emptyOverviewMessage: some View {
        if sessionsInDateRange.isEmpty {
            Text("Complete workouts to see trends")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("No sessions match this source filter")
                    .foregroundStyle(.secondary)
                Button("Reset source filter") {
                    sessionOriginFilter = .all
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Consistency (days trained)
    private var workoutDaysInPeriod: Set<Date> {
        let cal = Calendar.current
        var set = Set<Date>()
        for s in filteredSessions {
            set.insert(cal.startOfDay(for: s.endTime ?? s.startTime))
        }
        return set
    }

    private var consistencyDayCells: [ConsistencyDayCell] {
        let cal = Calendar.current
        var days: [Date] = []
        var d = cal.startOfDay(for: periodCutoff)
        let endDay = cal.startOfDay(for: Date())
        while d <= endDay {
            days.append(d)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        let trained = workoutDaysInPeriod
        return days.map { ConsistencyDayCell(day: $0, didWorkout: trained.contains($0)) }
    }

    private var consistencySection: some View {
        Section {
            if filteredSessions.isEmpty {
                emptyOverviewMessage
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dots show days you logged a workout in this range.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(consistencyDayCells) { cell in
                                VStack(spacing: 5) {
                                    Circle()
                                        .fill(cell.didWorkout ? Color.accentColor : Color.primary.opacity(0.1))
                                        .frame(width: 11, height: 11)
                                    Text(cell.narrowWeekday)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(cell.dayLabel), \(cell.didWorkout ? "workout logged" : "rest")")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Consistency")
        }
    }

    private struct YearHeatmapDay: Identifiable {
        let id: Date
        let date: Date
        let sessionCount: Int
    }

    /// Last 365 days (calendar days), all completed sessions — independent of the History range filters.
    private var yearHeatmapDays: [YearHeatmapDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -364, to: today) else { return [] }
        var countByDay: [Date: Int] = [:]
        for s in dataVM.completedSessions where s.isCompleted {
            let d = cal.startOfDay(for: s.endTime ?? s.startTime)
            countByDay[d, default: 0] += 1
        }
        var out: [YearHeatmapDay] = []
        var d = start
        while d <= today {
            out.append(YearHeatmapDay(id: d, date: d, sessionCount: countByDay[d] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    private var yearHeatmapWeekColumns: [[YearHeatmapDay]] {
        let days = yearHeatmapDays
        guard !days.isEmpty else { return [] }
        var weeks: [[YearHeatmapDay]] = []
        var row: [YearHeatmapDay] = []
        for day in days {
            row.append(day)
            if row.count == 7 {
                weeks.append(row)
                row = []
            }
        }
        if !row.isEmpty {
            weeks.append(row)
        }
        return weeks
    }

    private func yearHeatmapCellColor(count: Int) -> Color {
        switch count {
        case 0: return Color.primary.opacity(0.07)
        case 1: return Color.green.opacity(0.38)
        case 2: return Color.green.opacity(0.58)
        default: return Color.green.opacity(0.82)
        }
    }

    private var yearTrainingHeatmapSection: some View {
        Section {
            if dataVM.completedSessions.isEmpty {
                Text("Complete workouts to see your training density here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Each square is a day; darker green means more sessions that day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 3) {
                            ForEach(Array(yearHeatmapWeekColumns.enumerated()), id: \.offset) { _, week in
                                VStack(spacing: 3) {
                                    ForEach(week) { day in
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .fill(yearHeatmapCellColor(count: day.sessionCount))
                                            .frame(width: 10, height: 10)
                                            .accessibilityLabel(
                                                day.sessionCount == 0
                                                    ? "No workout"
                                                    : "\(day.sessionCount) session\(day.sessionCount == 1 ? "" : "s")"
                                            )
                                    }
                                    if week.count < 7 {
                                        ForEach(0..<(7 - week.count), id: \.self) { _ in
                                            Color.clear.frame(width: 10, height: 10)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    HStack(spacing: 8) {
                        Text("Less")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(yearHeatmapCellColor(count: 0))
                            .frame(width: 10, height: 10)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(yearHeatmapCellColor(count: 1))
                            .frame(width: 10, height: 10)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(yearHeatmapCellColor(count: 2))
                            .frame(width: 10, height: 10)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(yearHeatmapCellColor(count: 3))
                            .frame(width: 10, height: 10)
                        Text("More")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Training year (365 days)")
        }
    }

    // MARK: - Muscle balance
    @ViewBuilder
    private var muscleBalanceSection: some View {
        if !filteredSessions.isEmpty {
            Section {
                let rows = muscleGroupVolumeRows(in: filteredSessions)
                if rows.isEmpty {
                    Text("No muscle-tagged exercises in this range")
                        .foregroundStyle(.secondary)
                } else {
                    HistoryChartCard(title: "Volume by muscle (lb·rep)") {
                        Chart(rows) { row in
                            BarMark(
                                x: .value("Volume", row.volume),
                                y: .value("Muscle", row.name)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.mint.opacity(0.85), .teal.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                        .chartXAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let n = v.as(Double.self) {
                                        Text(historyFormatCompact(n))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(preset: .aligned) { _ in
                                AxisValueLabel()
                            }
                        }
                        .frame(height: CGFloat(min(380, max(140, rows.count * 30))))
                    }
                }
            } header: {
                Text("Muscle balance")
            }
        }
    }

    // MARK: - Trend charts (weekly aggregates)
    private var trendsChartsSection: some View {
        Section {
            if filteredSessions.isEmpty {
                Group {
                    if sessionsInDateRange.isEmpty {
                        Text("Complete workouts to see trends")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No sessions match this source filter")
                                .foregroundStyle(.secondary)
                            Button("Reset source filter") {
                                sessionOriginFilter = .all
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    workoutsPerWeekChart
                    volumePerWeekChart
                    setsPerWeekChart
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("Trends")
        }
    }

    private var weeklyVolumeAverage: Double? {
        let v = weeklyVolumeFiltered.map(\.volume)
        guard !v.isEmpty else { return nil }
        return v.reduce(0, +) / Double(v.count)
    }

    private var weeklySetsAverage: Double? {
        let c = weeklySetCountsFiltered.map(\.count)
        guard !c.isEmpty else { return nil }
        return Double(c.reduce(0, +)) / Double(c.count)
    }

    private var workoutsPerWeekChart: some View {
        HistoryChartCard(title: "Workouts per week") {
            Chart(weeklyWorkoutsByOrigin) { row in
                BarMark(
                    x: .value("Week", row.weekStart),
                    y: .value("Workouts", row.count)
                )
                .foregroundStyle(by: .value("Source", row.segment))
            }
            .chartForegroundStyleScale([
                "No open slots": Color.blue,
                "Has open slots": Color.purple,
                "Plan": Color.indigo,
                "Older": Color.secondary
            ])
            .chartLegend(.visible)
            .chartXSelection(value: $selectedWorkoutsWeek)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 196)
            if let tip = workoutsWeekTooltip(for: selectedWorkoutsWeek) {
                Text(tip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var volumePerWeekChart: some View {
        HistoryChartCard(title: "Volume per week (lb·rep)") {
            Chart {
                ForEach(weeklyVolumeFiltered) { row in
                    AreaMark(
                        x: .value("Week", row.weekStart),
                        y: .value("Volume", row.volume)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.35), .orange.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    LineMark(
                        x: .value("Week", row.weekStart),
                        y: .value("Volume", row.volume)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                if let avg = weeklyVolumeAverage {
                    RuleMark(y: .value("Avg", avg))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("avg \(historyFormatCompact(avg))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .chartXSelection(value: $selectedVolumeWeek)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text(historyFormatCompact(n))
                        }
                    }
                }
            }
            .frame(height: 196)
            if let tip = volumeWeekTooltip(for: selectedVolumeWeek) {
                Text(tip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var setsPerWeekChart: some View {
        HistoryChartCard(title: "Sets per week") {
            Chart {
                ForEach(weeklySetCountsFiltered) { row in
                    AreaMark(
                        x: .value("Week", row.weekStart),
                        y: .value("Sets", row.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.32), .green.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    LineMark(
                        x: .value("Week", row.weekStart),
                        y: .value("Sets", row.count)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                if let avg = weeklySetsAverage {
                    RuleMark(y: .value("Avg", avg))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("avg \(historyFormatCompact(avg))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .chartXSelection(value: $selectedSetsWeek)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let n = v.as(Int.self) {
                            Text("\(n)")
                        }
                    }
                }
            }
            .frame(height: 196)
            if let tip = setsWeekTooltip(for: selectedSetsWeek) {
                Text(tip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private func workoutsWeekTooltip(for selected: Date?) -> String? {
        guard let selected, let week = nearestWeekStart(selected, in: weeklyWorkoutsByOrigin.map(\.weekStart)) else { return nil }
        let cal = Calendar.current
        let rows = weeklyWorkoutsByOrigin.filter { cal.isDate($0.weekStart, equalTo: week, toGranularity: .weekOfYear) }
        guard !rows.isEmpty else { return nil }
        let total = rows.reduce(0) { $0 + $1.count }
        let parts = rows.map { "\($0.segment): \($0.count)" }.sorted()
        let df = DateFormatter()
        df.dateStyle = .medium
        return "Week of \(df.string(from: week)) — \(total) total (\(parts.joined(separator: ", ")))"
    }

    private func volumeWeekTooltip(for selected: Date?) -> String? {
        guard let selected, let week = nearestWeekStart(selected, in: weeklyVolumeFiltered.map(\.weekStart)),
              let row = weeklyVolumeFiltered.first(where: { Calendar.current.isDate($0.weekStart, equalTo: week, toGranularity: .weekOfYear) })
        else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        return "Week of \(df.string(from: week)): \(historyFormatCompact(row.volume)) lb·rep"
    }

    private func setsWeekTooltip(for selected: Date?) -> String? {
        guard let selected, let week = nearestWeekStart(selected, in: weeklySetCountsFiltered.map(\.weekStart)),
              let row = weeklySetCountsFiltered.first(where: { Calendar.current.isDate($0.weekStart, equalTo: week, toGranularity: .weekOfYear) })
        else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        return "Week of \(df.string(from: week)): \(row.count) sets"
    }

    private func nearestWeekStart(_ selected: Date, in weekStarts: [Date]) -> Date? {
        let unique = Array(Set(weekStarts))
        guard !unique.isEmpty else { return nil }
        return unique.min(by: { abs($0.timeIntervalSince(selected)) < abs($1.timeIntervalSince(selected)) })
    }

    private struct ConsistencyDayCell: Identifiable {
        let day: Date
        let didWorkout: Bool
        var id: Date { day }
        var narrowWeekday: String {
            day.formatted(Date.FormatStyle().weekday(.narrow))
        }
        var dayLabel: String {
            day.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private struct MuscleVolumeRow: Identifiable {
        let name: String
        let volume: Double
        var id: String { name }
    }

    private func muscleGroupVolumeRows(in sessions: [WorkoutSession]) -> [MuscleVolumeRow] {
        var byGroup: [String: Double] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { continue }
                let vol = log.loggedSets.reduce(0) { $0 + $1.totalVolumeLoad }
                let muscles = ex.targetedMuscles
                if muscles.isEmpty {
                    byGroup[MuscleGroup.other.rawValue, default: 0] += vol
                } else {
                    for m in muscles {
                        byGroup[m.rawValue, default: 0] += vol
                    }
                }
            }
        }
        return byGroup.map { MuscleVolumeRow(name: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }
    }

    private struct WeekData: Identifiable {
        let id: Date
        let weekStart: Date
        let count: Int
    }

    private struct WeekOriginBar: Identifiable {
        let id: String
        let weekStart: Date
        let segment: String
        let count: Int
    }

    private struct WeekVolumeData: Identifiable {
        let id: Date
        let weekStart: Date
        let volume: Double
    }

    private func weekSegmentLabel(for session: WorkoutSession) -> String {
        switch session.sessionPlanOrigin {
        case nil:
            return "Older"
        case .workout(let id):
            if let w = dataVM.workout(id: id) {
                return w.hasOpenSlots ? "Has open slots" : "No open slots"
            }
            return "Plan"
        }
    }

    private var weeklyWorkoutsByOrigin: [WeekOriginBar] {
        let calendar = Calendar.current
        var tallies: [Date: [String: Int]] = [:]
        for session in filteredSessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let seg = weekSegmentLabel(for: session)
            var m = tallies[weekStart] ?? [:]
            m[seg, default: 0] += 1
            tallies[weekStart] = m
        }
        let segmentOrder = ["No open slots", "Has open slots", "Plan", "Older"]
        return tallies.flatMap { weekStart, counts in
            segmentOrder.compactMap { seg in
                let c = counts[seg] ?? 0
                guard c > 0 else { return nil }
                return WeekOriginBar(
                    id: "\(weekStart.timeIntervalSince1970)-\(seg)",
                    weekStart: weekStart,
                    segment: seg,
                    count: c
                )
            }
        }
        .sorted { a, b in
            if a.weekStart != b.weekStart { return a.weekStart < b.weekStart }
            let oa = segmentOrder.firstIndex(of: a.segment) ?? 99
            let ob = segmentOrder.firstIndex(of: b.segment) ?? 99
            return oa < ob
        }
    }

    private var weeklyVolumeFiltered: [WeekVolumeData] {
        let calendar = Calendar.current
        var volumeByWeek: [Date: Double] = [:]
        for session in filteredSessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let vol = session.exerciseLogs.flatMap(\.loggedSets).reduce(0) { $0 + $1.totalVolumeLoad }
            volumeByWeek[weekStart, default: 0] += vol
        }
        return volumeByWeek
            .map { WeekVolumeData(id: $0.key, weekStart: $0.key, volume: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    private var weeklySetCountsFiltered: [WeekData] {
        let calendar = Calendar.current
        var setsByWeek: [Date: Int] = [:]
        for session in filteredSessions {
            let d = session.endTime ?? session.startTime
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            let sets = session.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
            setsByWeek[weekStart, default: 0] += sets
        }
        return setsByWeek
            .map { WeekData(id: $0.key, weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }
    
    // MARK: - Workouts completed in range
    private var workoutsCompletedSection: some View {
        Section {
            if filteredSessions.isEmpty {
                if sessionsInDateRange.isEmpty {
                    Text(emptySessionsInRangeMessage)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No sessions match this source filter")
                            .foregroundStyle(.secondary)
                        Button("Reset source filter") {
                            sessionOriginFilter = .all
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                ForEach(filteredSessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)
                        .environmentObject(dataVM)
                        .environmentObject(currentVM)
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.workout.name)
                                    .font(.headline)
                                Text(formatDate(session.endTime ?? session.startTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(sessionOriginCaption(session))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(durationString(for: session))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if completedSessionIsSameCalendarDay(session) {
                            Button {
                                startAgainFromCompletedSession(
                                    session,
                                    currentVM: currentVM,
                                    openCurrentWorkoutSheet: openCurrentWorkoutSheet,
                                    setPendingReplace: { pendingStartAgainReplace = $0 }
                                )
                            } label: {
                                Label("Continue", systemImage: "arrow.clockwise.circle.fill")
                            }
                            .tint(.green)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) {
                            dataVM.deleteCompletedSession(id: session.id)
                        }
                    }
                }
            }
        } header: {
            Text("Recent sessions (\(rangeDescription))")
        }
    }
    
    // MARK: - Workout-level analytics (sessions per workout in range)
    private var workoutAnalyticsSection: some View {
        Section {
            let grouped = Dictionary(grouping: filteredSessions) { $0.workout.id }
            let q = exploreSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let sorted = grouped
                .sorted { ($1.value.first?.endTime ?? .distantPast) > ($0.value.first?.endTime ?? .distantPast) }
                .filter { q.isEmpty || ($0.value.first?.workout.name ?? "").lowercased().contains(q) }
            if sorted.isEmpty {
                Text(q.isEmpty ? "No workout data in this range" : "No workouts match your search")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted, id: \.key) { workoutId, sessions in
                    let name = sessions.first?.workout.name ?? "Unknown"
                    let last = sessions.map(\.endTime).compactMap { $0 }.max()
                    NavigationLink(destination: WorkoutHistoryDetailView(workoutId: workoutId, workoutName: name)
                        .environmentObject(dataVM)
                        .environmentObject(currentVM)
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.headline)
                                if let last = last {
                                    Text("Last: \(formatDate(last))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("By workout")
        }
    }
    
    // MARK: - Exercise-level analytics (in range)
    private var exerciseAnalyticsSection: some View {
        Section {
            let q = exploreSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let stats = exerciseStats(in: filteredSessions).filter {
                q.isEmpty || dataVM.resolvedDisplayName(for: $0.sampleExercise).lowercased().contains(q)
            }
            if stats.isEmpty {
                Text(q.isEmpty ? "No exercise data in this range" : "No exercises match your search")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.id) { stat in
                    NavigationLink(destination: ExerciseHistoryDetailView(
                        exerciseId: stat.id,
                        rangeSessions: filteredSessions,
                        originFilteredAllSessions: originFilteredAllSessionsSorted
                    )
                        .environmentObject(dataVM)
                        .environmentObject(userPreferences)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dataVM.resolvedDisplayName(for: stat.sampleExercise))
                                .font(.headline)
                            HStack(spacing: 16) {
                                Label("\(stat.sessions) session\(stat.sessions == 1 ? "" : "s")", systemImage: "calendar")
                                Label("\(stat.totalSets) sets", systemImage: "square.stack.3d.up")
                                if stat.volume > 0 {
                                    Label(
                                        WeightStoreConversion.formatVolumeLbRep(stat.volume, unit: userPreferences.weightDisplayUnit),
                                        systemImage: "scalemass"
                                    )
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("By exercise")
        }
    }
    
    // MARK: - Muscle group analytics (in range)
    private var muscleGroupAnalyticsSection: some View {
        Section {
            let q = exploreSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let stats = muscleGroupStats(in: filteredSessions).filter {
                q.isEmpty || $0.name.lowercased().contains(q)
            }
            if stats.isEmpty {
                Text(q.isEmpty ? "No muscle group data in this range" : "No muscle groups match your search")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.sorted(by: { $0.sessions > $1.sessions }), id: \.name) { stat in
                    NavigationLink(destination: MuscleGroupHistoryDetailView(muscleGroupName: stat.name, sessions: filteredSessions)
                        .environmentObject(dataVM)
                        .environmentObject(userPreferences)) {
                        HStack {
                            Text(stat.name)
                                .font(.headline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(stat.sessions) session\(stat.sessions == 1 ? "" : "s")")
                                Text("\(stat.exerciseCount) exercise\(stat.exerciseCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        } header: {
            Text("By muscle group")
        }
    }
    
    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func durationString(for session: WorkoutSession) -> String {
        let end = session.endTime ?? session.startTime
        let secs = Int(end.timeIntervalSince(session.startTime))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    private func sessionOriginCaption(_ session: WorkoutSession) -> String {
        switch session.sessionPlanOrigin {
        case nil:
            return "Older session"
        case .workout(let id):
            if let w = dataVM.workout(id: id) {
                return "\(w.name) · \(w.listDetailSubtitle)"
            }
            return "From training plan"
        }
    }
    
    private struct ExerciseStat: Identifiable {
        let id: UUID
        let sampleExercise: Exercise
        let sessions: Int
        let totalSets: Int
        let volume: Double
    }
    
    private func exerciseStats(in sessions: [WorkoutSession]) -> [ExerciseStat] {
        var byId: [UUID: (sample: Exercise, sessions: Set<UUID>, sets: Int, volume: Double)] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { continue }
                var entry = byId[ex.id] ?? (sample: ex, sessions: [], sets: 0, volume: 0)
                entry.sessions.insert(session.id)
                entry.sets += log.loggedSets.count
                entry.volume += log.loggedSets.reduce(0) { $0 + $1.totalVolumeLoad }
                byId[ex.id] = entry
            }
        }
        return byId.map { id, data in
            ExerciseStat(id: id, sampleExercise: data.sample, sessions: data.sessions.count, totalSets: data.sets, volume: data.volume)
        }
    }
    
    private struct MuscleGroupStat {
        let name: String
        let sessions: Int
        let exerciseCount: Int
    }
    
    private func muscleGroupStats(in sessions: [WorkoutSession]) -> [MuscleGroupStat] {
        var byGroup: [String: (sessions: Set<UUID>, exercises: Set<UUID>)] = [:]
        for session in sessions {
            for log in session.exerciseLogs {
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { continue }
                let muscles = ex.targetedMuscles
                if muscles.isEmpty {
                    let g = MuscleGroup.other.rawValue
                    var e = byGroup[g] ?? (sessions: [], exercises: [])
                    e.sessions.insert(session.id)
                    e.exercises.insert(ex.id)
                    byGroup[g] = e
                } else {
                    for m in muscles {
                        let key = m.rawValue
                        var e = byGroup[key] ?? (sessions: [], exercises: [])
                        e.sessions.insert(session.id)
                        e.exercises.insert(ex.id)
                        byGroup[key] = e
                    }
                }
            }
        }
        return byGroup.map { name, data in
            MuscleGroupStat(name: name, sessions: data.sessions.count, exerciseCount: data.exercises.count)
        }
    }
}

private func historyRpeLabel(_ rpe: Double) -> String {
    if abs(rpe.truncatingRemainder(dividingBy: 1)) < 0.001 {
        return "RPE \(Int(rpe))"
    }
    return String(format: "RPE %.1f", rpe)
}

// MARK: - Session detail (single workout session: exercises + logged sets)
private struct SessionDetailView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    let session: WorkoutSession

    @State private var confirmDeleteSession = false
    @State private var pendingStartAgainReplace: PendingWorkoutReplace?
    @State private var prKindsBySetId: [UUID: [PersonalRecordEvent.Kind]] = [:]

    private var endDate: Date { session.endTime ?? session.startTime }

    private var canStartAgainToday: Bool {
        completedSessionIsSameCalendarDay(session)
    }

    private var sessionPlanLine: String {
        switch session.sessionPlanOrigin {
        case nil:
            return "Not recorded (older log)"
        case .workout(let id):
            if let w = dataVM.workout(id: id) {
                return "\(w.name) (\(w.listDetailSubtitle))"
            }
            return "Plan workout (removed from library)"
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(HistoryView.formatDateStatic(endDate))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(HistoryView.durationStringStatic(for: session))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Session plan")
                    Spacer()
                    Text(sessionPlanLine)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            if !session.sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Workout notes") {
                    Text(session.sessionNotes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if canStartAgainToday {
                Section {
                    Button {
                        startAgainFromCompletedSession(
                            session,
                            currentVM: currentVM,
                            openCurrentWorkoutSheet: openCurrentWorkoutSheet,
                            setPendingReplace: { pendingStartAgainReplace = $0 }
                        )
                    } label: {
                        Label("Continue session", systemImage: "arrow.clockwise.circle.fill")
                    }
                } footer: {
                    Text("Continues this session with the same logged sets and progress. This finished entry stays in your history until you complete the new run.")
                }
            }
            ForEach(session.exerciseLogs) { log in
                Section {
                    ForEach(log.loggedSets) { set in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
                                if set.isWarmup {
                                    Text("Warm-up")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                if let rpe = set.rpe {
                                    Text(historyRpeLabel(rpe))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                if let kinds = prKindsBySetId[set.id], !kinds.isEmpty {
                                    ForEach(kinds, id: \.self) { k in
                                        Text(sessionDetailPRBadgeLabel(k))
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15), in: Capsule())
                                    }
                                }
                                Spacer()
                            }
                            let summary = set.configurationSummary(fieldNames: log.workoutExercise.configurationFields)
                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dataVM.displayName(for: log.workoutExercise))
                        if let slotLabel = HistoryView.templateSlotCaption(for: log, session: session, dataVM: dataVM) {
                            Text("Slot: \(slotLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !log.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(log.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", role: .destructive) {
                    confirmDeleteSession = true
                }
            }
        }
        .confirmationDialog(
            "Remove this workout from your history? This cannot be undone.",
            isPresented: $confirmDeleteSession,
            titleVisibility: .visible
        ) {
            Button("Delete from history", role: .destructive) {
                dataVM.deleteCompletedSession(id: session.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartAgainReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
        .onAppear {
            rebuildSessionDetailPRMap()
        }
    }

    private func sessionDetailPRBadgeLabel(_ kind: PersonalRecordEvent.Kind) -> String {
        switch kind {
        case .maxWeight: return "Wt PR"
        case .estimatedOneRM: return "1RM PR"
        case .maxVolumeSet: return "Vol PR"
        }
    }

    private func rebuildSessionDetailPRMap() {
        var map: [UUID: [PersonalRecordEvent.Kind]] = [:]
        for log in session.exerciseLogs {
            for set in log.loggedSets {
                let kinds = dataVM.personalRecordKindsForHistoricalSet(set: set, log: log, session: session)
                if !kinds.isEmpty {
                    map[set.id] = kinds
                }
            }
        }
        prKindsBySetId = map
    }
}

// MARK: - Workout history (list of sessions for one workout)
private struct WorkoutHistoryDetailView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.openCurrentWorkoutSheet) private var openCurrentWorkoutSheet
    @State private var pendingStartAgainReplace: PendingWorkoutReplace?
    let workoutId: UUID
    let workoutName: String

    private var sessionsForWorkout: [WorkoutSession] {
        dataVM.completedSessions.filter { $0.workout.id == workoutId }
    }

    private var sortedSessions: [WorkoutSession] {
        sessionsForWorkout.sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    /// Chronological for chart (oldest → newest).
    private var durationTrendPoints: [WorkoutDurationPoint] {
        sessionsForWorkout
            .sorted { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }
            .map { s in
                let end = s.endTime ?? s.startTime
                let sec = max(1, Int(end.timeIntervalSince(s.startTime)))
                return WorkoutDurationPoint(id: s.id, date: end, minutes: max(1, sec / 60))
            }
    }

    var body: some View {
        List {
            if durationTrendPoints.count >= 2 {
                Section {
                    HistoryChartCard(title: "Session duration trend") {
                        Chart(durationTrendPoints) { pt in
                            AreaMark(
                                x: .value("Date", pt.date),
                                y: .value("Minutes", pt.minutes)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.indigo.opacity(0.3), .indigo.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Minutes", pt.minutes)
                            )
                            .foregroundStyle(.indigo)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, durationTrendPoints.count / 4))) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let m = v.as(Int.self) {
                                        Text("\(m)m")
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }
            }
            ForEach(sortedSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)
                    .environmentObject(dataVM)
                    .environmentObject(currentVM)
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(HistoryView.formatDateStatic(session.endTime ?? session.startTime))
                                .font(.headline)
                            Text("\(session.exerciseLogs.count) exercise\(session.exerciseLogs.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(HistoryView.durationStringStatic(for: session))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if completedSessionIsSameCalendarDay(session) {
                        Button {
                            startAgainFromCompletedSession(
                                session,
                                currentVM: currentVM,
                                openCurrentWorkoutSheet: openCurrentWorkoutSheet,
                                setPendingReplace: { pendingStartAgainReplace = $0 }
                            )
                        } label: {
                            Label("Continue", systemImage: "arrow.clockwise.circle.fill")
                        }
                        .tint(.green)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        dataVM.deleteCompletedSession(id: session.id)
                    }
                }
            }
        }
        .navigationTitle(workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .workoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: $pendingStartAgainReplace,
            onAfterReplace: { openCurrentWorkoutSheet?() }
        )
    }
}

private struct WorkoutDurationPoint: Identifiable {
    let id: UUID
    let date: Date
    let minutes: Int
}

private struct ExerciseProgressionPoint: Identifiable {
    let id: UUID
    let date: Date
    let estOneRM: Double
}

private struct ExerciseVolumePoint: Identifiable {
    let id: UUID
    let date: Date
    let volumeLbRep: Double
}

private enum ExerciseHistoryDataScope: String, CaseIterable {
    case selectedRange
    case allTime

    var label: String {
        switch self {
        case .selectedRange: return "Selected range"
        case .allTime: return "All time"
        }
    }
}

// MARK: - Exercise history (each session where exercise was done + logged sets)
private struct ExerciseHistoryDetailView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var userPreferences: UserPreferences
    let exerciseId: UUID
    let rangeSessions: [WorkoutSession]
    let originFilteredAllSessions: [WorkoutSession]
    @State private var dataScope: ExerciseHistoryDataScope = .selectedRange

    private var effectiveSessions: [WorkoutSession] {
        switch dataScope {
        case .selectedRange:
            return rangeSessions
        case .allTime:
            return originFilteredAllSessions
        }
    }

    private var sessionLogs: [(session: WorkoutSession, log: ExerciseLog)] {
        effectiveSessions.compactMap { session in
            guard let log = session.exerciseLogs.first(where: { $0.workoutExercise.exerciseId == exerciseId }) else { return nil }
            return (session, log)
        }.sorted { ($0.session.endTime ?? $0.session.startTime) > ($1.session.endTime ?? $1.session.startTime) }
    }

    private var navigationTitle: String {
        if let ex = dataVM.globalExercises.first(where: { $0.id == exerciseId }) {
            return dataVM.resolvedDisplayName(for: ex)
        }
        if let log = sessionLogs.first?.log {
            return dataVM.displayName(for: log.workoutExercise)
        }
        return "Exercise"
    }

    private var progressionSeries: [ExerciseProgressionPoint] {
        sessionLogs.compactMap { item -> ExerciseProgressionPoint? in
            guard let est = Self.bestWorkingEst1RM(for: item.log) else { return nil }
            let date = item.session.endTime ?? item.session.startTime
            return ExerciseProgressionPoint(id: item.session.id, date: date, estOneRM: est)
        }
        .sorted { $0.date < $1.date }
    }

    private static func bestWorkingEst1RM(for log: ExerciseLog) -> Double? {
        var best = 0.0
        var found = false
        for set in log.loggedSets where !set.isWarmup && set.reps > 0 {
            var candidate = historyEpleyEst1RM(weight: set.weight, reps: set.reps)
            for d in set.dropSegments where d.reps > 0 {
                let e = historyEpleyEst1RM(weight: d.weight, reps: d.reps)
                if e > candidate { candidate = e }
            }
            if candidate > best {
                best = candidate
                found = true
            }
        }
        return found ? best : nil
    }

    private var progressionLoadAxisLabel: String { userPreferences.weightDisplayUnit.shortLabel }

    private func progressionChartY(_ estStoredLb: Double) -> Double {
        WeightStoreConversion.displayValue(storedPounds: estStoredLb, unit: userPreferences.weightDisplayUnit)
    }

    private var progressionInsight: String? {
        guard let peak = progressionSeries.map(\.estOneRM).max(), peak > 0 else { return nil }
        let d = WeightStoreConversion.displayValue(storedPounds: peak, unit: userPreferences.weightDisplayUnit)
        let rounded = d == floor(d) ? "\(Int(d))" : String(format: "%.1f", d)
        let u = userPreferences.weightDisplayUnit.shortLabel
        return "Peak estimated 1RM in this range: \(rounded) \(u) (Epley, working sets only)."
    }

    private var volumeSeries: [ExerciseVolumePoint] {
        sessionLogs.map { item in
            let vol = item.log.loggedSets.reduce(0.0) { $0 + $1.totalVolumeLoad }
            let d = item.session.endTime ?? item.session.startTime
            return ExerciseVolumePoint(id: item.session.id, date: d, volumeLbRep: vol)
        }
        .sorted { $0.date < $1.date }
    }

    private var volumeAxisLabel: String {
        userPreferences.weightDisplayUnit == .pounds ? "lb·rep" : "kg·rep"
    }

    private func volumeChartY(_ lbRep: Double) -> Double {
        WeightStoreConversion.volumeDisplayValue(lbRep: lbRep, unit: userPreferences.weightDisplayUnit)
    }

    var body: some View {
        List {
            Section {
                Picker("Scope", selection: $dataScope) {
                    ForEach(ExerciseHistoryDataScope.allCases, id: \.rawValue) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(
                    dataScope == .selectedRange
                        ? "Matches the time range on the History tab."
                        : "Every session that included this exercise, using your session source filter (no date limit)."
                )
                .font(.caption2)
            }

            if !progressionSeries.isEmpty {
                Section {
                    if progressionSeries.count >= 2 {
                        HistoryChartCard(title: "Strength trend (est. 1RM)") {
                        Chart(progressionSeries) { pt in
                            AreaMark(
                                x: .value("Session", pt.date),
                                y: .value(progressionLoadAxisLabel, progressionChartY(pt.estOneRM))
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.28), .cyan.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value("Session", pt.date),
                                y: .value(progressionLoadAxisLabel, progressionChartY(pt.estOneRM))
                            )
                            .foregroundStyle(.cyan)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Session", pt.date),
                                y: .value(progressionLoadAxisLabel, progressionChartY(pt.estOneRM))
                            )
                            .foregroundStyle(.cyan)
                            .symbolSize(36)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, progressionSeries.count / 3))) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let n = v.as(Double.self) {
                                        Text(historyFormatCompact(n))
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                        }
                    }
                    if let progressionInsight {
                        Text(progressionInsight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Progression")
                }
            }

            if volumeSeries.count >= 2 {
                Section {
                    HistoryChartCard(title: "Volume per session") {
                        Chart(volumeSeries) { pt in
                            BarMark(
                                x: .value("Session", pt.date),
                                y: .value(volumeAxisLabel, volumeChartY(pt.volumeLbRep))
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.mint, .teal.opacity(0.85)], startPoint: .bottom, endPoint: .top)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, volumeSeries.count / 3))) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let n = v.as(Double.self) {
                                        Text(historyFormatCompact(n))
                                    }
                                }
                            }
                        }
                        .frame(height: 188)
                    }
                } header: {
                    Text("Volume trend")
                } footer: {
                    Text("Sum of load × reps for this exercise each session (including drop segments).")
                        .font(.caption2)
                }
            }

            ForEach(sessionLogs, id: \.session.id) { item in
                Section {
                    HStack {
                        Text("Workout")
                        Spacer()
                        Text(item.session.workout.name)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                            .foregroundStyle(.secondary)
                    }
                    if let slotLabel = HistoryView.templateSlotCaption(for: item.log, session: item.session, dataVM: dataVM) {
                        HStack {
                            Text("Template slot")
                            Spacer()
                            Text(slotLabel)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    ForEach(item.log.loggedSets) { set in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
                                if set.isWarmup {
                                    Text("Warm-up")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                Spacer()
                            }
                            let summary = set.configurationSummary(fieldNames: item.log.workoutExercise.configurationFields)
                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Muscle group history (sessions + exercises that targeted this muscle + sets)
private struct MuscleGroupHistoryDetailView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var userPreferences: UserPreferences
    let muscleGroupName: String
    let sessions: [WorkoutSession]

    private var sessionLogs: [(session: WorkoutSession, logs: [ExerciseLog])] {
        sessions.compactMap { session in
            let logs = session.exerciseLogs.filter { log in
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { return false }
                return ex.targetedMuscles.contains(where: { $0.rawValue == muscleGroupName })
                    || (ex.targetedMuscles.isEmpty && muscleGroupName == MuscleGroup.other.rawValue)
            }
            if logs.isEmpty { return nil }
            return (session, logs)
        }.sorted { ($0.session.endTime ?? $0.session.startTime) > ($1.session.endTime ?? $1.session.startTime) }
    }

    private var muscleVolumeTrendPoints: [MuscleSessionVolumePoint] {
        sessionLogs
            .sorted { ($0.session.endTime ?? $0.session.startTime) < ($1.session.endTime ?? $1.session.startTime) }
            .map { item in
                let vol = item.logs.reduce(0.0) { acc, log in
                    acc + log.loggedSets.reduce(0) { $0 + $1.totalVolumeLoad }
                }
                let d = item.session.endTime ?? item.session.startTime
                return MuscleSessionVolumePoint(id: item.session.id, date: d, volume: vol)
            }
    }

    var body: some View {
        List {
            if muscleVolumeTrendPoints.count >= 2 {
                Section {
                    HistoryChartCard(title: "Volume per session (lb·rep)") {
                        Chart(muscleVolumeTrendPoints) { pt in
                            BarMark(
                                x: .value("Date", pt.date),
                                y: .value("Volume", pt.volume)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.teal, .mint.opacity(0.85)], startPoint: .bottom, endPoint: .top)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, muscleVolumeTrendPoints.count / 4))) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let n = v.as(Double.self) {
                                        Text(historyFormatCompact(n))
                                    }
                                }
                            }
                        }
                        .frame(height: 188)
                    }
                } header: {
                    Text("Trend")
                }
            }
            ForEach(sessionLogs, id: \.session.id) { item in
                Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Workout")
                        Spacer()
                        Text(item.session.workout.name)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(item.logs) { log in
                        DisclosureGroup {
                            ForEach(log.loggedSets) { set in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
                                        if set.isWarmup {
                                            Text("Warm-up")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.quaternary, in: Capsule())
                                        }
                                        Spacer()
                                    }
                                    let summary = set.configurationSummary(fieldNames: log.workoutExercise.configurationFields)
                                    if !summary.isEmpty {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dataVM.displayName(for: log.workoutExercise))
                                if let slotLabel = HistoryView.templateSlotCaption(for: log, session: item.session, dataVM: dataVM) {
                                    Text("Slot: \(slotLabel)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                }
            }
        }
        .navigationTitle(muscleGroupName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MuscleSessionVolumePoint: Identifiable {
    let id: UUID
    let date: Date
    let volume: Double
}

// MARK: - Shared formatters (used by detail views)
extension HistoryView {
    /// Slot label when the session was started from a flexible library workout and row bindings exist.
    static func templateSlotCaption(for log: ExerciseLog, session: WorkoutSession, dataVM: DataManager) -> String? {
        guard case .workout(let libraryId) = session.sessionPlanOrigin,
              let slotUUID = session.workout.templateSlotId(forWorkoutExerciseRow: log.workoutExercise.id),
              let lib = dataVM.workout(id: libraryId),
              lib.hasFlexibleSlots,
              let slot = dataVM.flexibleSlots(from: lib).first(where: { $0.id == slotUUID })
        else { return nil }
        let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
    }

    static func formatDateStatic(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func durationStringStatic(for session: WorkoutSession) -> String {
        let end = session.endTime ?? session.startTime
        let secs = Int(end.timeIntervalSince(session.startTime))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}
