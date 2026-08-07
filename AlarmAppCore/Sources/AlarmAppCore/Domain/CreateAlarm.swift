import Foundation

public struct CreateAlarmRequest: Sendable {
    public var title: String
    public var time: ClockTime
    public var daysOfWeek: [Weekday]
    public var soundId: String
    public var soundVolume: Double
    public var groupId: UUID?
    /// When false, creates a one-shot instance on `fromDate` only (ignores daysOfWeek / horizon).
    public var repeats: Bool
    /// Used only when materializing near-term notification instances (not for pattern storage).
    public var horizonDays: Int
    /// Optional inclusive last calendar day for the pattern. When nil and repeating → open-ended.
    public var endDate: Date?
    public var snoozeEnabled: Bool
    public var snoozeMinutes: Int
    public var isWakeSchedule: Bool
    public var fromDate: Date
    public var calendar: Calendar
    public var now: Date

    public init(
        title: String,
        time: ClockTime,
        daysOfWeek: [Weekday],
        soundId: String = "default",
        soundVolume: Double = 1.0,
        groupId: UUID? = nil,
        repeats: Bool = true,
        horizonDays: Int = AlarmHorizon.notificationDays,
        endDate: Date? = nil,
        snoozeEnabled: Bool = true,
        snoozeMinutes: Int = SnoozePolicy.defaultMinutes,
        isWakeSchedule: Bool = false,
        fromDate: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) {
        self.title = title
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.soundId = soundId
        self.soundVolume = soundVolume
        self.groupId = groupId
        self.repeats = repeats
        self.horizonDays = horizonDays
        self.endDate = endDate
        self.snoozeEnabled = snoozeEnabled
        self.snoozeMinutes = snoozeMinutes
        self.isWakeSchedule = isWakeSchedule
        self.fromDate = fromDate
        self.calendar = calendar
        self.now = now
    }
}

public enum CreateAlarmError: Error, Equatable, Sendable {
    case emptyTitle
    case noDaysSelected
    case invalidHorizon
    case endDateBeforeStart
}

public enum AlarmFireDate {
    public static func make(day: Date, time: ClockTime, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: start)
    }
}

/// Rolling windows: pattern is stored; only a short near-term slice is materialized for notifications.
public enum AlarmHorizon {
    /// Days ahead to materialize `AlarmInstance` rows for local notifications.
    public static let notificationDays = 14
    /// Kept for callers that previously used a long open-ended materialization window.
    public static let openEndedDays = notificationDays
}

public struct AlarmSchedule: Sendable, Equatable, Identifiable {
    public var id: UUID { instanceId }
    public let instanceId: UUID
    public let fireDate: Date
    public let soundId: String
    public let soundVolume: Double

    public init(
        instanceId: UUID,
        fireDate: Date,
        soundId: String = "default",
        soundVolume: Double = 1.0
    ) {
        self.instanceId = instanceId
        self.fireDate = fireDate
        self.soundId = soundId
        self.soundVolume = soundVolume
    }
}

public struct CreateAlarmResult: Sendable {
    public let alarmId: UUID
    public let groupId: UUID?
    public let instanceCount: Int
    public let schedules: [AlarmSchedule]
    public let title: String
}

public struct PreparedInstanceSpec: Sendable, Equatable {
    public let scheduledDate: Date
    public let scheduledTime: ClockTime

    public init(scheduledDate: Date, scheduledTime: ClockTime) {
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
    }
}

public struct PreparedAlarm: Sendable {
    public let id: UUID
    public let title: String
    public let time: ClockTime
    public let daysOfWeek: [Weekday]
    public let soundId: String
    public let soundVolume: Double
    public let groupId: UUID?
    public let endsOn: Date?
    public let snoozeEnabled: Bool
    public let snoozeMinutes: Int
    public let isWakeSchedule: Bool
    public let createdAt: Date
    public let updatedAt: Date
    /// Only one-shot alarms carry a concrete instance here. Repeating alarms are pattern-only.
    public let instances: [PreparedInstanceSpec]

    public init(
        id: UUID,
        title: String,
        time: ClockTime,
        daysOfWeek: [Weekday],
        soundId: String,
        soundVolume: Double,
        groupId: UUID?,
        endsOn: Date?,
        snoozeEnabled: Bool = true,
        snoozeMinutes: Int = SnoozePolicy.defaultMinutes,
        isWakeSchedule: Bool = false,
        createdAt: Date,
        updatedAt: Date,
        instances: [PreparedInstanceSpec]
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.soundId = soundId
        self.soundVolume = soundVolume
        self.groupId = groupId
        self.endsOn = endsOn
        self.snoozeEnabled = snoozeEnabled
        self.snoozeMinutes = SnoozePolicy.clampMinutes(snoozeMinutes)
        self.isWakeSchedule = isWakeSchedule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.instances = instances
    }
}

/// Builds a single `Alarm` pattern. Repeating alarms do **not** pre-create a row per day.
public struct CreateAlarm {
    public init() {}

    public func prepare(_ request: CreateAlarmRequest) throws -> PreparedAlarm {
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw CreateAlarmError.emptyTitle }

        var calendar = request.calendar
        calendar.timeZone = request.calendar.timeZone
        let startOfFrom = calendar.startOfDay(for: request.fromDate)
        let now = request.now

        let soundId = AlarmSoundCatalog.resolve(request.soundId).id
        let soundVolume = AlarmSoundCatalog.clampVolume(request.soundVolume)

        if !request.repeats {
            let weekdayIndex = calendar.component(.weekday, from: startOfFrom)
            let weekday = Weekday.from(calendarWeekday: weekdayIndex) ?? .monday
            return PreparedAlarm(
                id: UUID(),
                title: title,
                time: request.time,
                daysOfWeek: [weekday],
                soundId: soundId,
                soundVolume: soundVolume,
                groupId: request.groupId,
                endsOn: startOfFrom,
                snoozeEnabled: request.snoozeEnabled,
                snoozeMinutes: request.snoozeMinutes,
                isWakeSchedule: request.isWakeSchedule,
                createdAt: now,
                updatedAt: now,
                instances: [PreparedInstanceSpec(scheduledDate: startOfFrom, scheduledTime: request.time)]
            )
        }

        guard !request.daysOfWeek.isEmpty else { throw CreateAlarmError.noDaysSelected }

        let endsOn: Date?
        if let endDate = request.endDate {
            let end = calendar.startOfDay(for: endDate)
            guard end >= startOfFrom else { throw CreateAlarmError.endDateBeforeStart }
            endsOn = end
        } else {
            endsOn = nil
        }

        return PreparedAlarm(
            id: UUID(),
            title: title,
            time: request.time,
            daysOfWeek: request.daysOfWeek.sorted { $0.rawValue < $1.rawValue },
            soundId: soundId,
            soundVolume: soundVolume,
            groupId: request.groupId,
            endsOn: endsOn,
            snoozeEnabled: request.snoozeEnabled,
            snoozeMinutes: request.snoozeMinutes,
            isWakeSchedule: request.isWakeSchedule,
            createdAt: now,
            updatedAt: now,
            instances: []
        )
    }
}
