import Foundation

/// Days of week for repeating alarm groups (Monday-first product calendar).
public enum Weekday: Int, Codable, CaseIterable, Sendable, Hashable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    /// Maps to `Calendar` weekday (Sunday = 1 … Saturday = 7).
    public var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    public static func from(calendarWeekday: Int) -> Weekday? {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
}

public enum AlarmStatus: String, Codable, Sendable {
    case pending
    case fired
    case cancelled
    case snoozed
}

public enum CancelReason: String, Codable, Sendable {
    case wakeWatch
    case manualToday
    case manualWeek
    case exception
    case userDismiss
    case snoozed
    case wakePrompt
    case nextHoursWindow
}

public enum ExceptionType: String, Codable, Sendable {
    case singleDay
    case dateRange
    case weeklyOverride
}

public enum ExceptionAction: String, Codable, Sendable {
    case skip
    case replace
}

public enum WakeSource: String, Codable, Sendable {
    case watchManual
    case watchAuto
    case phoneManual
}
