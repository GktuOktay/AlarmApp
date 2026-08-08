import AVFoundation
import Foundation
import AlarmAppCore

@MainActor
final class AlarmSoundPreview {
    private var player: AVAudioPlayer?

    func play(soundId: String, volume: Double) {
        player?.stop()
        let sound = AlarmSoundCatalog.resolve(soundId)
        let fileName = sound.fileName ?? AlarmSoundCatalog.resolve(AlarmSoundCatalog.randomAssignableId()).fileName
        guard let fileName,
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

    func setVolume(_ volume: Double) {
        player?.volume = Float(AlarmSoundCatalog.clampVolume(volume))
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
