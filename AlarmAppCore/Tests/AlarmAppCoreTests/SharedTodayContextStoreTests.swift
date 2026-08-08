import XCTest
@testable import AlarmAppCore

final class SharedTodayContextStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "group.test.alarmapp.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testWriteThenReadRoundTripsTodayContext() {
        let instance = InstanceSummary(
            id: UUID(),
            alarmId: UUID(),
            time: ClockTime(hour: 7, minute: 30),
            status: .pending
        )
        let group = ActiveGroupSummary(id: UUID(), name: "Morning", remainingInstances: [instance])
        let context = TodayContext(
            date: Date(timeIntervalSince1970: 1_723_000_000),
            activeGroups: [group],
            autoWakeDetectionEnabled: false,
            wakeAlarmId: UUID(),
            wakeGroupId: UUID(),
            nextWakeFireDate: Date(timeIntervalSince1970: 1_723_010_000)
        )

        SharedTodayContextStore.write(context, appGroupId: suiteName)
        let decoded = SharedTodayContextStore.read(appGroupId: suiteName)

        XCTAssertEqual(decoded, context)
    }

    func testReadReturnsNilWhenNothingWritten() {
        XCTAssertNil(SharedTodayContextStore.read(appGroupId: suiteName))
    }

    func testReadReturnsNilForUnprovisionedAppGroup() {
        // Simulates the real-world state today: no App Group entitlement exists,
        // so UserDefaults(suiteName:) with a bogus/unprovisioned id degrades to nil
        // reads rather than throwing.
        XCTAssertNil(SharedTodayContextStore.read(appGroupId: "group.not.provisioned.\(UUID().uuidString)"))
    }
}
