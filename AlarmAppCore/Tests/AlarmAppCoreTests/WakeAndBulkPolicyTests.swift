import XCTest
@testable import AlarmAppCore

final class WakeAndBulkPolicyTests: XCTestCase {
    func testWakeScheduleReplacesPrevious() {
        let a = UUID(), b = UUID()
        XCTAssertEqual(WakeSchedulePolicy.applying(selectedId: b, currentWakeId: a), b)
    }

    func testNextHoursOnlyInsideWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let inside = now.addingTimeInterval(60 * 60)
        let outside = now.addingTimeInterval(4 * 60 * 60)
        let scope = BulkCancelScope.allNextHours(3)
        XCTAssertTrue(scope.includesFireDate(inside, now: now))
        XCTAssertFalse(scope.includesFireDate(outside, now: now))
    }
}
