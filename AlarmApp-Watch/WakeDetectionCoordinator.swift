import Foundation
import SwiftData
import AlarmAppCore
import Combine

/// Coordinates wake-detection samples → prompt presentation. Never cancels on its own.
@MainActor
final class WakeDetectionCoordinator: ObservableObject {
    static let shared = WakeDetectionCoordinator()

    @Published var promptContext: WakePromptContext?
    @Published private(set) var lastPromptAt: Date?

    private let engine = WakeDetectionEngine()
    private let sensors = WakeSensorAdapter()
    private var container: ModelContainer?
    private var tickTask: Task<Void, Never>?
    private var isEnabled = true

    struct WakePromptContext: Identifiable, Equatable {
        var id: UUID { wakeAlarmId }
        let wakeAlarmId: UUID
        let groupId: UUID?
        let title: String
        let offeredAt: Date
    }

    func start(container: ModelContainer, isEnabled: Bool = true) {
        self.container = container
        self.isEnabled = isEnabled
        sensors.start()
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.evaluateOnce()
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15s
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        sensors.stop()
    }

    func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            promptContext = nil
        }
    }

    func dismissPromptWithoutAction() {
        // Hayır / timeout — no-op on alarms (fail-safe).
        if let offered = promptContext?.offeredAt {
            lastPromptAt = offered
        }
        promptContext = nil
    }

    func acknowledgePromptShowingOptions() {
        if let offered = promptContext?.offeredAt {
            lastPromptAt = offered
        }
        // Keep context so bulk UI can use wake alarm / group; caller clears after cancel or dismiss.
    }

    func clearPrompt() {
        promptContext = nil
    }

    /// Preview / simulator hook.
    func presentForPreview(_ context: WakePromptContext) {
        promptContext = context
    }

    private func evaluateOnce() async {
        guard isEnabled, promptContext == nil else { return }
        guard WatchRingingPresenter.shared.session == nil else { return }
        guard let container else { return }

        let repo = SwiftDataAlarmRepository(modelContainer: container)
        guard let wake = try? await repo.fetchActiveAlarms().first(where: \.isWakeSchedule) else {
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let wakeFire = nextWakeFireDate(for: wake, now: now, calendar: calendar)

        let config = WakeDetectionConfig(
            windowHoursBeforeWake: 4,
            cooldownMinutes: 20,
            isEnabled: isEnabled
        )

        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: wakeFire,
            sleepBecameAwake: sensors.sleepBecameAwake,
            motionAboveThreshold: sensors.motionAboveThreshold,
            lastPromptAt: lastPromptAt,
            config: config
        )

        guard case .offerPrompt(let at)? = event else { return }

        promptContext = WakePromptContext(
            wakeAlarmId: wake.id,
            groupId: wake.groupId,
            title: wake.title.isEmpty ? "Uyanma" : wake.title,
            offeredAt: at
        )
    }

    private func nextWakeFireDate(
        for wake: AlarmSummary,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        // Prefer today's fire if still ahead or within window start; else tomorrow.
        let todayStart = calendar.startOfDay(for: now)
        guard let todayFire = AlarmFireDate.make(day: todayStart, time: wake.time, calendar: calendar) else {
            return nil
        }
        let windowStart = todayFire.addingTimeInterval(-4 * 3600)
        if now >= windowStart && now <= todayFire {
            return todayFire
        }
        if now < windowStart {
            return todayFire
        }
        // After today's fire — look at tomorrow (next sleep cycle).
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return nil
        }
        return AlarmFireDate.make(day: tomorrow, time: wake.time, calendar: calendar)
    }
}
