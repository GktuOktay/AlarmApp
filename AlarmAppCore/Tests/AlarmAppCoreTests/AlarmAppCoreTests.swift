import XCTest
import SwiftData
@testable import AlarmAppCore

final class AlarmAppCoreTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertFalse(AlarmAppCoreModule.version.isEmpty)
    }

    func testInMemoryContainerCreates() throws {
        let container = try ModelContainerFactory.makeInMemory()
        XCTAssertNotNil(container)
    }
}
