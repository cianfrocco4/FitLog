//
//  FormGuideAudioSession.swift
//  FitLog
//
//  Configures AVAudioSession so muted form-guide playback never interrupts background music.
//

import AVFoundation

enum FormGuideAudioSession {
    private static var didConfigure = false

    /// Idempotent: use `.ambient` + `.mixWithOthers` so AVPlayer does not take over the audio route.
    static func activateForMutedVideoPlayback() {
        guard !didConfigure else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            didConfigure = true
        } catch {
            // Best-effort; playback remains muted regardless.
        }
    }
}
