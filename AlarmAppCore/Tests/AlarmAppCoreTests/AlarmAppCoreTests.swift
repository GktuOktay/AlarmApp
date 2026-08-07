import XCTest
@testable import AlarmAppCore

final class AlarmInstanceGeneratorTests: XCTestCase {
    func testInclusiveEndProducesThirteenAlarms() throws {
        let times = try AlarmInstanceGenerator.clockTimes(
            start: ClockTime(hour: 6, minute: 0),
            end: ClockTime(hour: 7, minute: 0),
            intervalMinutes: 5
        )
        XCTAssertEqual(times.count, 13)
        XCTAssertEqual(times.first, ClockTime(hour: 6, minute: 0))
        XCTAssertEqual(times.last, ClockTime(hour: 7, minute: 0))
    }

    func testStartEqualsEndProducesOne() throws {
        let times = try AlarmInstanceGenerator.clockTimes(
            start: ClockTime(hour: 6, minute: 0),
            end: ClockTime(hour: 6, minute: 0),
            intervalMinutes: 5
        )
        XCTAssertEqual(times, [ClockTime(hour: 6, minute: 0)])
    }

    func testInvalidIntervalThrows() {
        XCTAssertThrowsError(
            try AlarmInstanceGenerator.clockTimes(
                start: ClockTime(hour: 6, minute: 0),
                end: ClockTime(hour: 7, minute: 0),
                intervalMinutes: 0
            )
        ) { error in
            XCTAssertEqual(error as? AlarmInstanceGenerationError, .invalidInterval)
        }
    }

    func testOvernightWindow() throws {
        let times = try AlarmInstanceGenerator.clockTimes(
            start: ClockTime(hour: 23, minute: 30),
            end: ClockTime(hour: 0, minute: 30),
            intervalMinutes: 30
        )
        XCTAssertEqual(
            times,
            [
                ClockTime(hour: 23, minute: 30),
                ClockTime(hour: 0, minute: 0),
                ClockTime(hour: 0, minute: 30)
            ]
        )
    }
}

final class CreateAlarmGroupTests: XCTestCase {
    func testPrepareCreatesInstancesOnMatchingWeekdays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // Monday 2026-08-03
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!

        let prepared = try CreateAlarmGroup().prepare(
            CreateAlarmGroupRequest(
                name: "Sabah",
                timeStart: ClockTime(hour: 6, minute: 0),
                timeEnd: ClockTime(hour: 6, minute: 10),
                intervalMinutes: 5,
                daysOfWeek: [.monday],
                horizonDays: 7,
                fromDate: monday,
                calendar: calendar,
                now: monday
            )
        )

        // 3 times/day × 1 Monday in a 7-day window starting Monday = 3
        // Wait: Mon Aug 3 only one Monday in 7 days? Aug 3 Mon ... Aug 9 Sun — one Monday.
        XCTAssertEqual(prepared.instances.count, 3)
        XCTAssertEqual(prepared.instances.map(\.scheduledTime).sorted(), [
            ClockTime(hour: 6, minute: 0),
            ClockTime(hour: 6, minute: 5),
            ClockTime(hour: 6, minute: 10)
        ])
    }

    func testEmptyNameFails() {
        XCTAssertThrowsError(
            try CreateAlarmGroup().prepare(
                CreateAlarmGroupRequest(
                    name: "  ",
                    timeStart: ClockTime(hour: 6, minute: 0),
                    timeEnd: ClockTime(hour: 7, minute: 0),
                    intervalMinutes: 5,
                    daysOfWeek: [.monday]
                )
            )
        ) { error in
            XCTAssertEqual(error as? CreateAlarmGroupError, .emptyName)
        }
    }
}

final class OverlapDetectorTests: XCTestCase {
    func testDetectsSharedDayAndTime() throws {
        let times = try AlarmInstanceGenerator.clockTimes(
            start: ClockTime(hour: 6, minute: 0),
            end: ClockTime(hour: 6, minute: 10),
            intervalMinutes: 5
        )
        let overlaps = AlarmGroupOverlapDetector.overlaps(
            candidateDays: [.monday, .tuesday],
            candidateTimes: times,
            existing: [
                (
                    id: UUID(),
                    name: "Eski",
                    days: [.monday],
                    times: [ClockTime(hour: 6, minute: 5)]
                )
            ]
        )
        XCTAssertEqual(overlaps.count, 1)
        XCTAssertEqual(overlaps[0].time, ClockTime(hour: 6, minute: 5))
        XCTAssertEqual(overlaps[0].weekday, .monday)
    }
}

final class AlarmFireDateTests: XCTestCase {
    func testCombinesDayAndClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let fire = AlarmFireDate.make(day: day, time: ClockTime(hour: 6, minute: 25), calendar: calendar)
        XCTAssertNotNil(fire)
        XCTAssertEqual(calendar.component(.hour, from: fire!), 6)
        XCTAssertEqual(calendar.component(.minute, from: fire!), 25)
        XCTAssertEqual(calendar.component(.day, from: fire!), 6)
    }
}

final class AlarmAppCoreSmokeTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertFalse(AlarmAppCoreModule.version.isEmpty)
    }

    func testInMemoryContainerCreates() throws {
        let container = try ModelContainerFactory.makeInMemory()
        XCTAssertNotNil(container)
    }
}

final class AlarmSoundCatalogTests: XCTestCase {
    func testResolveUnknownFallsBackToDefault() {
        let sound = AlarmSoundCatalog.resolve("nope")
        XCTAssertEqual(sound.id, "default")
        XCTAssertNil(sound.fileName)
    }

    func testClampVolume() {
        XCTAssertEqual(AlarmSoundCatalog.clampVolume(-1), 0)
        XCTAssertEqual(AlarmSoundCatalog.clampVolume(0.5), 0.5)
        XCTAssertEqual(AlarmSoundCatalog.clampVolume(2), 1)
    }

    func testCatalogContainsDefaultAndBundledIds() {
        let ids = Set(AlarmSoundCatalog.all.map(\.id))
        XCTAssertTrue(ids.contains("default"))
        XCTAssertTrue(ids.contains("classic_bell"))
        XCTAssertTrue(ids.contains("digital_beep"))
        XCTAssertTrue(ids.contains("mechanical_ring"))
        XCTAssertTrue(ids.contains("electronic_buzz"))
        XCTAssertTrue(ids.contains("soft_chime"))
        XCTAssertTrue(ids.contains("radar_pulse"))
    }
}

final class NotificationSoundResolverTests: XCTestCase {
    func testDefaultWithoutCritical() {
        let r = NotificationSoundResolver.resolve(
            soundId: "default",
            volume: 0.4,
            criticalEnabled: false
        )
        XCTAssertEqual(r, .systemDefault)
    }

    func testNamedWithoutCritical() {
        let r = NotificationSoundResolver.resolve(
            soundId: "classic_bell",
            volume: 0.8,
            criticalEnabled: false
        )
        XCTAssertEqual(r, .named("classic_bell"))
    }

    func testDefaultWithCriticalUsesVolume() {
        let r = NotificationSoundResolver.resolve(
            soundId: "default",
            volume: 0.25,
            criticalEnabled: true
        )
        XCTAssertEqual(r, .criticalDefault(volume: 0.25))
    }

    func testUnknownIdWithCriticalNamedFallsBackDefaultCritical() {
        let r = NotificationSoundResolver.resolve(
            soundId: "missing",
            volume: 1.5,
            criticalEnabled: true
        )
        XCTAssertEqual(r, .criticalDefault(volume: 1.0))
    }
}
