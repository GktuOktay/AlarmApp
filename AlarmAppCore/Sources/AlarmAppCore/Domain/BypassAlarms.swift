import Foundation

public enum BypassTarget: Sendable, Equatable {
    case group(UUID)
    case alarm(UUID)
}

/// Builds skip exception drafts and evaluates coverage / expiry.
public enum BypassAlarms {
    /// Inclusive calendar-day range. Same start/end → single day; otherwise date range.
    public static func draft(
        from startDay: Date,
        to endDay: Date,
        target: BypassTarget,
        calendar: Calendar = .autoupdatingCurrent
    ) -> AlarmExceptionDraft {
        let start = calendar.startOfDay(for: startDay)
        var end = calendar.startOfDay(for: endDay)
        if end < start { end = start }

        let type: ExceptionType = (start == end) ? .singleDay : .dateRange
        let endDate: Date? = (type == .singleDay) ? nil : end

        switch target {
        case .group(let id):
            return AlarmExceptionDraft(
                groupId: id,
                alarmId: nil,
                type: type,
                startDate: start,
                endDate: endDate,
                action: .skip
            )
        case .alarm(let id):
            return AlarmExceptionDraft(
                groupId: nil,
                alarmId: id,
                type: type,
                startDate: start,
                endDate: endDate,
                action: .skip
            )
        }
    }

    public static func singleDayDraft(
        day: Date,
        target: BypassTarget,
        calendar: Calendar = .autoupdatingCurrent
    ) -> AlarmExceptionDraft {
        draft(from: day, to: day, target: target, calendar: calendar)
    }

    /// Last inclusive day covered by the exception.
    public static func lastCoveredDay(
        start: Date,
        end: Date?,
        type: ExceptionType,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let startDay = calendar.startOfDay(for: start)
        switch type {
        case .singleDay:
            return startDay
        case .dateRange, .weeklyOverride:
            if let end {
                return calendar.startOfDay(for: end)
            }
            // Open-ended: treat as still active forever (never purge by date alone).
            return calendar.date(byAdding: .year, value: 100, to: startDay) ?? startDay
        }
    }

    /// True when the exception’s last day is before `asOf`’s calendar day (no longer needed).
    public static func isFullyPast(
        start: Date,
        end: Date?,
        type: ExceptionType,
        asOf: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let today = calendar.startOfDay(for: asOf)
        let last = lastCoveredDay(start: start, end: end, type: type, calendar: calendar)
        // Open-ended without endDate: last is far future → not past.
        if type != .singleDay && end == nil { return false }
        return last < today
    }

    /// Returns true if `day` falls on a skip exception for this alarm or its group.
    public static func isSkipped(
        day: Date,
        alarmId: UUID,
        groupId: UUID?,
        exceptions: [(alarmId: UUID?, groupId: UUID?, start: Date, end: Date?, action: ExceptionAction, type: ExceptionType)],
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        for ex in exceptions where ex.action == .skip {
            let matchesAlarm = ex.alarmId == alarmId
            let matchesGroup = groupId != nil && ex.groupId == groupId
            guard matchesAlarm || matchesGroup else { continue }

            let start = calendar.startOfDay(for: ex.start)
            if ex.type == .singleDay {
                if start == dayStart { return true }
            } else if let end = ex.end {
                let endDay = calendar.startOfDay(for: end)
                if dayStart >= start && dayStart <= endDay { return true }
            } else if dayStart >= start {
                return true
            }
        }
        return false
    }
}
