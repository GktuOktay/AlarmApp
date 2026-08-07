import Foundation

public struct TodayContext: Codable, Equatable, Sendable {
    public var date: Date
    public var activeGroups: [ActiveGroupSummary]
    /// S7 phone preference mirrored to Watch (default `true` for older payloads).
    public var autoWakeDetectionEnabled: Bool
    /// Active wake-schedule alarm id (nil if none / legacy payload).
    public var wakeAlarmId: UUID?
    /// Optional group of the wake-schedule alarm.
    public var wakeGroupId: UUID?
    /// Next wake fire used by Watch wake detection (nil if none / legacy).
    public var nextWakeFireDate: Date?

    public init(
        date: Date,
        activeGroups: [ActiveGroupSummary],
        autoWakeDetectionEnabled: Bool = true,
        wakeAlarmId: UUID? = nil,
        wakeGroupId: UUID? = nil,
        nextWakeFireDate: Date? = nil
    ) {
        self.date = date
        self.activeGroups = activeGroups
        self.autoWakeDetectionEnabled = autoWakeDetectionEnabled
        self.wakeAlarmId = wakeAlarmId
        self.wakeGroupId = wakeGroupId
        self.nextWakeFireDate = nextWakeFireDate
    }

    enum CodingKeys: String, CodingKey {
        case date
        case activeGroups
        case autoWakeDetectionEnabled
        case wakeAlarmId
        case wakeGroupId
        case nextWakeFireDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        activeGroups = try container.decode([ActiveGroupSummary].self, forKey: .activeGroups)
        autoWakeDetectionEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .autoWakeDetectionEnabled) ?? true
        wakeAlarmId = try container.decodeIfPresent(UUID.self, forKey: .wakeAlarmId)
        wakeGroupId = try container.decodeIfPresent(UUID.self, forKey: .wakeGroupId)
        nextWakeFireDate = try container.decodeIfPresent(Date.self, forKey: .nextWakeFireDate)
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
    public var alarmId: UUID
    public var time: ClockTime
    public var status: AlarmStatus

    public init(id: UUID, alarmId: UUID, time: ClockTime, status: AlarmStatus) {
        self.id = id
        self.alarmId = alarmId
        self.time = time
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id
        case alarmId
        case time
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        // Legacy Watch payloads omitted alarmId; zero UUID keeps decode alive.
        alarmId = try container.decodeIfPresent(UUID.self, forKey: .alarmId)
            ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        time = try container.decode(ClockTime.self, forKey: .time)
        status = try container.decode(AlarmStatus.self, forKey: .status)
    }
}

public enum WatchMessage: Codable, Equatable, Sendable {
    case todayContextUpdate(TodayContext)
    case wakeConfirmed(groupId: UUID, timestamp: Date)
    case snoozeApplied(alarmId: UUID, instanceId: UUID, fireDate: Date)
    case dismissApplied(alarmId: UUID, instanceId: UUID)
    case bulkCancelApplied(scope: BulkCancelScope, timestamp: Date)
}
