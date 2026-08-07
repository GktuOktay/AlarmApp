import XCTest
@testable import AlarmAppCore

final class WakeDetectionEngineTests: XCTestCase {
    private let engine = WakeDetectionEngine()
    private let fire = Date(timeIntervalSince1970: 1_700_000_000) // fixed wake fire
    private var enabledConfig: WakeDetectionConfig {
        WakeDetectionConfig(windowHoursBeforeWake: 4, cooldownMinutes: 20, isEnabled: true)
    }

    func testNilWakeAlarmReturnsNil() {
        let event = engine.evaluate(
            now: fire.addingTimeInterval(-3600),
            wakeAlarmFire: nil,
            sleepBecameAwake: true,
            motionAboveThreshold: true,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertNil(event)
    }

    func testOutsideWindowBeforeReturnsNil() {
        // 5 hours before fire — outside 4h window
        let now = fire.addingTimeInterval(-5 * 3600)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: false,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertNil(event)
    }

    func testOutsideWindowAfterFireReturnsNil() {
        let now = fire.addingTimeInterval(60)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: true,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertNil(event)
    }

    func testDisabledConfigReturnsNil() {
        var config = enabledConfig
        config.isEnabled = false
        let now = fire.addingTimeInterval(-3600)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: true,
            lastPromptAt: nil,
            config: config
        )
        XCTAssertNil(event)
    }

    func testCooldownSuppressesPrompt() {
        let now = fire.addingTimeInterval(-3600)
        let last = now.addingTimeInterval(-10 * 60) // 10 min ago, cooldown 20
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: false,
            lastPromptAt: last,
            config: enabledConfig
        )
        XCTAssertNil(event)
    }

    func testNoSignalReturnsNil() {
        let now = fire.addingTimeInterval(-3600)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: false,
            motionAboveThreshold: false,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertNil(event)
    }

    func testSleepBecameAwakeOffersPrompt() {
        let now = fire.addingTimeInterval(-2 * 3600)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: false,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertEqual(event, .offerPrompt(at: now))
    }

    func testMotionAboveThresholdOffersPrompt() {
        let now = fire.addingTimeInterval(-30 * 60)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: false,
            motionAboveThreshold: true,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertEqual(event, .offerPrompt(at: now))
    }

    func testEitherSignalOffersPrompt() {
        let now = fire.addingTimeInterval(-90 * 60)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: true,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertEqual(event, .offerPrompt(at: now))
    }

    func testCooldownExpiredAllowsPrompt() {
        let now = fire.addingTimeInterval(-3600)
        let last = now.addingTimeInterval(-21 * 60) // 21 min ago
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: false,
            lastPromptAt: last,
            config: enabledConfig
        )
        XCTAssertEqual(event, .offerPrompt(at: now))
    }

    func testWindowBoundaryInclusiveAtStart() {
        let now = fire.addingTimeInterval(-4 * 3600)
        let event = engine.evaluate(
            now: now,
            wakeAlarmFire: fire,
            sleepBecameAwake: true,
            motionAboveThreshold: false,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertEqual(event, .offerPrompt(at: now))
    }

    func testWindowBoundaryInclusiveAtFire() {
        let event = engine.evaluate(
            now: fire,
            wakeAlarmFire: fire,
            sleepBecameAwake: false,
            motionAboveThreshold: true,
            lastPromptAt: nil,
            config: enabledConfig
        )
        XCTAssertEqual(event, .offerPrompt(at: fire))
    }

    /// Fail-safe: engine must only emit prompt events — never cancel.
    func testEngineOnlyEmitsOfferPrompt() {
        let mirror = Mirror(reflecting: WakeDetectionEngine())
        let hasCancel = mirror.children.contains { child in
            let label = child.label?.lowercased() ?? ""
            return label.contains("cancel") || label.contains("repository")
        }
        XCTAssertFalse(hasCancel)

        let cases = WakeDetectionEvent.offerPrompt(at: fire)
        switch cases {
        case .offerPrompt:
            break
        }
    }
}
