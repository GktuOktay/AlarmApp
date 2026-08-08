import Foundation
import AlarmAppCore

/// Picks the best available alarm backend at runtime: AlarmKit on iOS 26+ gives a native
/// full-screen alert that shows even over the lock screen; older iOS falls back to the
/// existing local-notification + in-app ringing screen approach.
public struct HybridAlarmScheduler: NotificationScheduling {
    public init() {}

    public func prepareCategories() async {
        if #available(iOS 26.0, *) {
            await AlarmKitScheduler().prepareCategories()
        } else {
            await LocalNotificationScheduler().prepareCategories()
        }
    }

    public func requestAuthorization() async throws -> Bool {
        if #available(iOS 26.0, *) {
            return try await AlarmKitScheduler().requestAuthorization()
        } else {
            return try await LocalNotificationScheduler().requestAuthorization()
        }
    }

    public func schedule(
        instanceId: UUID,
        alarmId: UUID,
        fireDate: Date,
        title: String,
        body: String,
        soundId: String,
        soundVolume: Double
    ) async throws {
        if #available(iOS 26.0, *) {
            try await AlarmKitScheduler().schedule(
                instanceId: instanceId,
                alarmId: alarmId,
                fireDate: fireDate,
                title: title,
                body: body,
                soundId: soundId,
                soundVolume: soundVolume
            )
        } else {
            try await LocalNotificationScheduler().schedule(
                instanceId: instanceId,
                alarmId: alarmId,
                fireDate: fireDate,
                title: title,
                body: body,
                soundId: soundId,
                soundVolume: soundVolume
            )
        }
    }

    public func cancelPending(instanceIds: [UUID]) async {
        if #available(iOS 26.0, *) {
            await AlarmKitScheduler().cancelPending(instanceIds: instanceIds)
        } else {
            await LocalNotificationScheduler().cancelPending(instanceIds: instanceIds)
        }
    }
}
