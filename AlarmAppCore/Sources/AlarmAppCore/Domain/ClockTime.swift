import Foundation

/// Hour and minute in the user's local calendar (no seconds).
public struct ClockTime: Codable, Hashable, Sendable, Comparable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    public var minutesFromMidnight: Int {
        hour * 60 + minute
    }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }

    public static func from(minutesFromMidnight total: Int) -> ClockTime {
        let normalized = ((total % (24 * 60)) + (24 * 60)) % (24 * 60)
        return ClockTime(hour: normalized / 60, minute: normalized % 60)
    }
}
