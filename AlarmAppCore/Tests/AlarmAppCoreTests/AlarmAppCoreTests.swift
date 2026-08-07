import XCTest
@testable import AlarmAppCore

final class CreateAlarmTests: XCTestCase {
    func testPrepareStoresWeeklyPatternWithoutInstances() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!

        let prepared = try CreateAlarm().prepare(
            CreateAlarmRequest(
                title: "Sabah",
                time: ClockTime(hour: 6, minute: 0),
                daysOfWeek: [.monday],
                horizonDays: 7,
                fromDate: monday,
                calendar: calendar,
                now: monday
            )
        )

        XCTAssertTrue(prepared.instances.isEmpty)
        XCTAssertEqual(prepared.daysOfWeek, [.monday])
        XCTAssertEqual(prepared.time, ClockTime(hour: 6, minute: 0))
        XCTAssertNil(prepared.endsOn)
        XCTAssertNil(prepared.groupId)
    }

    func testPrepareWithTwoWeekdaysKeepsPatternOnly() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!

        let prepared = try CreateAlarm().prepare(
            CreateAlarmRequest(
                title: "Sabah",
                time: ClockTime(hour: 6, minute: 30),
                daysOfWeek: [.monday, .wednesday],
                horizonDays: 7,
                fromDate: monday,
                calendar: calendar,
                now: monday
            )
        )

        XCTAssertTrue(prepared.instances.isEmpty)
        XCTAssertEqual(prepared.daysOfWeek, [.monday, .wednesday])
    }

    func testEmptyTitleFails() {
        XCTAssertThrowsError(
            try CreateAlarm().prepare(
                CreateAlarmRequest(
                    title: "  ",
                    time: ClockTime(hour: 6, minute: 0),
                    daysOfWeek: [.monday]
                )
            )
        ) { error in
            XCTAssertEqual(error as? CreateAlarmError, .emptyTitle)
        }
    }

    func testPrepareWithEndDateStoresPatternNotInstances() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!

        let prepared = try CreateAlarm().prepare(
            CreateAlarmRequest(
                title: "Hafta",
                time: ClockTime(hour: 7, minute: 0),
                daysOfWeek: [.monday, .wednesday, .friday],
                endDate: friday,
                fromDate: monday,
                calendar: calendar,
                now: monday
            )
        )

        XCTAssertTrue(prepared.instances.isEmpty)
        XCTAssertEqual(prepared.endsOn, calendar.startOfDay(for: friday))
        XCTAssertEqual(prepared.daysOfWeek, [.monday, .wednesday, .friday])
    }

    func testEndDateBeforeStartFails() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!

        XCTAssertThrowsError(
            try CreateAlarm().prepare(
                CreateAlarmRequest(
                    title: "X",
                    time: ClockTime(hour: 6, minute: 0),
                    daysOfWeek: [.monday],
                    endDate: sunday,
                    fromDate: monday,
                    calendar: calendar,
                    now: monday
                )
            )
        ) { error in
            XCTAssertEqual(error as? CreateAlarmError, .endDateBeforeStart)
        }
    }

    func testOneShotCreatesSingleInstance() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!

        let prepared = try CreateAlarm().prepare(
            CreateAlarmRequest(
                title: "Tek",
                time: ClockTime(hour: 8, minute: 0),
                daysOfWeek: [],
                repeats: false,
                fromDate: day,
                calendar: calendar,
                now: day
            )
        )

        XCTAssertEqual(prepared.instances.count, 1)
        XCTAssertEqual(prepared.endsOn, calendar.startOfDay(for: day))
        XCTAssertEqual(prepared.daysOfWeek, [.thursday])
    }

    func testPrepareClampsVolumeAndKeepsSoundId() throws {
        let prepared = try CreateAlarm().prepare(
            CreateAlarmRequest(
                title: "Ses",
                time: ClockTime(hour: 6, minute: 0),
                daysOfWeek: [.monday],
                soundId: "classic_bell",
                soundVolume: 1.8,
                repeats: true
            )
        )
        XCTAssertEqual(prepared.soundId, "classic_bell")
        XCTAssertEqual(prepared.soundVolume, 1.0)
    }

    func testPrepareUnknownSoundBecomesDefault() throws {
        let prepared = try CreateAlarm().prepare(
            CreateAlarmRequest(
                title: "Ses",
                time: ClockTime(hour: 6, minute: 0),
                daysOfWeek: [.monday],
                soundId: "nope",
                soundVolume: 0.3
            )
        )
        XCTAssertEqual(prepared.soundId, "default")
        XCTAssertEqual(prepared.soundVolume, 0.3)
    }
}

final class AlarmOccurrenceExpanderTests: XCTestCase {
    func testExpandsMatchingWeekdaysOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 9))!
        let alarm = AlarmPatternSnapshot(
            id: UUID(),
            title: "Sabah",
            time: ClockTime(hour: 6, minute: 0),
            daysOfWeek: [.monday, .wednesday],
            isActive: true,
            endsOn: nil,
            createdAt: monday
        )

        let occ = AlarmOccurrenceExpander.expand(
            alarms: [alarm],
            exceptions: [],
            from: monday,
            to: sunday,
            calendar: calendar
        )
        XCTAssertEqual(occ.count, 2)
        XCTAssertEqual(calendar.component(.day, from: occ[0].dayStart), 3)
        XCTAssertEqual(calendar.component(.day, from: occ[1].dayStart), 5)
    }

    func testRespectsEndDateAndBypass() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!
        let alarmId = UUID()
        let alarm = AlarmPatternSnapshot(
            id: alarmId,
            title: "Sabah",
            time: ClockTime(hour: 7, minute: 0),
            daysOfWeek: [.monday, .wednesday, .friday],
            isActive: true,
            endsOn: friday,
            createdAt: monday
        )
        let wed = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        let exceptions: [BypassExceptionTuple] = [
            (alarmId, nil, wed, nil, .skip, .singleDay)
        ]

        let occ = AlarmOccurrenceExpander.expand(
            alarms: [alarm],
            exceptions: exceptions,
            from: monday,
            to: friday,
            calendar: calendar
        )
        XCTAssertEqual(occ.count, 2)
        XCTAssertEqual(Set(occ.map { calendar.component(.day, from: $0.dayStart) }), Set([3, 7]))
    }
}

final class BypassAlarmsTests: XCTestCase {
    func testAlarmLevelSkip() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let alarmId = UUID()

        let skipped = BypassAlarms.isSkipped(
            day: day,
            alarmId: alarmId,
            groupId: nil,
            exceptions: [
                (alarmId: alarmId, groupId: nil, start: day, end: nil, action: .skip, type: .singleDay)
            ],
            calendar: calendar
        )
        XCTAssertTrue(skipped)
    }

    func testGroupLevelSkipAppliesToMember() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let alarmId = UUID()
        let groupId = UUID()

        let skipped = BypassAlarms.isSkipped(
            day: day,
            alarmId: alarmId,
            groupId: groupId,
            exceptions: [
                (alarmId: nil, groupId: groupId, start: day, end: nil, action: .skip, type: .singleDay)
            ],
            calendar: calendar
        )
        XCTAssertTrue(skipped)
    }

    func testDateRangeCoversInclusiveDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!
        let mid = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!
        let after = calendar.date(from: DateComponents(year: 2026, month: 8, day: 9))!
        let alarmId = UUID()

        let exceptions: [(UUID?, UUID?, Date, Date?, ExceptionAction, ExceptionType)] = [
            (alarmId, nil, start, end, .skip, .dateRange)
        ]
        XCTAssertTrue(BypassAlarms.isSkipped(day: start, alarmId: alarmId, groupId: nil, exceptions: exceptions, calendar: calendar))
        XCTAssertTrue(BypassAlarms.isSkipped(day: mid, alarmId: alarmId, groupId: nil, exceptions: exceptions, calendar: calendar))
        XCTAssertTrue(BypassAlarms.isSkipped(day: end, alarmId: alarmId, groupId: nil, exceptions: exceptions, calendar: calendar))
        XCTAssertFalse(BypassAlarms.isSkipped(day: after, alarmId: alarmId, groupId: nil, exceptions: exceptions, calendar: calendar))
    }

    func testDraftSameDayIsSingleDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let draft = BypassAlarms.draft(from: day, to: day, target: .alarm(UUID()), calendar: calendar)
        XCTAssertEqual(draft.type, .singleDay)
        XCTAssertNil(draft.endDate)
    }

    func testDraftMultiDayIsDateRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let draft = BypassAlarms.draft(from: start, to: end, target: .group(UUID()), calendar: calendar)
        XCTAssertEqual(draft.type, .dateRange)
        XCTAssertEqual(draft.endDate, calendar.startOfDay(for: end))
    }

    func testPastSingleDayIsFullyPast() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        XCTAssertTrue(BypassAlarms.isFullyPast(start: day, end: nil, type: .singleDay, asOf: today, calendar: calendar))
        XCTAssertFalse(BypassAlarms.isFullyPast(start: today, end: nil, type: .singleDay, asOf: today, calendar: calendar))
    }

    func testPastRangeIsFullyPastOnlyAfterLastDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!
        let onLast = end
        let after = calendar.date(from: DateComponents(year: 2026, month: 8, day: 9))!
        XCTAssertFalse(BypassAlarms.isFullyPast(start: start, end: end, type: .dateRange, asOf: onLast, calendar: calendar))
        XCTAssertTrue(BypassAlarms.isFullyPast(start: start, end: end, type: .dateRange, asOf: after, calendar: calendar))
    }
}

final class OverlapDetectorTests: XCTestCase {
    func testDetectsSharedDayAndTime() {
        let overlaps = AlarmOverlapDetector.overlaps(
            candidateDays: [.monday, .tuesday],
            candidateTime: ClockTime(hour: 6, minute: 5),
            existing: [
                (
                    id: UUID(),
                    title: "Eski",
                    days: [.monday],
                    time: ClockTime(hour: 6, minute: 5)
                )
            ]
        )
        XCTAssertEqual(overlaps.count, 1)
        XCTAssertEqual(overlaps[0].time, ClockTime(hour: 6, minute: 5))
        XCTAssertEqual(overlaps[0].weekday, .monday)
    }

    func testDifferentTimeNoOverlap() {
        let overlaps = AlarmOverlapDetector.overlaps(
            candidateDays: [.monday],
            candidateTime: ClockTime(hour: 7, minute: 0),
            existing: [
                (id: UUID(), title: "Eski", days: [.monday], time: ClockTime(hour: 6, minute: 0))
            ]
        )
        XCTAssertTrue(overlaps.isEmpty)
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
