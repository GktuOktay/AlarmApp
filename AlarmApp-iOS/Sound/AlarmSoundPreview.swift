import AVFoundation
import Foundation
import AlarmAppCore

@MainActor
final class AlarmSoundPreview {
    private var player: AVAudioPlayer?

    func play(soundId: String, volume: Double) {
        player?.stop()
        let sound = AlarmSoundCatalog.resolve(soundId)
        guard let fileName = sound.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: "caf")
        else {
            player = nil
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = Float(AlarmSoundCatalog.clampVolume(volume))
            player?.play()
        } catch {
            player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
