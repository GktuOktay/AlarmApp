import Foundation
import SwiftData
import AlarmAppCore

/// Boots WatchConnectivity and applies incoming sync on watchOS.
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
            let scheduler = LocalNotificationScheduler()
            for await message in connectivity.incomingMessages {
                await Self.applyIncoming(
                    message,
                    repository: repo,
                    scheduler: scheduler
                )
            }
        }
    }

    func send(_ message: WatchMessage) {
        Task {
            try? await WCSessionWatchConnectivityService.shared.send(message)
        }
    }

    private static func applyIncoming(
        _ message: WatchMessage,
        repository: SwiftDataAlarmRepository,
        scheduler: LocalNotificationScheduler
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
                    title: "Alarm",
                    body: "Alarm · \(timeText)",
                    soundId: schedule.soundId,
                    soundVolume: schedule.soundVolume
                )
            }

            await MainActor.run {
                if let session = WatchRingingPresenter.shared.session,
                   effects.cancelledInstanceIds.contains(session.instanceId) {
                    WatchRingingPresenter.shared.dismiss()
                }
                if let candidate = effects.ringingCandidate,
                   WatchRingingPresenter.shared.session == nil {
                    WatchRingingPresenter.shared.present(
                        WatchRingingSession(
                            alarmId: candidate.alarmId,
                            instanceId: candidate.instanceId,
                            groupId: candidate.groupId,
                            title: candidate.title,
                            timeText: candidate.timeText,
                            snoozeEnabled: candidate.snoozeEnabled
                        )
                    )
                }
            }
        } catch {
            // Fail-safe: leave local alarms firing if apply fails.
        }
    }
}
