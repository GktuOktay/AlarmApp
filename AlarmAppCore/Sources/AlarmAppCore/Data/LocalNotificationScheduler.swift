import Foundation
import UserNotifications

public enum LocalNotificationSchedulerError: Error, Sendable {
    case notAuthorized
}

public struct LocalNotificationScheduler: NotificationScheduling {
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
        switch NotificationSoundResolver.resolve(
            soundId: soundId,
            volume: soundVolume,
            criticalEnabled: criticalAlertsEnabled
        ) {
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
    }
}
