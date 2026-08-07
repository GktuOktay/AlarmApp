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
    @Published private(set) var isHealthKitAuthorized = false

    private let healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    private let motionManager = CMMotionActivityManager()
    private var pollTask: Task<Void, Never>?
    private var lastSleepSampleEnd: Date?

    func start() {
        refreshHealthKitAuthorization()
        startMotionUpdatesIfAvailable()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
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

    func refreshHealthKitAuthorization() {
        guard let healthStore,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            isHealthKitAuthorized = false
            return
        }
        let status = healthStore.authorizationStatus(for: sleepType)
        isHealthKitAuthorized = (status == .sharingAuthorized)
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
            // Denied or unavailable — leave unauthorized; engine stays quiet.
        }
        refreshHealthKitAuthorization()
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
