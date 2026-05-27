//
//  ExerciseFormGuideView.swift
//  FitLog
//
//  Reusable compact and expanded form guide UI.
//

import SwiftUI

struct ExerciseFormGuideCompactView: View {
    let exercise: Exercise
    var height: CGFloat = 120
    var shouldAutoPlay: Bool = true
    var onTap: (() -> Void)?

    @Environment(ExerciseFormGuideService.self) private var formGuideService
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var guide: ExerciseFormGuide?
    @State private var isLoading = false
    @State private var loadError: String?

    private var serviceLoadState: ExerciseFormGuideLoadState {
        formGuideService.loadState(for: exercise.id)
    }

    private var resolvedGuide: ExerciseFormGuide? {
        guide ?? formGuideService.cachedGuide(for: exercise.id)
    }

    var body: some View {
        Group {
            if let resolvedGuide, let video = resolvedGuide.bestVideo(
                gender: userPreferences.formGuideGender,
                angle: userPreferences.formGuideAngle
            ) {
                Button {
                    onTap?()
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        ExerciseFormVideoPlayer(
                            video: video,
                            requestHeaders: formGuideService.streamRequestHeaders(),
                            shouldAutoPlay: shouldAutoPlay && !reduceMotion
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 6) {
                            Image(systemName: "figure.strengthtraining.traditional")
                            Text("Form guide")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(10)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Form guide for \(exercise.name)")
                .accessibilityHint("Double tap to open full form guide")
            } else if let resolvedGuide, onTap != nil {
                Button {
                    onTap?()
                } label: {
                    stepsOnlyPlaceholder(for: resolvedGuide)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Form tips for \(exercise.name)")
                .accessibilityHint("Double tap to open full form guide")
            } else if isLoading || serviceLoadState == .loading {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: height)
                    .overlay {
                        ProgressView()
                    }
            } else if let loadError {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: height)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "play.rectangle.on.rectangle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(loadError)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                        }
                    }
                    .accessibilityLabel(loadError)
            }
        }
        .task(id: exercise.id) {
            await loadGuideIfNeeded()
        }
        .onChange(of: serviceLoadState) { _, newState in
            syncFromServiceLoadState(newState)
        }
    }

    private func stepsOnlyPlaceholder(for guide: ExerciseFormGuide) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.08))
            .frame(height: height)
            .overlay {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.traditional")
                        Text("Form tips")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    if let cue = guide.keyCue ?? guide.steps.first {
                        Text(cue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
    }

    private func loadGuideIfNeeded() async {
        guard formGuideService.isConfigured else { return }
        if let cached = formGuideService.cachedGuide(for: exercise.id) {
            guide = cached
            loadError = nil
            return
        }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        guide = await formGuideService.guide(for: exercise)
        if guide == nil {
            guide = formGuideService.cachedGuide(for: exercise.id)
        }
        applyLoadErrorIfNeeded()
    }

    private func syncFromServiceLoadState(_ state: ExerciseFormGuideLoadState) {
        if case .loaded(let loadedGuide) = state {
            guide = loadedGuide
            loadError = nil
            return
        }
        if guide == nil, formGuideService.cachedGuide(for: exercise.id) != nil {
            guide = formGuideService.cachedGuide(for: exercise.id)
            loadError = nil
            return
        }
        if !isLoading {
            applyLoadErrorIfNeeded()
        }
    }

    private func applyLoadErrorIfNeeded() {
        guard guide == nil else {
            loadError = nil
            return
        }
        switch formGuideService.loadState(for: exercise.id) {
        case .failed(let message):
            loadError = message
        case .unavailable:
            loadError = "Video unavailable for this exercise."
        default:
            if formGuideService.isConfigured {
                loadError = "Loading form guide\u{2026}"
            }
        }
    }
}

struct ExerciseFormGuideInfoButton: View {
    let exercise: Exercise

    @Environment(ExerciseFormGuideService.self) private var formGuideService
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var presentedExercise: Exercise?

    var body: some View {
        Button {
            presentedExercise = exercise
        } label: {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Form guide for \(exercise.name)")
        .accessibilityHint("Shows exercise demonstration and form tips")
        .sheet(item: $presentedExercise) { exercise in
            ExerciseFormGuideSheet(exercise: exercise)
                .environment(formGuideService)
                .environmentObject(aiService)
                .environmentObject(userPreferences)
        }
    }
}

struct ExerciseFormGuideSheet: View {
    let exercise: Exercise

    @Environment(ExerciseFormGuideService.self) private var formGuideService
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var guide: ExerciseFormGuide?
    @State private var formTips: [String] = []
    @State private var formTipsLoading = false
    @State private var loadError: String?
    @State private var selectedAngle: FormGuideAngle = .front
    @State private var selectedGender: FormGuideGender = .male
    @State private var selectedTipIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    videoSection
                    keyCueSection
                    tipsCarouselSection
                    stepsSection
                }
                .padding()
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: exercise.id) {
                selectedGender = userPreferences.formGuideGender
                selectedAngle = userPreferences.formGuideAngle
                await loadContent()
            }
            .sensoryFeedback(.selection, trigger: selectedAngle)
            .sensoryFeedback(.selection, trigger: selectedGender)
        }
    }

    @ViewBuilder
    private var videoSection: some View {
        if let guide, guide.bestVideo(gender: selectedGender, angle: selectedAngle) != nil {
            VStack(alignment: .leading, spacing: 12) {
                TabView(selection: $selectedAngle) {
                    ForEach(availableAngles(in: guide, gender: selectedGender), id: \.self) { angle in
                        if let clip = guide.bestVideo(gender: selectedGender, angle: angle) {
                            ExerciseFormVideoPlayer(
                                video: clip,
                                requestHeaders: formGuideService.streamRequestHeaders(),
                                shouldAutoPlay: !reduceMotion
                            )
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .tag(angle)
                        }
                    }
                }
                .frame(height: 260)
                .tabViewStyle(.page(indexDisplayMode: availableAngles(in: guide, gender: selectedGender).count > 1 ? .automatic : .never))

                HStack {
                    Picker("Demo model", selection: $selectedGender) {
                        ForEach(FormGuideGender.allCases) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Demonstration model")
                }
                .onChange(of: selectedGender) { _, newValue in
                    userPreferences.formGuideGender = newValue
                    if !availableAngles(in: guide, gender: newValue).contains(selectedAngle) {
                        selectedAngle = availableAngles(in: guide, gender: newValue).first ?? .front
                    }
                }
                .onChange(of: selectedAngle) { _, newValue in
                    userPreferences.formGuideAngle = newValue
                }
            }
        } else if formGuideService.isConfigured {
            unavailableVideoPlaceholder
        } else {
            unavailableVideoPlaceholder
        }
    }

    @ViewBuilder
    private var keyCueSection: some View {
        if let cue = displayedTips.first {
            VStack(alignment: .leading, spacing: 8) {
                Text("Key point")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(cue)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var tipsCarouselSection: some View {
        if !displayedTips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Coach's cues")
                    .font(.headline)
                if displayedTips.count > 1, dynamicTypeSize < .accessibility2 {
                    TabView(selection: $selectedTipIndex) {
                        ForEach(Array(displayedTips.enumerated()), id: \.offset) { index, tip in
                            tipCard(tip)
                                .tag(index)
                        }
                    }
                    .frame(minHeight: 88)
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(displayedTips.enumerated()), id: \.offset) { _, tip in
                            tipCard(tip)
                        }
                    }
                }
            }
        } else if formTipsLoading {
            ProgressView("Loading form tips…")
        }
    }

    @ViewBuilder
    private var stepsSection: some View {
        if let steps = guide?.steps, !steps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Steps")
                    .font(.headline)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func tipCard(_ tip: String) -> some View {
        Text(tip)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var unavailableVideoPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(loadError ?? "Video unavailable for this exercise.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var displayedTips: [String] {
        if !formTips.isEmpty { return formTips }
        return guide?.steps ?? []
    }

    private func availableAngles(in guide: ExerciseFormGuide, gender: FormGuideGender) -> [FormGuideAngle] {
        let angles = FormGuideAngle.allCases.filter { angle in
            guide.videos.contains { $0.gender == gender && $0.angle == angle }
        }
        return angles.isEmpty ? [.front] : angles
    }

    private func loadContent() async {
        formTipsLoading = true
        defer { formTipsLoading = false }

        async let guideTask = formGuideService.guide(for: exercise)
        async let tipsTask = loadFormTips()

        guide = await guideTask
        formTips = await tipsTask

        if guide == nil, formGuideService.isConfigured {
            switch formGuideService.loadState(for: exercise.id) {
            case .failed(let message):
                loadError = message
            case .unavailable:
                loadError = "No demonstration found for this exercise."
            default:
                break
            }
        }
    }

    private func loadFormTips() async -> [String] {
        guard aiService.isConfigured else {
            return ExerciseFormHeuristicTips.tips(for: exercise)
        }
        do {
            return try await aiService.fetchFormTips(for: exercise)
        } catch {
            return ExerciseFormHeuristicTips.tips(for: exercise)
        }
    }
}

struct ExerciseFormGuideLibraryThumbnail: View {
    let exercise: Exercise

    @Environment(ExerciseFormGuideService.self) private var formGuideService
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var guide: ExerciseFormGuide?

    var body: some View {
        Group {
            if let thumbnailURL = thumbnailImageURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        thumbnailPlaceholder
                    case .empty:
                        thumbnailPlaceholder
                            .overlay { ProgressView().controlSize(.small) }
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                thumbnailPlaceholder
            }
        }
        .task(id: exercise.id) {
            guard formGuideService.isConfigured else { return }
            guide = await formGuideService.guide(for: exercise)
        }
        .accessibilityHidden(true)
    }

    private var thumbnailImageURL: URL? {
        guard let guide else { return nil }
        return guide.bestVideo(
            gender: userPreferences.formGuideGender,
            angle: userPreferences.formGuideAngle
        )?.ogImageURL ?? guide.videos.first?.ogImageURL
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }
}

#if DEBUG
// MARK: - Previews

private enum ExerciseFormGuidePreviewData {
    static let squat = Exercise(
        id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        name: "Back Squat (High Bar)",
        description: "Compound lower-body lift.",
        targetedMuscles: [.quads, .glutes]
    )

    static let sampleGuide = ExerciseFormGuide(
        fitLogExerciseId: squat.id,
        title: "Barbell Squat",
        steps: [
            "Set the bar on your upper back and brace your core.",
            "Sit your hips back and down while keeping your chest tall.",
            "Drive through your mid-foot to stand."
        ],
        videos: [
            ExerciseFormGuideVideo(
                id: "male-front-squat.mp4",
                streamURL: URL(string: "https://api.musclewiki.com/stream/videos/branded/squat.mp4")!,
                gender: .male,
                angle: .front,
                ogImageURL: URL(string: "https://api.musclewiki.com/og/squat.jpg")
            ),
            ExerciseFormGuideVideo(
                id: "male-side-squat.mp4",
                streamURL: URL(string: "https://api.musclewiki.com/stream/videos/branded/squat-side.mp4")!,
                gender: .male,
                angle: .side,
                ogImageURL: URL(string: "https://api.musclewiki.com/og/squat-side.jpg")
            )
        ],
        keyCue: "Brace, sit between your hips, and drive the floor away."
    )

    @MainActor
    static func previewService(withGuide: Bool) -> ExerciseFormGuideService {
        let service = ExerciseFormGuideService(apiKey: withGuide ? "preview-key" : nil)
        if withGuide {
            service.seedPreviewGuide(sampleGuide)
        }
        return service
    }
}

#Preview("Compact — with guide") {
    ExerciseFormGuideCompactView(
        exercise: ExerciseFormGuidePreviewData.squat
    )
    .environment(ExerciseFormGuidePreviewData.previewService(withGuide: true))
    .environmentObject(UserPreferences())
    .padding()
}

#Preview("Compact — dark") {
    ExerciseFormGuideCompactView(
        exercise: ExerciseFormGuidePreviewData.squat
    )
    .environment(ExerciseFormGuidePreviewData.previewService(withGuide: true))
    .environmentObject(UserPreferences())
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Info button") {
    ExerciseFormGuideInfoButton(exercise: ExerciseFormGuidePreviewData.squat)
        .environment(ExerciseFormGuidePreviewData.previewService(withGuide: true))
        .environmentObject(AIService(apiKey: nil, baseURL: OpenAIConfig.aiBaseURL, model: OpenAIConfig.aiModel))
        .environmentObject(UserPreferences())
        .padding()
}

#Preview("Sheet — loaded") {
    ExerciseFormGuideSheet(exercise: ExerciseFormGuidePreviewData.squat)
        .environment(ExerciseFormGuidePreviewData.previewService(withGuide: true))
        .environmentObject(AIService(apiKey: nil, baseURL: OpenAIConfig.aiBaseURL, model: OpenAIConfig.aiModel))
        .environmentObject(UserPreferences())
}

#Preview("Library thumbnail") {
    ExerciseFormGuideLibraryThumbnail(exercise: ExerciseFormGuidePreviewData.squat)
        .environment(ExerciseFormGuidePreviewData.previewService(withGuide: true))
        .environmentObject(UserPreferences())
        .padding()
}
#endif
