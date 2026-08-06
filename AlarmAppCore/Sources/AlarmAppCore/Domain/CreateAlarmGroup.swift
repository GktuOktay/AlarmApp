import Foundation

public struct CreateAlarmGroupRequest: Sendable {
    public var name: String
    public var timeStart: ClockTime
    public var timeEnd: ClockTime
    public var intervalMinutes: Int
    public var daysOfWeek: [Weekday]
    public var soundId: String
    /// How many days ahead (from `fromDate`) to materialize instances.
    public var horizonDays: Int
    public var fromDate: Date
    public var calendar: Calendar
    public var now: Date

    public init(
        name: String,
        timeStart: ClockTime,
        timeEnd: ClockTime,
        intervalMinutes: Int,
        daysOfWeek: [Weekday],
        soundId: String = "default",
        horizonDays: Int = 14,
        fromDate: Date = Date(),
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.name = name
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.intervalMinutes = intervalMinutes
        self.daysOfWeek = daysOfWeek
        self.soundId = soundId
        self.horizonDays = horizonDays
        self.fromDate = fromDate
        self.calendar = calendar
        self.now = now
    }
}

public enum CreateAlarmGroupError: Error, Equatable, Sendable {
    case emptyName
    case noDaysSelected
    case invalidHorizon
    case generation(AlarmInstanceGenerationError)
}

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

public struct CreateAlarmGroupResult: Sendable {
    public let groupId: UUID
    public let instanceCount: Int
    public let clockTimesPerDay: [ClockTime]
    public let schedules: [AlarmSchedule]
    public let groupName: String
}

/// Builds an `AlarmGroup` + pending `AlarmInstance`s for matching weekdays in the horizon.
public struct CreateAlarmGroup {
    public init() {}

    public func prepare(_ request: CreateAlarmGroupRequest) throws -> PreparedAlarmGroup {
        let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CreateAlarmGroupError.emptyName }
        guard !request.daysOfWeek.isEmpty else { throw CreateAlarmGroupError.noDaysSelected }
        guard request.horizonDays > 0 else { throw CreateAlarmGroupError.invalidHorizon }

        let times: [ClockTime]
        do {
            times = try AlarmInstanceGenerator.clockTimes(
                start: request.timeStart,
                end: request.timeEnd,
                intervalMinutes: request.intervalMinutes
            )
        } catch let error as AlarmInstanceGenerationError {
            throw CreateAlarmGroupError.generation(error)
        }

        let daySet = Set(request.daysOfWeek)
        var calendar = request.calendar
        calendar.timeZone = request.calendar.timeZone

        let startOfFrom = calendar.startOfDay(for: request.fromDate)
        var specs: [PreparedInstanceSpec] = []

        for dayOffset in 0..<request.horizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfFrom) else { continue }
            let weekdayIndex = calendar.component(.weekday, from: day)
            guard let weekday = Weekday.from(calendarWeekday: weekdayIndex), daySet.contains(weekday) else {
                continue
            }
            for time in times {
                specs.append(PreparedInstanceSpec(scheduledDate: day, scheduledTime: time))
            }
        }

        let now = request.now
        return PreparedAlarmGroup(
            id: UUID(),
            name: name,
            timeStart: request.timeStart,
            timeEnd: request.timeEnd,
            intervalMinutes: request.intervalMinutes,
            daysOfWeek: request.daysOfWeek.sorted { $0.rawValue < $1.rawValue },
            soundId: request.soundId,
            createdAt: now,
            updatedAt: now,
            instances: specs
        )
    }
}

public struct PreparedInstanceSpec: Sendable, Equatable {
    public let scheduledDate: Date
    public let scheduledTime: ClockTime
}

public struct PreparedAlarmGroup: Sendable {
    public let id: UUID
    public let name: String
    public let timeStart: ClockTime
    public let timeEnd: ClockTime
    public let intervalMinutes: Int
    public let daysOfWeek: [Weekday]
    public let soundId: String
    public let createdAt: Date
    public let updatedAt: Date
    public let instances: [PreparedInstanceSpec]
}
