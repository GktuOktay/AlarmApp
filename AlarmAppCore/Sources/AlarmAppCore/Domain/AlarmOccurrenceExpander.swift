import Foundation

/// One concrete occurrence derived from an alarm’s weekly pattern (not necessarily persisted).
public struct AlarmOccurrence: Sendable, Equatable, Identifiable {
    public var id: String { "\(alarmId.uuidString)-\(dayStart.timeIntervalSince1970)" }
    public let alarmId: UUID
    public let dayStart: Date
    public let time: ClockTime
    public let title: String
    public let groupId: UUID?
    public let groupName: String?
    public let status: AlarmStatus

    public init(
        alarmId: UUID,
        dayStart: Date,
        time: ClockTime,
        title: String,
        groupId: UUID? = nil,
        groupName: String? = nil,
        status: AlarmStatus = .pending
    ) {
        self.alarmId = alarmId
        self.dayStart = dayStart
        self.time = time
        self.title = title
        self.groupId = groupId
        self.groupName = groupName
        self.status = status
    }
}

/// Value snapshot used to expand occurrences without SwiftData models.
public struct AlarmPatternSnapshot: Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let time: ClockTime
    public let daysOfWeek: [Weekday]
    public let isActive: Bool
    public let endsOn: Date?
    public let createdAt: Date
    public let groupId: UUID?
    public let groupName: String?

    public init(
        id: UUID,
        title: String,
        time: ClockTime,
        daysOfWeek: [Weekday],
        isActive: Bool,
        endsOn: Date?,
        createdAt: Date,
        groupId: UUID? = nil,
        groupName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.isActive = isActive
        self.endsOn = endsOn
        self.createdAt = createdAt
        self.groupId = groupId
        self.groupName = groupName
    }
}

public typealias BypassExceptionTuple = (
    alarmId: UUID?,
    groupId: UUID?,
    start: Date,
    end: Date?,
    action: ExceptionAction,
    type: ExceptionType
)

/// Expands weekly alarm patterns into calendar occurrences (source of truth for “which days ring”).
public enum AlarmOccurrenceExpander {
    public static func matchesPattern(
        day: Date,
        alarm: AlarmPatternSnapshot,
        exceptions: [BypassExceptionTuple],
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard alarm.isActive else { return false }
        let dayStart = calendar.startOfDay(for: day)
        let createdDay = calendar.startOfDay(for: alarm.createdAt)
        guard dayStart >= createdDay else { return false }
        if let endsOn = alarm.endsOn {
            guard dayStart <= calendar.startOfDay(for: endsOn) else { return false }
        }
        let weekdayIndex = calendar.component(.weekday, from: dayStart)
        guard let weekday = Weekday.from(calendarWeekday: weekdayIndex),
              alarm.daysOfWeek.contains(weekday)
        else { return false }
        return !BypassAlarms.isSkipped(
            day: dayStart,
            alarmId: alarm.id,
            groupId: alarm.groupId,
            exceptions: exceptions,
            calendar: calendar
        )
    }

    public static func expand(
        alarms: [AlarmPatternSnapshot],
        exceptions: [BypassExceptionTuple],
        from startDay: Date,
        to endDay: Date,
        statuses: [UUID: [Date: AlarmStatus]] = [:],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [AlarmOccurrence] {
        let start = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)
        guard start <= end else { return [] }

        var result: [AlarmOccurrence] = []
        var day = start
        while day <= end {
            for alarm in alarms {
                guard matchesPattern(day: day, alarm: alarm, exceptions: exceptions, calendar: calendar) else {
                    continue
                }
                let status = statuses[alarm.id]?[day] ?? .pending
                result.append(
                    AlarmOccurrence(
                        alarmId: alarm.id,
                        dayStart: day,
                        time: alarm.time,
                        title: alarm.title,
                        groupId: alarm.groupId,
                        groupName: alarm.groupName,
                        status: status
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result.sorted {
            if $0.dayStart != $1.dayStart { return $0.dayStart < $1.dayStart }
            return $0.time < $1.time
        }
    }

    public static func nextOccurrences(
        alarm: AlarmPatternSnapshot,
        exceptions: [BypassExceptionTuple],
        from startDay: Date,
        limit: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [AlarmOccurrence] {
        guard limit > 0 else { return [] }
        let start = calendar.startOfDay(for: startDay)
        guard let far = calendar.date(byAdding: .day, value: 366, to: start) else { return [] }
        return Array(
            expand(
                alarms: [alarm],
                exceptions: exceptions,
                from: start,
                to: far,
                calendar: calendar
            ).prefix(limit)
        )
    }
}
