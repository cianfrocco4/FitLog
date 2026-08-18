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
        .onChange(of: video.id) { _, _ in
            playback.resetForNewVideo()
        }
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
        private var configuredVideoID: String?
        private var configuredRetryGeneration: Int?
        private var statusObservation: NSKeyValueObservation?
        private var readyObservation: NSKeyValueObservation?
        private var failureObserver: NSObjectProtocol?
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

            teardown()
            self.playback = playback

            let asset = FormGuideVideoAsset.makeURLAsset(url: video.streamURL, headers: requestHeaders)
            let item = AVPlayerItem(asset: asset)
            let queuePlayer = AVQueuePlayer(playerItem: item)
            queuePlayer.isMuted = isMuted
            queuePlayer.automaticallyWaitsToMinimizeStalling = true
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            playerView.player = queuePlayer
            configuredVideoID = video.id
            configuredRetryGeneration = retryGeneration

            observePlayback(item: item, playerView: playerView, playback: playback)

            if shouldAutoPlay {
                FormGuideAudioSession.activateForMutedVideoPlayback()
                queuePlayer.play()
            }
        }

        func teardown() {
            if let failureObserver {
                NotificationCenter.default.removeObserver(failureObserver)
            }
            failureObserver = nil
            statusObservation?.invalidate()
            statusObservation = nil
            readyObservation?.invalidate()
            readyObservation = nil
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player = nil
            configuredVideoID = nil
            configuredRetryGeneration = nil
        }

        private func observePlayback(
            item: AVPlayerItem,
            playerView: FormGuidePlayerView,
            playback: FormGuideVideoPlaybackState
        ) {
            statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak playback] item, _ in
                let status = item.status
                let message = Self.playbackFailureMessage(for: item)
                Task { @MainActor in
                    guard status == .failed else { return }
                    playback?.isReadyForDisplay = false
                    playback?.failureMessage = message
                }
            }

            readyObservation = playerView.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak playback] layer, _ in
                let isReady = layer.isReadyForDisplay
                Task { @MainActor in
                    guard isReady else { return }
                    playback?.isReadyForDisplay = true
                    playback?.failureMessage = nil
                }
            }

            failureObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak playback] notification in
                let message = Self.playbackFailureMessage(
                    from: notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                )
                playback?.isReadyForDisplay = false
                playback?.failureMessage = message
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
