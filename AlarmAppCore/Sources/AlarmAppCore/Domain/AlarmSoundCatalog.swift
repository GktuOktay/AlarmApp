import Foundation

public struct AlarmSound: Identifiable, Sendable, Equatable {
    public let id: String
    public let displayNameKey: String
    /// Bundle resource name without extension; nil = system default notification sound.
    public let fileName: String?

    public init(id: String, displayNameKey: String, fileName: String?) {
        self.id = id
        self.displayNameKey = displayNameKey
        self.fileName = fileName
    }
}

public enum AlarmSoundCatalog {
    public static let all: [AlarmSound] = [
        AlarmSound(id: "default", displayNameKey: "sound.default", fileName: nil),
        AlarmSound(id: "classic_bell", displayNameKey: "sound.classic_bell", fileName: "classic_bell"),
        AlarmSound(id: "digital_beep", displayNameKey: "sound.digital_beep", fileName: "digital_beep"),
        AlarmSound(id: "mechanical_ring", displayNameKey: "sound.mechanical_ring", fileName: "mechanical_ring"),
        AlarmSound(id: "electronic_buzz", displayNameKey: "sound.electronic_buzz", fileName: "electronic_buzz"),
        AlarmSound(id: "soft_chime", displayNameKey: "sound.soft_chime", fileName: "soft_chime"),
        AlarmSound(id: "radar_pulse", displayNameKey: "sound.radar_pulse", fileName: "radar_pulse"),
        AlarmSound(id: "beep_fast_high", displayNameKey: "sound.beep_fast_high", fileName: "beep_fast_high"),
        AlarmSound(id: "beep_slow_low", displayNameKey: "sound.beep_slow_low", fileName: "beep_slow_low"),
        AlarmSound(id: "siren_sweep", displayNameKey: "sound.siren_sweep", fileName: "siren_sweep"),
        AlarmSound(id: "double_beep", displayNameKey: "sound.double_beep", fileName: "double_beep"),
        AlarmSound(id: "triple_pulse", displayNameKey: "sound.triple_pulse", fileName: "triple_pulse"),
        AlarmSound(id: "alarm_classic_urgent", displayNameKey: "sound.alarm_classic_urgent", fileName: "alarm_classic_urgent"),
        AlarmSound(id: "gentle_wake", displayNameKey: "sound.gentle_wake", fileName: "gentle_wake"),
        AlarmSound(id: "rising_tone", displayNameKey: "sound.rising_tone", fileName: "rising_tone"),
        AlarmSound(id: "digital_alarm", displayNameKey: "sound.digital_alarm", fileName: "digital_alarm"),
        AlarmSound(id: "old_clock", displayNameKey: "sound.old_clock", fileName: "old_clock"),
        AlarmSound(id: "buzzer_short", displayNameKey: "sound.buzzer_short", fileName: "buzzer_short"),
        AlarmSound(id: "buzzer_long", displayNameKey: "sound.buzzer_long", fileName: "buzzer_long"),
        AlarmSound(id: "chime_bells", displayNameKey: "sound.chime_bells", fileName: "chime_bells"),
        AlarmSound(id: "morse_like", displayNameKey: "sound.morse_like", fileName: "morse_like"),
        AlarmSound(id: "police_siren", displayNameKey: "sound.police_siren", fileName: "police_siren"),
        AlarmSound(id: "ambulance_siren", displayNameKey: "sound.ambulance_siren", fileName: "ambulance_siren"),
        AlarmSound(id: "soft_piano_like", displayNameKey: "sound.soft_piano_like", fileName: "soft_piano_like"),
        AlarmSound(id: "space_alert", displayNameKey: "sound.space_alert", fileName: "space_alert"),
    ]

    /// Sounds that can be assigned as a real default (excludes the system "default" placeholder).
    public static var assignableSounds: [AlarmSound] {
        all.filter { $0.fileName != nil }
    }

    public static func resolve(_ id: String) -> AlarmSound {
        all.first { $0.id == id } ?? all[0]
    }

    public static func randomAssignableId() -> String {
        assignableSounds.randomElement()?.id ?? all[1].id
    }

    public static func clampVolume(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
