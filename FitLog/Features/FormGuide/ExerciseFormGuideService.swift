//
//  ExerciseFormGuideService.swift
//  FitLog
//
//  Fetches MuscleWiki exercise videos and metadata with in-memory + URLCache caching.
//

import Foundation

@MainActor
@Observable
final class ExerciseFormGuideService {
    private let session: URLSession
    private let apiKey: String?
    private let proxyBaseURL: String?
    private var guideCache: [UUID: ExerciseFormGuide] = [:]
    private var unavailableExerciseIds: Set<UUID> = []
    private var loadStates: [UUID: ExerciseFormGuideLoadState] = [:]
    private var inFlightTasks: [UUID: Task<ExerciseFormGuide?, Never>] = [:]

    init(
        apiKey: String? = MuscleWikiConfig.apiKey,
        proxyBaseURL: String? = MuscleWikiConfig.proxyBaseURL
    ) {
        self.apiKey = apiKey
        self.proxyBaseURL = proxyBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.urlCache = URLCache(
            memoryCapacity: 4 * 1024 * 1024,
            diskCapacity: 5 * 1024 * 1024,
            diskPath: "ExerciseFormGuideURLCache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }

    private var usesProxy: Bool { proxyBaseURL != nil }

    var isConfigured: Bool { usesProxy || apiKey != nil }

    func loadState(for exerciseId: UUID) -> ExerciseFormGuideLoadState {
        loadStates[exerciseId] ?? .idle
    }

    func cachedGuide(for exerciseId: UUID) -> ExerciseFormGuide? {
        guideCache[exerciseId]
    }

    @discardableResult
    func guide(for exercise: Exercise) async -> ExerciseFormGuide? {
        if let cached = guideCache[exercise.id] {
            loadStates[exercise.id] = .loaded(cached)
            return cached
        }

        if unavailableExerciseIds.contains(exercise.id) {
            loadStates[exercise.id] = .unavailable
            return nil
        }

        guard isConfigured else {
            loadStates[exercise.id] = .failed(ExerciseFormGuideError.notConfigured.localizedDescription)
            return nil
        }

        if let existingTask = inFlightTasks[exercise.id] {
            return await existingTask.value
        }

        let task = Task<ExerciseFormGuide?, Never> { @MainActor in
            await self.fetchGuide(for: exercise)
        }
        inFlightTasks[exercise.id] = task
        defer { inFlightTasks.removeValue(forKey: exercise.id) }
        return await task.value
    }

    func preloadGuide(for exercise: Exercise) {
        guard guideCache[exercise.id] == nil,
              !unavailableExerciseIds.contains(exercise.id),
              inFlightTasks[exercise.id] == nil
        else { return }
        Task { await guide(for: exercise) }
    }

    func streamRequestHeaders() -> [String: String] {
        guard !usesProxy, let apiKey else { return [:] }
        return ["X-API-Key": apiKey]
    }

    func wakeProxyHostIfNeeded() {
        guard let baseRaw = proxyBaseURL,
              let root = URL(string: baseRaw) else { return }

        let url = root.appendingPathComponent("health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25

        Task(priority: .utility) {
            _ = try? await session.data(for: request)
        }
    }

    #if DEBUG
    func seedPreviewGuide(_ guide: ExerciseFormGuide) {
        guideCache[guide.fitLogExerciseId] = guide
        loadStates[guide.fitLogExerciseId] = .loaded(guide)
    }
    #endif

    // MARK: - Networking

    private var streamBaseURL: URL {
        if let base = proxyBaseURL, let url = URL(string: base) {
            return url.appending(path: "v1/form-guide/stream/videos/branded")
        }
        return MuscleWikiConfig.muscleWikiBaseURL.appending(path: "stream/videos/branded")
    }

    private func fetchGuide(for exercise: Exercise) async -> ExerciseFormGuide? {
        loadStates[exercise.id] = .loading

        do {
            let payload = try await fetchMuscleWikiPayload(for: exercise)
            guard let guide = ExerciseFormGuidePayloadParser.makeGuide(
                from: payload,
                exercise: exercise,
                streamBaseURL: streamBaseURL
            ) else {
                loadStates[exercise.id] = .failed("No form guide content available for this exercise.")
                return nil
            }
            guideCache[exercise.id] = guide
            loadStates[exercise.id] = .loaded(guide)
            return guide
        } catch ExerciseFormGuideError.noMatch {
            markUnavailable(exercise.id)
            return nil
        } catch {
            loadStates[exercise.id] = .failed(error.localizedDescription)
            return nil
        }
    }

    private func fetchMuscleWikiPayload(for exercise: Exercise) async throws -> MuscleWikiExercisePayload {
        if let mapping = ExerciseFormGuideMapper.mapping(for: exercise),
           let muscleWikiId = mapping.muscleWikiId {
            return try await fetchExercise(id: muscleWikiId)
        }

        let query = ExerciseFormGuideMapper.searchQuery(for: exercise)
        if let searchMatch = try await searchExercise(query: query) {
            return searchMatch
        }

        throw ExerciseFormGuideError.noMatch
    }

    private func fetchExercise(id: Int) async throws -> MuscleWikiExercisePayload {
        let url = MuscleWikiConfig.exerciseURL(id: id)
        let data = try await performGET(url: url)
        return try JSONDecoder().decode(MuscleWikiExercisePayload.self, from: data)
    }

    private func searchExercise(query: String) async throws -> MuscleWikiExercisePayload? {
        guard let url = MuscleWikiConfig.searchURL(query: query, limit: 1) else { return nil }
        let data = try await performGET(url: url)
        let results = try ExerciseFormGuidePayloadParser.decodeSearchResults(from: data)
        guard let first = results.first else { return nil }

        let hasVideos = !(first.videos?.isEmpty ?? true)
        let hasSteps = !(first.steps?.isEmpty ?? true)
        if hasVideos || hasSteps {
            return first
        }
        return try await fetchExercise(id: first.id)
    }

    private func performGET(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !usesProxy, let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ExerciseFormGuideError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw ExerciseFormGuideError.notAuthorized
        case 404:
            throw ExerciseFormGuideError.noMatch
        case 429:
            throw ExerciseFormGuideError.rateLimited
        case 503:
            throw ExerciseFormGuideError.notConfigured
        default:
            throw ExerciseFormGuideError.httpStatus(http.statusCode)
        }
    }

    private func markUnavailable(_ exerciseId: UUID) {
        unavailableExerciseIds.insert(exerciseId)
        loadStates[exerciseId] = .unavailable
    }
}

enum ExerciseFormGuideError: LocalizedError {
    case notConfigured
    case notAuthorized
    case noMatch
    case rateLimited
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Form guide videos are not configured."
        case .notAuthorized:
            return "Form guide API key is invalid or expired."
        case .noMatch:
            return "No form guide found for this exercise."
        case .rateLimited:
            return "Form guide API limit reached. Try again later."
        case .invalidResponse:
            return "Unexpected response from form guide service."
        case .httpStatus(let code):
            return "Form guide request failed (HTTP \(code))."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
