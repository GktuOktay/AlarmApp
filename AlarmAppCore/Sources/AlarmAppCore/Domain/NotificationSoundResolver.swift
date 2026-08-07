import Foundation

public enum ResolvedNotificationSound: Equatable, Sendable {
    case systemDefault
    case named(String)
    case criticalDefault(volume: Float)
    case criticalNamed(String, volume: Float)
}

public enum NotificationSoundResolver {
    public static func resolve(
        soundId: String,
        volume: Double,
        criticalEnabled: Bool
    ) -> ResolvedNotificationSound {
        let sound = AlarmSoundCatalog.resolve(soundId)
        let v = Float(AlarmSoundCatalog.clampVolume(volume))
        if criticalEnabled {
            if let file = sound.fileName {
                return .criticalNamed(file, volume: v)
            }
            return .criticalDefault(volume: v)
        }
        if let file = sound.fileName {
            return .named(file)
        }
        return .systemDefault
    }
}
