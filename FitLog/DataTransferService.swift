//
//  DataTransferService.swift
//  FitLog
//
//  Export/import helpers for app data portability.
//

import Foundation

enum DataTransferFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }
}

struct DataTransferPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let backup: BackupSnapshot
}

enum DataTransferError: LocalizedError {
    case unreadableFile
    case invalidJSON
    case invalidCSV
    case emptyImport
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "Could not read the selected file."
        case .invalidJSON:
            return "The JSON file is not a valid FitLog export."
        case .invalidCSV:
            return "The CSV file format is invalid."
        case .emptyImport:
            return "The selected file contains no importable rows."
        case .unsupportedFormat:
            return "Unsupported file format."
        }
    }
}

@MainActor
final class DataTransferServiceClient {
    private weak var dataManager: DataManager?

    init(dataManagerProvider: @escaping () -> DataManager?) {
        self.dataManager = dataManagerProvider()
    }

    func attachDataManager(_ dataManager: DataManager) {
        self.dataManager = dataManager
    }

    func makeArchiveData() throws -> Data {
        guard let dm = dataManager else { throw DataTransferError.unreadableFile }
        return try DataTransferService.makeExportData(format: .json, snapshot: dm.backupSnapshot())
    }

    func makeSessionsCSV() throws -> String {
        guard let dm = dataManager else { throw DataTransferError.unreadableFile }
        let data = try DataTransferService.makeExportData(format: .csv, snapshot: dm.backupSnapshot())
        guard let text = String(data: data, encoding: .utf8) else { throw DataTransferError.invalidCSV }
        return text
    }

    func importArchiveData(_ data: Data) throws {
        guard let dm = dataManager else { throw DataTransferError.unreadableFile }
        let snapshot = try DataTransferService.importSnapshot(from: data, format: .json)
        dm.overwriteWithImportedSnapshot(snapshot)
    }

    func importData(_ data: Data, format: DataTransferFormat) throws {
        guard let dm = dataManager else { throw DataTransferError.unreadableFile }
        let snapshot = try DataTransferService.importSnapshot(from: data, format: format)
        dm.overwriteWithImportedSnapshot(snapshot)
    }

    func writeArchiveExportFile() throws -> URL {
        let data = try makeArchiveData()
        let name = "FitLog-\(dateStamp()).fitlog"
        let url = temporaryExportURL(fileName: name)
        try data.write(to: url, options: .atomic)
        return url
    }

    func writeCSVExportFile() throws -> URL {
        let text = try makeSessionsCSV()
        let name = "FitLog-Sessions-\(dateStamp()).csv"
        let url = temporaryExportURL(fileName: name)
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    private func temporaryExportURL(fileName: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: fileName)
    }

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

enum DataTransferService {
    /// Picks JSON vs CSV from the file URL extension (nil if unknown).
    static func inferFormat(from url: URL) -> DataTransferFormat? {
        switch url.pathExtension.lowercased() {
        case "csv": return .csv
        case "json", "fitlog": return .json
        default: return nil
        }
    }

    static func makeExportData(
        format: DataTransferFormat,
        snapshot: BackupSnapshot
    ) throws -> Data {
        switch format {
        case .json:
            let payload = DataTransferPayload(
                schemaVersion: currentSchemaVersion,
                exportedAt: Date(),
                backup: snapshot
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(payload)
        case .csv:
            return try csvData(from: snapshot)
        }
    }

    static func importSnapshot(from data: Data, format: DataTransferFormat) throws -> BackupSnapshot {
        switch format {
        case .json:
            return try importJSONSnapshot(data)
        case .csv:
            return try importCSVSnapshot(data)
        }
    }

    // MARK: - JSON

    private static func importJSONSnapshot(_ data: Data) throws -> BackupSnapshot {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(DataTransferPayload.self, from: data) {
            return payload.backup
        }
        if let backup = try? decoder.decode(BackupSnapshot.self, from: data) {
            return backup
        }
        throw DataTransferError.invalidJSON
    }

    // MARK: - CSV

    private static func csvData(from snapshot: BackupSnapshot) throws -> Data {
        var lines: [String] = []
        lines.append("type,id,date,workout,exercise,weight,reps,restTime,isWarmup,dropVolume,sessionVolume,sessionDurationSeconds")

        for session in snapshot.sessions {
            let end = session.endTime ?? session.startTime
            let duration = Int(end.timeIntervalSince(session.startTime))
            let sessionVolume = session.exerciseLogs
                .flatMap(\.loggedSets)
                .reduce(0.0) { $0 + $1.totalVolumeLoad }

            for log in session.exerciseLogs {
                let exerciseName = displayNameForCSV(log.workoutExercise, exercises: snapshot.exercises)
                for set in log.loggedSets {
                    let row = [
                        "set",
                        session.id.uuidString,
                        isoDate(end),
                        csvEscape(session.workout.name),
                        csvEscape(exerciseName),
                        csvNumber(set.weight),
                        "\(set.reps)",
                        "\(set.restTime)",
                        set.isWarmup ? "1" : "0",
                        csvNumber(set.dropSegments.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }),
                        csvNumber(sessionVolume),
                        "\(max(0, duration))"
                    ].joined(separator: ",")
                    lines.append(row)
                }
            }
        }

        guard !lines.isEmpty else { throw DataTransferError.invalidCSV }
        let csv = lines.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else { throw DataTransferError.invalidCSV }
        return data
    }

    private static func importCSVSnapshot(_ data: Data) throws -> BackupSnapshot {
        guard let text = String(data: data, encoding: .utf8) else { throw DataTransferError.invalidCSV }
        let rows = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard rows.count > 1 else { throw DataTransferError.emptyImport }

        let header = parseCSVRow(rows[0]).map { $0.lowercased() }
        guard header.contains("date"),
              header.contains("workout"),
              header.contains("exercise"),
              header.contains("weight"),
              header.contains("reps")
        else { throw DataTransferError.invalidCSV }

        let idxDate = header.firstIndex(of: "date")!
        let idxWorkout = header.firstIndex(of: "workout")!
        let idxExercise = header.firstIndex(of: "exercise")!
        let idxWeight = header.firstIndex(of: "weight")!
        let idxReps = header.firstIndex(of: "reps")!
        let idxRest = header.firstIndex(of: "resttime")
        let idxWarm = header.firstIndex(of: "iswarmup")

        var exercisesByName: [String: Exercise] = [:]
        var workoutsByName: [String: Workout] = [:]
        var sessionsByDayAndWorkout: [String: WorkoutSession] = [:]

        for row in rows.dropFirst() {
            let cols = parseCSVRow(row)
            let maxIndex = [idxDate, idxWorkout, idxExercise, idxWeight, idxReps].max() ?? 0
            guard cols.count > maxIndex else { continue }

            let dateText = cols[idxDate].trimmingCharacters(in: .whitespacesAndNewlines)
            let workoutName = cols[idxWorkout].trimmingCharacters(in: .whitespacesAndNewlines)
            let exerciseName = cols[idxExercise].trimmingCharacters(in: .whitespacesAndNewlines)
            let weight = Double(cols[idxWeight].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let reps = Int(cols[idxReps].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let rest = idxRest.flatMap { idx -> Int? in
                guard idx < cols.count else { return nil }
                return Int(cols[idx].trimmingCharacters(in: .whitespacesAndNewlines))
            } ?? 90
            let warm = idxWarm.flatMap { idx -> Int? in
                guard idx < cols.count else { return nil }
                return Int(cols[idx].trimmingCharacters(in: .whitespacesAndNewlines))
            } == 1

            guard !workoutName.isEmpty, !exerciseName.isEmpty, reps > 0 else { continue }
            let setDate = parseDate(dateText) ?? Date()

            let exercise: Exercise = {
                if let existing = exercisesByName[exerciseName.lowercased()] { return existing }
                let ex = Exercise(
                    id: UUID(),
                    name: exerciseName,
                    description: "",
                    targetedMuscles: [.other],
                    isCustom: true,
                    configurationOptions: []
                )
                exercisesByName[exerciseName.lowercased()] = ex
                return ex
            }()

            let workout: Workout = {
                if let existing = workoutsByName[workoutName.lowercased()] { return existing }
                let wk = Workout(id: UUID(), name: workoutName, exercises: [])
                workoutsByName[workoutName.lowercased()] = wk
                return wk
            }()

            let dayKey = dayStamp(setDate)
            let sessionKey = "\(dayKey)|\(workout.id.uuidString)"
            var session = sessionsByDayAndWorkout[sessionKey] ?? WorkoutSession(
                id: UUID(),
                workout: workout,
                startTime: setDate,
                endTime: setDate,
                exerciseLogs: [],
                activeExerciseIds: [],
                completedExerciseIds: []
            )

            let rowId: UUID
            if let existing = session.workout.exercises.first(where: { $0.snapshot?.exerciseId == exercise.id }) {
                rowId = existing.id
            } else {
                let we = WorkoutExercise(
                    id: UUID(),
                    exercise: exercise,
                    defaultRestTime: rest,
                    recommendedSets: 3,
                    recommendedReps: "8-12"
                )
                session.workout.exercises.append(we)
                session.exerciseLogs.append(ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: []))
                rowId = we.id
            }

            if let idx = session.exerciseLogs.firstIndex(where: { $0.workoutExercise.id == rowId }) {
                session.exerciseLogs[idx].loggedSets.append(
                    LoggedSet(
                        id: UUID(),
                        weight: weight,
                        reps: reps,
                        restTime: rest,
                        timestamp: setDate,
                        isWarmup: warm,
                        configuration: [:],
                        dropSegments: []
                    )
                )
            }
            session.endTime = max(session.endTime ?? setDate, setDate)
            sessionsByDayAndWorkout[sessionKey] = session
            workoutsByName[workoutName.lowercased()] = session.workout
        }

        let sessions = sessionsByDayAndWorkout.values.sorted { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }
        guard !sessions.isEmpty else { throw DataTransferError.emptyImport }

        let workouts = Array(workoutsByName.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let exercises = Array(exercisesByName.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: exercises,
            workouts: workouts,
            sessions: sessions,
            program: TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date())),
            displayNames: [:]
        )
    }

    // MARK: - Utilities

    private static func displayNameForCSV(_ we: WorkoutExercise, exercises: [Exercise]) -> String {
        switch we.resolution {
        case .concrete(let snap):
            if let ex = exercises.first(where: { $0.id == snap.exerciseId }) {
                return ex.name
            }
            return snap.nameAtTimeOfLog
        case .flexible(let b):
            if let eid = b.defaultExerciseId, let ex = exercises.first(where: { $0.id == eid }) {
                return ex.name
            }
            let label = b.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return label.isEmpty ? "Open slot" : label
        }
    }

    private static func parseCSVRow(_ line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = next
                } else {
                    inQuotes.toggle()
                }
            } else if ch == ",", !inQuotes {
                out.append(current)
                current = ""
            } else {
                current.append(ch)
            }
            i = line.index(after: i)
        }
        out.append(current)
        return out
    }

    private static func csvEscape(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
        guard needsQuotes else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func csvNumber(_ value: Double) -> String {
        if value == floor(value) { return String(Int(value)) }
        return String(format: "%.2f", value)
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) { return d }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = f.date(from: raw) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: raw)
    }

    private static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current
        let y = c.component(.year, from: date)
        let m = c.component(.month, from: date)
        let d = c.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
