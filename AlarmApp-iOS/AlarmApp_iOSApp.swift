import SwiftUI
import SwiftData
import UserNotifications
import AlarmAppCore

enum AppModelStore {
    static var container: ModelContainer!
}

@main
struct AlarmApp_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var preferences = AppPreferences()
    @StateObject private var ringing = RingingPresenter.shared
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.makeOnDisk()
            AppModelStore.container = container
        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(preferences: preferences)
                .environmentObject(ringing)
                .fullScreenCover(item: $ringing.session) { session in
                    AlarmRingingView(session: session) {
                        ringing.dismiss()
                    }
                    .modelContainer(container)
                }
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
                            alarmId: schedule.alarmId,
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

        let alarmId: UUID? = {
            if let s = info["alarmId"] as? String { return UUID(uuidString: s) }
            return nil
        }()

        guard let container = AppModelStore.container else { return }
        let repo = SwiftDataAlarmRepository(modelContainer: container)
        let scheduler = LocalNotificationScheduler()
        let title = response.notification.request.content.title

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            guard let alarmId else { return }
            let session = await MainActor.run {
                RingingPresenter.makeSession(
                    container: container,
                    alarmId: alarmId,
                    instanceId: instanceId,
                    fallbackTitle: title
                )
            }
            await MainActor.run {
                RingingPresenter.shared.present(session)
            }

        case AlarmNotificationAction.stopToday:
            guard let alarmId else { return }
            do {
                let cancelled = try await repo.dismissAlarm(
                    alarmId: alarmId,
                    instanceId: instanceId,
                    now: Date()
                )
                await scheduler.cancelPending(instanceIds: cancelled)
            } catch {
                // Fail-safe: keep firing — do not invent a cancel.
            }

        case AlarmNotificationAction.snooze:
            guard let alarmId else { return }
            do {
                let schedule = try await repo.snoozeAlarm(
                    alarmId: alarmId,
                    instanceId: instanceId,
                    now: Date()
                )
                await scheduler.cancelPending(instanceIds: [instanceId])
                let timeText = String(
                    format: "%02d:%02d",
                    Calendar.autoupdatingCurrent.component(.hour, from: schedule.fireDate),
                    Calendar.autoupdatingCurrent.component(.minute, from: schedule.fireDate)
                )
                try await scheduler.schedule(
                    instanceId: schedule.instanceId,
                    alarmId: schedule.alarmId,
                    fireDate: schedule.fireDate,
                    title: title,
                    body: String(format: String(localized: "notif.alarm_body"), timeText),
                    soundId: schedule.soundId,
                    soundVolume: schedule.soundVolume
                )
            } catch {
                // Fail-safe: snoozeDisabled or missing instance — leave alarm state alone.
            }

        default:
            break
        }
    }
}
