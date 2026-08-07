import XCTest
import SwiftData
@testable import AlarmAppCore

final class WatchMessageSyncApplierTests: XCTestCase {
    private var calendar: Calendar { .autoupdatingCurrent }

    func testApplyDismissIsIdempotent() async throws {
        let (repo, _) = try makeRepo()
        let now = Date()
        let seeded = try await seedPending(repo: repo, at: now.addingTimeInterval(60))

        let first = try await WatchMessageSyncApplier.apply(
            .dismissApplied(alarmId: seeded.alarmId, instanceId: seeded.instanceId),
            repository: repo,
            now: now
        )
        let second = try await WatchMessageSyncApplier.apply(
            .dismissApplied(alarmId: seeded.alarmId, instanceId: seeded.instanceId),
            repository: repo,
            now: now
        )

        XCTAssertEqual(first.cancelledInstanceIds, [seeded.instanceId])
        XCTAssertEqual(second.cancelledInstanceIds, [seeded.instanceId])
        XCTAssertTrue(second.newSchedules.isEmpty)
    }

    func testApplyRemoteSnoozeUsesPeerFireDateAndIsIdempotent() async throws {
        let (repo, container) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let peerFire = now.addingTimeInterval(12 * 60)
        let seeded = try await seedPending(repo: repo, at: now.addingTimeInterval(60))

        let first = try await WatchMessageSyncApplier.apply(
            .snoozeApplied(
                alarmId: seeded.alarmId,
                instanceId: seeded.instanceId,
                fireDate: peerFire
            ),
            repository: repo,
            now: now
        )
        XCTAssertEqual(first.cancelledInstanceIds, [seeded.instanceId])
        XCTAssertEqual(first.newSchedules.count, 1)
        XCTAssertEqual(
            first.newSchedules[0].fireDate.timeIntervalSince(peerFire),
            0,
            accuracy: 0.001
        )

        let second = try await WatchMessageSyncApplier.apply(
            .snoozeApplied(
                alarmId: seeded.alarmId,
                instanceId: seeded.instanceId,
                fireDate: peerFire
            ),
            repository: repo,
            now: now
        )
        XCTAssertEqual(second.cancelledInstanceIds, [seeded.instanceId])
        XCTAssertTrue(second.newSchedules.isEmpty)

        let old = try fetchInstance(id: seeded.instanceId, container: container)
        XCTAssertEqual(old.status, .snoozed)
    }

    func testApplyBulkCancel() async throws {
        let (repo, _) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let seeded = try await seedPending(repo: repo, at: now.addingTimeInterval(30 * 60))

        let effects = try await WatchMessageSyncApplier.apply(
            .bulkCancelApplied(scope: .allNextHours(3), timestamp: now),
            repository: repo,
            now: now
        )
        XCTAssertEqual(effects.cancelledInstanceIds, [seeded.instanceId])
    }

    func testTodayContextSuggestsRingingCandidateWhenDue() async throws {
        let (repo, _) = try makeRepo()
        let now = Date()
        let due = now.addingTimeInterval(-30)
        let seeded = try await seedPending(repo: repo, at: due, title: "Sabah")

        let day = calendar.startOfDay(for: due)
        let comps = calendar.dateComponents([.hour, .minute], from: due)
        let time = ClockTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
        let context = TodayContext(
            date: day,
            activeGroups: [
                ActiveGroupSummary(
                    id: UUID(),
                    name: "G",
                    remainingInstances: [
                        InstanceSummary(id: seeded.instanceId, time: time, status: .pending)
                    ]
                )
            ]
        )

        let effects = try await WatchMessageSyncApplier.apply(
            .todayContextUpdate(context),
            repository: repo,
            now: now
        )
        XCTAssertEqual(effects.ringingCandidate?.instanceId, seeded.instanceId)
        XCTAssertEqual(effects.ringingCandidate?.alarmId, seeded.alarmId)
        XCTAssertEqual(effects.ringingCandidate?.title, "Sabah")
    }

    // MARK: - Helpers

    private struct Seeded {
        let alarmId: UUID
        let instanceId: UUID
    }

    private func makeRepo() throws -> (SwiftDataAlarmRepository, ModelContainer) {
        let container = try ModelContainerFactory.makeInMemory()
        return (SwiftDataAlarmRepository(modelContainer: container), container)
    }

    private func seedPending(
        repo: SwiftDataAlarmRepository,
        at fireDate: Date,
        title: String = "Test"
    ) async throws -> Seeded {
        let day = calendar.startOfDay(for: fireDate)
        let comps = calendar.dateComponents([.hour, .minute], from: fireDate)
        let time = ClockTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
        let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: fireDate)) ?? .monday
        let stamp = Date()
        let prepared = PreparedAlarm(
            id: UUID(),
            title: title,
            time: time,
            daysOfWeek: [weekday],
            soundId: "default",
            soundVolume: 1.0,
            groupId: nil,
            endsOn: day,
            snoozeEnabled: true,
            snoozeMinutes: 9,
            isWakeSchedule: false,
            createdAt: stamp,
            updatedAt: stamp,
            instances: [PreparedInstanceSpec(scheduledDate: day, scheduledTime: time)]
        )
        let result = try await repo.createAlarm(from: prepared)
        let matching = result.schedules.first {
            abs($0.fireDate.timeIntervalSince(fireDate)) < 60
        }
        return Seeded(
            alarmId: result.alarmId,
            instanceId: matching?.instanceId ?? result.schedules[0].instanceId
        )
    }

    private func fetchInstance(id: UUID, container: ModelContainer) throws -> AlarmInstance {
        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<AlarmInstance>())
        return try XCTUnwrap(all.first { $0.id == id })
    }
}
