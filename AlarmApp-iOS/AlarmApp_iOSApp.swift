import SwiftUI
import SwiftData
import UserNotifications
import AlarmAppCore

@main
struct AlarmApp_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            GroupListView()
                .task {
                    let scheduler = LocalNotificationScheduler()
                    await scheduler.prepareCategories()
                    _ = try? await scheduler.requestAuthorization()
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
            try? await LocalNotificationScheduler().schedule(
                instanceId: instanceId,
                fireDate: fire,
                title: response.notification.request.content.title,
                body: "Ertelendi — 5 dakika sonra"
            )
        default:
            break
        }
    }
}
