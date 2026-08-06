import Foundation

public protocol AlarmRepository {
    func createGroup(_ group: AlarmGroup) async throws
    func cancelToday(groupId: UUID) async throws
    func skipWeek(groupId: UUID, weekStart: Date) async throws
    func scheduleException(_ exception: AlarmException) async throws
    func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws
    func todayContext() async throws -> TodayContext
    func fetchActiveGroups() async throws -> [AlarmGroup]
}

public protocol NotificationScheduling {
    func schedule(instance: AlarmInstance) async throws
    func cancelPending(instanceIds: [UUID]) async
}

public protocol WatchConnectivityService {
    func send(_ message: WatchMessage) async throws
    var incomingMessages: AsyncStream<WatchMessage> { get }
}
