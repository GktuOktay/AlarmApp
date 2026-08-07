import Foundation

public struct TodayContext: Codable, Equatable, Sendable {
    public var date: Date
    public var activeGroups: [ActiveGroupSummary]

    public init(date: Date, activeGroups: [ActiveGroupSummary]) {
        self.date = date
        self.activeGroups = activeGroups
    }
}

public struct ActiveGroupSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var remainingInstances: [InstanceSummary]

    public init(id: UUID, name: String, remainingInstances: [InstanceSummary]) {
        self.id = id
        self.name = name
        self.remainingInstances = remainingInstances
    }
}

public struct InstanceSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var time: ClockTime
    public var status: AlarmStatus

    public init(id: UUID, time: ClockTime, status: AlarmStatus) {
        self.id = id
        self.time = time
        self.status = status
    }
}

public enum WatchMessage: Codable, Equatable, Sendable {
    case todayContextUpdate(TodayContext)
    case wakeConfirmed(groupId: UUID, timestamp: Date)
    case snoozeApplied(alarmId: UUID, instanceId: UUID, fireDate: Date)
    case dismissApplied(alarmId: UUID, instanceId: UUID)
    case bulkCancelApplied(scope: BulkCancelScope, timestamp: Date)
}
