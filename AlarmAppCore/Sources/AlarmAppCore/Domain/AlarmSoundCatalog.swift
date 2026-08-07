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
    ]

    public static func resolve(_ id: String) -> AlarmSound {
        all.first { $0.id == id } ?? all[0]
    }

    public static func clampVolume(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
