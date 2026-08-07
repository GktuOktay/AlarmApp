import XCTest
@testable import AlarmAppCore

final class WatchConnectivityDeliveryTests: XCTestCase {
    func testTodayContextPrefersApplicationContextEvenWhenReachable() {
        let context = TodayContext(date: Date(), activeGroups: [])
        let delivery = WatchMessageDelivery.choose(
            for: .todayContextUpdate(context),
            isReachable: true
        )
        XCTAssertEqual(delivery, .applicationContext)
    }

    func testReachableUsesSendMessageForActionEvents() {
        let id = UUID()
        XCTAssertEqual(
            WatchMessageDelivery.choose(
                for: .dismissApplied(alarmId: id, instanceId: id),
                isReachable: true
            ),
            .sendMessage
        )
        XCTAssertEqual(
            WatchMessageDelivery.choose(
                for: .snoozeApplied(alarmId: id, instanceId: id, fireDate: Date()),
                isReachable: true
            ),
            .sendMessage
        )
        XCTAssertEqual(
            WatchMessageDelivery.choose(
                for: .bulkCancelApplied(scope: .allToday, timestamp: Date()),
                isReachable: true
            ),
            .sendMessage
        )
        XCTAssertEqual(
            WatchMessageDelivery.choose(
                for: .wakeConfirmed(groupId: id, timestamp: Date()),
                isReachable: true
            ),
            .sendMessage
        )
    }

    func testUnreachableFallsBackToTransferUserInfo() {
        let id = UUID()
        XCTAssertEqual(
            WatchMessageDelivery.choose(
                for: .dismissApplied(alarmId: id, instanceId: id),
                isReachable: false
            ),
            .transferUserInfo
        )
    }

    func testFakeServiceRecordsDeliveryChoice() async throws {
        let fake = FakeWatchConnectivityService()
        fake.isReachable = false
        let message = WatchMessage.dismissApplied(alarmId: UUID(), instanceId: UUID())
        try await fake.send(message)
        XCTAssertEqual(fake.sent, [message])
        XCTAssertEqual(fake.deliveries, [.transferUserInfo])

        fake.isReachable = true
        let context = WatchMessage.todayContextUpdate(TodayContext(date: Date(), activeGroups: []))
        try await fake.send(context)
        XCTAssertEqual(fake.deliveries.last, .applicationContext)
    }

    func testCodecRoundTripThroughDictionary() throws {
        let message = WatchMessage.wakeConfirmed(groupId: UUID(), timestamp: Date(timeIntervalSince1970: 42))
        let dict = try WatchMessageCodec.dictionary(encoding: message)
        let decoded = try WatchMessageCodec.message(from: dict)
        XCTAssertEqual(decoded, message)
    }
}
