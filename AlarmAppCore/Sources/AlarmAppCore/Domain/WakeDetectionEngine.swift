import Foundation

/// Configuration for early-wake prompt evaluation on Watch.
public struct WakeDetectionConfig: Sendable, Equatable {
    public var windowHoursBeforeWake: Int
    public var cooldownMinutes: Int
    public var isEnabled: Bool

    public init(
        windowHoursBeforeWake: Int = 4,
        cooldownMinutes: Int = 20,
        isEnabled: Bool = true
    ) {
        self.windowHoursBeforeWake = windowHoursBeforeWake
        self.cooldownMinutes = cooldownMinutes
        self.isEnabled = isEnabled
    }
}

/// Events produced by wake detection. Prompt only — never cancel.
public enum WakeDetectionEvent: Sendable, Equatable {
    case offerPrompt(at: Date)
}

/// Pure wake-detection policy. Emits `.offerPrompt` only; never cancels alarms.
public struct WakeDetectionEngine: Sendable {
    public init() {}

    /// Evaluates whether to offer the early-wake confirmation prompt.
    ///
    /// Rules:
    /// - Disabled / missing wake fire / outside `[fire − window, fire]` → `nil`
    /// - Within cooldown of `lastPromptAt` → `nil`
    /// - `sleepBecameAwake || motionAboveThreshold` → `.offerPrompt(at: now)`
    ///
    /// Fail-safe: uncertainty yields `nil` (alarms keep firing). This type has no repository
    /// dependency and must never cancel.
    public func evaluate(
        now: Date,
        wakeAlarmFire: Date?,
        sleepBecameAwake: Bool,
        motionAboveThreshold: Bool,
        lastPromptAt: Date?,
        config: WakeDetectionConfig
    ) -> WakeDetectionEvent? {
        guard config.isEnabled else { return nil }
        guard let wakeAlarmFire else { return nil }
        guard isInsideDetectionWindow(now: now, wakeAlarmFire: wakeAlarmFire, config: config) else {
            return nil
        }
        if let lastPromptAt, isInCooldown(now: now, lastPromptAt: lastPromptAt, config: config) {
            return nil
        }
        guard sleepBecameAwake || motionAboveThreshold else { return nil }
        return .offerPrompt(at: now)
    }

    private func isInsideDetectionWindow(
        now: Date,
        wakeAlarmFire: Date,
        config: WakeDetectionConfig
    ) -> Bool {
        let hours = max(config.windowHoursBeforeWake, 0)
        let windowStart = wakeAlarmFire.addingTimeInterval(-TimeInterval(hours) * 3600)
        return now >= windowStart && now <= wakeAlarmFire
    }

    private func isInCooldown(
        now: Date,
        lastPromptAt: Date,
        config: WakeDetectionConfig
    ) -> Bool {
        let minutes = max(config.cooldownMinutes, 0)
        let cooldownEnd = lastPromptAt.addingTimeInterval(TimeInterval(minutes) * 60)
        return now < cooldownEnd
    }
}
