import Foundation

public enum AlarmFireDate {
    /// Combines a day (any time) with a clock time in the given calendar.
    public static func make(day: Date, time: ClockTime, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: start)
    }
}

public struct AlarmSchedule: Sendable, Equatable, Identifiable {
    public var id: UUID { instanceId }
    public let instanceId: UUID
    public let fireDate: Date

    public init(instanceId: UUID, fireDate: Date) {
        self.instanceId = instanceId
        self.fireDate = fireDate
    }
}
