import Foundation

/// Value-type exception payload (Swift 6–safe across actors; `@Model` stays inside ModelActor).
public struct AlarmExceptionDraft: Sendable, Equatable {
    public var id: UUID
    public var groupId: UUID?
    public var alarmId: UUID?
    public var type: ExceptionType
    public var startDate: Date
    public var endDate: Date?
    public var action: ExceptionAction
    public var replacementGroupId: UUID?

    public init(
        id: UUID = UUID(),
        groupId: UUID? = nil,
        alarmId: UUID? = nil,
        type: ExceptionType,
        startDate: Date,
        endDate: Date? = nil,
        action: ExceptionAction,
        replacementGroupId: UUID? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.alarmId = alarmId
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.action = action
        self.replacementGroupId = replacementGroupId
    }
}

public struct AlarmSummary: Sendable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var time: ClockTime
    public var daysOfWeek: [Weekday]
    public var soundId: String
    public var soundVolume: Double
    public var isActive: Bool
    public var snoozeEnabled: Bool
    public var snoozeMinutes: Int
    public var isWakeSchedule: Bool
    public var groupId: UUID?
    public var groupName: String?

    public init(
        id: UUID,
        title: String,
        time: ClockTime,
        daysOfWeek: [Weekday],
        soundId: String,
        soundVolume: Double = 1.0,
        isActive: Bool,
        snoozeEnabled: Bool = true,
        snoozeMinutes: Int = SnoozePolicy.defaultMinutes,
        isWakeSchedule: Bool = false,
        groupId: UUID? = nil,
        groupName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.soundId = soundId
        self.soundVolume = soundVolume
        self.isActive = isActive
        self.snoozeEnabled = snoozeEnabled
        self.snoozeMinutes = snoozeMinutes
        self.isWakeSchedule = isWakeSchedule
        self.groupId = groupId
        self.groupName = groupName
    }
}

public struct AlarmGroupSummary: Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var isActive: Bool
    public var alarmCount: Int

    public init(id: UUID, name: String, isActive: Bool, alarmCount: Int) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.alarmCount = alarmCount
    }
}

public struct DayAlarmItem: Sendable, Identifiable, Equatable {
    public var id: UUID { instanceId }
    public var instanceId: UUID
    public var alarmId: UUID
    public var groupId: UUID?
    public var title: String
    public var time: ClockTime
    public var status: AlarmStatus
    public var groupName: String?

    public init(
        instanceId: UUID,
        alarmId: UUID,
        groupId: UUID? = nil,
        title: String,
        time: ClockTime,
        status: AlarmStatus,
        groupName: String? = nil
    ) {
        self.instanceId = instanceId
        self.alarmId = alarmId
        self.groupId = groupId
        self.title = title
        self.time = time
        self.status = status
        self.groupName = groupName
    }
}

/// Repository boundary uses only `Sendable` value types — never pass `@Model` across actors.
public protocol AlarmRepository: Sendable {
    func createAlarm(from prepared: PreparedAlarm) async throws -> CreateAlarmResult
    func createGroup(name: String) async throws -> UUID
    func assignAlarm(alarmId: UUID, to groupId: UUID?) async throws
    /// Cancels today's pending instances for all alarms in the group.
    @discardableResult
    func cancelToday(groupId: UUID) async throws -> [UUID]
    /// Cancels today's pending instances for a single alarm.
    @discardableResult
    func cancelToday(alarmId: UUID) async throws -> [UUID]
    /// Skips an inclusive calendar-day range for a group (cancels pending instances + stores exception).
    @discardableResult
    func bypassDays(groupId: UUID, from startDay: Date, to endDay: Date) async throws -> [UUID]
    /// Skips an inclusive calendar-day range for one alarm.
    @discardableResult
    func bypassDays(alarmId: UUID, from startDay: Date, to endDay: Date) async throws -> [UUID]
    /// Skips a single calendar day for a group.
    @discardableResult
    func bypassDay(groupId: UUID, day: Date) async throws -> [UUID]
    /// Skips a single calendar day for one alarm.
    @discardableResult
    func bypassDay(alarmId: UUID, day: Date) async throws -> [UUID]
    func skipWeek(groupId: UUID, weekStart: Date) async throws
    func scheduleException(_ draft: AlarmExceptionDraft) async throws
    /// Deletes skip exceptions whose last covered day is before today.
    @discardableResult
    func purgeExpiredExceptions(asOf now: Date) async throws -> Int
    /// Whether a skip exception covers this day for the given alarm (alarm-level or its group).
    func isDayBypassed(alarmId: UUID, groupId: UUID?, day: Date) async throws -> Bool
    func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws
    /// Dismisses a single ringing/pending instance (`cancelled` + `userDismiss`).
    @discardableResult
    func dismissAlarm(alarmId: UUID, instanceId: UUID, now: Date) async throws -> [UUID]
    /// Snoozes an instance: marks old as `.snoozed`, creates a new pending schedule at `now + snoozeMinutes`.
    func snoozeAlarm(alarmId: UUID, instanceId: UUID, now: Date) async throws -> AlarmSchedule
    /// Bulk-cancels pending instances matching `scope`. Wake UI may pass `.wakePrompt`.
    @discardableResult
    func cancel(scope: BulkCancelScope, reason: CancelReason, now: Date) async throws -> [UUID]
    /// Marks at most one alarm as the wake schedule (`nil` clears).
    func setWakeScheduleAlarm(alarmId: UUID?) async throws
    func todayContext() async throws -> TodayContext
    func fetchActiveAlarms() async throws -> [AlarmSummary]
    func fetchActiveGroups() async throws -> [AlarmGroupSummary]
    func instances(on day: Date) async throws -> [DayAlarmItem]
    /// For active alarms, ensures pending instances exist through a short notification window (pattern remains source of truth).
    @discardableResult
    func extendOpenEndedSchedules(
        horizonDays: Int,
        calendar: Calendar,
        now: Date
    ) async throws -> [AlarmSchedule]
}

public enum AlarmNotificationAction {
    public static let categoryId = "ALARM_INSTANCE"
    public static let stopToday = "STOP_TODAY"
    public static let snooze = "SNOOZE"
}

public protocol NotificationScheduling: Sendable {
    func prepareCategories() async
    func requestAuthorization() async throws -> Bool
    func schedule(
        instanceId: UUID,
        alarmId: UUID,
        fireDate: Date,
        title: String,
        body: String,
        soundId: String,
        soundVolume: Double
    ) async throws
    func cancelPending(instanceIds: [UUID]) async
}

public protocol WatchConnectivityService: Sendable {
    func send(_ message: WatchMessage) async throws
    var incomingMessages: AsyncStream<WatchMessage> { get }
}
