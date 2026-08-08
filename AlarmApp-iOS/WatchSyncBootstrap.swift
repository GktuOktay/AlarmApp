import Foundation
import SwiftData
import AlarmAppCore

/// Boots WatchConnectivity, applies incoming sync, and pushes today context (iPhone).
@MainActor
final class WatchSyncBootstrap {
    static let shared = WatchSyncBootstrap()

    private var listenTask: Task<Void, Never>?
    private var container: ModelContainer?

    func start(container: ModelContainer) {
        self.container = container
        let connectivity = WCSessionWatchConnectivityService.shared
        connectivity.activate()

        listenTask?.cancel()
        listenTask = Task {
            let repo = SwiftDataAlarmRepository(modelContainer: container)
            let scheduler = HybridAlarmScheduler()
            for await message in connectivity.incomingMessages {
                await Self.applyIncoming(
                    message,
                    repository: repo,
                    scheduler: scheduler
                )
            }
        }
    }

    func pushTodayContext() async {
        guard let container else { return }
        let repo = SwiftDataAlarmRepository(modelContainer: container)
        guard var context = try? await repo.todayContext() else { return }
        context.autoWakeDetectionEnabled = Self.autoWakeDetectionEnabledFromDefaults()
        do {
            try await WCSessionWatchConnectivityService.shared.send(.todayContextUpdate(context))
        } catch WatchConnectivityError.unsupported {
            // Host without WCSession.
        } catch {
            // Queued-until-activated path should not throw; other errors leave next push to retry.
        }
    }

    private static func autoWakeDetectionEnabledFromDefaults() -> Bool {
        let key = AppPreferences.autoWakePromptEnabledKey
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    func send(_ message: WatchMessage) {
        Task {
            do {
                try await WCSessionWatchConnectivityService.shared.send(message)
            } catch WatchConnectivityError.unsupported {
                // Host without WCSession.
            } catch {
                // Fail-safe: local phone state already updated.
            }
        }
    }

    private static func applyIncoming(
        _ message: WatchMessage,
        repository: SwiftDataAlarmRepository,
        scheduler: some NotificationScheduling
    ) async {
        do {
            let effects = try await WatchMessageSyncApplier.apply(
                message,
                repository: repository
            )
            await scheduler.cancelPending(instanceIds: effects.cancelledInstanceIds)

            for schedule in effects.newSchedules where schedule.fireDate > Date() {
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

            await MainActor.run {
                if let session = RingingPresenter.shared.session,
                   effects.cancelledInstanceIds.contains(session.instanceId) {
                    RingingPresenter.shared.dismiss()
                }
            }
        } catch {
            // Fail-safe: leave local alarms firing if apply fails.
        }
    }
}
