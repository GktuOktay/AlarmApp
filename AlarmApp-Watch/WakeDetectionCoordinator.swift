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
    /// Latest iPhone today context — wake fire / ids come from here, not a full local catalog.
    private var latestTodayContext: TodayContext?

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
        sensors.start() // requests HealthKit read auth, then polls sleep
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
        } else {
            Task { await sensors.requestHealthKitAuthorizationIfNeeded() }
        }
    }

    /// Called when iPhone pushes `todayContextUpdate` (application context).
    func updateTodayContext(_ context: TodayContext) {
        latestTodayContext = context
        updateEnabled(context.autoWakeDetectionEnabled)
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
        guard let context = latestTodayContext,
              let wakeAlarmId = context.wakeAlarmId,
              let wakeFire = context.nextWakeFireDate else {
            return
        }

        let now = Date()
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

        let title = await wakeTitle(for: wakeAlarmId) ?? "Uyanma"
        promptContext = WakePromptContext(
            wakeAlarmId: wakeAlarmId,
            groupId: context.wakeGroupId,
            title: title,
            offeredAt: at
        )
    }

    private func wakeTitle(for wakeAlarmId: UUID) async -> String? {
        guard let container else { return nil }
        let repo = SwiftDataAlarmRepository(modelContainer: container)
        guard let wake = try? await repo.fetchActiveAlarms().first(where: { $0.id == wakeAlarmId }) else {
            return nil
        }
        return wake.title.isEmpty ? nil : wake.title
    }
}
