import AVFoundation
import Foundation
import AlarmAppCore

/// Loops the alarm sound continuously while the ringing screen is shown, so audio
/// keeps playing until the user dismisses or snoozes the alarm (not limited by the
/// short duration iOS gives to a single notification sound).
@MainActor
final class ContinuousRingingPlayer {
    private var player: AVAudioPlayer?

    func start(soundId: String, volume: Double) {
        stop()
        let sound = AlarmSoundCatalog.resolve(soundId)
        let fileName = sound.fileName ?? AlarmSoundCatalog.resolve(AlarmSoundCatalog.randomAssignableId()).fileName
        guard let fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: "caf")
        else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = Float(AlarmSoundCatalog.clampVolume(volume))
            newPlayer.play()
            player = newPlayer
        } catch {
            player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
