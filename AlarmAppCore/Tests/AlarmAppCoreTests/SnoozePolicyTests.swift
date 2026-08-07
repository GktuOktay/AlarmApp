import XCTest
@testable import AlarmAppCore

final class SnoozePolicyTests: XCTestCase {
    func testClampMinutes() {
        XCTAssertEqual(SnoozePolicy.clampMinutes(0), 1)
        XCTAssertEqual(SnoozePolicy.clampMinutes(9), 9)
        XCTAssertEqual(SnoozePolicy.clampMinutes(99), 30)
    }

    func testFireDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let fire = SnoozePolicy.fireDate(from: now, minutes: 9)
        XCTAssertEqual(fire.timeIntervalSince(now), 9 * 60, accuracy: 0.001)
    }
}
