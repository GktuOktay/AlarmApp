import Foundation
import SwiftData

@Model
public final class AlarmGroup {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Alarm.group)
    public var alarms: [Alarm] = []

    @Relationship(deleteRule: .cascade, inverse: \AlarmException.group)
    public var exceptions: [AlarmException] = []

    public init(
        id: UUID = UUID(),
        name: String,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class Alarm {
    @Attribute(.unique) public var id: UUID
    public var title: String
    /// Minutes from midnight — stored as Int so SwiftData can query/sort (Codable `ClockTime` is not a keypath).
    public var timeMinutes: Int
    /// Stored as raw `Weekday` ints for SwiftData compatibility.
    public var daysOfWeekRaw: [Int]
    public var soundId: String
    public var soundVolume: Double
    public var isActive: Bool
    public var snoozeEnabled: Bool
    public var snoozeMinutes: Int
    public var isWakeSchedule: Bool
    /// Optional inclusive end date; nil = açık uçlu (horizon ile üretilir).
    public var endsOn: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var group: AlarmGroup?

    @Relationship(deleteRule: .cascade, inverse: \AlarmInstance.alarm)
    public var instances: [AlarmInstance] = []

    public var time: ClockTime {
        get { ClockTime.from(minutesFromMidnight: timeMinutes) }
        set { timeMinutes = newValue.minutesFromMidnight }
    }

    public var daysOfWeek: [Weekday] {
        get { daysOfWeekRaw.compactMap(Weekday.init(rawValue:)) }
        set { daysOfWeekRaw = newValue.map(\.rawValue) }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        time: ClockTime,
        daysOfWeek: [Weekday],
        soundId: String = "default",
        soundVolume: Double = 1.0,
        isActive: Bool = true,
        snoozeEnabled: Bool = true,
        snoozeMinutes: Int = SnoozePolicy.defaultMinutes,
        isWakeSchedule: Bool = false,
        endsOn: Date? = nil,
        group: AlarmGroup? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.timeMinutes = time.minutesFromMidnight
        self.daysOfWeekRaw = daysOfWeek.map(\.rawValue)
        self.soundId = soundId
        self.soundVolume = soundVolume
        self.isActive = isActive
        self.snoozeEnabled = snoozeEnabled
        self.snoozeMinutes = SnoozePolicy.clampMinutes(snoozeMinutes)
        self.isWakeSchedule = isWakeSchedule
        self.endsOn = endsOn
        self.group = group
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class AlarmInstance {
    @Attribute(.unique) public var id: UUID
    public var alarm: Alarm?
    public var scheduledDate: Date
    public var scheduledTimeMinutes: Int
    public var statusRaw: String
    public var cancelledReasonRaw: String?
    public var updatedAt: Date

    public var scheduledTime: ClockTime {
        get { ClockTime.from(minutesFromMidnight: scheduledTimeMinutes) }
        set { scheduledTimeMinutes = newValue.minutesFromMidnight }
    }

    public var status: AlarmStatus {
        get { AlarmStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    public var cancelledReason: CancelReason? {
        get {
            guard let cancelledReasonRaw else { return nil }
            return CancelReason(rawValue: cancelledReasonRaw)
        }
        set { cancelledReasonRaw = newValue?.rawValue }
    }

    public init(
        id: UUID = UUID(),
        alarm: Alarm? = nil,
        scheduledDate: Date,
        scheduledTime: ClockTime,
        status: AlarmStatus = .pending,
        cancelledReason: CancelReason? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.alarm = alarm
        self.scheduledDate = scheduledDate
        self.scheduledTimeMinutes = scheduledTime.minutesFromMidnight
        self.statusRaw = status.rawValue
        self.cancelledReasonRaw = cancelledReason?.rawValue
        self.updatedAt = updatedAt
    }
}

@Model
public final class AlarmException {
    @Attribute(.unique) public var id: UUID
    public var group: AlarmGroup?
    /// Optional alarm-level target (mutually exclusive with group for skip bypass).
    public var alarmId: UUID?
    public var typeRaw: String
    public var startDate: Date
    public var endDate: Date?
    public var actionRaw: String
    public var replacementGroupId: UUID?
    public var createdAt: Date

    public var type: ExceptionType {
        get { ExceptionType(rawValue: typeRaw) ?? .singleDay }
        set { typeRaw = newValue.rawValue }
    }

    public var action: ExceptionAction {
        get { ExceptionAction(rawValue: actionRaw) ?? .skip }
        set { actionRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        group: AlarmGroup? = nil,
        alarmId: UUID? = nil,
        type: ExceptionType,
        startDate: Date,
        endDate: Date? = nil,
        action: ExceptionAction,
        replacementGroupId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.group = group
        self.alarmId = alarmId
        self.typeRaw = type.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.actionRaw = action.rawValue
        self.replacementGroupId = replacementGroupId
        self.createdAt = createdAt
    }
}

@Model
public final class WakeEventLog {
    @Attribute(.unique) public var id: UUID
    public var groupId: UUID
    public var detectedAt: Date
    public var sourceRaw: String
    public var confirmed: Bool
    public var createdAt: Date

    public var source: WakeSource {
        get { WakeSource(rawValue: sourceRaw) ?? .phoneManual }
        set { sourceRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        groupId: UUID,
        detectedAt: Date,
        source: WakeSource,
        confirmed: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.detectedAt = detectedAt
        self.sourceRaw = source.rawValue
        self.confirmed = confirmed
        self.createdAt = createdAt
    }
}
