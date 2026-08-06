import Foundation
import UserNotifications

public enum LocalNotificationSchedulerError: Error, Sendable {
    case notAuthorized
}

public struct LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func prepareCategories() async {
        let stop = UNNotificationAction(
            identifier: AlarmNotificationAction.stopToday,
            title: "Bugün Kapat",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: AlarmNotificationAction.snooze,
            title: "Ertele (5 dk)",
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

    public func schedule(instanceId: UUID, fireDate: Date, title: String, body: String) async throws {
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = AlarmNotificationAction.categoryId
        content.userInfo = [
            "instanceId": instanceId.uuidString,
            "groupName": title
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
}
