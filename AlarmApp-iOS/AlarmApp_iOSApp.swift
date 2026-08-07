import SwiftUI
import SwiftData
import UserNotifications
import AlarmAppCore

@main
struct AlarmApp_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var preferences = AppPreferences()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.makeOnDisk()
        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(preferences: preferences)
                .task {
                    let scheduler = LocalNotificationScheduler()
                    await scheduler.prepareCategories()
                    _ = try? await scheduler.requestAuthorization()

                    let repo = SwiftDataAlarmRepository(modelContainer: container)
                    _ = try? await repo.purgeExpiredExceptions(asOf: Date())
                    let newSchedules = (try? await repo.extendOpenEndedSchedules(
                        horizonDays: AlarmHorizon.notificationDays,
                        calendar: .autoupdatingCurrent,
                        now: Date()
                    )) ?? []
                    let now = Date()
                    for schedule in newSchedules where schedule.fireDate > now {
                        let timeText = String(
                            format: "%02d:%02d",
                            Calendar.autoupdatingCurrent.component(.hour, from: schedule.fireDate),
                            Calendar.autoupdatingCurrent.component(.minute, from: schedule.fireDate)
                        )
                        try? await scheduler.schedule(
                            instanceId: schedule.instanceId,
                            fireDate: schedule.fireDate,
                            title: String(localized: "calendar.alarm_fallback"),
                            body: String(format: String(localized: "notif.alarm_body"), timeText),
                            soundId: schedule.soundId,
                            soundVolume: schedule.soundVolume
                        )
                    }
                }
        }
        .modelContainer(container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let instanceString = info["instanceId"] as? String,
              let instanceId = UUID(uuidString: instanceString)
        else { return }

        switch response.actionIdentifier {
        case AlarmNotificationAction.stopToday, UNNotificationDefaultActionIdentifier:
            // Full "bugün kapat" needs groupId; for now cancel this notification only.
            // Group-level cancel is available from the list swipe.
            await LocalNotificationScheduler().cancelPending(instanceIds: [instanceId])
        case AlarmNotificationAction.snooze:
            let fire = Date().addingTimeInterval(5 * 60)
            let soundId = (info["soundId"] as? String) ?? "default"
            let soundVolume = (info["soundVolume"] as? Double) ?? 1.0
            try? await LocalNotificationScheduler().schedule(
                instanceId: instanceId,
                fireDate: fire,
                title: response.notification.request.content.title,
                body: String(localized: "notif.snoozed"),
                soundId: soundId,
                soundVolume: soundVolume
            )
        default:
            break
        }
    }
}
