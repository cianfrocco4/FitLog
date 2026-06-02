//
//  ExerciseFormVideoPlayer.swift
//  FitLog
//
//  Looping muted video player for form guide demonstrations.
//

import AVFoundation
import AVKit
import SwiftUI

struct ExerciseFormVideoPlayer: View {
    let video: ExerciseFormGuideVideo
    let requestHeaders: [String: String]
    var isMuted: Bool = true
    var shouldAutoPlay: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ExerciseFormVideoPlayerRepresentable(
            video: video,
            requestHeaders: requestHeaders,
            isMuted: isMuted,
            shouldAutoPlay: shouldAutoPlay && !reduceMotion
        )
        .accessibilityLabel("Exercise demonstration video, \(video.angle.displayName) view")
    }
}

private struct ExerciseFormVideoPlayerRepresentable: UIViewControllerRepresentable {
    let video: ExerciseFormGuideVideo
    let requestHeaders: [String: String]
    let isMuted: Bool
    let shouldAutoPlay: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .secondarySystemBackground
        context.coordinator.configure(
            controller: controller,
            video: video,
            requestHeaders: requestHeaders,
            isMuted: isMuted,
            shouldAutoPlay: shouldAutoPlay
        )
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.configure(
            controller: controller,
            video: video,
            requestHeaders: requestHeaders,
            isMuted: isMuted,
            shouldAutoPlay: shouldAutoPlay
        )
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.teardown()
        controller.player = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var looper: AVPlayerLooper?
        private var player: AVQueuePlayer?
        private var configuredVideoID: String?

        func configure(
            controller: AVPlayerViewController,
            video: ExerciseFormGuideVideo,
            requestHeaders: [String: String],
            isMuted: Bool,
            shouldAutoPlay: Bool
        ) {
            guard configuredVideoID != video.id else {
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

            let asset = AVURLAsset(
                url: video.streamURL,
                options: ["AVURLAssetHTTPHeaderFieldsKey": requestHeaders]
            )
            let item = AVPlayerItem(asset: asset)
            let queuePlayer = AVQueuePlayer(playerItem: item)
            queuePlayer.isMuted = isMuted
            queuePlayer.automaticallyWaitsToMinimizeStalling = true
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            controller.player = queuePlayer
            configuredVideoID = video.id

            if shouldAutoPlay {
                FormGuideAudioSession.activateForMutedVideoPlayback()
                queuePlayer.play()
            }
        }

        func teardown() {
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player = nil
            configuredVideoID = nil
        }
    }
}
