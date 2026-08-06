import Foundation
import SwiftData

@Model
public final class AlarmGroup {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var timeStart: ClockTime
    public var timeEnd: ClockTime
    public var intervalMinutes: Int
    public var daysOfWeek: [Weekday]
    public var soundId: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AlarmInstance.group)
    public var instances: [AlarmInstance] = []

    @Relationship(deleteRule: .cascade, inverse: \AlarmException.group)
    public var exceptions: [AlarmException] = []

    public init(
        id: UUID = UUID(),
        name: String,
        timeStart: ClockTime,
        timeEnd: ClockTime,
        intervalMinutes: Int,
        daysOfWeek: [Weekday],
        soundId: String,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.intervalMinutes = intervalMinutes
        self.daysOfWeek = daysOfWeek
        self.soundId = soundId
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class AlarmInstance {
    @Attribute(.unique) public var id: UUID
    public var group: AlarmGroup?
    public var scheduledDate: Date
    public var scheduledTime: ClockTime
    public var status: AlarmStatus
    public var cancelledReason: CancelReason?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        group: AlarmGroup? = nil,
        scheduledDate: Date,
        scheduledTime: ClockTime,
        status: AlarmStatus = .pending,
        cancelledReason: CancelReason? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.group = group
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.status = status
        self.cancelledReason = cancelledReason
        self.updatedAt = updatedAt
    }
}

@Model
public final class AlarmException {
    @Attribute(.unique) public var id: UUID
    public var group: AlarmGroup?
    public var type: ExceptionType
    public var startDate: Date
    public var endDate: Date?
    public var action: ExceptionAction
    public var replacementGroupId: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        group: AlarmGroup? = nil,
        type: ExceptionType,
        startDate: Date,
        endDate: Date? = nil,
        action: ExceptionAction,
        replacementGroupId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.group = group
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.action = action
        self.replacementGroupId = replacementGroupId
        self.createdAt = createdAt
    }
}

@Model
public final class WakeEventLog {
    @Attribute(.unique) public var id: UUID
    public var groupId: UUID
    public var detectedAt: Date
    public var source: WakeSource
    public var confirmed: Bool
    public var createdAt: Date

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
        self.source = source
        self.confirmed = confirmed
        self.createdAt = createdAt
    }
}
