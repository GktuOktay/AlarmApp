import XCTest
@testable import AlarmAppCore

final class WatchMessageTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testTodayContextUpdateRoundTrip() throws {
        let wakeId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let alarmId = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let fire = Date(timeIntervalSince1970: 1_700_000_050)
        let context = TodayContext(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            activeGroups: [
                ActiveGroupSummary(
                    id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                    name: "Sabah",
                    remainingInstances: [
                        InstanceSummary(
                            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                            alarmId: alarmId,
                            time: ClockTime(hour: 7, minute: 30),
                            status: .pending
                        )
                    ]
                )
            ],
            autoWakeDetectionEnabled: false,
            wakeAlarmId: wakeId,
            wakeGroupId: wakeId,
            nextWakeFireDate: fire
        )
        try assertRoundTrip(.todayContextUpdate(context))
    }

    func testTodayContextDecodesMissingAutoWakeAsTrue() throws {
        let legacy = """
        {"date":-978307200,"activeGroups":[]}
        """.data(using: .utf8)!
        let decoded = try decoder.decode(TodayContext.self, from: legacy)
        XCTAssertTrue(decoded.autoWakeDetectionEnabled)
        XCTAssertTrue(decoded.activeGroups.isEmpty)
        XCTAssertNil(decoded.wakeAlarmId)
        XCTAssertNil(decoded.wakeGroupId)
        XCTAssertNil(decoded.nextWakeFireDate)
    }

    func testInstanceSummaryDecodesMissingAlarmIdAsZeroUUID() throws {
        let legacy = """
        {"id":"11111111-2222-3333-4444-555555555555","time":{"hour":7,"minute":0},"status":"pending"}
        """.data(using: .utf8)!
        let decoded = try decoder.decode(InstanceSummary.self, from: legacy)
        XCTAssertEqual(decoded.alarmId, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    func testWakeConfirmedRoundTrip() throws {
        let groupId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let timestamp = Date(timeIntervalSince1970: 1_700_000_100)
        try assertRoundTrip(.wakeConfirmed(groupId: groupId, timestamp: timestamp))
    }

    func testSnoozeAppliedRoundTrip() throws {
        let alarmId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let instanceId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let fireDate = Date(timeIntervalSince1970: 1_700_000_200)
        try assertRoundTrip(.snoozeApplied(alarmId: alarmId, instanceId: instanceId, fireDate: fireDate))
    }

    func testDismissAppliedRoundTrip() throws {
        let alarmId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let instanceId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        try assertRoundTrip(.dismissApplied(alarmId: alarmId, instanceId: instanceId))
    }

    func testBulkCancelAppliedRoundTrip() throws {
        let groupId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let timestamp = Date(timeIntervalSince1970: 1_700_000_300)
        try assertRoundTrip(.bulkCancelApplied(scope: .groupToday(groupId), timestamp: timestamp))
        try assertRoundTrip(.bulkCancelApplied(scope: .allNextHours(3), timestamp: timestamp))
        try assertRoundTrip(.bulkCancelApplied(scope: .allToday, timestamp: timestamp))
    }

    private func assertRoundTrip(_ message: WatchMessage) throws {
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(WatchMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }
}
