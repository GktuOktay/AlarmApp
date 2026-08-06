import Foundation

/// Value-type exception payload (Swift 6–safe across actors; `@Model` stays inside ModelActor).
public struct AlarmExceptionDraft: Sendable, Equatable {
    public var id: UUID
    public var groupId: UUID?
    public var type: ExceptionType
    public var startDate: Date
    public var endDate: Date?
    public var action: ExceptionAction
    public var replacementGroupId: UUID?

    public init(
        id: UUID = UUID(),
        groupId: UUID? = nil,
        type: ExceptionType,
        startDate: Date,
        endDate: Date? = nil,
        action: ExceptionAction,
        replacementGroupId: UUID? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.action = action
        self.replacementGroupId = replacementGroupId
    }
}

public struct AlarmGroupSummary: Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var timeStart: ClockTime
    public var timeEnd: ClockTime
    public var intervalMinutes: Int
    public var daysOfWeek: [Weekday]
    public var soundId: String
    public var isActive: Bool

    public init(
        id: UUID,
        name: String,
        timeStart: ClockTime,
        timeEnd: ClockTime,
        intervalMinutes: Int,
        daysOfWeek: [Weekday],
        soundId: String,
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.intervalMinutes = intervalMinutes
        self.daysOfWeek = daysOfWeek
        self.soundId = soundId
        self.isActive = isActive
    }
}

/// Repository boundary uses only `Sendable` value types — never pass `@Model` across actors.
public protocol AlarmRepository: Sendable {
    func createGroup(from prepared: PreparedAlarmGroup) async throws -> CreateAlarmGroupResult
    func cancelToday(groupId: UUID) async throws
    func skipWeek(groupId: UUID, weekStart: Date) async throws
    func scheduleException(_ draft: AlarmExceptionDraft) async throws
    func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws
    func todayContext() async throws -> TodayContext
    func fetchActiveGroups() async throws -> [AlarmGroupSummary]
}

public protocol NotificationScheduling: Sendable {
    func schedule(instanceId: UUID, fireDate: Date) async throws
    func cancelPending(instanceIds: [UUID]) async
}

public protocol WatchConnectivityService: Sendable {
    func send(_ message: WatchMessage) async throws
    var incomingMessages: AsyncStream<WatchMessage> { get }
}
