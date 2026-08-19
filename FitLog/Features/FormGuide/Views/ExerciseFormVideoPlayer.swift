//
//  ExerciseFormVideoPlayer.swift
//  FitLog
//
//  Looping muted video player for form guide demonstrations.
//

import AVFoundation
import SwiftUI
import UIKit

struct ExerciseFormVideoPlayer: View {
    let video: ExerciseFormGuideVideo
    let requestHeaders: [String: String]
    var isMuted: Bool = true
    var shouldAutoPlay: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback = FormGuideVideoPlaybackState()

    var body: some View {
        ZStack {
            posterLayer

            ExerciseFormVideoPlayerRepresentable(
                video: video,
                requestHeaders: requestHeaders,
                isMuted: isMuted,
                shouldAutoPlay: shouldAutoPlay && !reduceMotion,
                retryGeneration: playback.retryGeneration,
                playback: playback
            )
            .opacity(playback.isReadyForDisplay ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            if playback.failureMessage == nil, !playback.isReadyForDisplay {
                ProgressView()
                    .controlSize(.regular)
                    .accessibilityLabel("Loading demonstration video")
            }

            if let failureMessage = playback.failureMessage {
                errorOverlay(message: failureMessage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.12))
        .accessibilityElement(children: playback.failureMessage == nil ? .ignore : .contain)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        if playback.failureMessage != nil {
            return "Exercise demonstration video failed to load, \(video.angle.displayName) view"
        }
        return "Exercise demonstration video, \(video.angle.displayName) view"
    }

    @ViewBuilder
    private var posterLayer: some View {
        if playback.isReadyForDisplay {
            Color.clear
        } else if let imageURL = video.ogImageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Color.clear
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "play.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                playback.retry()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityHint("Reloads the demonstration video")
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

@Observable
private final class FormGuideVideoPlaybackState {
    var isReadyForDisplay = false
    var failureMessage: String?
    var retryGeneration = 0

    func resetForNewVideo() {
        isReadyForDisplay = false
        failureMessage = nil
    }

    func retry() {
        resetForNewVideo()
        retryGeneration += 1
    }
}

private struct ExerciseFormVideoPlayerRepresentable: UIViewRepresentable {
    let video: ExerciseFormGuideVideo
    let requestHeaders: [String: String]
    let isMuted: Bool
    let shouldAutoPlay: Bool
    let retryGeneration: Int
    let playback: FormGuideVideoPlaybackState

    func makeUIView(context: Context) -> FormGuidePlayerView {
        let view = FormGuidePlayerView()
        context.coordinator.configure(
            playerView: view,
            video: video,
            requestHeaders: requestHeaders,
            isMuted: isMuted,
            shouldAutoPlay: shouldAutoPlay,
            retryGeneration: retryGeneration,
            playback: playback
        )
        return view
    }

    func updateUIView(_ uiView: FormGuidePlayerView, context: Context) {
        context.coordinator.configure(
            playerView: uiView,
            video: video,
            requestHeaders: requestHeaders,
            isMuted: isMuted,
            shouldAutoPlay: shouldAutoPlay,
            retryGeneration: retryGeneration,
            playback: playback
        )
    }

    static func dismantleUIView(_ uiView: FormGuidePlayerView, coordinator: Coordinator) {
        coordinator.teardown()
        uiView.player = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var looper: AVPlayerLooper?
        private var player: AVQueuePlayer?
        private weak var playerView: FormGuidePlayerView?
        private var configuredVideoID: String?
        private var configuredRetryGeneration: Int?
        private var currentItemObservation: NSKeyValueObservation?
        private var currentItemStatusObservation: NSKeyValueObservation?
        private var looperStatusObservation: NSKeyValueObservation?
        private var readyObservation: NSKeyValueObservation?
        private var failureObserver: NSObjectProtocol?
        private var loadTask: Task<Void, Never>?
        private weak var playback: FormGuideVideoPlaybackState?

        func configure(
            playerView: FormGuidePlayerView,
            video: ExerciseFormGuideVideo,
            requestHeaders: [String: String],
            isMuted: Bool,
            shouldAutoPlay: Bool,
            retryGeneration: Int,
            playback: FormGuideVideoPlaybackState
        ) {
            self.playback = playback
            self.playerView = playerView

            let configurationUnchanged = configuredVideoID == video.id
                && configuredRetryGeneration == retryGeneration
            if configurationUnchanged {
                player?.isMuted = isMuted
                if shouldAutoPlay {
                    FormGuideAudioSession.activateForMutedVideoPlayback()
                    player?.play()
                } else {
                    player?.pause()
                }
                return
            }

            playback.resetForNewVideo()
            teardown()
            self.playback = playback
            self.playerView = playerView
            configuredVideoID = video.id
            configuredRetryGeneration = retryGeneration

            let videoID = video.id
            let generation = retryGeneration
            let remoteURL = video.streamURL
            let headers = requestHeaders
            let muted = isMuted
            let autoPlay = shouldAutoPlay

            loadTask = Task { [weak self] in
                do {
                    let fileURL = try await FormGuideVideoClipStore.shared.localFile(
                        for: remoteURL,
                        headers: headers
                    )
                    try Task.checkCancellation()
                    await MainActor.run {
                        self?.attachLocalPlayer(
                            fileURL: fileURL,
                            isMuted: muted,
                            shouldAutoPlay: autoPlay,
                            videoID: videoID,
                            retryGeneration: generation
                        )
                    }
                } catch is CancellationError {
                    return
                } catch let urlError as URLError where urlError.code == .cancelled {
                    return
                } catch {
                    if Task.isCancelled { return }
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? Coordinator.playbackFailureMessage(from: error)
                    await MainActor.run {
                        self?.applyFailure(
                            message,
                            videoID: videoID,
                            retryGeneration: generation
                        )
                    }
                }
            }
        }

        private func attachLocalPlayer(
            fileURL: URL,
            isMuted: Bool,
            shouldAutoPlay: Bool,
            videoID: String,
            retryGeneration: Int
        ) {
            guard FormGuideVideoAsset.shouldApplyPlaybackEvent(
                configuredVideoID: configuredVideoID,
                configuredRetryGeneration: configuredRetryGeneration,
                eventVideoID: videoID,
                eventRetryGeneration: retryGeneration
            ) else { return }
            guard let playerView else { return }

            let asset = AVURLAsset(url: fileURL)
            let item = AVPlayerItem(asset: asset)
            let queuePlayer = AVQueuePlayer(playerItem: item)
            queuePlayer.isMuted = isMuted
            queuePlayer.automaticallyWaitsToMinimizeStalling = true
            let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            looper = playerLooper
            player = queuePlayer
            playerView.player = queuePlayer

            observePlayback(
                templateItem: item,
                queuePlayer: queuePlayer,
                looper: playerLooper,
                playerView: playerView,
                videoID: videoID,
                retryGeneration: retryGeneration
            )

            if shouldAutoPlay {
                FormGuideAudioSession.activateForMutedVideoPlayback()
                queuePlayer.play()
            }
        }

        func teardown() {
            loadTask?.cancel()
            loadTask = nil
            if let failureObserver {
                NotificationCenter.default.removeObserver(failureObserver)
            }
            failureObserver = nil
            currentItemObservation?.invalidate()
            currentItemObservation = nil
            currentItemStatusObservation?.invalidate()
            currentItemStatusObservation = nil
            looperStatusObservation?.invalidate()
            looperStatusObservation = nil
            readyObservation?.invalidate()
            readyObservation = nil
            player?.pause()
            looper?.disableLooping()
            looper = nil
            playerView?.player = nil
            player = nil
            configuredVideoID = nil
            configuredRetryGeneration = nil
        }

        private func observePlayback(
            templateItem: AVPlayerItem,
            queuePlayer: AVQueuePlayer,
            looper: AVPlayerLooper,
            playerView: FormGuidePlayerView,
            videoID: String,
            retryGeneration: Int
        ) {
            attachCurrentItemStatusObserver(
                templateItem,
                videoID: videoID,
                retryGeneration: retryGeneration
            )

            currentItemObservation = queuePlayer.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
                guard let item = player.currentItem else { return }
                self?.attachCurrentItemStatusObserver(
                    item,
                    videoID: videoID,
                    retryGeneration: retryGeneration
                )
            }

            looperStatusObservation = looper.observe(\.status, options: [.initial, .new]) { [weak self] looper, _ in
                guard looper.status == .failed else { return }
                self?.applyFailure(
                    Self.playbackFailureMessage(from: looper.error),
                    videoID: videoID,
                    retryGeneration: retryGeneration
                )
            }

            readyObservation = playerView.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                self?.applyReady(
                    layer.isReadyForDisplay,
                    videoID: videoID,
                    retryGeneration: retryGeneration
                )
            }

            failureObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let failedItem = notification.object as? AVPlayerItem,
                      self.playerContains(failedItem)
                else { return }
                self.applyFailure(
                    Self.playbackFailureMessage(
                        from: notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                    ),
                    videoID: videoID,
                    retryGeneration: retryGeneration
                )
            }
        }

        private func attachCurrentItemStatusObserver(
            _ item: AVPlayerItem,
            videoID: String,
            retryGeneration: Int
        ) {
            currentItemStatusObservation?.invalidate()
            currentItemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard item.status == .failed else { return }
                self?.applyFailure(
                    Self.playbackFailureMessage(for: item),
                    videoID: videoID,
                    retryGeneration: retryGeneration
                )
            }
        }

        private func playerContains(_ item: AVPlayerItem) -> Bool {
            if player?.currentItem === item { return true }
            return player?.items().contains { $0 === item } ?? false
        }

        private func applyReady(_ isReady: Bool, videoID: String, retryGeneration: Int) {
            Task { @MainActor [weak self] in
                // AVPlayerLooper briefly reports not-ready on each item advance.
                // Latch true only so loops do not flash the poster/spinner.
                guard let self,
                      isReady,
                      FormGuideVideoAsset.shouldApplyPlaybackEvent(
                        configuredVideoID: self.configuredVideoID,
                        configuredRetryGeneration: self.configuredRetryGeneration,
                        eventVideoID: videoID,
                        eventRetryGeneration: retryGeneration
                      )
                else { return }
                self.playback?.isReadyForDisplay = true
                self.playback?.failureMessage = nil
            }
        }

        private func applyFailure(_ message: String, videoID: String, retryGeneration: Int) {
            Task { @MainActor [weak self] in
                guard let self,
                      FormGuideVideoAsset.shouldApplyPlaybackEvent(
                        configuredVideoID: self.configuredVideoID,
                        configuredRetryGeneration: self.configuredRetryGeneration,
                        eventVideoID: videoID,
                        eventRetryGeneration: retryGeneration
                      )
                else { return }
                self.playback?.isReadyForDisplay = false
                self.playback?.failureMessage = message
            }
        }

        private static func playbackFailureMessage(for item: AVPlayerItem) -> String {
            playbackFailureMessage(from: item.error)
        }

        private static func playbackFailureMessage(from error: Error?) -> String {
            if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                return "This demonstration couldn’t be loaded."
            }
            return "This demonstration couldn’t be loaded. Check your connection and try again."
        }
    }
}

private final class FormGuidePlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#if DEBUG
#Preview("Poster while loading") {
    ExerciseFormVideoPlayer(
        video: ExerciseFormGuideVideo(
            id: "preview-front",
            streamURL: URL(string: "https://example.invalid/squat.mp4")!,
            gender: .male,
            angle: .front,
            ogImageURL: URL(string: "https://example.invalid/squat.jpg")
        ),
        requestHeaders: [:],
        shouldAutoPlay: false
    )
    .frame(height: 220)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .padding()
}

#Preview("Accessibility large") {
    ExerciseFormVideoPlayer(
        video: ExerciseFormGuideVideo(
            id: "preview-a11y",
            streamURL: URL(string: "https://example.invalid/squat.mp4")!,
            gender: .female,
            angle: .front,
            ogImageURL: nil
        ),
        requestHeaders: [:],
        shouldAutoPlay: false
    )
    .frame(height: 260)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .padding()
    .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    ExerciseFormVideoPlayer(
        video: ExerciseFormGuideVideo(
            id: "preview-side",
            streamURL: URL(string: "https://example.invalid/squat-side.mp4")!,
            gender: .male,
            angle: .side,
            ogImageURL: nil
        ),
        requestHeaders: [:],
        shouldAutoPlay: false
    )
    .frame(height: 220)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .padding()
    .preferredColorScheme(.dark)
}
#endif
