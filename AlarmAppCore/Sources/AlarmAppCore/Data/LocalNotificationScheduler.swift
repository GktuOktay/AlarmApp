import Foundation
@preconcurrency import UserNotifications

public enum LocalNotificationSchedulerError: Error, Sendable {
    case notAuthorized
}

/// Schedules local notifications. `UNUserNotificationCenter` is not `Sendable`;
/// we mark the wrapper `@unchecked Sendable` because the shared center is used
/// only through Apple’s async APIs from cooperative contexts.
public struct LocalNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let criticalAlertsEnabled: Bool

    public init(
        center: UNUserNotificationCenter = .current(),
        criticalAlertsEnabled: Bool = false
    ) {
        self.center = center
        self.criticalAlertsEnabled = criticalAlertsEnabled
    }

    public func prepareCategories() async {
        let stop = UNNotificationAction(
            identifier: AlarmNotificationAction.stopToday,
            title: "Alarmı kapat",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: AlarmNotificationAction.snooze,
            title: "Ertele",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: AlarmNotificationAction.categoryId,
            actions: [stop, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Current notification authorization status, for display in Settings.
    public func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
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
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = makeSound(soundId: soundId, soundVolume: soundVolume)
        content.categoryIdentifier = AlarmNotificationAction.categoryId
        content.userInfo = [
            "instanceId": instanceId.uuidString,
            "alarmId": alarmId.uuidString,
            "groupName": title,
            "soundId": soundId,
            "soundVolume": soundVolume,
        ]
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: instanceId.uuidString,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    public func cancelPending(instanceIds: [UUID]) async {
        let ids = instanceIds.map(\.uuidString)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func makeSound(soundId: String, soundVolume: Double) -> UNNotificationSound {
        let resolved = NotificationSoundResolver.resolve(
            soundId: soundId,
            volume: soundVolume,
            criticalEnabled: criticalAlertsEnabled
        )

        #if os(watchOS)
        // watchOS: named / critical custom sounds are unavailable — use system default.
        switch resolved {
        case .systemDefault, .named, .criticalDefault, .criticalNamed:
            return .default
        }
        #else
        switch resolved {
        case .systemDefault:
            return .default
        case .named(let name):
            return UNNotificationSound(named: UNNotificationSoundName(name))
        case .criticalDefault(let volume):
            return .defaultCriticalSound(withAudioVolume: volume)
        case .criticalNamed(let name, let volume):
            return UNNotificationSound.criticalSoundNamed(
                UNNotificationSoundName(name),
                withAudioVolume: volume
            )
        }
        #endif
    }
}
