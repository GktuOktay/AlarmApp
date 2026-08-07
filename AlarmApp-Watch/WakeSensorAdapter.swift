import Foundation
import HealthKit
import CoreMotion
import Combine

/// Best-effort Watch sensor feed for `WakeDetectionEngine`.
/// Uses HealthKit sleep analysis and CoreMotion when available; stubs stay false otherwise.
/// Never cancels alarms — only exposes signal flags for the engine.
@MainActor
final class WakeSensorAdapter: ObservableObject {
    @Published private(set) var sleepBecameAwake = false
    @Published private(set) var motionAboveThreshold = false
    /// `true` after HealthKit auth request completed (or HK unavailable path settled).
    /// Not tied to `sharingAuthorized` — that flag is write-only and does not reflect sleep read access.
    @Published private(set) var isHealthKitAuthorized = false

    private let healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    private let motionManager = CMMotionActivityManager()
    private var pollTask: Task<Void, Never>?
    private var lastSleepSampleEnd: Date?

    func start() {
        startMotionUpdatesIfAvailable()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.requestHealthKitAuthorizationIfNeeded()
            while !Task.isCancelled {
                await self?.pollSleepTransition()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        if CMMotionActivityManager.isActivityAvailable() {
            motionManager.stopActivityUpdates()
        }
    }

    func requestHealthKitAuthorizationIfNeeded() async {
        guard let healthStore,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            isHealthKitAuthorized = false
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
        } catch {
            // Denied or unavailable — still attempt queries; empty results keep the engine quiet.
        }
        // Read access is not exposed via `authorizationStatus` / `sharingAuthorized`.
        // After the request finishes, treat as ready-to-query.
        isHealthKitAuthorized = true
    }

    /// Injects signals for simulator / previews / tests without real sensors.
    func applyStub(sleepBecameAwake: Bool? = nil, motionAboveThreshold: Bool? = nil) {
        if let sleepBecameAwake { self.sleepBecameAwake = sleepBecameAwake }
        if let motionAboveThreshold { self.motionAboveThreshold = motionAboveThreshold }
    }

    private func startMotionUpdatesIfAvailable() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            let confident = activity.confidence == .medium || activity.confidence == .high
            let moving = activity.walking || activity.running || activity.automotive
            self.motionAboveThreshold = confident && moving
        }
    }

    private func pollSleepTransition() async {
        // Prefer querying after auth request; empty samples are fine. Do not gate on write status.
        guard isHealthKitAuthorized,
              let healthStore,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return
        }

        let end = Date()
        let start = end.addingTimeInterval(-6 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { [weak self] _, samples, _ in
                Task { @MainActor in
                    defer { continuation.resume() }
                    guard let self else { return }
                    let categories = (samples as? [HKCategorySample]) ?? []
                    // Detect recent transition into awake.
                    let awakeValue = HKCategoryValueSleepAnalysis.awake.rawValue
                    if let latest = categories.first(where: { $0.value == awakeValue }) {
                        let became = self.lastSleepSampleEnd.map { latest.endDate > $0 } ?? true
                        let recent = end.timeIntervalSince(latest.endDate) < 15 * 60
                        self.sleepBecameAwake = became && recent
                        self.lastSleepSampleEnd = latest.endDate
                    } else {
                        self.sleepBecameAwake = false
                    }
                }
            }
            healthStore.execute(query)
        }
    }
}
