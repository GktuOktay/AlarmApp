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

    func testSetWakeScheduleAlarmNilClears() async throws {
        let (repo, _) = try makeRepo()
        let now = Date()
        let seeded = try await seedPendingInstance(repo: repo, at: now.addingTimeInterval(120), title: "Wake")

        try await repo.setWakeScheduleAlarm(alarmId: seeded.alarmId)
        try await repo.setWakeScheduleAlarm(alarmId: nil)

        let alarms = try await repo.fetchActiveAlarms()
        XCTAssertTrue(alarms.filter(\.isWakeSchedule).isEmpty)
    }

    func testTodayContextIncludesWakeFieldsAndInstanceAlarmId() async throws {
        let (repo, _) = try makeRepo()
        let now = Date()
        let groupId = try await repo.createGroup(name: "Sabah")
        let seeded = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(3600),
            title: "Uyanma",
            groupId: groupId
        )
        try await repo.setWakeScheduleAlarm(alarmId: seeded.alarmId)

        let context = try await repo.todayContext()
        XCTAssertEqual(context.wakeAlarmId, seeded.alarmId)
        XCTAssertEqual(context.wakeGroupId, groupId)
        XCTAssertNotNil(context.nextWakeFireDate)
        let summary = try XCTUnwrap(context.activeGroups.first?.remainingInstances.first)
        XCTAssertEqual(summary.id, seeded.instanceId)
        XCTAssertEqual(summary.alarmId, seeded.alarmId)
    }

    func testCancelGroupTodayCancelsAndBypassesDay() async throws {
        let (repo, container) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let groupId = try await repo.createGroup(name: "Sabah")
        let inGroup = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(60 * 60),
            title: "InGroup",
            groupId: groupId
        )
        let otherGroupId = try await repo.createGroup(name: "Diğer")
        let otherGroup = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(90 * 60),
            title: "OtherGroup",
            groupId: otherGroupId
        )
        let ungrouped = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(120 * 60),
            title: "Ungrouped"
        )

        let cancelled = try await repo.cancel(
            scope: .groupToday(groupId),
            reason: .wakePrompt,
            now: now
        )

        XCTAssertEqual(Set(cancelled), [inGroup.instanceId])

        let cancelledInstance = try fetchInstance(id: inGroup.instanceId, container: container)
        XCTAssertEqual(cancelledInstance.status, .cancelled)
        XCTAssertEqual(cancelledInstance.cancelledReason, .wakePrompt)

        let otherInstance = try fetchInstance(id: otherGroup.instanceId, container: container)
        let ungroupedInstance = try fetchInstance(id: ungrouped.instanceId, container: container)
        XCTAssertEqual(otherInstance.status, .pending)
        XCTAssertEqual(ungroupedInstance.status, .pending)

        let day = calendar.startOfDay(for: now)
        let bypassed = try await repo.isDayBypassed(alarmId: inGroup.alarmId, groupId: groupId, day: day)
        let otherBypassed = try await repo.isDayBypassed(
            alarmId: otherGroup.alarmId,
            groupId: otherGroupId,
            day: day
        )
        let ungroupedBypassed = try await repo.isDayBypassed(
            alarmId: ungrouped.alarmId,
            groupId: nil,
            day: day
        )
        XCTAssertTrue(bypassed)
        XCTAssertFalse(otherBypassed)
        XCTAssertFalse(ungroupedBypassed)
    }

    func testCancelAllTodayCancelsAndBypassesDay() async throws {
        let (repo, container) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let groupId = try await repo.createGroup(name: "Sabah")
        let grouped = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(60 * 60),
            title: "Grouped",
            groupId: groupId
        )
        let ungrouped = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(2 * 60 * 60),
            title: "Ungrouped"
        )
        let tomorrow = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(26 * 60 * 60),
            title: "Tomorrow"
        )

        let cancelled = try await repo.cancel(
            scope: .allToday,
            reason: .manualToday,
            now: now
        )

        XCTAssertEqual(Set(cancelled), [grouped.instanceId, ungrouped.instanceId])

        let groupedInstance = try fetchInstance(id: grouped.instanceId, container: container)
        let ungroupedInstance = try fetchInstance(id: ungrouped.instanceId, container: container)
        let tomorrowInstance = try fetchInstance(id: tomorrow.instanceId, container: container)
        XCTAssertEqual(groupedInstance.status, .cancelled)
        XCTAssertEqual(groupedInstance.cancelledReason, .manualToday)
        XCTAssertEqual(ungroupedInstance.status, .cancelled)
        XCTAssertEqual(tomorrowInstance.status, .pending)

        let day = calendar.startOfDay(for: now)
        let groupedBypassed = try await repo.isDayBypassed(
            alarmId: grouped.alarmId,
            groupId: groupId,
            day: day
        )
        let ungroupedBypassed = try await repo.isDayBypassed(
            alarmId: ungrouped.alarmId,
            groupId: nil,
            day: day
        )
        let tomorrowDay = calendar.startOfDay(for: now.addingTimeInterval(26 * 60 * 60))
        let tomorrowBypassed = try await repo.isDayBypassed(
            alarmId: tomorrow.alarmId,
            groupId: nil,
            day: tomorrowDay
        )
        XCTAssertTrue(groupedBypassed)
        XCTAssertTrue(ungroupedBypassed)
        XCTAssertFalse(tomorrowBypassed)
    }

    func testCountPendingInGroupTodayAfterDismiss() async throws {
        let (repo, _) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let groupId = try await repo.createGroup(name: "Sabah")
        let first = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(60 * 60),
            title: "First",
            groupId: groupId
        )
        _ = try await seedPendingInstance(
            repo: repo,
            at: now.addingTimeInterval(90 * 60),
            title: "Second",
            groupId: groupId
        )

        let before = try await repo.countPendingInGroupToday(groupId: groupId, now: now)
        XCTAssertEqual(before, 2)
        _ = try await repo.dismissAlarm(alarmId: first.alarmId, instanceId: first.instanceId, now: now)
        let remaining = try await repo.countPendingInGroupToday(groupId: groupId, now: now)
        XCTAssertEqual(remaining, 1)
        XCTAssertTrue(
            PostDismissWakeOfferPolicy.shouldOffer(
                groupId: groupId,
                remainingPendingInGroupToday: remaining
            )
        )
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
        title: String = "Test",
        groupId: UUID? = nil
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
            groupId: groupId,
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
