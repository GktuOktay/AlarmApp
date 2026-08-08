import XCTest
@testable import AlarmAppCore

final class AppLogTests: XCTestCase {
    override func tearDown() {
        AppLog.setSink(nil)
        AppLog.clearRing()
        super.tearDown()
    }

    func testRecordingSinkCapturesErrorCategory() {
        let sink = RecordingLogSink()
        AppLog.setSink(sink)

        AppLog.error(.wcsession, "ingest dropped undecodable payload")
        AppLog.error(.wake, "notification dismiss failed", error: WatchConnectivityError.unsupported)

        let events = sink.events
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].category, .wcsession)
        XCTAssertEqual(events[0].level, .error)
        XCTAssertEqual(events[0].message, "ingest dropped undecodable payload")
        XCTAssertEqual(events[1].category, .wake)
        XCTAssertNotNil(events[1].errorDescription)
    }

    func testUnsupportedWatchSendCanBeLoggedByCaller() {
        let sink = RecordingLogSink()
        AppLog.setSink(sink)
        AppLog.error(.wcsession, "send failed", error: WatchConnectivityError.unsupported)
        XCTAssertEqual(sink.events.first?.category, .wcsession)
        XCTAssertTrue(sink.events.first?.errorDescription?.contains("unsupported") == true)
    }
}
