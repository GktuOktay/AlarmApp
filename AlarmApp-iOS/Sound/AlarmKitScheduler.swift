import AlarmKit
import Foundation
import AlarmAppCore

/// Schedules alarms through AlarmKit (iOS 26+), which presents a native full-screen alert
/// even when the device is locked — unlike a plain local notification. Each of our
/// `AlarmInstance` rows maps 1:1 to one AlarmKit alarm keyed by the same `instanceId`,
/// so the rest of the app's per-instance materialization/cancellation logic is unchanged.
@available(iOS 26.0, *)
struct AlarmKitScheduler: NotificationScheduling {
    private struct Metadata: AlarmMetadata {}

    func prepareCategories() async {
        // AlarmKit alerts render their own stop/secondary buttons; no UNNotificationCategory needed.
    }

    func requestAuthorization() async throws -> Bool {
        let state = try await AlarmManager.shared.requestAuthorization()
        return state == .authorized
    }

    func schedule(
        instanceId: UUID,
        alarmId: UUID,
        fireDate: Date,
        title: String,
        body: String,
        soundId: String,
        soundVolume: Double
    ) async throws {
        guard fireDate > Date() else { return }

        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: String(localized: "ringing.dismiss")),
            textColor: .white,
            systemImageName: "stop.circle.fill"
        )
        let snoozeButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: String(localized: "ringing.snooze")),
            textColor: .white,
            systemImageName: "zzz"
        )
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: stopButton,
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes<Metadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: Metadata(),
            tintColor: .accentColor
        )
        let configuration = AlarmManager.AlarmConfiguration<Metadata>.alarm(
            schedule: .fixed(fireDate),
            attributes: attributes
        )
        _ = try await AlarmManager.shared.schedule(id: instanceId, configuration: configuration)
    }

    func cancelPending(instanceIds: [UUID]) async {
        for id in instanceIds {
            try? AlarmManager.shared.cancel(id: id)
        }
    }
}
