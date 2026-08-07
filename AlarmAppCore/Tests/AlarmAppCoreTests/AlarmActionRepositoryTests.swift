import XCTest
import SwiftData
@testable import AlarmAppCore

final class AlarmActionRepositoryTests: XCTestCase {
    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }

    func testDismissAlarmMarksCancelledWithUserDismiss() async throws {
        let (repo, container) = try makeRepo()
        let now = Date()
        let seeded = try await seedPendingInstance(repo: repo, at: now.addingTimeInterval(60), snoozeEnabled: true)

        let cancelled = try await repo.dismissAlarm(
            alarmId: seeded.alarmId,
            instanceId: seeded.instanceId,
            now: now
        )

        XCTAssertEqual(cancelled, [seeded.instanceId])
        let instance = try fetchInstance(id: seeded.instanceId, container: container)
        XCTAssertEqual(instance.status, .cancelled)
        XCTAssertEqual(instance.cancelledReason, .userDismiss)
    }

    func testSnoozeAlarmCreatesPendingSchedule() async throws {
        let (repo, container) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snoozeMinutes = 9
        let seeded = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(60),
            snoozeEnabled: true,
            snoozeMinutes: snoozeMinutes
        )

        let schedule = try await repo.snoozeAlarm(
            alarmId: seeded.alarmId,
            instanceId: seeded.instanceId,
            now: now
        )

        let expectedFire = SnoozePolicy.fireDate(from: now, minutes: snoozeMinutes)
        XCTAssertEqual(schedule.fireDate.timeIntervalSince(expectedFire), 0, accuracy: 0.001)

        let old = try fetchInstance(id: seeded.instanceId, container: container)
        XCTAssertEqual(old.status, .snoozed)
        XCTAssertEqual(old.cancelledReason, .snoozed)

        let created = try fetchInstance(id: schedule.instanceId, container: container)
        XCTAssertEqual(created.status, .pending)
        XCTAssertNil(created.cancelledReason)
        XCTAssertEqual(created.alarm?.id, seeded.alarmId)
    }

    func testSnoozeDisabledThrows() async throws {
        let (repo, _) = try makeRepo()
        let now = Date()
        let seeded = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(60),
            snoozeEnabled: false
        )

        do {
            _ = try await repo.snoozeAlarm(
                alarmId: seeded.alarmId,
                instanceId: seeded.instanceId,
                now: now
            )
            XCTFail("Expected snoozeDisabled")
        } catch SwiftDataAlarmRepositoryError.snoozeDisabled {
            // expected
        }
    }

    func testCancelAllNextHoursOnlyInsideWindow() async throws {
        let (repo, container) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let inside = try await seedPendingInstance(repo: repo, at: now.addingTimeInterval(60 * 60), title: "Inside")
        let outside = try await seedPendingInstance(repo: repo, at: now.addingTimeInterval(4 * 60 * 60), title: "Outside")

        let cancelled = try await repo.cancel(
            scope: .allNextHours(3),
            reason: .nextHoursWindow,
            now: now
        )

        XCTAssertEqual(Set(cancelled), [inside.instanceId])
        let insideInstance = try fetchInstance(id: inside.instanceId, container: container)
        let outsideInstance = try fetchInstance(id: outside.instanceId, container: container)
        XCTAssertEqual(insideInstance.status, .cancelled)
        XCTAssertEqual(insideInstance.cancelledReason, .nextHoursWindow)
        XCTAssertEqual(outsideInstance.status, .pending)
        XCTAssertNil(outsideInstance.cancelledReason)
    }

    func testSetWakeScheduleAlarmIsExclusive() async throws {
        let (repo, _) = try makeRepo()
        let now = Date()
        let a = try await seedPendingInstance(repo: repo, at: now.addingTimeInterval(120), title: "A")
        let b = try await seedPendingInstance(repo: repo, at: now.addingTimeInterval(180), title: "B")

        try await repo.setWakeScheduleAlarm(alarmId: a.alarmId)
        try await repo.setWakeScheduleAlarm(alarmId: b.alarmId)

        let alarms = try await repo.fetchActiveAlarms()
        let wakeIds = Set(alarms.filter(\.isWakeSchedule).map(\.id))
        XCTAssertEqual(wakeIds, [b.alarmId])
    }

    // MARK: - Helpers

    private struct SeededInstance {
        let alarmId: UUID
        let instanceId: UUID
    }

    private func makeRepo() throws -> (SwiftDataAlarmRepository, ModelContainer) {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataAlarmRepository(modelContainer: container)
        return (repo, container)
    }

    private func seedPendingInstance(
        repo: SwiftDataAlarmRepository,
        at fireDate: Date,
        snoozeEnabled: Bool = true,
        snoozeMinutes: Int = SnoozePolicy.defaultMinutes,
        title: String = "Test"
    ) async throws -> SeededInstance {
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
            snoozeEnabled: snoozeEnabled,
            snoozeMinutes: snoozeMinutes,
            isWakeSchedule: false,
            createdAt: stamp,
            updatedAt: stamp,
            instances: [PreparedInstanceSpec(scheduledDate: day, scheduledTime: time)]
        )

        let result = try await repo.createAlarm(from: prepared)
        let matching = result.schedules.first {
            abs($0.fireDate.timeIntervalSince(fireDate)) < 60
        }
        let instanceId = matching?.instanceId ?? result.schedules[0].instanceId
        return SeededInstance(alarmId: result.alarmId, instanceId: instanceId)
    }

    private func fetchInstance(id: UUID, container: ModelContainer) throws -> AlarmInstance {
        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<AlarmInstance>())
        let instance = try XCTUnwrap(all.first { $0.id == id })
        return instance
    }
}
